# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Make root writable using a tmpfs overlay and install ltsp-init
# @LTSP.CONF: IMAGE OVERLAY

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
    local img_src img rest

    warn "Running $0"
    kernel_vars
    re set_readahead "$rootmnt"
    if [ -n "$IMAGE" ]; then
        img_src=$IMAGE
        img=${img_src%%,*}
        rest=${img_src#$img}
        re mkdir -p "/run/initramfs/ltsp"
        case "${img_src}" in
            http:*|https:*|ftp:*)
                configure_networking
                warn "Running: wget $img -O /run/initramfs/ltsp/${img##*/}"
                re wget "$img" -O "/run/initramfs/ltsp/${img##*/}"
                img_src="/run/initramfs/ltsp/${img##*/}$rest"
                IMAGE_TO_RAM=0
                ;;
        esac
        if [ "${img_src#/}" = "$img_src" ]; then
            # If it doesn't start with slash, it's relative to $rootmnt
            img_src="$rootmnt/$img_src"
            img="$rootmnt/$img"
        fi
        if [ "$IMAGE_TO_RAM" = "1" ]; then
            warn "Running: cp $img /run/initramfs/ltsp/${img##*/}"
            re cp "$img" "/run/initramfs/ltsp/${img##*/}"
            re umount "/root"
            img_src="/run/initramfs/ltsp/${img##*/}$rest"
        fi
        re mount_img_src "$img_src" "$rootmnt"
        re set_readahead "$rootmnt"
    elif [ ! -d "$rootmnt/proc" ]; then
        die "$rootmnt/proc doesn't exist and ltsp.image wasn't specified"
    fi
    # Handle some common live CDs
    if [ ! -d "$rootmnt/proc" ]; then
        for img_src in "$rootmnt/casper/filesystem.squashfs" \
            "$rootmnt/live/filesystem.squashfs"
        do
            if [ -f "$img_src" ]; then
                warn "Running: mount -t squashfs -o ro $img_src $rootmnt"
                re mount -t squashfs -o ro "$img_src" "$rootmnt"
                re set_readahead "$rootmnt"
            fi
        done
    fi
    test -d "$rootmnt/proc" || die "$rootmnt/proc doesn't exist in $_APPLET"
    if [ "$OVERLAY" != "0" ]; then
        re modprobe_overlay
        re overlay "$rootmnt" "$rootmnt" "/run/initramfs/ltsp"
    fi
    re install_ltsp
}

install_ltsp() {
    # Rsync saves space, but it's not available e.g. in stretch-mate-sch
    if [ -x "$rootmnt/usr/bin/rsync" ]; then
        # Running rsync outside the chroot fails because of missing libraries
        re mount --bind /usr/share/ltsp "$rootmnt/tmp"
        re chroot "$rootmnt" rsync -a --delete /tmp/ /usr/share/ltsp
        re umount "$rootmnt/tmp"
        re mount --bind /etc/ltsp "$rootmnt/tmp"
        re chroot "$rootmnt" rsync -a --delete /tmp/ /etc/ltsp
        re umount "$rootmnt/tmp"
    else
        re rm -rf "$rootmnt/usr/share/ltsp"
        re cp -a /usr/share/ltsp "$rootmnt/usr/share/"
        re rm -rf "$rootmnt/etc/ltsp"
        re cp -a /etc/ltsp "$rootmnt/etc/"
    fi
    # Symlink the ltsp binary
    re ln -sf ../share/ltsp/ltsp "$rootmnt/usr/sbin/ltsp"
    # Symlink the service
    re ln -sf ../../../usr/share/ltsp/common/service/ltsp.service "$rootmnt/lib/systemd/system/ltsp.service"
    re ln -sf ../ltsp.service "$rootmnt/lib/systemd/system/multi-user.target.wants/ltsp.service"
    # Copy our modules configuration
    if [ -f /etc/modprobe.d/ltsp.conf ] && [ -d "$rootmnt/etc/modprobe.d" ]
    then
        re cp -a /etc/modprobe.d/ltsp.conf "$rootmnt/etc/modprobe.d/"
    fi
    # To avoid specifying an init=, we override the real init.
    # We can't mount --bind as it's in use by libraries and can't be unmounted.
    re mv "$rootmnt/sbin/init" "$rootmnt/sbin/init.ltsp"
    re ln -s ../../usr/share/ltsp/client/init/init "$rootmnt/sbin/init"
    # Jessie needs a 3.18+ kernel and this initramfs-tools hack:
    if grep -qs jessie /etc/os-release; then
        echo "init=${init:-/sbin/init}" >> /scripts/init-bottom/ORDER
    fi
}

modprobe_overlay() {
    local overlayko

    grep -q overlay /proc/filesystems &&
        return 0
    modprobe overlay &&
        grep -q overlay /proc/filesystems &&
        return 0
    overlayko="$rootmnt/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko"
    if [ -f "$overlayko" ]; then
        # Do not `ln -s "$rootmnt/lib/modules" /lib/modules`
        # In that case, /root is in use after modprobe
        warn "Loading overlay module from real root" >&2
        # insmod is availabe in Debian initramfs but not in Ubuntu
        "$rootmnt/sbin/insmod" "$overlayko" &&
            grep -q overlay /proc/filesystems &&
            return 0
    fi
    return 1
}
