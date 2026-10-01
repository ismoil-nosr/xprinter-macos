#!/usr/bin/env python3
"""Behavior tests for the native filter, including malformed input and real PDF RIP."""
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/tests'
FILTER = ROOT / 'build/stage/Library/Printers/OpenXprinter/rastertoxp330b'
PPD = ROOT / 'driver/Open-Xprinter-XP330B.ppd'
FIXTURE = ROOT / 'build/make-raster'
ENV = dict(os.environ, PPD=str(PPD), LC_ALL='C')


def run_filter(path, options='', copies=1, stdin=False, env=ENV):
    args = [str(FILTER), '1', 'test', 'Synthetic label', str(copies), options]
    return subprocess.run(args if stdin else args + [str(path)],
                          input=path.read_bytes() if stdin else None,
                          capture_output=True, env=env, timeout=10)


def bitmaps(data):
    result = []
    cursor = 0
    while True:
        match = re.search(rb'BITMAP (\d+),(\d+),(\d+),(\d+),(\d+),', data[cursor:])
        if not match:
            return result
        start = cursor + match.end()
        stride, height = int(match[3]), int(match[4])
        end = start + stride * height
        assert end <= len(data) and int(match[5]) == 0
        result.append((stride, height, data[start:end]))
        cursor = end


class FilterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        OUTPUT.mkdir(parents=True, exist_ok=True)

    def fixture(self, name='gray1', copies=1, pages=1):
        path = OUTPUT / f'{name}-{copies}-{pages}.raster'
        subprocess.run([str(FIXTURE), str(path), name, str(copies), str(pages)], check=True, timeout=10)
        return path

    def test_pixel_polarity_padding_and_color_modes(self):
        for fmt in ['gray1', 'black1', 'gray8', 'black8', 'rgb8']:
            with self.subTest(format=fmt):
                result = run_filter(self.fixture(fmt))
                self.assertEqual(result.returncode, 0, result.stderr)
                stride, height, pixels = bitmaps(result.stdout)[0]
                self.assertEqual((stride, height), (21, 81))
                for y in range(height):
                    row = bytearray([255] * stride)
                    if y % 2 == 0:
                        for x in [0, 7, 8, 160]:
                            row[x // 8] &= ~(128 >> (x % 8))
                    self.assertEqual(pixels[y * stride:(y + 1) * stride], row)

    def test_home_once_after_size_and_gap_before_bitmap(self):
        result = run_filter(self.fixture(pages=3))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count(b'HOME\r\n'), 1)
        self.assertEqual(len(bitmaps(result.stdout)), 3)
        self.assertLess(result.stdout.index(b'SIZE '), result.stdout.index(b'HOME'))
        self.assertLess(result.stdout.index(b'GAP '), result.stdout.index(b'HOME'))
        self.assertLess(result.stdout.index(b'HOME'), result.stdout.index(b'CLS'))

    def test_continuous_roll_does_not_home(self):
        result = run_filter(self.fixture(), 'PaperType=Continue GapsHeight=2')
        self.assertEqual(result.returncode, 0)
        self.assertNotIn(b'HOME', result.stdout)
        self.assertIn(b'GAP 0 mm,0 mm', result.stdout)

    def test_black_marks(self):
        result = run_filter(self.fixture(), 'PaperType=LabelMark GapsHeight=3')
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'BLINE 3 mm,0 mm', result.stdout)
        self.assertIn(b'HOME\r\n', result.stdout)

    def test_copies_are_not_multiplied(self):
        result = run_filter(self.fixture(copies=2), copies=2)
        self.assertIn(b'PRINT 1,2\r\n', result.stdout)
        self.assertEqual(result.stdout.count(b'PRINT '), 1)
        # The raster header wins when a RIP already expanded the copies into pages.
        result = run_filter(self.fixture(copies=1, pages=2), copies=2)
        self.assertEqual(result.stdout.count(b'PRINT 1,1\r\n'), 2)

    def test_stdin_and_filename_match(self):
        path = self.fixture()
        file = run_filter(path)
        stream = run_filter(path, stdin=True)
        self.assertEqual(file.returncode, stream.returncode)
        self.assertEqual(file.stdout, stream.stdout)

    def test_rejects_unsupported_headers_without_printer_output(self):
        for fmt in ['wide', 'tall', 'dpi', 'rgba']:
            with self.subTest(format=fmt):
                result = run_filter(self.fixture(fmt))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, b'')
        result = run_filter(self.fixture(copies=101))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b'')

    def test_invalid_and_truncated_inputs_emit_nothing(self):
        path = self.fixture()
        for content in [b'', b'not a raster', path.read_bytes()[:20], path.read_bytes()[:-50]]:
            broken = OUTPUT / 'broken.raster'
            broken.write_bytes(content)
            result = run_filter(broken)
            self.assertNotEqual(result.returncode, 0, content[:20])
            self.assertEqual(result.stdout, b'')

    def test_rejects_unsafe_options_and_missing_profile(self):
        path = self.fixture()
        for options in ['GapsHeight=-1', 'GapsHeight=0', 'Darkness=999', 'PrintSpeed=12',
                        'PaperType=Other', 'MediaMethod=Transfer', 'Threshold=0']:
            result = run_filter(path, options)
            self.assertNotEqual(result.returncode, 0, options)
            self.assertEqual(result.stdout, b'')
        result = run_filter(path, copies=101)
        self.assertNotEqual(result.returncode, 0)
        result = run_filter(path, env=dict(ENV, PPD='/does-not-exist.ppd'))
        self.assertNotEqual(result.returncode, 0)

    def test_real_pdf_cups_pipeline(self):
        cases = [('barcode-30x20', 'LabelGaps', 1, 30, 20, 1),
                 ('barcode-58x40', 'LabelGaps', 1, 58, 40, 1),
                 ('qr-30x20', 'LabelGaps', 1, 30, 20, 1),
                 ('qr-58x40', 'LabelGaps', 1, 58, 40, 1),
                 ('unicode-50x30', 'LabelGaps', 1, 50, 30, 1),
                 ('batch-58x40', 'LabelGaps', 1, 58, 40, 3),
                 ('barcode-58x40', 'LabelGaps', 2, 58, 40, 1),
                 ('barcode-58x40', 'Continue', 1, 58, 40, 1),
                 ('barcode-58x40', 'LabelMark', 1, 58, 40, 1),
                 ('imported-58x40', 'LabelGaps', 1, 58, 40, 1)]
        report = []
        for name, stock, copies, width, height, pages in cases:
            with self.subTest(pdf=name, stock=stock, copies=copies):
                raster = OUTPUT / f'{name}-{stock}-{copies}.raster'
                pdf = OUTPUT / f'{name}.pdf'
                media = (f'{height}x{width}mmRotated.Fullbleed' if width > height
                         else f'{width}x{height}mm.Fullbleed')
                args = ['/usr/sbin/cupsfilter', '-p', str(PPD), '-m', 'application/vnd.cups-raster',
                        '-n', str(copies), '-o', f'PageSize={media}', '-o', 'Resolution=203dpi',
                        '-o', 'fit-to-page=false', '-o', 'number-up=1', '-o', 'scaling=100', str(pdf)]
                with raster.open('wb') as out:
                    rip = subprocess.run(args, stdout=out, stderr=subprocess.PIPE, timeout=30)
                self.assertEqual(rip.returncode, 0, rip.stderr)
                result = run_filter(raster, f'PaperType={stock}', copies)
                self.assertEqual(result.returncode, 0, result.stderr)
                maps = bitmaps(result.stdout)
                self.assertEqual(len(maps), pages)
                self.assertEqual(result.stdout.count(b'HOME\r\n'), 0 if stock == 'Continue' else 1)
                self.assertEqual(result.stdout.count(f'PRINT 1,{copies}\r\n'.encode()), pages)
                for stride, rows, _ in maps:
                    self.assertLessEqual(abs(rows - round(height * 203 / 25.4)), 1)
                    self.assertLessEqual(abs(stride * 8 - round(width * 203 / 25.4)), 8)
                output = OUTPUT / f'{name}-{stock}-{copies}.tspl'
                output.write_bytes(result.stdout)
                report.append(dict(case=output.name, pages=pages, copies=copies, passed=True))
        (OUTPUT / 'cups-pipeline.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
