#!/bin/bash
# SPDX-License-Identifier: MIT
# Run ONLY on an ephemeral CI Mac; installs and uninstalls this package twice.
set -Eeuo pipefail
[[ "${CI:-}" == true && "${GITHUB_ACTIONS:-}" == true ]] || { printf '%s\n' 'This installation test is restricted to GitHub Actions runners.' >&2; exit 1; }
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERSION="$(<"$PROJECT_DIR/VERSION")"
PACKAGE="$PROJECT_DIR/dist/Open-Xprinter-$VERSION-universal-unsigned.pkg"
for attempt in 1 2; do
    sudo /usr/sbin/installer -pkg "$PACKAGE" -target /
    /usr/bin/codesign --verify --deep --strict '/Applications/Open Xprinter.app'
    /usr/bin/codesign --verify --strict /Library/Printers/OpenXprinter/rastertoxp330b
    [[ "$(/usr/bin/stat -f %u /Library/Printers/OpenXprinter/setup-printer.sh)" == 0 ]]
    [[ "$(/usr/bin/stat -f %Lp /Library/Printers/OpenXprinter/setup-printer.sh)" == 755 ]]
    [[ "$(/bin/readlink /usr/libexec/cups/filter/rastertoxp330b)" == /Library/Printers/OpenXprinter/rastertoxp330b ]]
    '/Applications/Open Xprinter.app/Contents/MacOS/OpenXprinter' --self-test "$PROJECT_DIR/build/tests/installed-$attempt" > /dev/null
done
sudo /Library/Printers/OpenXprinter/uninstall.sh
[[ ! -e '/Applications/Open Xprinter.app' ]]
[[ ! -e /Library/Printers/OpenXprinter/rastertoxp330b ]]
[[ ! -L /usr/libexec/cups/filter/rastertoxp330b ]]
printf '%s\n' 'Fresh Mac installation without USB, reinstall and uninstall PASS'
