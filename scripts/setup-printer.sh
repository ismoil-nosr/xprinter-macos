#!/bin/bash
# SPDX-License-Identifier: MIT
# Installed root-owned helper. Uses only built-in macOS tools; no downloads.
set -Eeuo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C
TASK_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/printer-common.sh
source "$TASK_DIR/printer-common.sh"
QUEUE=XP330B_OpenSource
PROFILE=/Library/Printers/OpenXprinter/Open-Xprinter-XP330B.ppd
MODE=configure
DEVICE_URI=""
PAPER_SIZE=""
STOCK=""
GAP=""
DARKNESS=""
DRY_RUN=0
TASK_TEMP=""
DISCOVERY_PID=""

cleanup() {
    if [[ -n "$DISCOVERY_PID" ]]; then /bin/kill "$DISCOVERY_PID" 2>/dev/null || true; fi
    if [[ -n "$TASK_TEMP" ]]; then /bin/rm -rf -- "$TASK_TEMP"; fi
}
trap cleanup EXIT
trap 'printf "Setup failed on line %s. See the message above.\n" "$LINENO" >&2' ERR
fail() { printf '%s\n' "$*" >&2; exit 1; }
run() {
    if ((DRY_RUN)); then printf 'Would run:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}

while (($#)); do
    case "$1" in
        --configure) MODE=configure; shift ;;
        --auto) MODE=auto; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --device-uri|--paper-size|--stock|--gap|--darkness)
            (($# >= 2)) || fail "Missing value for $1"
            case "$1" in
                --device-uri) DEVICE_URI="$2" ;;
                --paper-size) PAPER_SIZE="$2" ;;
                --stock) STOCK="$2" ;;
                --gap) GAP="$2" ;;
                --darkness) DARKNESS="$2" ;;
            esac
            shift 2 ;;
        --help) printf '%s\n' 'Usage: setup-printer.sh [--auto | --configure] [--dry-run] [--device-uri USB_URI] [--paper-size SIZE --stock LabelGaps|LabelMark|Continue --gap 0..10 --darkness 0..15]'; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
