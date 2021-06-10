# This file is part of LTSP, https://ltsp.org
# Copyright 2021 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Override desktop sessions to prefix some LTSP code

session_cmdline() {
    local msg fname

    msg=""
    for fname in ~/.config/ltsp/session/*; do
        test -f "$fname" || continue
        msg=$(
            . "$fname" && printf "%s\n<i>  * On %s since %s</i>" \
                "$msg" "$HOSTNAME" "${fname##*/}"
        )
    done
    if [ -n "$msg" ]; then
        msg="$msg

Multiple simultaneous logins are not supported.
<b>If you continue, all other sessions will be logged out,
and any unsaved work may be lost.</b>

Would you like to continue?"
        "$_LTSP_DIR/common/ltsp/dialog" "$msg" "You are already logged in!" ||
            exit 0
    fi
    if [ ! -d ~/.config/ltsp/session ]; then
        re mkdir -pm 700 ~/.config
        re mkdir -p ~/.config/ltsp/session
    fi
    rm -f ~/.config/ltsp/session/*
    fname=~/.config/ltsp/session/"$(date +%Y%m%d-%H%M%S)"
    printf "HOSTNAME=%s\nIP_ADDRESS=%s\nMAC_ADDRESS=%s\n" \
        "$(hostname)" "$IP_ADDRESS" "$MAC_ADDRESS" >"$fname"
    # Cleanup on either normal or abnormal termination
    exit_command "pkill -u '$(id -un)'"
    exit_command "rm -f '$fname'"
    # Run the session in the background
    "$@" &
    pid=$!
    # `tail --follow=name` works over SSHFS and locally,
    # but not over NFS with nolock. Use a sleep loop instead.
    while [ -d "/proc/$pid" ] && [ -f "$fname" ]; do
        sleep 1
    done
}
