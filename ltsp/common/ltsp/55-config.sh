# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2021 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Functions related to LTSP configuration and environment variables

# Output the values of all the variables that match the expression.
# A second "invert-match" expression is also supported.
echo_values() {
    local ex1 ex2 var value

    ex1=$1
    # ex2 defaults to an unmatchable expression
    ex2=${2:-.^}
    for var in $(echo_vars "$ex1" "$ex2"); do
        eval "value=\$$var"
        echo "$value"
    done
}

# Output the names of all the variables that match the expression.
# A second "invert-match" expression is also supported.
echo_vars() {
    local ex1 ex2 var value

    ex1=$1
    # ex2 defaults to an unmatchable expression
    ex2=${2:-.^}
    while IFS="=" read -r var value; do
        eval "value=\$$var"
        test -n "$value" || continue
        echo "$var"
    # We want "[[:alnum:]_]*" to match only English letters, hence LC_ALL=C
    done <<EOF
$(set | LC_ALL=C grep -E "^$ex1=" | LC_ALL=C grep -vE "^$ex2=")
EOF
}

eval_ini() {
    local config applet clients_section server_section sub_dir

    config=${1:-/etc/ltsp/ltsp.conf}
    applet=${2:-$_APPLET}
    if [ -d /run/ltsp/client ] || [ "$$" = "1" ]; then
        clients_section=clients
        # Server applets that run on clients should also evaluate [SERVER]
        sub_dir=${_APPLET_DIR%/*}
        sub_dir=${sub_dir##*/}
        if [ "$sub_dir" = "server" ]; then
            server_section=server
        else
            server_section=
        fi
    else
        clients_section=
        server_section=server
    fi
    eval "$(ini2sh "$config")" || die "Error while evaluating $config"
    re section_call unnamed $clients_section common $server_section "$MAC_ADDRESS" "$IP_ADDRESS"
    # MAC/IP sections are allowed to set HOSTNAME
    re section_call "$HOSTNAME"
    if [ "${applet:-ltsp}" != "ltsp" ]; then
        re section_call "$applet/" "$applet/$MAC_ADDRESS" \
            "$applet/$IP_ADDRESS" "$applet/$HOSTNAME"
    fi
}

# Replace % with $ and then eval the resulting string.
# In some cases we need strings with variables like
# LTSPDM_USERS="(guest|[ab][0-9]-)%{HOSTNAME#pc}"
# ...but have the variables evaluated later, not at assignment time.
eval_percent() {
    # Use cat <<EOF to process $ while allowing single/double quotes
    eval "cat <<EOF
$(echo "$*" | tr '%' '$')
EOF
"
}

# Convert an .ini file, like ltsp.conf, to a shell sourceable file.
# The basic ideas are:
# [a1:b2:c3:d4:*:*] becomes a function: section_a1_b2_c3_d4____() {
# INCLUDE=old_monitor becomes a call: section_old_monitor
# And a section_call() function is implemented to use like:
#   section_call "unnamed"
#   section_call "common"
#   section_call "$applet/"
#   section_call "$mac"
#   section_call "$ip"
#   section_call "$applet/$hostname"
# Use lowercase in parameters.
# To name the functions something_* rather than section_*, use:
#   ini2sh -v prefix=something_
ini2sh() {
    re awk -f - "$1" <<"EOF"
BEGIN {
    if (prefix == "") {
        prefix="section_"
    } else {
        # Sanitize prefix passed in the cmdline
        prefix=tolower(prefix)
        gsub("[^a-z0-9]", "_", prefix)
    }
    # We maintain two lists for sections, to be used later
    list_sections=""
    list_cases=""
    # Cope with parameters above all sections, which is a user error
    section_id=prefix "unnamed"
    print section_id "() {\n"\
        "# Prevent infinite recursion\n"\
        "test \"$" section_id "\" = 1 && return 0 || " section_id "=1"
}
{
if ($0 ~ /^[ ]*\[[^]]*\]/) {  # [Section]
    print "}\n"
    section=tolower($0)
    sub("#.*", "", section)
    gsub("[^-*./:?@_|0-9a-z]", "", section)
    section_id=section
    section_id=prefix section_id
    gsub("[^a-z0-9]", "_", section_id)
    print section_id "() {\n"\
        "test \"$" section_id "\" = 1 && return 0 || " section_id "=1"
    # Append the appropriate case line
    list_cases=list_cases "\n            " section ")  " section_id " \"$@\" ;;"
    list_sections=list_sections "\n" section_id
} else if (tolower($0) ~ /^include *=/) {  # INCLUDE = xxx
    value=tolower($0)
    sub("#.*", "", value)
    sub("include *= *", "", value)
    gsub("[^-*./:?@_|0-9a-z]", "", value)
    print prefix "call \"" value "\""
} else if ($0 ~ /^[a-zA-Z0-9_]* *=/) {  # VAR = xxx
    value=$0
    sub(" *= *", "=", value)  # remove spaces only around the first =
    print value
} else {
    print $0
}
}
END {
    print "}\n\n"\
        "# List all sections, to be able to loop over them\n"\
        prefix "list() {\n"\
        "    echo \"\\"\
        list_sections "\"\n"\
        "}\n\n"\
        "# Example usage: " prefix "call \"unnamed\" \"clients\" \"$MAC\" \"$IP\" \"$lower_hostname\"\n"\
        prefix "call() {\n"\
        "    local section\n"\
        "\n"\
        "    for section in \"$@\"; do\n"\
        "        case \"$section\" in\n"\
        "            unnamed)  " prefix "unnamed \"$@\" ;;"\
        list_cases\
        "\n        esac\n"\
        "    done\n"\
        "}"
}
EOF
}

