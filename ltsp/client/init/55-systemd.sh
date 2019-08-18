# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Configure systemd related things
systemd_main() {
    local var

    # Use loglevel from /proc/cmdline instead of resetting it
    # Remember, `false && false` doesn't exit; use `||` when not using re/rw
    grep -qsw netconsole /proc/cmdline &&
        rw rm -f "/etc/sysctl.d/10-console-messages.conf"
    test -f "/usr/lib/tmpfiles.d/systemd.conf" &&
        rw sed "s|^[aA]|# &|" -i "/usr/lib/tmpfiles.d/systemd.conf"
    # Silence dmesg: Failed to open system journal: Operation not supported
    # Cap journal to 1M; TODO: make it configurable
    test -f "/etc/systemd/journald.conf" &&
        rw sed -e "s|[^[alpha]]*Storage=.*|Storage=volatile|" \
            -e "s|[^[alpha]]*RuntimeMaxUse=.*|RuntimeMaxUse=1M|" \
            -e "s|[^[alpha]]*ForwardToSyslog=.*|ForwardToSyslog=no|" \
            -i "/etc/systemd/journald.conf"
    # Shorten the waiting time for problematic shutdown tasks
    test -f "/etc/systemd/system.conf" &&
        rw sed "s|[^[alpha]]*DefaultTimeoutStopSec=.*|DefaultTimeoutStopSec=10s|" \
            -i "/etc/systemd/system.conf"
    test -f "/etc/systemd/user.conf" &&
        rw sed "s|[^[alpha]]*DefaultTimeoutStopSec=.*|DefaultTimeoutStopSec=10s|" \
            -i "/etc/systemd/user.conf"
    # Mask services
    for var in apt-daily.service apt-daily-upgrade.service \
        snapd.seeded.service rsyslog.service
    do
        rw ln -s /dev/null "/etc/systemd/system/$var"
    done
    # TODO: or this; both are fast: rw systemctl mask --quiet --root=/ --no-reload apt-daily.service apt-daily-upgrade.service snapd.seeded.service rsyslog.service
}
