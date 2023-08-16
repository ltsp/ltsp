# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2022 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Make root writable using a tmpfs overlay and install ltsp-init
# @LTSP.CONF: IMAGE

initrd_bottom_cmdline() {
    if [ -f /scripts/functions ]; then
        # Running on initramfs-tools
        re . /scripts/functions
    else
        # Running on dracut
        rootmnt=/sysroot
        # TODO: check which other variables we need, e.g. ROOT, netroot...
    fi
    run_main_functions "$_SCRIPTS" "$@"
}

initrd_bottom_main() {
    local tmpfs img_src img rest

    echo "Running $0 $_APPLET"
    kernel_vars
    re set_readahead "$rootmnt"
    tmpfs="/run/initramfs/ltsp"
    if [ -n "$IMAGE" ]; then
        img_src=$IMAGE
        # If it doesn't start with slash, it's relative to $rootmnt
        if [ "${img_src#/}" = "$img_src" ]; then
            img_src="$rootmnt/$img_src"
        fi
        if [ "$IMAGE_TO_RAM" = "1" ]; then
            img=${img_src%%,*}
            rest=${img_src#$img}
            re mkdir -p "$tmpfs"
            re vmount -t tmpfs -o mode=0755 tmpfs "$tmpfs"
            echo "Running: cp -a $img $tmpfs/${img##*/}"
            re cp -a "$img" "$tmpfs/${img##*/}"
            re umount "$rootmnt"
            img_src="$tmpfs/${img##*/}$rest"
        fi
    elif [ -d "$rootmnt/proc" ]; then
        # Plain NFS chroot booting
        img_src=$rootmnt
    else
        die "$rootmnt/proc doesn't exist and ltsp.image wasn't specified"
    fi
    re mount_img_src "$img_src" "$rootmnt" "$tmpfs"
    re set_readahead "$rootmnt"
    test -d "$rootmnt/proc" || die "$rootmnt/proc doesn't exist in $_APPLET"
    re install_ltsp
}

install_ltsp() {
    # When removing or renaming upstream / vendor shell files under $_LTSP_DIR,
    # replace them with empty ones and keep them in git for about 10 years,
    # to avoid side effects of both the old and new scripts being sourced
    # Busybox <= 2016 doesn't support cp -u
    rsr cp -au /usr/share/ltsp "$rootmnt/usr/share/" ||
        re cp -a /usr/share/ltsp "$rootmnt/usr/share/"
    rsr cp -au /etc/ltsp "$rootmnt/etc/" ||
        re cp -a /etc/ltsp "$rootmnt/etc/"
    # Symlink the ltsp binary
    re ln -sf ../share/ltsp/ltsp "$rootmnt/usr/sbin/ltsp"
    # Symlink the service; use absolute symlink due to /usr/lib migration
    re ln -sf /usr/share/ltsp/common/service/ltsp.service "$rootmnt/lib/systemd/system/ltsp.service"
    re ln -sf ../ltsp.service "$rootmnt/lib/systemd/system/multi-user.target.wants/ltsp.service"
    # Copy our modules configuration
    if [ -f /etc/modprobe.d/ltsp.conf ] && [ -d "$rootmnt/etc/modprobe.d" ]
    then
        re cp -a /etc/modprobe.d/ltsp.conf "$rootmnt/etc/modprobe.d/"
    fi
    # To avoid specifying an init=, we override the real init.
    # We can't mount --bind as it's in use by libraries and can't be unmounted.
    # With Linux 6.1 rename(2) on the symlink fails with ENXIO, so do not use
    # mv for now (see #860).
    re cp -a "$rootmnt/sbin/init" "$rootmnt/sbin/init.ltsp"
    re ln -sf ../../usr/share/ltsp/client/init/init "$rootmnt/sbin/init"
    # Jessie needs a 3.18+ kernel and this initramfs-tools hack:
    if grep -qs jessie /etc/os-release; then
        echo "init=${init:-/sbin/init}" >> /scripts/init-bottom/ORDER
    fi
}
