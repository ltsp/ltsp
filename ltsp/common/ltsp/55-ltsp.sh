# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2021 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Handle the pre-applet part of the ltsp command line
# @LTSP.CONF: BASE_DIR TFTP_DIR HOME_DIR PRE_APPLET_x POST_APPLET_x

# Constant variables may be set in any of the following steps:
# 1) user: environment, `VAR=value ltsp ...`
# 2) distro: 11-ltsp-distro.sh for all applets
# 3) upstream: 55-ltsp.sh for all applets
# 4) user: /etc/ltsp/ltsp.conf for all applets
# 5) distro: 11-$_APPLET-distro.sh for a specific applet
# 6) upstream: 55-$_APPLET-distro.sh for a specific applet
# For proper ordering, upstream and distros should use `VAR=${VAR:-value}`.
# We're still in the "sourcing" phase, so subsequent scripts may even use the
# variables before the "execution" phase.
# 7) user: cmdline `ltsp ... --VAR=value`, evaluated at the execution phase
# Btw, to see all constants: grep -rIwoh '$[A-Z][_A-Z0-9]*' | sort -u

BASE_DIR=${BASE_DIR:-/srv/ltsp}
TFTP_DIR=${TFTP_DIR:-/srv/tftp}
HOME_DIR=${HOME_DIR:-/home}

ltsp_cmdline() {
    local show_help help_param base_dir home_dir overwrite tftp_dir args

    show_help=0
    help_param=
    base_dir=
    home_dir=
    overwrite=
    tftp_dir=
    # No getopt in the initramfs; avoid it if $1 isn't an option
    if [ "${1#-}" != "$1" ]; then
        args=$(getopt -n "ltsp" -o "+b:h::m:o::t:V" -l \
            "base-dir:,help::,home-dir:,overwrite::,tftp-dir:,version" -- "$@") ||
            usage 1
        eval "set -- $args"
        while true; do
            case "$1" in
            -b | --base-dir)
                shift
                BASE_DIR=$1
                base_dir=$1
                ;;
            -h | --help)
                shift
                help_param=$1
                show_help=1
                ;;
            -m | --home-dir)
                shift
                HOME_DIR=$1
                home_dir=$1
                ;;
            -o | --overwrite)
                shift
                OVERWRITE=${1:-1}
                overwrite=${1:-1}
                ;;
            -t | --tftp-dir)
                shift
                TFTP_DIR=$1
                tftp_dir=$1
                ;;
            -V | --version)
                version
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *) die "ltsp: error in cmdline: $*" ;;
            esac
            shift
        done
    fi
    # Support `ltsp --help`, `ltsp --help=applet` and `ltsp --help applet`
    if [ "$show_help" = "1" ]; then
        if [ -n "$help_param" ] || [ -n "$1" ]; then
            _APPLET=${help_param:-$1}
        fi
        usage 0
    elif [ -z "$1" ]; then
        # Plain `ltsp` shows usage and exits with error
        usage 1
    fi
    # "$@" is the applet parameters; don't use it for the ltsp main functions
    re run_main_functions "$_SCRIPTS"
    _APPLET="$1"
    shift
    # ltsp.conf is evaluated on every `ltsp applet` call; it needs network_vars
    re network_vars
    if [ -r /etc/ltsp/ltsp.conf ]; then
        re eval_ini /etc/ltsp/ltsp.conf
    fi
    # Mainly for `login` and `session` applets
    if [ -r "/etc/ltsp/ltsp-$_APPLET.conf" ]; then
        re eval_ini "/etc/ltsp/ltsp-$_APPLET.conf"
    fi
    # Command line arguments take precedence over ltsp.conf; restore them
    BASE_DIR=${base_dir:-$BASE_DIR}
    HOME_DIR=${home_dir:-$HOME_DIR}
    OVERWRITE=${overwrite:-$OVERWRITE}
    TFTP_DIR=${tftp_dir:-$TFTP_DIR}
    # We could put the rest of the code below in an ltsp_main() function,
    # but we want ltsp/scriptname_main()s to finish before any applet starts
    re locate_applet_scripts "$_APPLET"
    # Remember, locate_applet_scripts has just updated $_SCRIPTS
    re source_scripts "$_SCRIPTS"
    re omit_functions
    re run_parameters "PRE"
    re "$_APPLET_FUNCTION" "$@"
    re run_parameters "POST"
}
