# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2025 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Functions for chroot/VM/squashfs manipulation, used by:
# chroot, image, info?, ipxe?, kernel, nbd-server?, initrd-bottom
# We use the following terminology:
# * img_src is a series of mount sources, for example:
#     img1,mount-options1,,img2,mount-options2,,...
# * img may be a simple name or a relative/absolute path.
# By "simple" we mean the way a user would pass it to ltsp, for example
# `ltsp kernel image-name`, without specifying chroot, VM, or squashfs image.
# Initramfs-tools don't quote `nfsmount ${NFSROOT}` or `$nbdpath`, so
# simple names may not contain anything weird like spaces etc.
# `ltsp kernel "~/VirtualBox VMs/image-name.img"` is allowed though.
# * img_path may be a relative/absolute path but not a simple name.
# * img_name is the simple name of an image.

# Convert from img_path (not img, not img_src) to img_name
img_path_to_name() {
    local img_path img_name

    img_path=$1
    img_name=${img_path##*/}
    if [ -f "$img_path" ]; then
        img_name=${img_name%.img}  # Remove the .img extension for files
    elif [ ! -e "$img_path" ]; then
        die "Image doesn't exist: $img_path"
    fi
    case "$img_name" in
        *,*)
            # Commas are reserved for mount options
            die "No commas allowed in LTSP image names: $img_path"
            ;;
        ""|.|..)
            # User used e.g. `..`; find the full path
            img_name=$(re readlink -f "$img_path")
            img_name=${img_path##*/}
            if [ "$img_name" = "" ]; then  # E.g. chrootless
                img_name=$(re uname -m)
                case "$img_name" in
                    # Try to use a common name for all x86 32bit variants
                    *86) img_name="x86_32" ;;
                esac
                warn "Using $img_name as the base name of image $img_path"
            fi
            ;;
    esac
    # Verify that the image name is the same with or without quotes
    set -- $img_name
    if [ "$img_name" != "$1" ]; then  # $1 was set by `set` above
        die "Invalid LTSP image name: $img_path"
    fi
    echo "$img_name"
}

# List the simple names (img_name) of all images under $BASE_DIR[/images]
# For nfsroot= to work, image names may not contain spaces
# So it can be used from other functions like this:
#   if [ "$#" -eq 0 ]; then
#       images=$(list_img_names)
#       set -- $images
#   fi
# Do not use `set -- $(list_img_names)` as it won't die on error
list_img_names() {
    # chroots, VMs, exported images
    local listc listv listi img_path img_names

    test "$#" -ne 0 || set -- -c -v -i
    while [ -n "$1" ]; do
        case "$1" in
            -c) listc=1 ;;
            -v) listv=1 ;;
            -i) listi=1 ;;
            *)  die "Error in list_all_images"
        esac
        shift
    done
    img_names=$(
        if [ "$listc" = "1" ]; then
            for img_path in "$BASE_DIR/"*; do
                test -d "$img_path/proc" || continue
                img_path_to_name "$img_path"
            done
        fi
        if [ "$listv" = "1" ]; then
            for img_path in "$BASE_DIR/"*.img; do
                test -f "$img_path" || continue
                img_path_to_name "$img_path"
            done
        fi
        if [ "$listi" = "1" ]; then
            for img_path in "$BASE_DIR/images/"*.img; do
                test -f "$img_path" || continue
                img_path_to_name "$img_path"
            done
        fi
        # `set -e` may not work in pipes or subshells; be more explicit
        ) || return $?
    echo "$img_names" | sort -u
}

