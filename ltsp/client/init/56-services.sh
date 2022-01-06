# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2022 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Disable services that shouldn't run in live sessions
# Placed after 55-various.sh which might add NFS entries in /etc/fstab
# @LTSP.CONF: DISABLE_SESSION_SERVICES DISABLE_SYSTEM_SERVICES
# @LTSP.CONF: KEEP_SESSION_SERVICES KEEP_SYSTEM_SERVICES
# @LTSP.CONF: MASK_SESSION_SERVICES MASK_SYSTEM_SERVICES

services_main() {
    disable_session_services
    disable_system_services
    mask_session_services
    mask_system_services
}

# $1: space-separated list of services to keep
# ${@:2}: lines with space-separated services and optional comments
# stdout: newline-separated processed list of services
# Shells strip the final newlines in `x=$(exclude_kept_services ...)`
exclude_kept_services() {
    local kept_services service

    kept_services=$1
    shift
    echo "$@" | sed 's/#.*//' | tr ' ' '\n' | while read -r service; do
        test -n "$service" || continue
        case " $kept_services " in
        *" $service "*) ;;
        *)
            echo "$service"
            ;;
        esac
    done
}

disable_session_services() {
    local services

    services="$(exclude_kept_services "$KEEP_SESSION_SERVICES" \
        "$DISABLE_SESSION_SERVICES")"
    test -n "$services" &&
        rw systemctl disable --user --global --quiet --root=/ --no-reload $services
}

disable_system_services() {
    local services service existing_services

    services="
# From Ubuntu 20.04 /lib/systemd/system:
alsa-restore               # Save/Restore Sound Card State
alsa-state                 # Manage Sound Card State (restore and store)
apparmor                   # Load AppArmor profiles
apt-daily                  # Daily apt download activities
apt-daily.timer            # Daily apt download activities
apt-daily-upgrade          # Daily apt upgrade and clean activities
apt-daily-upgrade.timer    # Daily apt upgrade and clean activities
dnsmasq                    # A lightweight DHCP and caching DNS server
epoptes                    # Computer lab monitoring tool
# Apply fw updates that exist in the image, but don't fetch new ones
fwupd-refresh.timer        # Refresh fwupd metadata regularly
logrotate.timer            # Daily rotation of log files
man-db.timer               # Daily man-db regeneration
ModemManager               # Modem Manager
nfs-kernel-server          # NFS server and services
nfs-server                 # NFS server and services
packagekit                 # PackageKit Daemon
packagekit-offline-update  # Update the operating system whilst offline
rsyslog                    # System Logging Service
ssh                        # OpenBSD Secure Shell server
systemd-random-seed        # Load/Save Random Seed
systemd-rfkill             # Load/Save RF Kill Switch Status
unattended-upgrades        # Unattended Upgrades Shutdown
ureadahead                 # [18.04] Read required files in advance
ureadahead-stop            # [18.04] Stop ureadahead data collection
x2goserver                 # X2Go Server Daemon
# From Ubuntu 20.04 /etc/init.d (excluding the ones in systemd):
alsa-utils                 # Restore and store ALSA driver settings
grub-common                # Record successful boot for GRUB
nbd-server                 # Network Block Device server
# From Raspberry Pi OS Buster:
dhcpcd                     # dhcpcd on all interfaces
# Third party:
anydesk                    # AnyDesk
teamviewerd                # TeamViewer remote control daemon
"

    # We don't need NFS-related services if we're not using nfs
    if ! grep -q nfs /etc/fstab; then
        services="$services
auth-rpcgss-module         # Kernel Module supporting RPCSEC_GSS
nfs-blkmap                 # pNFS block layout mapping daemon
nfs-common                 # nfs-config.service  # Preprocess NFS configuration
nfs-idmapd                 # NFSv4 ID-name mapping service
nfs-mountd                 # NFS Mount Daemon
nfs-utils                  # NFS server and client services
portmap                    # RPC bind portmap service
rpcbind                    # RPC bind portmap service
rpc-gssd                   # RPC security service for NFS client and server
rpc-statd-notify           # Notify NFS peers of a restart
rpc-statd                  # NFS status monitor for NFSv2/3 locking.
rpc-svcgssd                # RPC security service for NFS server
"
    fi

    services="$(exclude_kept_services "$KEEP_SYSTEM_SERVICES" \
        "$services
$DISABLE_SYSTEM_SERVICES")"

    # Avoid warnings for disabling non-existing services
    existing_services=""
    for service in $services; do
        if [ -f "/usr/lib/systemd/system/$service" ] ||
            [ -f "/usr/lib/systemd/system/$service.service" ] ||
            [ -f "/etc/systemd/system/$service" ] ||
            [ -f "/etc/systemd/system/$service.service" ] ||
            [ -f "/etc/init.d/$service" ]; then
            existing_services="$existing_services $service"
        fi
    done
    rw systemctl disable --quiet --root=/ --no-reload $existing_services
}

mask_session_services() {
    local services service

    services="
at-spi-dbus-bus         # AT-SPI D-Bus Bus
gnome-software-service  # GNOME Software
update-notifier         # Check for available updates automatically
"
    services="$(exclude_kept_services "$KEEP_SESSION_SERVICES" \
        "$services
$MASK_SESSION_SERVICES")"

    for service in $services; do
        if [ -f "/usr/lib/systemd/user/$service" ]; then
            rw systemctl mask --user --global --quiet --root=/ --no-reload "$service"
        fi
        re rm -f "/etc/xdg/autostart/$service.desktop" \
            "/usr/share/upstart/xdg/autostart/$service.desktop"
    done
}

mask_system_services() {
    local services

    services="
# From Ubuntu 20.04 /lib/systemd/system:
apt-daily                  # Daily apt download activities
apt-daily-upgrade          # Daily apt upgrade and clean activities
rsyslog                    # System Logging Service
"

    services="$(exclude_kept_services "$KEEP_SYSTEM_SERVICES" \
        "$services
$MASK_SYSTEM_SERVICES")"

    rw systemctl mask --quiet --root=/ --no-reload $services
}
