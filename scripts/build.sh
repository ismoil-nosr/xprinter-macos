#!/bin/bash
# SPDX-License-Identifier: MIT
# Native universal2 build with Apple SDKs; no Homebrew or proprietary dependencies.
set -Eeuo pipefail
export LC_ALL=C
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$PROJECT_DIR"
[[ "$(/usr/bin/uname -s)" == Darwin ]] || { printf '%s\n' 'Build on macOS with Xcode Command Line Tools.' >&2; exit 1; }
VERSION="$(<VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
BUILD_DIR="$PROJECT_DIR/build"
STAGE_DIR="$BUILD_DIR/stage"
APP="$STAGE_DIR/Applications/Open Xprinter.app"
DRIVER="$STAGE_DIR/Library/Printers/OpenXprinter"
mkdir -p "$BUILD_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DRIVER" "$STAGE_DIR/usr/libexec/cups/filter" dist
python3 scripts/generate-ppd.py
for arch in arm64 x86_64; do
    /usr/bin/xcrun clang -std=c11 -Wall -Wextra -Werror -Wno-deprecated-declarations -O2 \
        -target "$arch-apple-macos14" src/filter/rastertoxp330b.c -lcups -o "$BUILD_DIR/rastertoxp330b-$arch"
    /usr/bin/xcrun swiftc -swift-version 5 -O -target "$arch-apple-macosx14.0" \
        src/app/Localization.swift src/app/LabelRenderer.swift src/app/MCPRenderer.swift src/app/XprinterLabels.swift -o "$BUILD_DIR/OpenXprinter-$arch" \
        -framework AppKit -framework SwiftUI -framework CoreImage -framework PDFKit -framework Vision
done
/usr/bin/lipo -create "$BUILD_DIR/rastertoxp330b-arm64" "$BUILD_DIR/rastertoxp330b-x86_64" -output "$DRIVER/rastertoxp330b"
/usr/bin/lipo -create "$BUILD_DIR/OpenXprinter-arm64" "$BUILD_DIR/OpenXprinter-x86_64" -output "$APP/Contents/MacOS/OpenXprinter"
/usr/bin/install -m 0644 driver/Open-Xprinter-XP330B.ppd LICENSE "$DRIVER/"
/usr/bin/install -m 0755 scripts/setup-printer.sh scripts/printer-common.sh scripts/uninstall.sh "$DRIVER/"
/bin/ln -sfn /Library/Printers/OpenXprinter/rastertoxp330b "$STAGE_DIR/usr/libexec/cups/filter/rastertoxp330b"
/usr/bin/xcrun swift scripts/MakeIcon.swift "$BUILD_DIR/OpenXprinter.iconset"
/usr/bin/iconutil -c icns "$BUILD_DIR/OpenXprinter.iconset" -o "$APP/Contents/Resources/OpenXprinter.icns"
/usr/bin/install -m 0644 LICENSE README.md docs/INSTALL.md "$APP/Contents/Resources/"
for language in en ru zh-Hans; do
    mkdir -p "$APP/Contents/Resources/$language.lproj"
    /usr/bin/install -m 0644 "src/app/Resources/$language.lproj/Localizable.strings" "$APP/Contents/Resources/$language.lproj/"
