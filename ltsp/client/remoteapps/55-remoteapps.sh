# This file is part of LTSP, https://ltsp.org
# Copyright 2021 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Run applications on the LTSP server via ssh -X

remoteapps_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "r" -l \
        "register" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
        -r | --register) REGISTER=1 ;;
        --)
            shift
            break
            ;;
        *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    run_main_functions "$_SCRIPTS" "$@"
}

remoteapps_main() {
    if [ "$REGISTER" = 1 ]; then
        remoteapps_register "$@"
    else
        remoteapps_run "$@"
    fi
}

remoteapps_authorized_keys() {
    local key var contents

    # The first public key will be copied in authorized_keys
    # If that's not appropriate, do it manually beforehand
    unset key
    for var in ~/.ssh/*.pub; do
        test -f "$var" || continue
        key=${key:-$var}
        contents=$(cat "$var")
        if grep -qsF "$contents" ~/.ssh/authorized_keys; then
            # We're good to go
            return 0
        fi
    done
    if [ -z "$key" ]; then
        # No public key exists; create a new key
        re ssh-keygen -qf ~/.ssh/id_ed25519 -N '' -t ed25519
        key=~/.ssh/id_ed25519.pub
    fi
    (
        umask 0077
        cat "$key" >>~/.ssh/authorized_keys
    )
}

remoteapps_register() {
    local app

    for app; do
        re ln -sfn /usr/share/ltsp/client/remoteapps/ltsp-remoteapps "/usr/local/bin/$app"
    done
}

remoteapps_run() {
    re remoteapps_authorized_keys
    re ssh -X -oUserKnownHostsFile=/etc/ltsp/ssh_known_hosts server "$@"
}
