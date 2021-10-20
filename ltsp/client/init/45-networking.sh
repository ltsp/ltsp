# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Handle networking
# @LTSP.CONF: DNS_SERVER SERVER SEARCH_DOMAIN HOSTNAME

# TODO: this only handles Debian-based distributions currently
networking_main() {
    # Vars already set: DEVICE, GATEWAY, IP_ADDRESS, MAC_ADDRESS
    re import_ipconfig
    re detect_server
    re config_hostname
    re config_hosts
    re config_dns
    re config_ifupdown
    re config_network_manager
    re config_validlft
    re store_networking
}

config_dns() {
    local var resolv

    # DNS=1 under [common] means to use the LTSP server IP
    if [ "$DNS" = 1 ] && [ -n "$SERVER" ]; then
        DNS_SERVER="$SERVER"
    fi

    # If no DNS_SERVER was defined in ltsp.conf or in DHCP (e.g. IPAPPEND=3),
    # check the LTSP server, gateway, and Google Public DNS.
    if [ -z "$DNS_SERVER" ] && [ -x /usr/bin/dig ]; then
        warn "No DNS_SERVER, trying autodetection!"
        for var in $SERVER $GATEWAY 8.8.8.8; do
            if dig +time=1 +tries=1 +short "@$var" localhost >/dev/null 2>&1
            then
                DNS_SERVER="$var"
                break
            fi
        done
    fi

    test -n "$DNS_SERVER" || return 0

    # The symlink may be relative or absolute, so better use grep.
    if readlink /etc/resolv.conf | grep -q /run/systemd/resolve/; then
        # Deal with systemd-resolved.
        # We can't do per link DNS without systemd-networkd
        # (e.g. when using network-manager), so define them globally
        re mkdir -p /etc/systemd/resolved.conf.d
        {
            echo "# Generated by \`ltsp init\`, see man:ltsp(8)"
            echo "[Resolve]"
            test -n "$DNS_SERVER" && echo "DNS=$DNS_SERVER"
            test -n "$SEARCH_DOMAIN" && echo "Domains=$SEARCH_DOMAIN"
        } > /etc/systemd/resolved.conf.d/ltsp.conf
    else
        if [ -x /sbin/resolvconf ] && ( [ -L /etc/resolv.conf ] ||
            [ -e /var/lib/resolvconf/convert ] )
        then
            # Deal with resolvconf
            re mkdir -p /etc/resolvconf/resolv.conf.d/
            resolv=/etc/resolvconf/resolv.conf.d/base
        else
            # Plain resolv.conf
            resolv=/etc/resolv.conf
            # Remove possibly dangling symlinks
            re rm -f "$resolv"
        fi
        {
            echo "# Generated by \`ltsp init\`, see man:ltsp(8)"
            test -n "$SEARCH_DOMAIN" && echo "search $SEARCH_DOMAIN"
            for var in $DNS_SERVER; do
                echo "nameserver $var"
            done
        } > "$resolv"
    fi
    return 0
}

config_hostname() {
    local IP MAC

    # Remove spaces and default to e.g. ltsp123
    HOSTNAME=${HOSTNAME%% *}
    HOSTNAME=${HOSTNAME:-ltsp%{IP\}}
    case "$HOSTNAME" in
        *%{IP}*)
            IP=$(
                ip -oneline -family inet address show dev "$DEVICE" |
                sed 's/.* \([0-9.]*\)\/\([0-9]*\) .*/\1.\2/' |
                awk -F "." '{ print (2^24*$1+2^16*$2+2^8*$3+$4)%(2^(32-$5)) }')
                ;;
        *%{MAC}*)
            MAC=$(echo "$MAC_ADDRESS" | tr -d ':')
            ;;
    esac
    HOSTNAME=$(re eval_percent "$HOSTNAME")
    echo "$HOSTNAME" >/etc/hostname
    re hostname "$HOSTNAME"
}

config_hosts() {
    {
        printf "# Generated by \`ltsp init\`, see man:ltsp(8)
127.0.0.1\tlocalhost
127.0.1.1\t%s%s
%s\tserver

# The following lines are desirable for IPv6 capable hosts
::1\tip6-localhost ip6-loopback
fe00::0\tip6-localnet
ff00::0\tip6-mcastprefix
ff02::1\tip6-allnodes
ff02::2\tip6-allrouters
" "${SEARCH_DOMAIN:+$HOSTNAME.$SEARCH_DOMAIN }" "$HOSTNAME" "$SERVER"
        rw echo_values "HOSTS_[[:alnum:]_]*"
    } >/etc/hosts
}

config_ifupdown() {
    # Prohibit ifupdown from managing the boot interface
    test -f /etc/network/interfaces &&
        printf "# Generated by \`ltsp init\`, see man:ltsp(8)
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

auto %s
iface %s inet manual
" "$DEVICE" "$DEVICE"> /etc/network/interfaces

    # Never ifdown anything. Safer!
    test ! -x /sbin/ifdown ||
        rw ln -sf ../bin/true /sbin/ifdown
}

