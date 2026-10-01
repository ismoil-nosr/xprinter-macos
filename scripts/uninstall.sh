#!/bin/bash
# SPDX-License-Identifier: MIT
set -Eeuo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C
QUEUE=XP330B_OpenSource
DRY_RUN=0
[[ "${1:-}" != --dry-run ]] || { DRY_RUN=1; shift; }
(($# == 0)) || { printf '%s\n' 'Usage: uninstall.sh [--dry-run]' >&2; exit 1; }
((DRY_RUN)) || [[ $EUID -eq 0 ]] || { printf '%s\n' 'Use sudo to uninstall, or --dry-run to preview.' >&2; exit 1; }
run() { if ((DRY_RUN)); then printf 'Would run:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }
if /usr/bin/lpstat -p "$QUEUE" >/dev/null 2>&1; then
    /usr/bin/grep -Fq '*ModelName: "Open Xprinter XP-330B"' "/etc/cups/ppd/$QUEUE.ppd" || { printf '%s\n' 'Queue belongs to another driver; leaving it untouched.' >&2; exit 1; }
    [[ -z "$(/usr/bin/lpstat -W not-completed -o "$QUEUE")" ]] || { printf '%s\n' 'Finish or cancel pending jobs before uninstalling.' >&2; exit 1; }
    run /usr/sbin/lpadmin -x "$QUEUE"
fi
if [[ "$(/bin/readlink /usr/libexec/cups/filter/rastertoxp330b 2>/dev/null || true)" == /Library/Printers/OpenXprinter/rastertoxp330b ]]; then
    run /bin/rm /usr/libexec/cups/filter/rastertoxp330b
fi
if [[ -f '/Applications/Open Xprinter.app/Contents/Info.plist' ]]; then
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' '/Applications/Open Xprinter.app/Contents/Info.plist')"
    if [[ "$bundle_id" == com.ismoilnosr.openxprinter ]]; then run /bin/rm -rf '/Applications/Open Xprinter.app'; fi
fi
for name in Open-Xprinter-XP330B.ppd rastertoxp330b printer-common.sh setup-printer.sh uninstall.sh LICENSE; do
    run /bin/rm -f -- "/Library/Printers/OpenXprinter/$name"
done
if ((!DRY_RUN)); then /bin/rmdir /Library/Printers/OpenXprinter 2>/dev/null || true; fi
if /usr/sbin/pkgutil --pkg-info com.ismoilnosr.openxprinter >/dev/null 2>&1; then run /usr/sbin/pkgutil --forget com.ismoilnosr.openxprinter; fi
printf '%s\n' 'Open Xprinter removed. Other drivers, printers and your label documents were preserved.'
