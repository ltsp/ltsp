# This file is part of LTSP, https://ltsp.org
# Copyright 2020 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# If the root file system is read-only, it means that `ltsp initrd-bottom`
# didn't run and didn't create the tmpfs overlay. Create it now.
# Also process ltsp.image, if defined.
# Tested over NBD and NFSv3, but it currently has issues over NFSv4:
# https://bugzilla.kernel.org/show_bug.cgi?id=199013

ro_root_main() {
    test -w / && return 0

    # The following are currently only tested on Raspbian
    if [ "$ADMINISTRATIVE_CLIENT" = "1" ]; then
        echo "Administrative client; booting in NFS-RW mode"
        re mount -o remount,rw /
        re exec /sbin/init
    fi

    # Raspbian kernel has only /dev mounted at that point
    re mount_devices
    re mkdir -p /run/ltsp/client
    re kernel_vars
    re detect_server
    if [ -n "$IMAGE" ] && [ -n "$SERVER" ]; then
        # We want an existing mount point for the tmpfs outside of /run,
        # otherwise switch_root can't move the /run mount as it's in use.
        # Let's use /root that is used by initramfs-tools and always exists.
        re vmount -t nfs -o vers=3,nolock "$SERVER:/srv/ltsp" /root
        re vmount -o loop,ro "/root/$IMAGE" /root
        re mount_img_src /root /root /run/initramfs/ltsp
    else
        re mount_img_src / /root /run/initramfs/ltsp
    fi
    re set_readahead
    re fetch_ltsp_img
    rw at_exit -EXIT
    re exec switch_root /root /usr/share/ltsp/client/init/init
}

# Fetch and apply ltsp.img. Use NFS as some may use HTTP instead of TFTP.
fetch_ltsp_img() {
    re mkdir -p /run/ltsp/tmp/tftp
    re vmount --no-exit -t nfs -o vers=3,tcp,nolock \
        "$SERVER:/srv/tftp/ltsp" /run/ltsp/tmp/tftp
    re test -f /run/ltsp/tmp/tftp/ltsp.img
    re mkdir -p /run/ltsp/tmp/ltsp-img
    (
        re cd /run/ltsp/tmp/ltsp-img
        re cpio -i < /run/ltsp/tmp/tftp/ltsp.img
    ) || die
    re umount /run/ltsp/tmp/tftp
    install_ltsp /run/ltsp/tmp/ltsp-img /root
    re rm -rf /run/ltsp/tmp
}

# Similar to initrd-bottom>install_ltsp, but not specific to initramfs-tools
install_ltsp() {
    local src dst

    src=$1
    dst=$2
    if is_command rsync; then
        re rsync -a --delete "$src/usr/share/ltsp/" "$dst/usr/share/ltsp"
        re rsync -a --delete "$src/etc/ltsp/" "$dst/etc/ltsp"
    else
        re rm -rf "$dst/usr/share/ltsp"
        re cp -a "$src/usr/share/ltsp" "$dst/usr/share/"
        re rm -rf "$dst/etc/ltsp"
        re cp -a "$src/etc/ltsp" "$dst/etc/"
    fi
    ls -lha "$dst/usr/share/ltsp"
    # Symlink the ltsp binary
    re ln -sf ../share/ltsp/ltsp "$dst/usr/sbin/ltsp"
    # Symlink the service; use absolute symlink due to /usr/lib migration
    re ln -sf /usr/share/ltsp/common/service/ltsp.service "$dst/lib/systemd/system/ltsp.service"
    re ln -sf ../ltsp.service "$dst/lib/systemd/system/multi-user.target.wants/ltsp.service"
    # Copy our modules configuration
    if [ -f "$src/etc/modprobe.d/ltsp.conf" ] && [ -d "$dst/etc/modprobe.d" ]
    then
        re cp -a "$src/etc/modprobe.d/ltsp.conf" "$dst/etc/modprobe.d/"
    fi
}
