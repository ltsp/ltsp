# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Policykit related stuff
polkit_main() {
    # Disable suspend and hibernate on LTSP clients
    # PolicyKit < 0.106 doesn't support .rules files (LP: #1086783)

    if [ -f /usr/share/polkit-1/actions/org.freedesktop.login1.policy ]; then
        # Set <allow_*>no inside these address ranges
        re sed -e '/<action id="org.freedesktop.login1.suspend/,/<\/action>/ s/\(<allow.*>\)[^<]*</\1no</' \
            -e '/<action id="org.freedesktop.login1.hibernate/,/<\/action>/ s/\(<allow.*>\)[^<]*</\1no</' \
            -i /usr/share/polkit-1/actions/org.freedesktop.login1.policy
    fi
}
