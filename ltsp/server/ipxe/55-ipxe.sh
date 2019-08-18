# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Install iPXE binaries and configuration in TFTP

BINARIES_URL=${BINARIES_URL:-https://github.com/ltsp/binaries/releases/latest/download}

ipxe_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "b:u:" -l \
        "binaries:binaries-url:" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -b|--binaries) shift; BINARIES=$1 ;;
            -u|--binaries-url) shift; BINARIES_URL=$1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    test "$#" = "0" || usage 1
    run_main_functions "$_SCRIPTS" "$@"
}

ipxe_main() {
    local key items gotos r_items r_gotos img_name binary

    # Prepare the menu text for all images and chroot
    key=0
    items=""
    gotos=":images"
    img_name=$(re list_img_names -i)
    set -- $img_name
    for img_name in "$@"; do
        key=$((key+1))
        items="${items:+"$items\n"}$(printf "item --key %d %-20s %s" "$((key%10))" "$img_name" "$img_name.img")"
        gotos=":$img_name\n$gotos"
    done
    r_items=""
    r_gotos=":roots"
    img_name=$(re list_img_names -c)
    set -- $img_name
    for img_name in "$@"; do
        key=$((key+1))
        r_items="${r_items:+"$r_items\n"}$(printf "item --key %d %-20s %s" "$((key%10))" "r_$img_name" "$img_name")"
        r_gotos=":r_$img_name\nset img $img_name \&\& goto roots\n$r_gotos"
    done
    re mkdir -p "$TFTP_DIR/ltsp"
    exit_command "rw rm -f '$TFTP_DIR/ltsp/ltsp.ipxe.tmp'"
    re install_template "ltsp.ipxe" "$TFTP_DIR/ltsp/ltsp.ipxe.tmp" "\
s|^/srv/ltsp|$BASE_DIR|g
s|^#.*item.*\bimages\b.*|$(textif "$items$r_items" "$items\n$r_items" "&")|
s|^:images\$|$(textif "$items" "$gotos" "&")|
s|^:roots\$|$(textif "$r_items" "$r_gotos" "&")|
"
    re migrate_local_content "$TFTP_DIR/ltsp/ltsp.ipxe" "$TFTP_DIR/ltsp/ltsp.ipxe.tmp"
    if [ -f "$TFTP_DIR/ltsp/ltsp.ipxe" ]; then
        re mv "$TFTP_DIR/ltsp/ltsp.ipxe" "$TFTP_DIR/ltsp/ltsp.ipxe.old"
    fi
    re mv "$TFTP_DIR/ltsp/ltsp.ipxe.tmp" "$TFTP_DIR/ltsp/ltsp.ipxe"
    if [ "$BINARIES" != "0" ]; then
        # Prefer memtest.0 from ipxe.org over the one from distributions:
        # https://lists.ipxe.org/pipermail/ipxe-devel/2012-August/001731.html
        for binary in memtest.0 memtest.efi snponly.efi undionly.kpxe; do
            if [ "$OVERWRITE" = "1" ] || [ ! -f "$TFTP_DIR/ltsp/$binary" ]; then
                echo "Downloading $BINARIES_URL/$binary"
                re wget -q "$BINARIES_URL/$binary" -O "$TFTP_DIR/ltsp/$binary"
            else
                echo "Skipping existing $TFTP_DIR/ltsp/$binary"
            fi
        done
    fi
    echo "Installed iPXE binaries and configuration:"
    for binary in ltsp.ipxe memtest.0 memtest.efi snponly.efi undionly.kpxe; do
        re ls -l "$TFTP_DIR/ltsp/$binary"
    done
}