done
/usr/bin/install -m 0644 docs/README.ru.md "$APP/Contents/Resources/ru.lproj/README.md"
/usr/bin/install -m 0644 docs/README.zh-CN.md "$APP/Contents/Resources/zh-Hans.lproj/README.md"
python3 - "$APP" "$VERSION" <<'PY'
from pathlib import Path
import plistlib, sys
app, version = Path(sys.argv[1]), sys.argv[2]
info = {
    'CFBundleExecutable': 'OpenXprinter', 'CFBundleIdentifier': 'com.ismoilnosr.openxprinter',
    'CFBundleName': 'Open Xprinter', 'CFBundleDisplayName': 'Open Xprinter',
    'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'OpenXprinter',
    'CFBundleShortVersionString': version, 'CFBundleVersion': version,
    'CFBundleDevelopmentRegion': 'en', 'CFBundleLocalizations': ['en', 'ru', 'zh-Hans'],
    'LSMinimumSystemVersion': '14.0', 'NSHighResolutionCapable': True,
    'NSPrincipalClass': 'NSApplication', 'NSHumanReadableCopyright': 'Copyright 2026 Ismoil Nosr. MIT License.',
    'CFBundleDocumentTypes': [{'CFBundleTypeName': 'Labels', 'CFBundleTypeRole': 'Viewer',
        'LSHandlerRank': 'Alternate', 'LSItemContentTypes': ['com.adobe.pdf', 'public.png',
            'public.jpeg', 'public.comma-separated-values-text']}],
}
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
signing=(-s -)
if [[ -n "${APPLICATION_SIGNING_IDENTITY:-}" ]]; then signing=(-s "$APPLICATION_SIGNING_IDENTITY" --options runtime --timestamp); fi
/usr/bin/codesign --force "${signing[@]}" "$DRIVER/rastertoxp330b"
/usr/bin/codesign --force "${signing[@]}" "$APP"
/usr/bin/codesign --verify --strict "$DRIVER/rastertoxp330b"
/usr/bin/codesign --verify --deep --strict "$APP"
for executable in "$DRIVER/rastertoxp330b" "$APP/Contents/MacOS/OpenXprinter"; do /usr/bin/lipo "$executable" -verify_arch arm64 x86_64; done
/usr/bin/cupstestppd -W all driver/Open-Xprinter-XP330B.ppd
/usr/bin/pkgbuild --analyze --root "$STAGE_DIR" "$BUILD_DIR/components.plist"
python3 - "$BUILD_DIR/components.plist" <<'PY'
import plistlib, sys
from pathlib import Path
path = Path(sys.argv[1]); components = plistlib.loads(path.read_bytes())
for item in components:
    item['BundleIsRelocatable'] = False
    item['BundleIsVersionChecked'] = True
    item['BundleOverwriteAction'] = 'upgrade'
path.write_bytes(plistlib.dumps(components))
PY
/usr/bin/pkgbuild --root "$STAGE_DIR" --component-plist "$BUILD_DIR/components.plist" \
    --scripts packaging/scripts --identifier com.ismoilnosr.openxprinter --version "$VERSION" \
    --install-location / --ownership recommended "$BUILD_DIR/OpenXprinter-component.pkg"
python3 scripts/make-distribution.py "$VERSION" "$BUILD_DIR/Distribution.xml"
suffix=unsigned
product_args=(--distribution "$BUILD_DIR/Distribution.xml" --resources "$BUILD_DIR/resources" --package-path "$BUILD_DIR")
if [[ -n "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then
    [[ -n "${APPLICATION_SIGNING_IDENTITY:-}" ]] || { printf '%s\n' 'Supply both application and installer signing identities.' >&2; exit 1; }
    suffix=signed; product_args+=(--sign "$INSTALLER_SIGNING_IDENTITY" --timestamp)
fi
OUTPUT="$PROJECT_DIR/dist/Open-Xprinter-$VERSION-universal-$suffix.pkg"
mkdir -p "$BUILD_DIR/resources"
/usr/bin/install -m 0644 packaging/welcome.html packaging/conclusion.html "$BUILD_DIR/resources/"
for language in en ru zh-Hans; do
    mkdir -p "$BUILD_DIR/resources/$language.lproj"
    if [[ "$language" == en ]]; then
        /usr/bin/install -m 0644 packaging/welcome.html packaging/conclusion.html "$BUILD_DIR/resources/$language.lproj/"
    else
        /usr/bin/install -m 0644 "packaging/$language.lproj/welcome.html" "packaging/$language.lproj/conclusion.html" "$BUILD_DIR/resources/$language.lproj/"
    fi
done
/usr/bin/install -m 0644 LICENSE "$BUILD_DIR/resources/LICENSE.txt"
/usr/bin/productbuild "${product_args[@]}" "$OUTPUT"
printf 'Built %s\n' "$OUTPUT"
