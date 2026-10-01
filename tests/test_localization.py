#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check translation coverage and printf argument safety before launching the app."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'src/app'
languages = ['en', 'ru', 'zh-Hans']


def catalog(path):
    data = subprocess.check_output(['/usr/bin/plutil', '-convert', 'json', '-o', '-', str(path)])
    result = json.loads(data)
    # plutil silently overwrites duplicate keys; catch those in the source as well.
    keys = re.findall(r'^"((?:\\.|[^"\\])*)"\s*=', path.read_text(), re.MULTILINE)
    assert len(keys) == len(set(keys)) == len(result), f'Duplicate translation key: {path}'
    return result


catalogs = {language: catalog(APP / f'Resources/{language}.lproj/Localizable.strings') for language in languages}
english = catalogs['en']
for language, strings in catalogs.items():
    assert strings.keys() == english.keys(), f'Missing or extra keys in {language}'
    for key, value in strings.items():
        assert isinstance(value, str) and value.strip(), (language, key)
        assert re.findall(r'%(?:@|d)', key) == re.findall(r'%(?:@|d)', value), f'Format arguments changed: {language}: {key}'
        assert '%' not in re.sub(r'%(?:@|d)', '', value), f'Unsupported format specifier: {language}: {key}'
        if language == 'en':
            assert key == value, f'English key changed: {key}'

# The self-test diagnostics are developer output, not app UI. Ignore only those blocks.
keys = set()
for path in APP.glob('*.swift'):
    source = path.read_text()
    if '    static func selfTest' in source:
        start = source.index('    static func selfTest')
        if path.name == 'XprinterLabels.swift':
            source = source[:start] + source[source.index('\nstruct PDFPreview'):]
        else:
            source = source[:start]
    keys.update(re.findall(r'(?:L|LF|LabelFailure\.message|LabelFailure\.formatted)\("([^"\\]*)"', source))
    # Keys selected dynamically: printer statuses, input placeholders, menu actions, notices.
    if path.name == 'XprinterLabels.swift':
        keys.update(re.findall(r'(?:message|status) = "([^"\\]*)"', source))
        keys.update(re.findall(r'\("([^"\\]*)", (?:#selector|Selector)', source))
keys.update(['QR content or URL', 'Barcode value / label text',
             'Label size and stock saved for other Mac apps too.',
             'USB printer configured. Choose the label size loaded in your printer.'])
assert keys <= english.keys(), f'Untranslated app strings: {sorted(keys - english.keys())}'
for language in languages:
    built = ROOT / f'build/stage/Applications/Open Xprinter.app/Contents/Resources/{language}.lproj/Localizable.strings'
    assert catalog(built) == catalogs[language], f'Built catalog is stale: {language}'
assert '标签尺寸' == catalogs['zh-Hans']['Label size']
assert 'Размер этикетки' == catalogs['ru']['Label size']
print(f'{len(english)} keys in English, Russian and Simplified Chinese: coverage, duplicates and format arguments PASS')
