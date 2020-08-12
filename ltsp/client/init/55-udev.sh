# This file is part of LTSP, https://ltsp.org
# Copyright 2020 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Provide a way to create udev rules that match hardware to seats
# @LTSP.CONF: UDEV_SEAT_x


udev_main() {
    local seat_vars var value seat

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
