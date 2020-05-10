# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2020 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# @LTSP.CONF: PWMERGE_SUR PWMERGE_SGR PWMERGE_DUR PWMERGE_DGR
# @LTSP.CONF: PASSWORDS_x

pam_main() {
    local userpass user pass

    re "$_LTSP_DIR/client/login/pwmerge" \
        ${PWMERGE_SUR:+"--sur=$(re eval_percent "$PWMERGE_SUR")"} \
        ${PWMERGE_SGR:+"--sgr=$(re eval_percent "$PWMERGE_SGR")"} \
        ${PWMERGE_DUR:+"--dur=$(re eval_percent "$PWMERGE_DUR")"} \
        ${PWMERGE_DGR:+"--dgr=$(re eval_percent "$PWMERGE_DGR")"} \
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
