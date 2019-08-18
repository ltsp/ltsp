# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Configure NFS exports for LTSP

NFS_HOME=${NFS_HOME:-0}
NFS_TFTP=${NFS_TFTP:-1}

nfs_cmdline() {
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

nfs_main() {
    re mkdir -p /etc/exports.d
    install_template "ltsp-nfs.exports" "/etc/exports.d/ltsp-nfs.exports" "\
s|^/srv/ltsp|$BASE_DIR|
s|^/srv/tftp/ltsp|$(textif "$NFS_TFTP" "$TFTP_DIR" "#$TFTP_DIR")|
s|^#/home|$(textif "$NFS_HOME" "$HOME_DIR" "&")|
"
    re systemctl restart nfs-kernel-server
    echo "Restarted nfs-kernel-server"
}
