# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Install iPXE binaries and configuration in TFTP
# @LTSP.CONF: DEFAULT_IMAGE KERNEL_PARAMETERS MENU_TIMEOUT

BINARIES_URL=${BINARIES_URL:-https://github.com/ltsp/binaries/releases/latest/download}

ipxe_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

ipxe_prepvar() {
    echo "$*" |
        awk '{ var=toupper($0); gsub("[^A-Z0-9]", "_", var); print var }'
}

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
    local key items gotos methods boot_name boot_names item_label title client_sections binary sedp subdir boot_method_vars boot_method_var boot_method boot_method_name boot_method_target is_default

    # Prepare the menu text for all images and chroots
    key=0
    items=""   # The menu items to be inserted.
    gotos=""   # Jump targets setting correct ${img} var for menu items.
    methods="" # Jump targets with the respective boot_method.

    # INFO: The images/chroots automatism has been removed. It has been replaced
    # by the BOOT_METHOD functionality, which can achieve the same thing but
    # without hardwiring LTSP to any specific BOOT_METHOD.
    # As a side effect some code repititions have also been remove.

    # Extracts all vars with pattern BOOT_METHOD_[0-9]* and prepares boot
    # options for their respective dirs.
    boot_method_vars=$(echo_vars "BOOT_METHOD_[0-9]*")
    set -- $boot_method_vars

    for boot_method_var in "$@"; do
      eval "subdir=\$${boot_method_var}_DIR"
      eval "boot_method=\$${boot_method_var}"
      eval "boot_method_name=\$${boot_method_var}_NAME"
      boot_method_target=$(ipxe_lowercase ${boot_method_var})
      methods="${methods}${boot_method_target}:\nset cmdline_boot_method $boot_method \&\& goto ltsp\n"
      items="${items:+"$items\n"}$(printf "item --gap %s" "$boot_method_name")"
      boot_names=$(re list_boot_names $BASE_DIR/$subdir)
      set -- $boot_names
      for boot_name in "$@"; do
        key=$((key+1))
        [ $(ipxe_prepvar "${boot_method_var}_${boot_name}") = "${BOOT_DEFAULT}" ] && is_default=" --default" || is_default=""
        item_label=${key}_${boot_name}
        title=$(echo_values "$(ipxe_prepvar "${boot_method_var}_${boot_name}")")
        title="${title:-${boot_name} (./${subdir}${subdir:+/}${boot_name})}"
        if [ $key -lt 10 ]; then
          items="${items:+"$items\n"}$(printf "item%s --key %d %-20s %s" "$is_default" "$((key%10))" "$item_label" "$title")"
        else
          items="${items:+"$items\n"}$(printf "item%s %-28s %s" "$is_default" "$((key%10))" "$item_label" "$title")"
        fi
        gotos="$gotos:${item_label}:\nset img $boot_name \&\& goto ${boot_method_target}\n"

      done
    done

    re mkdir -p "$TFTP_DIR/ltsp"
    if [ "$OVERWRITE" != "1" ] && [ -f "$TFTP_DIR/ltsp/ltsp.ipxe" ]; then
        warn "Configuration file already exists: $TFTP_DIR/ltsp/ltsp.ipxe
To overwrite it, run: ltsp --overwrite $_APPLET ..."
    else
        client_sections=$(re client_sections)

        sedp="\
s|^/srv/ltsp|$BASE_DIR|g
s/\(|| set menu-timeout \)5000/$(textif "$MENU_TIMEOUT" "\1$MENU_TIMEOUT" "&")/
s|^:61:6c:6b:69:73:67\$|$(textif "$client_sections" "$client_sections" "&")|
s|^#.*item.*\bimages\b.*|$(textif "$items" "$items" "&")|
s|^:gotos\$|$(textif "$items" "$gotos" "&")|
s|^:boot_methods\$|$(textif "$items" "$methods" "&")|
"

        re install_template "ltsp.ipxe" "$TFTP_DIR/ltsp/ltsp.ipxe" "$sedp"
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
                    printf '\\ngoto start'
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