install_template() {
    local backup src dst sedp dstdir sname sext language

    if [ "$1" = "-b" ]; then
        backup=1
        shift
    else
        backup=
    fi
    src=$1
    dst=$2
    sedp=$3
    if [ -e "$dst" ] && [ "$OVERWRITE" = "0" ]; then
        die "Configuration file already exists: $dst
To overwrite it, run: ltsp --overwrite $_APPLET ..."
    fi
    dstdir=${dst%/*}
    re mkdir -p "$dstdir"
    # Prefer localized templates, if they exist.
    sname=${src%%.*}
    if [ "$sname" != "$src" ]; then
        sext=".${src#*.}"
    else
        unset sext
    fi
    language=${LANGUAGE:-$LANG}
    for language in "${language%%:*}" "${language%%.*}" "${language%%_*}" ""; do
        language=${language:+"-$language"}
        test -f "$_APPLET_DIR/$sname$language$sext" || continue
        if [ "$backup" = "1" ] && [ -f "$dst" ]; then
            re mv "$dst" "$dst.old"
        fi
        re sed "$sedp" "$_APPLET_DIR/$sname$language$sext" > "$dst"
        echo "Installed $_APPLET_DIR/$sname$language$sext in ${dst#%.tmp}"
        return 0
    done
    die "Template file $src not found."
}

kernel_vars() {
    # Exit if already evaluated
    test "$kernel_vars" = "1" && return 0 || kernel_vars=1

    # Extreme scenario: ltsp.image="/path/to ltsp.vbox=1"
    # We don't want that to set VBOX=1.
    # Plan: replace spaces between quotes with \001,
    # then split the parameters using space,
    # then keep the ones that look like ltsp.var=value,
    # and finally restore the spaces.
    # TODO: should we add quotes when they don't exist?
    # Note that it'll be hard when var=value" with "quotes" inside "it
    eval "
$(awk 'BEGIN { FS=""; }
    {
        s=$0   # source
        d=""   # dest
        inq=0  # in quote
        split(s, chars, "")
        for (i=1; i <= length(s); i++) {
            if (inq && chars[i] == " ")
                d=d "\001"
            else {
                d=d "" chars[i]
                if (chars[i] == "\"")
                    inq=!inq
            }
        }
        split(d, vars, " ")
        for (i=1; i in vars; i++) {
            gsub("\001", " ", vars[i])
            if (tolower(vars[i]) ~ /^ltsp.[a-zA-Z][-a-zA-Z0-9_]*=/) {
                varvalue=substr(vars[i], 6)
                eq=index(varvalue,"=")
                var=toupper(substr(varvalue, 1, eq-1))
                gsub("-", "_", var)
                value=substr(varvalue, eq+1)
                printf("%s=%s\n", var, value)
            }
        }
    }
    ' < /proc/cmdline)"
}

# We care about the IP/MAC used to connect to the LTSP server, not all of them
# To handle multiple MACs in ltsp.conf, use INCLUDE=
# Note that it's "GATEWAY to 192.168.67.1", not always the real gateway
network_vars() {
    local ip _dummy

    test -n "$DEVICE" && test -n "$IP_ADDRESS" && test -n "$MAC_ADDRESS" &&
        return 0
    # 192.168.67.1 is for clients and servers != 192.168.67.1,
    # 192.168.67.2 is to get DEVICE (instead of lo) when server = 192.168.67.1
    for ip in 192.168.67.1 192.168.67.2; do
        # Get the words around "dev" and "src"; possible output:
        # client1: 192.168.67.1 dev enp3s0 src 192.168.67.20 uid 0 \    cache
        # client2: 192.168.67.1 via 10.161.254.1 dev enp3s0 src 10.161.254.20 uid 0 \    cache
        # server1: 192.168.167.1 via 10.161.254.1 dev enp2s0 src 10.161.254.11 uid 0 \    cache
        # server2: local 192.168.67.1 dev lo src 192.168.67.1 uid 0 \    cache <local>
        # server2: 192.168.67.2 dev enp5s0 src 192.168.67.1 uid 0 \    cache
        read -r GATEWAY _dummy DEVICE _dummy IP_ADDRESS<<EOF
$(rw ip -o route get "$ip" | grep -o '[^ ]* *dev *[^ ]* *src *[^ ]*')
EOF
        if [ "$_dummy" != "src" ] || [ -z "$GATEWAY" ] ||
            [ -z "$DEVICE" ] || [ -z "$IP_ADDRESS" ]
        then
            warn "Could not parse output of: ip -o route get $ip"
            continue
        fi
        if [ "$DEVICE" = "lo" ]; then
            continue
        elif [ "$IP_ADDRESS" = "192.168.67.1" ]; then
            GATEWAY=$IP_ADDRESS
        else
            break
        fi
    done
    # Empty IP might mean "server with unplugged cable"; let's find a DEVICE
    if [ -z "$IP_ADDRESS" ]; then
        for DEVICE in /sys/class/net/*/device ""; do
            test -e "$DEVICE" || continue
            DEVICE=${DEVICE%/device}
            DEVICE=${DEVICE##*/}
            break
        done
    fi
    read -r _dummy MAC_ADDRESS <<EOF
$(re ip -o link show dev "$DEVICE" | grep -o 'link/ether [^ ]*')
EOF
    re test "MAC_ADDRESS=$MAC_ADDRESS" != "MAC_ADDRESS="
    # HOSTNAME is needed for eval_ini before import_ipconfig
    HOSTNAME=${HOSTNAME:-$(hostname)}
    test "$HOSTNAME" != "(none)" || unset HOSTNAME
}

# Omit functions specified in OMIT_FUNCTIONS
omit_functions() {
    local fun

    for fun in $OMIT_FUNCTIONS; do
        eval "$fun() { echo Omitting $fun; }"
    done
}

# Run parameters like PRE_INIT_XORG="ln -sf ../ltsp/xorg.conf /etc/X11/xorg.conf"
# $1 is either PRE or POST.
run_parameters() {
    local cap_applet ex1 ex2 parameters

    cap_applet=$(echo "$_APPLET" | awk '{ print(toupper($0)) }' |
        LC_ALL=C sed 's/[^[:alnum:]]/_/g')
    ex1="${1}_${cap_applet}_[[:alnum:]_]*"
    if [ "$cap_applet" = "INITRD" ]; then
        ex2="${ex1}BOTTOM_"
    else
        ex2=.^
    fi
    parameters=$(echo_values "$ex1" "$ex2")
    test -n "$parameters" || return 0
    re eval "$parameters"
}

# Used by install_template. This is for strings.
textif() {
    if [ -n "$1" ]; then
        echo "$2"
    else
        echo "$3"
    fi
}

# Used by install_template. This is for booleans.
textifb() {
    if [ "${1:-0}" != "0" ]; then
        echo "$2"
    else
        echo "$3"
    fi
}
