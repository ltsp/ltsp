# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Generate a squashfs image from an image source
# Vendors can add to $_COW_DIR between image_main and mksquashfs_main

image_cmdline() {
    local args _COW_DIR img_src

    args=$(re getopt -n "ltsp $_APPLET" -o "b:c:i:k:m:r::" -l \
        "backup:cleanup:ionice:kernel-initrd:mksquashfs-params:revert::" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -b|--backup) shift; BACKUP=$1 ;;
            -c|--cleanup) shift; CLEANUP=$1 ;;
            -i|--ionice) shift; IONICE=$1 ;;
            -k|--kernel-initrd) shift; KERNEL_INITRD=$1 ;;
            -m|--mksquashfs-params) shift; MKSQUASHFS_PARAMS=$1 ;;
            -r|--revert) shift; REVERT=${1:-1} ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    if [ "$#" -eq 0 ]; then
        img_src=$(list_img_names)
        set -- $img_src
        if [ "$#" -gt 3 ] && [ "$ALL_IMAGES" != "1" ]; then
            die "Refusing to run ltsp $_APPLET for $# detected images!
Please export ALL_IMAGES=1 if you want to allow this"
        fi
    fi
    for img_src in "$@"; do
        if [ "$REVERT" = "1" ]; then
            re revert "$img_src"
        else
            _COW_DIR=""
            run_main_functions "$_SCRIPTS" "$img_src"
        fi
    done
}

image_main() {
    local img_src img_path

    img_src="$1"
    img_path=$(add_path_to_src "${img_src%%,*}")
    _IMG_NAME=$(img_path_to_name "$img_path")
    re test "image_main:$_IMG_NAME" != "image_main:"
    _COW_DIR=$(re mktemp -d)
    exit_command "rw rmdir '$_COW_DIR'"
    # _COW_DIR has mode=0700; use a subdir to hide the mount from users
    _COW_DIR="$_COW_DIR/ltsp"
    re mkdir -p "$_COW_DIR"
    exit_command "rw rmdir '$_COW_DIR'"
    unset _LOCKROOT
    re mount_img_src "$img_src" "$_COW_DIR"
    # Before doing an overlay, let's make sure the underlying file system
    # isn't being rapidly modified, by disabling package management
    re lock_package_management
    re overlay "$_COW_DIR" "$_COW_DIR"
}

lock_package_management() {
    local lock pid

    # Lock needs write access; it's only needed for chroots and chrootless
    test -n "$_LOCKROOT" || return 0

    # Insert lock paths for other distributions here
    for lock in var/lib/dpkg/lock; do
        lock="$_LOCKROOT/$lock"
        test -f "$lock" && break
    done
    if [ ! -f "$lock" ]; then
        warn "Package management locking isn't supported in your distribution, continuing without it..."
        return 0
    fi
    echo "Trying to acquire package management lock: $lock"
    if [ ! -w "$lock" ]; then
        warn "Can't acquire ro lock: $lock"
        return 0
    fi
    # TODO: this needs `|| die`, but why isn't it affected by `set -e`?
    pid=$("$_APPLET_DIR/lockf" "$lock") || die
    exit_command "rw unlock_package_management $pid"
}

revert() {
    local img_src img_path img_name

    img_src="$1"
    img_path=$(add_path_to_src "${img_src%%,*}")
    img_name=$(img_path_to_name "$img_path")
    re test "revert:$img_name" != "revert:"
    test -f "$BASE_DIR/images/$img_name.img.old" ||
        die "Cannot revert, backup is missing: $BASE_DIR/images/$img_name.img.old"
    if [ -f "$BASE_DIR/images/$img_name.img" ]; then
        # Swap old with new file
        re mv "$BASE_DIR/images/$img_name.img" "$BASE_DIR/images/$img_name.img.tmp"
        re mv "$BASE_DIR/images/$img_name.img.old" "$BASE_DIR/images/$img_name.img"
        re mv "$BASE_DIR/images/$img_name.img.tmp" "$BASE_DIR/images/$img_name.img.old"
        echo "Swapped $BASE_DIR/images/$img_name.img with $BASE_DIR/images/$img_name.img.old"
    else
        re mv "$BASE_DIR/images/$img_name.img.old" "$BASE_DIR/images/$img_name.img"
        echo "Moved $BASE_DIR/images/$img_name.img.old to $BASE_DIR/images/$img_name.img"
    fi
    re "$0" kernel "$BASE_DIR/images/$img_name.img"
}

unlock_package_management() {
    local pid

    pid=$1
    # If the lock process was already terminated, exit
    grep -qsw lockf "/proc/$pid/cmdline" || return 0
    rw kill "$pid"
    # Package management unlocking happens right before `umount`,
    # so wait for the process kill / file unlock before continuing
    sleep 0.2
    grep -qsw lockf "/proc/$pid/cmdline" || return 0
    # If it's not killed by now, it's hanged, so force-kill it
    rw kill -9 "$pid"
    sleep 0.2
}
