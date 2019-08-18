# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create the additional LTSP initrd image at $TFTP_DIR/ltsp/ltsp.img
# Vendors can add to $_DST_DIR between initrd_main and cpio_main

initrd_cmdline() {
    local args _DST_DIR

    args=$(re getopt -n "ltsp $_APPLET" -o "" -l \
        "" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            --) shift ; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    _DST_DIR=$(re mktemp -d)
    run_main_functions "$_SCRIPTS" "$@"
}

initrd_main() {
    # The /usr/share/ltsp and /etc/ltsp directories are copied to the
    # initrd, and later on to the ltsp client file system
    re mkdir -p "$_DST_DIR/usr/share/ltsp"
    re cp -a "$_LTSP_DIR/client" "$_LTSP_DIR/common" "$_LTSP_DIR/ltsp" \
        "$_DST_DIR/usr/share/ltsp/"
    re mkdir -p "$_DST_DIR/conf/conf.d"
    # Busybox doesn't support ln -r
    re ln -s ../../usr/share/ltsp/client/initrd-bottom/initramfs-tools/ltsp-hook.conf \
        "$_DST_DIR/conf/conf.d/ltsp.conf"
    re mkdir -p "$_DST_DIR/etc/ltsp"
    if [ -d /etc/ltsp ]; then
        re cp -a /etc/ltsp/. "$_DST_DIR/etc/ltsp/"
    fi
    # Copy server public ssh keys; prepend "server" to each entry
    test -f "$_DST_DIR/etc/ltsp/ssh_known_hosts" ||
        rw sed "s/^/server /" /etc/ssh/ssh_host_*_key.pub > \
            "$_DST_DIR/etc/ltsp/ssh_known_hosts"
    # Copy server passwd and group
    re cp -a /etc/passwd "$_DST_DIR/etc/ltsp/"
    re cp -a /etc/group "$_DST_DIR/etc/ltsp/"
    # Copy epoptes keys; but provide for a future override
    if [ "$IGNORE_EPOPTES" != "1" ] && [ -f /etc/epoptes/server.crt ]; then
        re cp -a /etc/epoptes/server.crt "$_DST_DIR/etc/ltsp/epoptes.crt"
    fi
}
