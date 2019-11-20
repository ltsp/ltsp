# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# @LTSP.CONF: PWMERGE_SUR PWMERGE_SGR PWMERGE_DUR PWMERGE_DGR
# @LTSP.CONF: PASSWORDS_x

pam_main() {
    test "$LOCAL_AUTH" != "1" ||
        return 0
    local userpass user pass

    re "$_LTSP_DIR/client/login/pwmerge" \
        ${PWMERGE_SUR:+"--sur=$PWMERGE_SUR"} \
        ${PWMERGE_SGR:+"--sgr=$PWMERGE_SGR"} \
        ${PWMERGE_DUR:+"--dur=$PWMERGE_DUR"} \
        ${PWMERGE_DGR:+"--dgr=$PWMERGE_DGR"} \
        -lq /etc/ltsp /etc /etc
    re "$_LTSP_DIR/client/login/pamltsp" install
    userpass=$(re echo_values "PASSWORDS_[[:alnum:]_]*")
    # Disable globs
    set -f
    for userpass in $userpass; do
        user=${userpass%%/*}
        pass=${userpass##*/}
        if [ -n "$user" ] && grep -q "^$user:pamltsp" /etc/shadow; then
            re sed "s/^\($user:pamltsp\)[^:]*/\1=$pass/" -i /etc/shadow
        else
            warn "No shadow entries found for user regexp: $user"
        fi
    done
    set +f
}
