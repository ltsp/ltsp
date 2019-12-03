# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Run various tasks on network-online.target

service_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "s" -l \
        "stop" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -s|--stop) STOP=1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    run_main_functions "$_SCRIPTS" "$@"
}

service_main() {
    disable_flow_control
    enable_nat
    set_readahead
}

# We want to disable flow control in all interfaces, as all of them might
# serve LTSP clients.
disable_flow_control() {
    local iface output msg neg capabilities

    for iface in /sys/class/net/*/device; do
        test -e "$iface" || continue
        iface=${iface%/device}
        iface=${iface##*/}
        msg="Couldn't disable flow control for $iface"
        # If this interface supports ethtool
        if is_command ethtool && output=$(ethtool --show-pause "$iface")
        then
            # If flow control is enabled
            if echo "$output" | grep -q '^RX:.*on'; then
                # Some NICs like Intel [8086:10d3] require "autoneg off rx off",
                # while other like Marvel [11ab:4320] require "autoneg on rx off".
                # So we actually need to call ethtool again to check if it worked.
                msg="Failed to disable flow control for $iface using ethtool"
                for neg in off on; do
                    ethtool --pause "$iface" autoneg "$neg" rx off || true
                    if ethtool --show-pause "$iface" | grep -q '^RX:.*off'; then
                        msg="Disabled flow control (autoneg $neg, rx off) for $iface using ethtool"
                        break
                    fi
                done
            else
                msg="Flow control was already disabled for $iface using ethtool"
            fi
        # If this interface supports mii-tool
        elif is_command mii-tool && output=$(mii-tool -v "$iface")
        then
            # If flow control is enabled
            if echo "$output" | grep -q 'advertising:.*flow-control'; then
                capabilities=$(echo "$output" | sed -n 's/.*capabilities: *//p')
                if mii-tool -A "$capabilities" "$iface"; then
                    msg="Disabled flow control for $iface using mii-tool"
                else
                    msg="Failed to disable flow control for $iface using mii-tool"
                fi
            else
                msg="Flow control was already disabled for $iface using mii-tool"
            fi
        fi >/dev/null 2>&1
        warn "$msg"
    done
}

enable_nat() {
    local ipv4_forward

    # Only enable NAT on servers, if NAT=1 or IP_ADDRESS=192.168.67.1
    if [ -d /run/ltsp/client ] || [ "$NAT" = "0" ] ||
        { [ "$NAT" != "1" ] && [ "$IP_ADDRESS" != "192.168.67.1" ]; };
    then
        return 0
    fi
    # For now, just check if ip forwarding was already enabled;
    # TODO: in the future, introduce persistent_vars
    read -r ipv4_forward </proc/sys/net/ipv4/ip_forward
    if [ "$ipv4_forward" = 1 ]; then
        warn "IP forwarding was already enabled"
        return 0
    fi
    echo 1 >/proc/sys/net/ipv4/ip_forward
    rw iptables -s 192.168.67.0/24 -t nat -A POSTROUTING -j MASQUERADE
    warn "Enabled IP forwarding/masquerading for 192.168.67.0/24"
}
