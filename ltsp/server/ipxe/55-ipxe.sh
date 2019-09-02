# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Install iPXE binaries and configuration in TFTP
# @LTSP.CONF: DEFAULT_IMAGE KERNEL_PARAMETERS MENU_TIMEOUT

BINARIES_URL=${BINARIES_URL:-https://github.com/ltsp/binaries/releases/latest/download}

ipxe_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "b::u:" -l \
        "binaries::,binaries-url:" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -b|--binaries) shift; BINARIES=${1:-1} ;;
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
    local key items gotos r_items r_gotos img_name title client_sections binary

    # Prepare the menu text for all images and chroot
    key=0
    items=""
    gotos=":images"
    img_name=$(re list_img_names -i)
    set -- $img_name
    for img_name in "$@"; do
        key=$((key+1))
        title=$(echo_values "$(ipxe_name "$img_name.img")")
        title=${title:-$img_name.img}
        items="${items:+"$items\n"}$(printf "item --key %d %-20s %s" "$((key%10))" "$img_name" "$title")"
        gotos=":$img_name\n$gotos"
    done
    r_items=""
    r_gotos=":roots"
    img_name=$(re list_img_names -c)
    set -- $img_name
    for img_name in "$@"; do
        key=$((key+1))
        title=$(echo_values "$(ipxe_name "$img_name")")
        title=${title:-$img_name}
        r_items="${r_items:+"$r_items\n"}$(printf "item --key %d %-20s %s" "$((key%10))" "r_$img_name" "$title")"
        r_gotos=":r_$img_name\nset img $img_name \&\& goto roots\n$r_gotos"
    done
    re mkdir -p "$TFTP_DIR/ltsp"
    if [ "$OVERWRITE" != "1" ] && [ -f "$TFTP_DIR/ltsp/ltsp.ipxe" ]; then
        warn "Configuration file already exists: $TFTP_DIR/ltsp/ltsp.ipxe
To overwrite it, run: ltsp --overwrite $_APPLET ..."
    else
        client_sections=$(re client_sections)
        echo "$client_sections"
        re install_template "ltsp.ipxe" "$TFTP_DIR/ltsp/ltsp.ipxe" "\
s|^/srv/ltsp|$BASE_DIR|g
s/\(|| set menu-timeout \)5000/$(textif "$MENU_TIMEOUT" "\1$MENU_TIMEOUT" "&")/
s|^:61:6c:6b:69:73:67\$|$(textif "$client_sections" "$client_sections" "&")|
s|^#.*item.*\bimages\b.*|$(textif "$items$r_items" "$items\n$r_items" "&")|
s|^:images\$|$(textif "$items" "$gotos" "&")|
s|^:roots\$|$(textif "$r_items" "$r_gotos" "&")|
"
    fi
    if [ "$BINARIES" != "0" ]; then
        # Prefer memtest.0 from ipxe.org over the one from distributions:
        # https://lists.ipxe.org/pipermail/ipxe-devel/2012-August/001731.html
        for binary in memtest.0 memtest.efi snponly.efi undionly.kpxe; do
            if [ "$BINARIES" = "1" ] || [ ! -f "$TFTP_DIR/ltsp/$binary" ]; then
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

# Print the client sections list
client_sections() {
    local section mac first

    first=1
    for section in $(section_list); do
        # We only care about mac address sections
        case "$section" in
            section_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f])
                mac=$(echo "$section" |sed 's/section_//;s/_/:/g')
                # Use a subshell to avoid overriding useful variables
                (
                    unset DEFAULT_IMAGE KERNEL_PARAMETERS MENU_TIMEOUT
                    unset HOSTNAME
                    section_call "$mac"
                    test -n "$DEFAULT_IMAGE$KERNEL_PARAMETERS$MENU_TIMEOUT" ||
                        return 1
                    # Print an empty line between sections
                    test "$first" = "1" || printf '\\n\\n'
                    printf ':%s' "$mac"
                    test -n "$HOSTNAME" &&
                        printf '\\nset hostname %s' "$HOSTNAME"
                    test -n "$DEFAULT_IMAGE" &&
                        printf '\\nset img %s' "$DEFAULT_IMAGE"
                    test -n "$KERNEL_PARAMETERS" &&
                        printf '\\nset cmdline_client %s' "$KERNEL_PARAMETERS"
                    test -n "$MENU_TIMEOUT" &&
                        printf '\\nset menu-timeout %s' "$MENU_TIMEOUT"
                ) || continue
                unset first
                ;;
        esac
    done
}

ipxe_name() {
    echo "$*" |
        awk '{ var=toupper($0); gsub("[^A-Z0-9]", "_", var); print "IPXE_" var }'
}