[[ -z "$DEVICE_URI" ]] || is_xp330b_uri "$DEVICE_URI" || fail 'Only an XP-330B USB device URI is accepted.'
[[ -z "$PAPER_SIZE" ]] || is_media_size "$PAPER_SIZE" || fail 'Invalid label size (width 20–76 mm, feed height 10–1000 mm).'
[[ -z "$STOCK" || "$STOCK" == LabelGaps || "$STOCK" == LabelMark || "$STOCK" == Continue ]] || fail 'Invalid stock type.'
[[ -z "$GAP" ]] || is_integer "$GAP" 0 10 || fail 'Gap must be an integer from 0 to 10 mm.'
[[ -z "$DARKNESS" ]] || is_integer "$DARKNESS" 0 15 || fail 'Darkness must be an integer from 0 to 15.'
if [[ -n "$STOCK$GAP" ]]; then
    [[ -n "$STOCK" && -n "$GAP" ]] || fail 'Supply stock and gap together.'
    [[ "$STOCK" == Continue ]] || ((10#$GAP > 0)) || fail 'Labels with gaps or marks require a positive gap/mark height.'
fi
((DRY_RUN)) || [[ $EUID -eq 0 ]] || fail 'Run this helper through Open Xprinter, or with sudo.'
((DRY_RUN)) || [[ -f "$PROFILE" && -x /Library/Printers/OpenXprinter/rastertoxp330b ]] || fail 'Install the Open Xprinter package first.'

TASK_TEMP="$(/usr/bin/mktemp -d /private/tmp/open-xprinter-setup.XXXXXX)"
/usr/sbin/lpinfo --include-schemes usb -v > "$TASK_TEMP/devices" 2> "$TASK_TEMP/discovery-error" &
DISCOVERY_PID=$!
for ((attempt=0; attempt<10; attempt++)); do
    /bin/kill -0 "$DISCOVERY_PID" 2>/dev/null || break
    /bin/sleep 1
done
if /bin/kill -0 "$DISCOVERY_PID" 2>/dev/null; then
    /bin/kill "$DISCOVERY_PID" 2>/dev/null || true
    wait "$DISCOVERY_PID" 2>/dev/null || true
    DISCOVERY_PID=""
    [[ "$MODE" == auto ]] && { printf '%s\n' 'Driver installed. Open Open Xprinter to connect the USB printer.'; exit 0; }
    fail 'USB discovery timed out. Check the cable, turn on the printer, then refresh.'
fi
if ! wait "$DISCOVERY_PID"; then
    DISCOVERY_PID=""
    [[ "$MODE" == auto ]] && { printf '%s\n' 'Driver installed. Open Open Xprinter to finish printer setup.'; exit 0; }
    fail 'Could not discover USB printers. Check Print Center and USB, then retry.'
fi
DISCOVERY_PID=""
usb_uris < "$TASK_TEMP/devices" > "$TASK_TEMP/uris"
if [[ -n "$DEVICE_URI" ]]; then
    /usr/bin/grep -Fxq -- "$DEVICE_URI" "$TASK_TEMP/uris" || fail 'The selected USB printer is no longer connected. Refresh and select it again.'
else
    device_count="$(/usr/bin/awk 'END { print NR }' "$TASK_TEMP/uris")"
    if [[ "$device_count" != 1 ]]; then
        [[ "$MODE" == auto ]] && { printf '%s\n' 'Driver installed. Open Open Xprinter and select the connected XP-330B.'; exit 0; }
        [[ "$device_count" == 0 ]] && fail 'Connect and turn on the XP-330B, then refresh.'
        fail 'More than one XP-330B is connected. Select one in Open Xprinter.'
    fi
    IFS= read -r DEVICE_URI < "$TASK_TEMP/uris"
fi
is_xp330b_uri "$DEVICE_URI" || fail 'The detected USB URI is unsupported.'

EXISTS=0
if /usr/bin/lpstat -p "$QUEUE" >/dev/null 2>&1; then
    EXISTS=1
    if [[ ! -f "/etc/cups/ppd/$QUEUE.ppd" ]] || ! /usr/bin/grep -Fq '*ModelName: "Open Xprinter XP-330B"' "/etc/cups/ppd/$QUEUE.ppd"; then
        fail 'The Open Xprinter queue name is already used by another driver. Rename that queue in Print Center first.'
    fi
    pending="$(/usr/bin/lpstat -W not-completed -o "$QUEUE")"
    [[ -z "$pending" ]] || fail 'Finish or cancel pending Open Xprinter jobs in Print Center before reconfiguring.'
fi
if ((EXISTS)); then
    # A repair changes the USB destination and resumes only our queue. Keep its PPD defaults.
    run /usr/sbin/lpadmin -p "$QUEUE" -E -v "$DEVICE_URI"
else
    run /usr/sbin/lpadmin -p "$QUEUE" -E -v "$DEVICE_URI" -P "$PROFILE" \
        -D 'Xprinter XP-330B Labels (Open Source)' -o printer-is-shared=false \
        -o printer-error-policy=stop-printer -o PageSize=40x58mmRotated.Fullbleed \
        -o Resolution=203dpi -o PaperType=LabelGaps -o GapsHeight=2 -o Darkness=7 -o PrintSpeed=3
fi
defaults=()
[[ -z "$PAPER_SIZE" ]] || defaults+=(-o "PageSize=$PAPER_SIZE")
[[ -z "$STOCK" ]] || defaults+=(-o "PaperType=$STOCK")
[[ -z "$GAP" ]] || defaults+=(-o "GapsHeight=$GAP")
[[ -z "$DARKNESS" ]] || defaults+=(-o "Darkness=$DARKNESS")
if ((${#defaults[@]})); then run /usr/sbin/lpadmin -p "$QUEUE" "${defaults[@]}"; fi
printf '%s\n' 'Open Xprinter USB queue is ready. Open the app and match the loaded label size.'
