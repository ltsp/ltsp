# This file is part of LTSP, https://ltsp.org
# Copyright 2020 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Disable snap refresh. Code adapted from casper.

snap_main() {
    local var

    is_command snap || return 0
    # Use /lib, not /run like casper does, to avoid "failed to connect to dbus"
    # warnings later on when 56-mask-services.sh calls `systemctl disable`
    re mkdir -p /lib/systemd/system/snapd.service.wants
    echo "[Unit]
Description=Holds Snappy daemon refresh
After=snapd.service

[Service]
Type=oneshot
ExecStart=/usr/bin/snap set core refresh.hold='$(date --date=now+60days --iso-8601=seconds)'
# Only run once. If snapd restarts result in the setting being reset, remove
# this line and we will be started each time snapd.service starts.
RemainAfterExit=yes

[Install]
WantedBy=snapd.service" > /lib/systemd/system/snapd.hold.service
    re ln -s ../snapd.hold.service /lib/systemd/system/snapd.service.wants/

    # Work around snap hardlinking that wastes tmpfs space (LP #1867415)
    test "$SYMLINK_SNAPS" = 0 && return 0
    for var in /var/lib/snapd/seed/snaps/*.snap; do
        test -f "$var" || continue
        var=${var#/var/lib/snapd/seed/snaps/}
        test -f "/var/lib/snapd/snaps/$var" && continue
        re ln -s "/var/lib/snapd/seed/snaps/$var" "/var/lib/snapd/snaps/$var"
    done
}
