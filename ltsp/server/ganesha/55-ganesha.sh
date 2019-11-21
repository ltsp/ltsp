# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Configure NFS exports for LTSP

NFS_HOME=${NFS_HOME:-0}
NFS_TFTP=${NFS_TFTP:-1}

ganesha_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "h:t:" -l \
        "nfs-home:,nfs-tftp:" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -h|--nfs-home) shift; NFS_HOME=$1 ;;
            -t|--nfs-tftp) shift; NFS_TFTP=$1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    test "$#" = "0" || usage 1
    run_main_functions "$_SCRIPTS" "$@"
}

ganesha_conf_exclude(){
    sed -i "/^%include \"$(echo $1 | sed 's|/|\\/|g')\"/d" /etc/ganesha/ganesha.conf
}

ganesha_conf_include(){
    grep -q "^%include \"$1\"" /etc/ganesha/ganesha.conf ||
        re echo "%include \"$1\"" >> /etc/ganesha/ganesha.conf
}

ganesha_main() {
    re mkdir -p /etc/ganesha/ltsp

    re install_template "ltsp/base.conf" "/etc/ganesha/ltsp/base.conf" \
        "s|/srv/ltsp|$BASE_DIR|"

    re ganesha_conf_include "ltsp/base.conf"

    if [ "${NFS_TFTP:-1}" = "1" ]; then
        re ganesha_conf_include "ltsp/tftp.conf"
        re install_template "ltsp/tftp.conf" "/etc/ganesha/ltsp/tftp.conf" \
            "s|/srv/tftp/ltsp|$TFTP_DIR/ltsp|"
    else
        re ganesha_conf_exclude "ltsp/tftp.conf"
        rm -f "/etc/ganesha/ltsp/tftp.conf"
    fi

    if [ "${NFS_HOME:-0}" = "1" ]; then
        re ganesha_conf_include "ltsp/home.conf"
        re install_template "ltsp/home.conf" "/etc/ganesha/ltsp/home.conf" \
            "s|/home|$HOME_DIR|"
    else
        re ganesha_conf_exclude "ltsp/home.conf"
        rm -f "/etc/ganesha/ltsp/home.conf"
    fi

    re mkdir -p "$BASE_DIR" "$TFTP_DIR/ltsp"
    re systemctl restart nfs-ganesha
    echo "Restarted nfs-ganesha"
}
