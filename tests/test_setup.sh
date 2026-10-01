#!/bin/bash
# SPDX-License-Identifier: MIT
set -Eeuo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=scripts/printer-common.sh
source "$PROJECT_DIR/scripts/printer-common.sh"
is_xp330b_uri 'usb://Xprinter/XP-330B?location=2140000'
is_xp330b_uri 'usb://Xprinter/XP-330B?serial=SAFE%20TEST&location=1234'
# Shell substitution is intentional literal hostile input, never executed.
# shellcheck disable=SC2016
for uri in 'usb://Xprinter/XP-420B?location=1' 'ipp://example.test/printer' 'usb://Xprinter/XP-330B?x=$(id)' 'usb://Xprinter/XP-330B?x=1;rm' ''; do
    if is_xp330b_uri "$uri"; then printf 'Unexpected URI accepted: %s\n' "$uri"; exit 1; fi
done
is_media_size 40x58mmRotated.Fullbleed
is_media_size Custom.58.5x40mm
is_media_size Custom.76x1000mm
for size in A4 Custom.77x40mm Custom.58x9mm Custom.nanx40mm '--evil'; do
    if is_media_size "$size"; then printf 'Unexpected size accepted: %s\n' "$size"; exit 1; fi
done
is_integer 00 0 10
is_integer 08 0 10
if is_integer -1 0 10 || is_integer 16 0 15; then exit 1; fi
actual="$(printf '%s\n' 'direct usb://Other/Printer?location=1' 'direct usb://Xprinter/XP-330B?location=2' 'network ipp://example.test/printer' 'direct usb://Xprinter/XP-330B?location=1' 'direct usb://Xprinter/XP-330B?location=2' | usb_uris)"
expected=$'usb://Xprinter/XP-330B?location=1\nusb://Xprinter/XP-330B?location=2'
[[ "$actual" == "$expected" ]]
[[ -z "$(printf '%s\n' 'direct usb://Other/Printer?location=1' | usb_uris)" ]]
for args in '--gap -1' '--paper-size A4' '--stock Fake' '--unknown'; do
    # Intentional tokenization of fixed test vectors, never user input.
    # shellcheck disable=SC2086
    if /bin/bash "$PROJECT_DIR/scripts/setup-printer.sh" --dry-run $args >/dev/null 2>&1; then exit 1; fi
done
printf '%s\n' 'Setup validation: USB selection, no-device case, multiple-device case, media and input rejection PASS'
