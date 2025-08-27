# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Install Grub binaries and configuration in TFTP
# @LTSP.CONF: DEFAULT_IMAGE KERNEL_PARAMETERS MENU_TIMEOUT

HTTP=${HTTP:-0}
HTTP_IMAGE=${HTTP_IMAGE:-0}

grub_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "b::h::H::" -l \
        "binaries::,http::,http-image::" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -b|--binaries) shift; BINARIES=${1:-1} ;;
            -h|--http) shift; HTTP=${1:-1} ;;
            -H|--http-image) shift; HTTP_IMAGE=${1:-1} ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    test "$#" = "0" || usage 1
    run_main_functions "$_SCRIPTS" "$@"
}

grub_main() {
    local key items gotos r_items r_gotos img_name title client_sections
    local binary binsrc

    # Configure grub
    if [ -d /usr/lib/grub ]; then
        [ -d /usr/lib/grub/i386-pc ] || echo "Skipping Grub pc bootloader installation. Install the grub-pc-bin package if you need it."
        [ -d /usr/lib/grub/i386-efi ] || echo "Skipping Grub i386-efi bootloader installation. Install the grub-efi-ia32-bin package if you need it."
        [ -d /usr/lib/grub/x86_64-efi ] || echo "Skipping Grub x86_64-efi bootloader installation. Install the grub-efi-amd64-bin package if you need it."
        grub-mknetdir --net-directory="$TFTP_DIR" --subdir="ltsp/grub"
    else
        echo "Skipping Grub configuration. Install the grub-common package if you need it."
    fi

    # Prepare the menu text for all images and chroot
    items=""
    img_name=$(re list_img_names -i)
    set -- $img_name
    for img_name in "$@"; do
        key=$((key+1))
        title=$(echo_values "$(grub_name "$img_name.img")")
        title=${title:-$img_name.img}
        items="${items:+"$items\n"}$(grub_entry image "$img_name" "$title")"
    done
    r_items=""
    img_name=$(re list_img_names -c)
    set -- $img_name
    for img_name in "$@"; do
        key=$((key+1))
        title=$(echo_values "$(grub_name "$img_name")")
        title=${title:-$img_name}
        r_items="${r_items:+"$r_items\n"}$(grub_entry root "$img_name" "$title")"
    done
    re mkdir -p "$TFTP_DIR/ltsp"
    if [ "$OVERWRITE" = "0" ] && [ -f "$TFTP_DIR/ltsp/grub/grub.cfg" ]; then
        warn "Configuration file already exists: $TFTP_DIR/ltsp/grub/grub.cfg
To overwrite it, run: ltsp --overwrite $_APPLET ..."
    else
        client_sections=$(re client_sections)
        re install_template "grub.cfg" "$TFTP_DIR/ltsp/grub/grub.cfg" "\
s|/srv/ltsp|$BASE_DIR|g
s|^\(set cmdline_ltsp=.*\)|$(textif "$KERNEL_PARAMETERS" "\1\nset cmdline_client=\"$KERNEL_PARAMETERS\"" "&")|
s|^\(set cmdline_ltsp=.*\)|$(textif "$DEFAULT_IMAGE" "\1\nset default=\"$DEFAULT_IMAGE\"" "&")|
s/\( set timeout=\)5/$(textif "$MENU_TIMEOUT" "\1$MENU_TIMEOUT" "&")/
s|^\(# Client sections\)\$|$(textif "$client_sections" "\1\n$client_sections" "&")|
s|^\(# The \"images\" method can boot .*\)\$|$(textif "$items" "\1\n$items" "&")|
s|^\(# The \"roots\" method can boot .*\)\$|$(textif "$items" "\1\n$r_items" "&")|
s|^regexp --set=1:proto .*\$|$(textifb "$HTTP" "set proto=http\nset root=\"http,\${srv}\"" "&")|
"
    fi
    if [ "$BINARIES" != "0" ]; then
        # Prefer memtest.0 from distributions over the one from ipxe.org
        for binary in memtest.0 memtest.efi; do
            if [ "$BINARIES" = "1" ] || [ ! -f "$TFTP_DIR/ltsp/$binary" ]; then
                if [ "$binary" = "memtest.0" ] &&
                        [ -f "/boot/memtest86+.bin" ]; then
                    binsrc="/boot/memtest86+.bin"
                elif [ -f "/usr/share/ltsp/binaries/$binary" ]; then
                    binsrc="/usr/share/ltsp/binaries/$binary"
                elif [ "${binary%.*}" = "memtest" ]; then
                    warn "$binary not found, that GRUB menu won't work"
                    continue
                else
                    die "Could not locate required binary: $binary"
                fi
                re install -pm 644 "$binsrc" "$TFTP_DIR/ltsp/$binary"
                echo "Installed $binsrc in $TFTP_DIR/ltsp/$binary"
            else
                echo "Skipped existing $TFTP_DIR/ltsp/$binary"
            fi
        done
    fi
}

# Print the client sections list
client_sections() {
    local section mac first

    # If ltsp.conf doesn't exist, there's no section_list
    is_command section_list || return 0
    first=1
    for section in $(section_list); do
        # We only care about mac address sections
        case "$section" in
            section_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f]_[0-9a-f][0-9a-f])
                mac=$(echo "$section" |sed 's/section_//;s/_/:/g')
                # Use a subshell to avoid overriding useful variables
                (
                    unset DEFAULT_IMAGE KERNEL_PARAMETERS MENU_TIMEOUT
                    section_call "$mac"
                    test -n "$DEFAULT_IMAGE$KERNEL_PARAMETERS$MENU_TIMEOUT" ||
                        return 1
                    # Print an empty line between sections
                    test "$first" = "1" || printf '\\n\\n'
                    printf 'if [ "${net_default_mac}" = "%s" ]; then' "$mac"
                    test -n "$DEFAULT_IMAGE" &&
                        printf '\\n    set default="%s"' "$DEFAULT_IMAGE"
                    test -n "$KERNEL_PARAMETERS" &&
                        printf '\\n    set cmdline_client="%s"' "$KERNEL_PARAMETERS"
                    test -n "$MENU_TIMEOUT" &&
                        printf '\\n    set timeout="%s"' "$MENU_TIMEOUT"
                    printf '\\nfi'
                ) || continue
                unset first
                ;;
        esac
    done
}

grub_name() {
    echo "$*" |
        awk '{ var=toupper($0); gsub("[^A-Z0-9]", "_", var); print "GRUB_" var }'
}

grub_entry() {
    local cmdline_method img method title

    method=$1
    img=$2
    title=$3
    case "$method" in
        image)
            if [ "$HTTP_IMAGE" = 1 ]; then
                cmdline_method="ip=dhcp ltsp.image=http://\${srv}/ltsp/images/${img}.img"
            else
                cmdline_method="root=/dev/nfs nfsroot=\${srv}:/srv/ltsp ltsp.image=images/${img}.img loop.max_part=9"
            fi
        ;;
        root)
            cmdline_method="root=/dev/nfs nfsroot=\${srv}:/srv/ltsp/${img}"
        ;;
    esac

    awk -v ORS='\\n' '1'  <<EOF
menuentry "${title}" --class images {
    set cmdline="${cmdline_method} \${cmdline_ltsp} \${cmdline_client}"
    echo "\${proto}://\${srv}/ltsp/${img}/vmlinuz..."
    linux /ltsp/${img}/vmlinuz initrd=ltsp.img initrd=initrd.img \${cmdline}
    echo "\${proto}://\${srv}/ltsp/ltsp.img..."
    echo "\${proto}://\${srv}/ltsp/${img}/initrd.img..."
    initrd /ltsp/ltsp.img /ltsp/${img}/initrd.img
}
EOF
}
