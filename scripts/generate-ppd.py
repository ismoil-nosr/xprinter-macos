#!/usr/bin/env python3
"""Generate our own MIT-licensed PPD; no vendor PPD is read or embedded."""
from pathlib import Path

SIZES = [(30, 20), (40, 30), (50, 30), (50, 50), (58, 40),
         (60, 40), (70, 50), (76, 50), (58, 100), (76, 150)]


def media_name(width, height):
    # Standard metric PPD identifiers allow macOS PrintCore to retain feed direction.
    return (f"{height}x{width}mmRotated.Fullbleed" if width > height
            else f"{width}x{height}mm.Fullbleed")


def generate():
    default = media_name(58, 40)
    lines = [
        '*PPD-Adobe: "4.3"', '*% SPDX-License-Identifier: MIT',
        '*% Copyright (c) 2026 Ismoil Nosr', '*FormatVersion: "4.3"',
        '*FileVersion: "0.3.0"', '*LanguageVersion: English', '*LanguageEncoding: ISOLatin1',
        '*PCFileName: "XP330BOS.PPD"', '*Manufacturer: "Open Xprinter"',
        '*Product: "(XP-330B)"', '*ModelName: "Open Xprinter XP-330B"',
        '*ShortNickName: "XP-330B Open Source"',
        '*NickName: "Xprinter XP-330B Labels (Open Source)"',
        '*ColorDevice: False', '*DefaultColorSpace: Gray', '*FileSystem: False',
        '*LanguageLevel: "3"', '*PSVersion: "(3010.000) 0"', '*Throughput: "1"', '*LandscapeOrientation: Plus90',
        '*cupsVersion: 2.0', '*cupsManualCopies: False', '*cupsMaxCopies: 100',
        '*cupsFilter: "application/vnd.cups-raster 0 rastertoxp330b"',
        '*OpenUI *Resolution/Resolution: PickOne', '*OrderDependency: 10 AnySetup *Resolution',
        '*DefaultResolution: 203dpi',
        '*Resolution 203dpi/203 dpi: "<</HWResolution[203 203]>>setpagedevice"',
        '*CloseUI: *Resolution',
        '*OpenUI *ColorModel/Color mode: PickOne', '*OrderDependency: 10 AnySetup *ColorModel',
        '*DefaultColorModel: Gray',
        '*ColorModel Gray/Black and white: "<</cupsColorSpace 3/cupsColorOrder 0/cupsBitsPerColor 8>>setpagedevice"',
        '*CloseUI: *ColorModel',
    ]
    for key in ['PageSize', 'PageRegion']:
        lines += [f'*OpenUI *{key}/Label size: PickOne', f'*OrderDependency: 20 AnySetup *{key}',
                  f'*Default{key}: {default}']
        for width, height in SIZES:
            w, h = width * 72 / 25.4, height * 72 / 25.4
            lines.append(f'*{key} {media_name(width, height)}/{width} x {height} mm: "<</PageSize[{w:.5f} {h:.5f}]/ImagingBBox null>>setpagedevice"')
        lines.append(f'*CloseUI: *{key}')
    lines += [f'*DefaultImageableArea: {default}', f'*DefaultPaperDimension: {default}']
    for width, height in SIZES:
        w, h = width * 72 / 25.4, height * 72 / 25.4
        lines += [f'*ImageableArea {media_name(width, height)}: "0 0 {w:.5f} {h:.5f}"',
                  f'*PaperDimension {media_name(width, height)}: "{w:.5f} {h:.5f}"']
    lines += [
        '*HWMargins: "0 0 0 0"', '*VariablePaperSize: True', '*MaxMediaWidth: "215.43307"',
        '*MaxMediaHeight: "2834.64567"', '*CustomPageSize True: "pop pop pop <</PageSize[5 -2 roll]/ImagingBBox null>>setpagedevice"',
        '*ParamCustomPageSize Width: 1 points 56.69291 215.43307',
        '*ParamCustomPageSize Height: 2 points 28.34646 2834.64567',
        '*ParamCustomPageSize WidthOffset: 3 points 0 0',
        '*ParamCustomPageSize HeightOffset: 4 points 0 0',
        '*ParamCustomPageSize Orientation: 5 int 0 0',
    ]
    def choices(key, title, default_value, values):
        lines.extend([f'*OpenUI *{key}/{title}: PickOne', f'*OrderDependency: 30 AnySetup *{key}',
                      f'*Default{key}: {default_value}'])
        lines.extend(f'*{key} {value}/{label}: ""' for value, label in values)
        lines.append(f'*CloseUI: *{key}')
    choices('PaperType', 'Loaded stock', 'LabelGaps', [('LabelGaps', 'Labels with gaps'),
             ('LabelMark', 'Black mark labels'), ('Continue', 'Continuous roll')])
    choices('GapsHeight', 'Gap or black mark height', 2, [(n, f'{n} mm') for n in range(11)])
    choices('Darkness', 'Darkness', 7, [(n, str(n)) for n in range(16)])
    choices('PrintSpeed', 'Print speed', 3, [(n, f'{n} inches per second') for n in range(2, 5)])
    choices('MediaMethod', 'Printing method', 'Direct', [('Direct', 'Direct thermal')])
    lines += ['*OpenUI *Collate/Collate: Boolean', '*OrderDependency: 10 AnySetup *Collate',
              '*DefaultCollate: False', '*Collate True/Yes: "<</Collate true>>setpagedevice"',
              '*Collate False/No: "<</Collate false>>setpagedevice"', '*CloseUI: *Collate']
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    target = Path(__file__).resolve().parents[1] / 'driver/Open-Xprinter-XP330B.ppd'
    target.write_text(generate(), encoding='ascii')
    print(target.name)
