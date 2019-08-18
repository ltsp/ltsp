# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Remove some services that don't make sense in live sessions
# Depends on 55-various.sh to have put NFS entries in /etc/fstab
# @LTSP.CONF: MASK_SESSION_SERVICES KEEP_SESSION_SERVICES
# @LTSP.CONF: MASK_SYSTEM_SERVICES KEEP_SYSTEM_SERVICES

mask_services_main() {
    mask_session_services
    mask_system_services
}

exclude_kept_services() {
    local keep_services service

    keep_services=$1; shift
    # Allow multiple services in the same line; remove comments
    echo "$@" | sed 's/#.*//' | tr ' ' '\n' | while read service; do
        test -n "$service" || continue
        case " $keep_services " in
            *" $service "*)
                ;;
            *)
                echo -n " $service"
                ;;
        esac
    done
}

mask_session_services() {
    local mask_services service

    mask_services="
at-spi-dbus-bus         # AT-SPI D-Bus Bus
gnome-software-service  # GNOME Software
update-notifier         # Check for available updates automatically
"
    mask_services="$(exclude_kept_services "$KEEP_SESSION_SERVICES" \
"$mask_services
$MASK_SESSION_SERVICES")"

    # TODO: also blacklist and handle systemd user units
    for service in $mask_services; do
        rm -f "/etc/xdg/autostart/$service.desktop" \
            "/usr/share/upstart/xdg/autostart/$service.desktop"
    done
}

mask_system_services() {
    local mask_services service existing_services

    mask_services="
# From Ubuntu 18.04 /lib/systemd/system:
alsa-restore               # Save/Restore Sound Card State
alsa-state                 # Manage Sound Card State (restore and store)
apparmor                   # AppArmor initialization
apt-daily                  # Daily apt download activities
apt-daily.timer            # Daily apt download activities
apt-daily-upgrade          # Daily apt upgrade and clean activities
apt-daily-upgrade.timer    # Daily apt upgrade and clean activities
dnsmasq                    # A lightweight DHCP and caching DNS server
epoptes                    # Computer lab monitoring tool
ModemManager               # Modem Manager
packagekit                 # PackageKit Daemon
packagekit-offline-update  # Update the operating system whilst offline
ssh                        # OpenBSD Secure Shell server
systemd-random-seed        # Load/Save Random Seed
systemd-rfkill             # Load/Save RF Kill Switch Status
unattended-upgrades        # Unattended Upgrades Shutdown
ureadahead                 # Read required files in advance
ureadahead-stop            # Stop ureadahead data collection
x2goserver                 # X2Go Server Daemon
# From Ubuntu 18.04 /etc/init.d (excluding the ones in systemd):
alsa-utils                 # Restore and store ALSA driver settings
grub-common                # Record successful boot for GRUB
nbd-server                 # Network Block Device server
# Third party:
shared-folders             # Sch-scripts shared folders service
teamviewerd                # TeamViewer remote control daemon
"

# We don't need NFS-related services if we're not using nfs
if ! grep -q nfs /etc/fstab; then
    mask_services="$mask_services
auth-rpcgss-module         # Kernel Module supporting RPCSEC_GSS
nfs-blkmap                 # pNFS block layout mapping daemon
nfs-common                 # nfs-config.service  # Preprocess NFS configuration
nfs-idmapd                 # NFSv4 ID-name mapping service
nfs-kernel-server          # NFS server and services
nfs-mountd                 # NFS Mount Daemon
nfs-server                 # NFS server and services
nfs-utils                  # NFS server and client services
portmap                    # RPC bind portmap service
rpcbind                    # RPC bind portmap service
rpc-gssd                   # RPC security service for NFS client and server
rpc-statd-notify           # Notify NFS peers of a restart
rpc-statd                  # NFS status monitor for NFSv2/3 locking.
rpc-svcgssd                # RPC security service for NFS server
"
    fi

    mask_services="$(exclude_kept_services "$KEEP_SYSTEM_SERVICES" \
"$mask_services
$MASK_SYSTEM_SERVICES")"

    # Minimize `systemctl disable` errors to avoid alarming the users
    existing_services=""
    for service in $mask_services; do
        if [ -f "/lib/systemd/system/$service" ] ||
           [ -f "/lib/systemd/system/$service.service" ] ||
           [ -f "/etc/systemd/system/$service" ] ||
           [ -f "/etc/systemd/system/$service.service" ] ||
           [ -f "/etc/init.d/$service" ]
        then
            existing_services="$existing_services $service"
        fi
    done
    systemctl disable --quiet --root=/ --no-reload $existing_services
}