config_network_manager() {
    re test "DEVICE=$DEVICE" != "DEVICE="
    rw rm -rf /run/netplan /etc/netplan /lib/systemd/system-generators/netplan

    # Prohibit network-manager from managing the boot interface
    test -d /etc/NetworkManager/conf.d &&
        printf "%s" "[keyfile]
unmanaged-devices=interface-name:$DEVICE
" > /etc/NetworkManager/conf.d/ltsp.conf
    return 0
}

# Dracut sets the IP using the valid_lft parameter. From `man ip-address`:
# > the valid lifetime of this address; see section 5.5.4 of RFC 4862.
# > When it expires, the address is removed by the kernel.
# We don't want the address to be removed by the kernel, so we change it here
# to "forever".
config_validlft() {
    local ip mask brd

    # On the other hand some setups exist, e.g. Fedora with Network Manager,
    # that renew the lease only if valid_lft != "forever".
    # In such cases, just return:
    grep -qs "^BOOTPROTO=dhcp" "/etc/sysconfig/network-scripts/ifcfg-$DEVICE" &&
        return 0

    # Example output:
    # 2: enp2s0    inet 10.161.254.11/24 brd 10.161.254.255 scope global enp2s0\       valid_lft 25147sec preferred_lft 25147sec
    # We don't match it and we don't do anything if valid_lft = "forever".
    re ip -4 -oneline addr show dev "$DEVICE" |
        sed -n 's/.* \([0-9.]*\)\/\([0-9]*\) brd \([0-9.]*\) .* valid_lft [0-9][^ ]* .*/\1 \2 \3/p' |
        while read -r ip mask brd; do
            re ip -4 addr change "$ip/$mask" broadcast "$brd" dev "$DEVICE"
        done
}

# To detect the server, we don't want to use the following:
#  - IPCONFIG_ROOTSERVER may be invalid in case of proxyDHCP.
#  - `ps -fC nbd-client` doesn't work as it's now a kernel thread.
#  - It may be available in /proc/cmdline, but it's complex to check
#    for all the variations of ip=, root=, netroot=, nbdroot= etc.
# So assume that the first TCP connection is to the server (NFS etc)
detect_server() {
    local cmd

    test -z "$SERVER" || return 0
    grep -Eqw 'root=/dev/nbd.*|root=/dev/nfs' /proc/cmdline ||
        return 0
    if is_command ss; then
        cmd="ss -tn"
    elif is_command netstat; then
        cmd="netstat -tn"
    elif is_command busybox; then
        cmd="busybox netstat -tn"
    else
        warn "Not found: ss, netstat, busybox!"
        unset cmd
    fi
    if [ -n "$cmd" ]; then
        SERVER=$(rw $cmd |
            sed -n 's/.*[[:space:]]\([0-9.:]*\):\([0-9]*\)[^0-9]*/\1/p' |
            head -1)
    fi
    # If unable to detect, default to those:
    SERVER=${SERVER:-$IPCONFIG_ROOTSERVER}
    SERVER=${SERVER:-$GATEWAY}
    SERVER=${SERVER:-192.168.67.1}
}

# Import values saved by klibc ipconfig. Example:
# DEVICE='enp0s3'
# PROTO='dhcp'
# IPV4ADDR='10.161.254.38'
# IPV4BROADCAST='10.161.254.255'
# IPV4NETMASK='255.255.255.0'
# IPV4GATEWAY='10.161.254.1'
# IPV4DNS0='194.63.237.4'
# IPV4DNS1='194.63.239.164'
# HOSTNAME=''
# DNSDOMAIN=''
# NISDOMAIN=''
# ROOTSERVER='10.161.254.1'
# ROOTPATH=''
# filename=''
# UPTIME='6'
# DHCPLEASETIME='25200'
# DOMAINSEARCH=''
import_ipconfig() {
    local var

    test -f "/run/net-$DEVICE.conf" || return 0
    # Fetch the variables but prefix IPCONFIG_ in them
    eval "$(sed 's/^[[:alpha:]]/IPCONFIG_&/' "/run/net-$DEVICE.conf")" ||
        die "Error sourcing /run/net-$DEVICE.conf"
    if [ -z "$DNS_SERVER" ]; then
       for var in $IPCONFIG_IPV4DNS0 $IPCONFIG_IPV4DNS1; do
            # ignore nameserver of 0.0.0.0, which ipconfig may return
            # if both nameservers aren't specified.
            if [ "$var" != "0.0.0.0" ]; then
                DNS_SERVER="${DNS_SERVER+$DNS_SERVER }$var"
            fi
        done
    fi
    SEARCH_DOMAIN=${SEARCH_DOMAIN:-$IPCONFIG_DNSDOMAIN}
    HOSTNAME=${HOSTNAME:-$IPCONFIG_HOSTNAME}
}

# TODO: store networking information to /run/ltsp/environ
store_networking() {
    :
}
