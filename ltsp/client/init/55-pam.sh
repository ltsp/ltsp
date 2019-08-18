# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# @LTSP.CONF: PWMERGE_SUR PWMERGE_SGR PWMERGE_DUR PWMERGE_DGR

pam_main() {
    re "$_LTSP_DIR/client/login/pwmerge" \
        ${PWMERGE_SUR:+"--sur=$PWMERGE_SUR"} \
        ${PWMERGE_SGR:+"--sur=$PWMERGE_SGR"} \
        ${PWMERGE_DUR:+"--sur=$PWMERGE_DUR"} \
        ${PWMERGE_DGR:+"--sur=$PWMERGE_DGR"} \
        -lq /etc/ltsp /etc /etc
    re "$_LTSP_DIR/client/login/pamltsp" install
}
