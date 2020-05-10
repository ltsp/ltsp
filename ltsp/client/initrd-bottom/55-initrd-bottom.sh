# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2020 the LTSP team, see AUTHORS
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
    local tmpfs img_src img rest

    echo "Running $0 $_APPLET"
    kernel_vars
    re set_readahead "$rootmnt"
    tmpfs="/run/initramfs/ltsp"
    if [ -n "$IMAGE" ]; then
        img_src=$IMAGE
        img=${img_src%%,*}
        rest=${img_src#$img}
        case "${img}" in
            http:*|https:*|ftp:*)
                IMAGE_TO_RAM=1
                ;;
            /*)
                true
                ;;
            *)
                # If it doesn't start with slash, it's relative to $rootmnt
                img_src="$rootmnt/$img_src"
                img="$rootmnt/$img"
                ;;
        esac
        if [ "$IMAGE_TO_RAM" = "1" ]; then
            re mkdir -p "$tmpfs"
            re vmount -t tmpfs -o mode=0755 tmpfs "$tmpfs"
            # If it doesn't start with slash, image should be downloaded
            if [ "${img#/}" = "$img" ]; then
                # Initramfs requires explicit call configure_networking (LP: #1463846)
                if is_command configure_networking; then
                    configure_networking
                fi
                warn "Running: wget $img -O $tmpfs/${img##*/}"
                re wget "$img" -O "$tmpfs/${img##*/}"
            else
                echo "Running: cp -a $img $tmpfs/${img##*/}"
                re cp -a "$img" "$tmpfs/${img##*/}"
                re umount "$rootmnt"
            fi
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
    re mv "$rootmnt/sbin/init" "$rootmnt/sbin/init.ltsp"
    re ln -s ../../usr/share/ltsp/client/init/init "$rootmnt/sbin/init"
    # Jessie needs a 3.18+ kernel and this initramfs-tools hack:
    if grep -qs jessie /etc/os-release; then
        echo "init=${init:-/sbin/init}" >> /scripts/init-bottom/ORDER
    fi
}
