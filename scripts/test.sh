#!/bin/bash
# SPDX-License-Identifier: MIT
set -Eeuo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$PROJECT_DIR"
mkdir -p build/tests
APP='build/stage/Applications/Open Xprinter.app/Contents/MacOS/OpenXprinter'
[[ -x "$APP" ]] || { printf '%s\n' 'Run scripts/build.sh first.' >&2; exit 1; }
python3 tests/test_localization.py
"$APP" --self-test-localization > build/tests/localization.log
"$APP" --self-test "$PROJECT_DIR/build/tests" > build/tests/renderer.log
/usr/bin/xcrun clang -std=c11 -Wall -Wextra -Werror -Wno-deprecated-declarations tests/make-raster.c -lcups -o build/make-raster
python3 tests/test_filter.py
/usr/bin/xcrun swiftc -parse-as-library tests/VerifyTSPL.swift -o build/verify-tspl -framework Vision -framework CoreGraphics
build/verify-tspl "$PROJECT_DIR/build/tests"
/bin/bash tests/test_setup.sh
for script in scripts/*.sh tests/*.sh packaging/scripts/*; do /bin/bash -n "$script"; done
if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh tests/*.sh packaging/scripts/*; fi
python3 tests/test_package.py
printf '%s\n' 'All local checks passed. Hardware printing requires a connected XP-330B.'
