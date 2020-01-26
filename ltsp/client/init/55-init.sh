# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Override /sbin/init to run some LTSP code, then restore the real init

init_cmdline() {
    # Verify that this is a valid init environment
    test "$$" = "1" || die "ltsp init can run only as pid 1"
    # Create the directory that indicates an "ltsp mode" boot
    test -w /run && re mkdir -p /run/ltsp/client
    # OK, ready to run all the main functions
    re run_main_functions "$_SCRIPTS" "$@"
    # Since we don't return, we need to run the POST parameters manually
    re run_parameters "POST"
    rw at_exit -EXIT
    re exec /sbin/init
}

# Mount options from Debian initramfs-tools/init
mount_devices() {
    local mp mounts

    for mp in /dev /proc /run /sys; do
        test -d "$mp" || die "Missing directory: $mp"
    done
    test -f /proc/mounts ||
        re vmount -t proc -o nodev,noexec,nosuid proc /proc
    mounts=$(re awk '{ printf " %s ",$2 }' < /proc/mounts)
    test "$mounts" != "${mounts#* /sys }" ||
        re vmount -t sysfs -o nodev,noexec,nosuid sysfs /sys
    test "$mounts" != "${mounts#* /dev }" ||
        re vmount -t devtmpfs -o nosuid,mode=0755 udev /dev
    test -d /dev/pts ||
        re mkdir -p /dev/pts
    test "$mounts" != "${mounts#* /dev/pts }" ||
        re vmount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts
    test "$mounts" != "${mounts#* /run }" ||
        re vmount -t tmpfs -o noexec,nosuid,size=10%,mode=0755 tmpfs /run
}
