# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Override /sbin/init to run some LTSP code, then restore the real init

init_cmdline() {
    # Verify that this is a valid init environment
    test "$$" = "1" || die "ltsp init can run only as pid 1"
    re ensure_writable "$@"
    re mount_devices
    # Create the directory that indicates an "ltsp mode" boot
    re mkdir -p /run/ltsp/client
    # OK, ready to run all the main functions
    re run_main_functions "$_SCRIPTS" "$@"
    # Since we don't return, we need to run the POST parameters manually
    re run_parameters "POST"
    re exec /sbin/init
}

# If the root file system is read-only, create a tmpfs overlay over it.
# Tested over NBD and NFSv3, but it currently has issues over NFSv4:
# https://bugzilla.kernel.org/show_bug.cgi?id=199013
ensure_writable() {
    local mp

    test -w / && return 0
    # Sysadmins that want non-live mode should specify "rw" in the kernel
    # cmdline, so never do the following:
    # mount -o remount,rw / && return 0
    warn "The root file system isn't writable, activating overlay"
    # TODO: the following are currently untested
    # We want an existing mount point for the tmpfs outside of /run,
    # otherwise switch_root can't move the /run mount as it's in use.
    # Since ltsp must be installed for ro roots, let's use this dir:
    mp=/usr/share/ltsp/client/initrd-bottom
    test -d "$mp" || die "No mount point for overlay: $mp"
    re mount -t tmpfs tmpfs "$mp"
    re overlay "/" "$mp"
    re exec switch_root "$mp" "$0" "$@"
}

# Mount options from Debian initramfs-tools/init
mount_devices() {
    local mp mounts

    for mp in /dev /proc /run /sys; do
        test -d "$mp" || die "Missing directory: $mp"
    done
    test -f /proc/mounts ||
        re mount -vt proc -o nodev,noexec,nosuid proc /proc
    mounts=$(re awk '{ printf " %s ",$2 }' < /proc/mounts)
    test "$mounts" != "${mounts#* /sys }" ||
        re mount -vt sysfs -o nodev,noexec,nosuid sysfs /sys
    test "$mounts" != "${mounts#* /dev }" ||
        re mount -vt devtmpfs -o nosuid,mode=0755 udev /dev
    test "$mounts" != "${mounts#* /dev/pts }" ||
        re mount -vt devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts
    test "$mounts" != "${mounts#* /run }" ||
        re mount -vt tmpfs -o noexec,nosuid,size=10%,mode=0755 tmpfs /run
}
