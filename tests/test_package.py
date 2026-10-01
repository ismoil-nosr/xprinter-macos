#!/usr/bin/env python3
"""Inspect the built package without running installer scripts or modifying printers."""
from pathlib import Path
import plistlib
import os
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
version = (ROOT / 'VERSION').read_text().strip()
packages = list((ROOT / 'dist').glob(f'Open-Xprinter-{version}-universal-*.pkg'))
assert packages, 'Missing installer'
for directory in ['scripts', 'packaging/scripts', 'tests']:
    for script in (ROOT / directory).glob('*'):
        if script.suffix != '.sh' and directory != 'packaging/scripts':
            continue
        for command in set(re.findall(r'/(?:usr/(?:bin|sbin)|bin|sbin)/[A-Za-z0-9_+-]+', script.read_text())):
            assert os.access(command, os.X_OK), f'Missing macOS tool referenced by {script.name}: {command}'
for package in packages:
    with tempfile.TemporaryDirectory(prefix='open-xprinter-package-') as directory:
        expanded = Path(directory) / 'expanded'
        subprocess.run(['/usr/sbin/pkgutil', '--expand-full', str(package), str(expanded)], check=True)
        distribution = ET.parse(expanded / 'Distribution').getroot()
        assert distribution.find('allowed-os-versions/os-version').get('min') == '14.0'
        payload = expanded / 'OpenXprinter-component.pkg/Payload'
        app = payload / 'Applications/Open Xprinter.app'
        driver = payload / 'Library/Printers/OpenXprinter'
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == 'com.ismoilnosr.openxprinter'
        assert info['CFBundleShortVersionString'] == version
        for binary in [driver / 'rastertoxp330b', app / 'Contents/MacOS/OpenXprinter']:
            subprocess.run(['/usr/bin/lipo', str(binary), '-verify_arch', 'arm64', 'x86_64'], check=True)
            subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(binary)], check=True)
        symlink = payload / 'usr/libexec/cups/filter/rastertoxp330b'
        assert symlink.is_symlink()
        assert str(symlink.readlink()) == '/Library/Printers/OpenXprinter/rastertoxp330b'
        for script in ['setup-printer.sh', 'printer-common.sh', 'uninstall.sh']:
            assert (driver / script).stat().st_mode & 0o111
        assert (driver / 'LICENSE').is_file()
        assert (expanded / 'OpenXprinter-component.pkg/Scripts/postinstall').is_file()
        for file in payload.rglob('*'):
            if file.is_symlink() or not file.is_file():
                continue
            assert not file.stat().st_mode & 0o022, f'Group/world-writable payload: {file}'
            if file.suffix in {'.sh', '.ppd', '.md', '.plist'}:
                data = file.read_bytes()
                assert b'/Users/' not in data and b'/Downloads/' not in data, file
    print(f'{package.name}: package layout, architecture, signatures and permissions PASS')
