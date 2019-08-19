# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Activate swap partitions. Code adapted from casper.
# @LTSP.CONF: LOCAL_SWAP

swap_main() {
    re local_swap
}

local_swap() {
    local devices device magic

    test "$LOCAL_SWAP" != "0" || return 0
    devices=""
    for device in /dev/[hsv]d[a-z][0-9]*; do
        if ! [ -b "$device" ]; then
            continue
        fi
        blkid -o udev -p "${device%%[0-9]*}" | grep -q "^ID_FS_USAGE=raid" &&
            continue

        magic=$(re dd if="$device" bs=4086 skip=1 count=1 2>/dev/null |
            re dd bs=10 count=1 2>/dev/null) || continue

        if [ "$magic" = "SWAPSPACE2" ] || [ "$magic" = "SWAP-SPACE" ]; then
            # log "Found $device"
            devices="$devices $device"
            fi
    done

    for device in $devices; do
        re swapon "$device"
    done
}
