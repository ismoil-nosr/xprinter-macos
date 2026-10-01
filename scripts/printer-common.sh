#!/bin/bash
# SPDX-License-Identifier: MIT
# Pure validation helpers shared by setup and its tests. macOS Bash 3.2 compatible.

is_xp330b_uri() {
    [[ "$1" =~ ^usb://[Xx]printer/XP-330[Bb]\?[A-Za-z0-9%._~/?=\&:+-]+$ ]]
}

usb_uris() {
    /usr/bin/awk '$1 == "direct" && tolower($2) ~ /^usb:\/\/xprinter\/xp-330b\?/ { print $2 }' | /usr/bin/sort -u
}

is_media_size() {
    local size="$1"
    case "$size" in
        20x30mmRotated.Fullbleed|30x40mmRotated.Fullbleed|30x50mmRotated.Fullbleed|50x50mm.Fullbleed|40x58mmRotated.Fullbleed|40x60mmRotated.Fullbleed|50x70mmRotated.Fullbleed|50x76mmRotated.Fullbleed|58x100mm.Fullbleed|76x150mm.Fullbleed) return 0 ;;
    esac
    [[ "$size" =~ ^Custom\.([0-9]+([.][0-9]+)?)x([0-9]+([.][0-9]+)?)mm$ ]] || return 1
    local width="${BASH_REMATCH[1]}" height="${BASH_REMATCH[3]}"
    /usr/bin/awk -v width="$width" -v height="$height" 'BEGIN { exit !(width >= 20 && width <= 76 && height >= 10 && height <= 1000) }'
}

is_integer() {
    [[ "$1" =~ ^[0-9]{1,3}$ ]] || return 1
    local value=$((10#$1))
    ((value >= $2 && value <= $3))
}
