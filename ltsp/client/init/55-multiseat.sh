# This file is part of LTSP, https://ltsp.org
# Copyright 2020-2021 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Provide a way to create udev rules that match hardware to seats
# @LTSP.CONF: MULTISEAT UDEV_SEAT_x

multiseat_main() {
    local seat_vars var value seat

    # First do some voodoo to autodetect multiseat
    if [ "$MULTISEAT" = "1" ]; then
        detect_multiseat
    fi
    # But also allow finetuning the UDEV rules
    seat_vars=$(re echo_vars "UDEV_SEAT_[[:digit:]]_[[:alnum:]_]*")
    if [ -z "$seat_vars" ]; then
        # Delete our rules file in case a chrootless LTSP server contains it
        rm -f /etc/udev/rules.d/72-ltsp-seats.rules
        return 0
    fi
    for var in $seat_vars; do
        eval "value=\$$var"
        seat=${var#UDEV_SEAT_}
        seat=${seat%%_*}
        echo "TAG==\"seat\", DEVPATH==\"$value\", ENV{ID_SEAT}=\"seat-$seat\""
    done >/etc/udev/rules.d/72-ltsp-seats.rules
}

detect_multiseat() {
    local minbusnum count busnum

    UDEV_SEAT_1_GRAPHICS=${UDEV_SEAT_1_GRAPHICS:-auto}
    if [ "$UDEV_SEAT_1_GRAPHICS" = "auto" ]; then
        minbusnum="z"
        count=0
        while read -r busnum; do
            count=$((count + 1))
            busnum=${busnum%*/boot_vga}
            busnum=${busnum#/sys}
            # busnum=${busnum##*/}
            test "$busnum" "<" "$minbusnum" && minbusnum=$busnum
        done <<EOF
$(find /sys/devices/pci* -name boot_vga)
EOF
        if [ "$count" -ge 2 ]; then
            UDEV_SEAT_1_GRAPHICS="${minbusnum}*"
            if [ -n "$UDEV_SEAT_1_ODD_USB_PORTS" ]; then
                true
            elif [ -n "$(find /sys/devices -name '?-?.[1,3,5,7,9,11,13,15,17,19]')" ]; then
                # Some ASUS boards
                UDEV_SEAT_1_ODD_USB_PORTS="*/usb?/?-?/?-?.[1,3,5,7,9,11,13,15,17,19]/*"
            else
                # All the rest
                UDEV_SEAT_1_ODD_USB_PORTS="*/usb?/?-[1,3,5,7,9,11,13,15,17,19]/*"
            fi
        else
            unset UDEV_SEAT_1_GRAPHICS
            unset UDEV_SEAT_1_ODD_USB_PORTS
        fi
    fi
}
