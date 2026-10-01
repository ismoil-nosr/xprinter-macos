#!/bin/bash
# SPDX-License-Identifier: MIT
# Credentials stay in the macOS keychain. This script never accepts account passwords.
set -Eeuo pipefail
(($# == 2)) || { printf '%s\n' 'Usage: notarize.sh signed.pkg KEYCHAIN_PROFILE' >&2; exit 1; }
PACKAGE="$1" PROFILE="$2"
[[ -f "$PACKAGE" && "$PACKAGE" == *-signed.pkg ]] || { printf '%s\n' 'Supply a Developer ID signed package.' >&2; exit 1; }
/usr/sbin/pkgutil --check-signature "$PACKAGE"
/usr/bin/xcrun notarytool submit "$PACKAGE" --keychain-profile "$PROFILE" --wait
/usr/bin/xcrun stapler staple "$PACKAGE"
/usr/bin/xcrun stapler validate "$PACKAGE"
/usr/sbin/spctl --assess --type install --verbose "$PACKAGE"