# If img_src ($1) seems like a simple name, map to the appropriate
# chroot/VM/image under $BASE_DIR, depending on the defined priority.
add_path_to_src() {
    local img_src img rest priority

    img_src=$1; shift
    case "$img_src" in
        .*|/*)  echo "$img_src"; return 0 ;;
    esac
    img=${img_src%%,*}
    rest=${img_src#$img}
    test "$#" -ne 0 || set -- -c -v -i
    for priority in "$@"; do
        case "$priority" in
            -c) if [ -d "$BASE_DIR/$img/proc" ]; then
                    echo "$BASE_DIR/$img$rest"
                    return 0
                fi
                ;;
            -v) if [ -f "$BASE_DIR/$img.img" ]; then
                    echo "$BASE_DIR/$img.img$rest"
                    return 0
                fi
                ;;
            -i) if [ -f "$BASE_DIR/images/$img.img" ]; then
                    echo "$BASE_DIR/images/$img.img$rest"
                    return 0
                fi
                ;;
            *) die "Error in list_all_images: $priority" ;;
        esac
    done
    # Finally, check if it was a relative path under $BASE_DIR or $(pwd)
    if [ -e "$BASE_DIR/$img" ]; then
        echo "$BASE_DIR/$img$rest"
    elif [ -e "$img" ]; then
        echo "$img$rest"
    else
        die "Image does not exist: $img"
    fi
}

modprobe_overlay() {
    local target overlayko

    target=$1
    grep -q overlay /proc/filesystems &&
        return 0
    modprobe overlay &&
        grep -q overlay /proc/filesystems &&
        return 0
    # Try to load overlay.ko from the target
    for overlayko in "$target/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko"*; do
        if [ -f "$overlayko" ]; then
            # Do not `ln -s "$target/lib/modules" /lib/modules`
            # In that case, $target is in use after modprobe
            warn "Loading overlay module from real root" >&2
            # insmod is availabe in Debian initramfs but not in Ubuntu
            "$target/sbin/insmod" "$overlayko" &&
                grep -q overlay /proc/filesystems &&
                return 0
        fi
    done
    return 1
}

# Process a series of mount sources to mount an image to dst, for example:
#     img1,mount-options1,,img2,mount-options2,,...
# The following rules apply:
#   * If it's a directory, it's bind-mounted over $dst[/$subdir].
#   * If it's a file, the (special) mount options along with autodetection
#     are used to loop mount it over $dst[/$subdir].
# The following special mount options are recognized at the start of options:
#   * partition=1|etc
#   * fstype=squashfs|iso9660|ext4|vfat|etc
#   * subdir=boot/efi (mount $img in $dst/$subdir)
# The rest are passed as mount -o options (comma separated).
# After all the commands have been processed, if /proc doesn't exist,
# it's considered an error.
# Examples for ltsp.ipxe:
# set nfs_simple root=/dev/nfs nfsroot=${srv}:/srv/ltsp/${img} (no image required)
# set nfs_squashfs root=/dev/nfs nfsroot=${srv}:/srv/ltsp/${img} ltsp.image=ltsp.img
# set nfs_vbox root=/dev/nfs nfsroot=${srv}:/srv/ltsp/${img} ltsp.image=${img}-flat.vmdk
# set nfs_ubuntu_iso root=/dev/nfs nfsroot=${srv}:/srv/ltsp/cd ltsp.image=ubuntu-mate-18.04.1-desktop-i386.iso,fstype=iso9660,loop,ro,,casper/filesystem.squashfs,fstype=squashfs,loop,ro
# root=/dev/sda1 ltsp.image=/path/to/VMs/bionic-mate-flat.vmdk,partition=1
# Examples for ltsp image:
# ltsp image -c /,,/boot/efi,subdir=boot/efi
mount_img_src() {
    local img_src dst tmpfs options img partition fstype subdir var_value value first_time

    img_src=$1
    dst=$2
    tmpfs=$3
    # Ensure $dst is a directory but not /
    dst=$(re readlink -f "$dst")
    test -d "${dst%/}" || die "Error in mount_img_src: $dst"
    # _LOCKROOT is needed for lock_package_management()
    unset _LOCKROOT
    first_time=1
    while [ -n "$img_src" ]; do
        img_options=${img_src%%,,*}
        img_src=${img_src#$img_options}
        img_src=${img_src#,,}
        img=${img_options%%,*}
        options=${img_options#$img}
        options=${options#,}
        partition=
        fstype=
        subdir=
        while [ -n "$options" ]; do
            var_value=${options%%,*}
            value=${var_value#*=}
            case "$options" in
                fstype=*)  fstype=$value ;;
                partition=*)  partition=$value ;;
                subdir=*)  subdir=$value ;;
                *)  break  ;;
            esac
            options=${options#$var_value}
            options=${options#,}
        done
        if [ "$first_time" = "1" ]; then
            # Allow the first img to be a simple img_name
            img_path=$(add_path_to_src "$img")
            unset first_time
        elif [ "${img#/}" = "$img" ]; then
            # Submounts may be absolute or relative to $dst
            img_path=$dst/$img
        else
            img_path=$img
        fi
        debug "img=$img
img_path=$img_path
options=$options
partition=$partition
fstype=$fstype
subdir=$subdir
img_src=$img_src
"
        # Now img_path has enough path information
        if [ -d "$img_path" ]; then
            re omount "$img_path" "$dst/$subdir" "$tmpfs" -o "${options:-ro}"
            _LOCKROOT="${_LOCKROOT:-$img_path}"
        elif [ -e "$img_path" ]; then
            re mount_file "$img_path" "$dst/$subdir" "$tmpfs" "$options" "$fstype" "$partition"
        else
            # Warn, don't die, to allow test-mounting image sources
            warn "Image doesn't exist: $img_path"
            return 1
        fi
    done
}

# Get the mount type of a device; may also return special types for convenience
mount_type() {
    # result=$(mount_type "$src") means we're already in a subshell,
    # no need to worry about namespace pollution
    src=$1
    vars=$(re blkid -po export "$src")
    # blkid outputs invalid characters in e.g. APPLICATION_ID=, grep it out
    eval "$(echo "$vars" | grep -E '^PART_ENTRY_TYPE=|^PTTYPE=|^TYPE=')"
    if [ -n "$PTTYPE" ] && [ -z "$TYPE" ]; then
        # "gpt" or "dos" (both for the main and the extended partition table)
        # .iso CDs also get "dos", but they also get TYPE=, which works
        echo "gpt"
    elif [ "$PART_ENTRY_TYPE" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]; then
        # We ignore the efi partition; it doesn't contain root nor kernels
        echo ""
    elif [ "$TYPE" = "swap" ]; then
        # We ignore swap partitions too
        echo ""
    else
        echo "$TYPE"
    fi
}

# Try to loop mount a raw partition/disk file to dst
mount_file() {
    local src dst tmpfs options fstype partition loopdev loopparts \
        lohelp loparams


    src=$1
    dst=$2
    tmpfs=$3
    options=$4
    fstype=$5
    partition=$6
    re test -e "$src"
    re test -d "$dst"
    # See https://github.com/ltsp/ltsp/issues/112#issuecomment-579704835
    test -d /sys/module/loop || re modprobe loop max_part=9
    fstype=${fstype:-$(mount_type "$src")}
    if [ "$fstype" = "gpt" ]; then  # A partition table
        unset fstype
        loopdev=$(re losetup -f) || die ""
        unset loparams
        lohelp=$(losetup --help 2>&1)
        echo "$lohelp" | grep -q '^[[:space:]]*-r' &&
            loparams="${loparams}r"
        echo "$lohelp" | grep -q '^[[:space:]]*-P' &&
            loparams="${loparams}P"
        echo "Running: losetup ${loparams:+"-$loparams "}$loopdev $src"
        re losetup "$loopdev" ${loparams:+"-$loparams"} "$src"
        exit_command "rw losetup -d '$loopdev'"
        loopparts="${loopdev}p${partition:-*}"
    elif [ -n "$fstype" ]; then  # A filesystem (partition)
        unset loopparts
    else
        die "I don't know how to mount $src"
    fi
    for image in ${loopparts:-"$src"}; do
        # No need to run blkid again if it was a filesystem
        if [ -n "$loopparts" ]; then
            fstype=${fstype:-$(mount_type "$image")}
        fi
        case "$fstype" in
            "")  continue ;;
            ext*)  options=${options:-ro,noload} ;;
            *)  options=${options:-ro} ;;
        esac
        re omount "$image" "$dst" "$tmpfs" -t "$fstype" ${options:+-o "$options"}
        return 0
    done
    die "I don't know how to mount $src"
}

# Mount with squashfuse if /dev/loop-control is missing
mount_squashfuse_or_loop() {
    local src dst options

    src=$1
    dst=$2
    # Shift src and dst coordinates
    shift 2

    if [ -f "$src" ] && [ ! -e /dev/loop-control ] && is_command squashfuse; then
        echo "Loop devices missing, using squashfuse for $src"
        re squashfuse -o allow_other,ro "$src" "$dst"
        exit_command "rw fusermount -u '$dst'"
    else
        re vmount "$@" "$src" "$dst"
    fi
}

# Overlay src into dst, unless OVERLAY=0.
# Create a tmpfs on the first call. Create appropriate subdirs there to use
# for up/work dirs; don't use overlayfs subdirs like ltsp-update-image did,
# for efficiency reasons.
omount() {
    local src dst tmpfs i tmpdst

    src=$1
    dst=$2
    tmpfs=$3
    # The rest are parameters to mount
    shift 3
    re test -e "$src"
    re test -d "$dst"
    if [ "$OVERLAY" = "0" ]; then
        # Support running LTSP inside discardable containers
        if [ -d "$src" ]; then
            re vmount --bind "$src" "$dst"
        else
            re mount_squashfuse_or_loop "$src" "$dst" "$@"
        fi
        return 0
    fi
    if [ ! -d "$tmpfs" ] || [ "$(stat -fc %T "$tmpfs")" != "tmpfs" ]; then
        re mkdir -p "$tmpfs"
        re vmount -t tmpfs -o mode=0755 tmpfs "$tmpfs"
    fi
    i=0
    while [ -d "$tmpfs/$i" ]; do
        i=$((i+1))
    done
    tmpdst=$tmpfs/$i
    re mkdir -p "$tmpdst/up" "$tmpdst/work"
    # No need for `exit_command rm ...` on tmpfs
    if [ ! -d "$src" ]; then
        re mkdir -p "$tmpdst/looproot"
        re mount_squashfuse_or_loop "$src" "$tmpdst/looproot" "$@"
        src="$tmpdst/looproot"
    fi
    # Autodetect live CDs, after all the mounts but before needing overlay
    if [ "$_APPLET" = "initrd-bottom" ] && [ ! -d "$src/proc" ]; then
        for i in "$src/casper/filesystem.squashfs" \
            "$src/live/filesystem.squashfs"
        do
            if [ -f "$i" ]; then
                echo "Autodetected live CD image: $i"
                re vmount -t squashfs -o ro "$i" "$src"
                re set_readahead "$src"
                break
            fi
        done
    fi
    if ! grep -q overlay /proc/filesystems; then
        re modprobe_overlay "$src"
        grep -q overlay /proc/filesystems || die "Could not modprobe overlay"
    fi
    re vmount -t overlay -o "upperdir=$tmpdst/up,lowerdir=$src,workdir=$tmpdst/work" "$tmpfs" "$dst"
}

# Most file systems use 128 KB readahead. NFS had a bug and used 15 MB.
# In LTSP, we want all network file systems to use only 4 KB readahead,
# as it lowers the network traffic to about half.
# I.e. NFS, NBD, SSHFS, and loop devices.
# https://github.com/ltsp/ltsp/issues/27#issuecomment-533976774
set_readahead() {
    local mpoint devs dev rakf rak

    mpoint=$1
    if [ -n "$mpoint" ]; then
        devs=$(rw awk '$5 =="'"$mpoint"'" { print $3 }' </proc/self/mountinfo)
    elif [ -f /proc/fs/nfsfs/volumes ]; then
        devs=$(rw awk '/^v[0-9]/ { print $4 }' </proc/fs/nfsfs/volumes)
    fi
    for dev in $devs; do
        for rakf in \
            "/sys/class/bdi/$dev/read_ahead_kb" \
            "/sys/dev/block/$dev/../bdi/read_ahead_kb"
        do
            test -e "$rakf" || continue
            read -r rak <"$rakf"
            test "$rak" != "${READ_AHEAD_KB:-128}" || continue
            echo "${READ_AHEAD_KB:-128}" >"$rakf"
            break
        done
    done
}

# Be verbose, mount, and call exit_command if --no-exit wasn't passed.
# Destination must be the last parameter.
vmount() {
    local dst no_exit

    if [ "$1" = "--no-exit" ]; then
        no_exit=1
        shift
    else
        unset no_exit
    fi
    echo "Running: mount $*"
    re mount "$@"
    # Set dst to the last argument
    for dst; do true; done
    test "$no_exit" = "1" ||
        exit_command "rw umount $dst"
}
