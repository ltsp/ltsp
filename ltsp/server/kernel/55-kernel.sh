# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Copy vmlinuz and initrd.img from image to TFTP

kernel_cmdline() {
    local args

    args=$(re getopt -n "ltsp $_APPLET" -o "k:" -l \
        "kernel-initrd:" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -k|--kernel-initrd) shift; KERNEL_INITRD=$1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    run_main_functions "$_SCRIPTS" "$@"
}

kernel_main() {
    local tmp img_src img_name runipxe

    if [ "$#" -eq 0 ]; then
        img_src=$(list_img_names)
        set -- $img_src
        if [ "$#" -gt 3 ] && [ "$ALL_IMAGES" != "1" ]; then
            die "Refusing to run ltsp $_APPLET for $# detected images!
Please export ALL_IMAGES=1 if you want to allow this"
        fi
    fi
    runipxe=0
    for img_src in "$@"; do
        img_path=$(add_path_to_src "${img_src%%,*}")
        img_name=$(img_path_to_name "$img_path")
        re test "kernel_main:$img_name" != "kernel_main:"
        tmp=$(re mktemp -d)
        exit_command "rw rmdir '$tmp'"
        # tmp has mode=0700; use a subdir to hide the mount from users
        re mkdir -p "$tmp/ltsp"
        exit_command "rw rmdir '$tmp/ltsp'"
        tmp=$tmp/ltsp
        re mount_img_src "$img_src" "$tmp"
        re mkdir -p "$TFTP_DIR/ltsp/$img_name/"
        read -r vmlinuz initrd <<EOF
$(search_kernel "$tmp" | head -n 1)
EOF
        if [ -f "$vmlinuz" ] && [ -f "$initrd" ]; then
            test -f "$TFTP_DIR/ltsp/$img_name/vmlinuz" || runipxe=1
            re install -pm 644 "$vmlinuz" "$TFTP_DIR/ltsp/$img_name/vmlinuz"
            re install -pm 644 "$initrd" "$TFTP_DIR/ltsp/$img_name/initrd.img"
            re ls -l "$TFTP_DIR/ltsp/$img_name/vmlinuz" \
                "$TFTP_DIR/ltsp/$img_name/initrd.img"
        else
            warn "Could not locate vmlinuz and initrd.img in $img_src"
        fi
        # Unmount everything and continue with the next image
        rw at_exit -EXIT
    done
    if [ "$runipxe" = "1" ]; then
        echo "To update the iPXE menu, run: ltsp ipxe"
    fi
}

# Search for the kernel and initrd inside $dir
search_kernel() {
    local dir vglob ireg vmlinuz initrd

    dir=${1%/}
    while read -r vglob ireg <&3; do
        # Ignore comments and empty lines
        if [ -z "$vglob" ] || [ "$vglob" = "#" ]; then
            continue
        fi
        # debug "\tvglob=%s\tireg=%s\n" "$glob" "$ireg"
        for vmlinuz in "$dir/"$vglob "$dir/boot/"$vglob; do
            test -f "$vmlinuz" || continue
            initrd=$(printf "%s" "$vmlinuz" | sed "$ireg")
            if [ "$vmlinuz" = "$initrd" ]; then
                debug "\tRegex returned the same file name, ignoring:\n"
                debug "$vmlinuz" "$initrd" "$ireg"
                continue
            fi
            if [ -f "$initrd" ]; then
                printf "%s\t%s\n" "$(ls "$vmlinuz")" "$(ls "$initrd")"
            else
                debug "FOUND: $vmlinuz, NOT FOUND: $initrd\n"
            fi
        done | sort -rV
    done 3<<EOF
# Column 1: a glob pattern to locate the kernel(s)
# Column 2: sed regex to derive the initrd file name from the kernel
# The user defined one comes first
    $KERNEL_INITRD
# openSUSE-Tumbleweed-GNOME-Live-x86_64-Current.iso
    boot/*/loader/linux s|linux|initrd|
# Ubuntu 18 live CDs:
    casper/vmlinuz s|vmlinuz|initrd|
# Ubuntu 10, 12, 14, LinuxMint 19, Xubuntu 18:
    casper/vmlinuz s|vmlinuz|initrd.lz|
# Ubuntu 8 live CD:
    casper/vmlinuz s|vmlinuz|initrd.gz|
# debian-testing-amd64-DVD-1.iso
    install.amd/vmlinuz s|vmlinuz|initrd.gz|
# Fedora-Workstation-Live-x86_64-29-1.2.iso
    isolinux/vmlinuz s|vmlinuz|initrd.img|
# debian-live-testing-i386-xfce+nonfree.iso
    live/vmlinuz-* s|vmlinuz|initrd.img|
# deb-based, prefer symlinks, see: man kernel-img.conf
    vmlinuz s|vmlinuz|initrd.img|
# deb-based installations
    vmlinuz-* s|vmlinuz|initrd.img|
# CentOS/Gentoo installations (vmlinuz-VER => initramfs-VER.img)
    vmlinuz-* s|vmlinuz-\(.*\)|initramfs-\1.img|
# Tinycorelinux
    vmlinuz s|vmlinuz|core.gz|
EOF
}
