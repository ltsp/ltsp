# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# @LTSP.CONF: X_DRIVER X_HORIZSYNC X_VERTREFRESH X_PREFERREDMODE
# @LTSP.CONF: X_VIRTUAL X_MODES

xorg_conf_main() {
    test -n "$X_DRIVER$X_HORIZSYNC$X_VERTREFRESH$X_PREFERREDMODE" ||
        test -n "$X_MODELINE$X_VIRTUAL$X_MODES" ||
        return 0

    OVERWRITE=1 install_template "xorg.conf" "/etc/X11/xorg.conf" "\
s|^\( *\)# \(Driver *\).*|$(textif "$X_DRIVER" "\1\2  \"$X_DRIVER\"" "&")|
s|^\( *\)# \(HorizSync *\).*|$(textif "$X_HORIZSYNC" "\1\2  $X_HORIZSYNC" "&")|
s|^\( *\)# \(VertRefresh *\).*|$(textif "$X_VERTREFRESH" "\1\2  $X_VERTREFRESH" "&")|
s|^\( *\)# \(Option *\)\(\"PreferredMode\" *\).*|$(textif "$X_PREFERREDMODE" "\1\2  \3\"$X_PREFERREDMODE\"" "&")|
s|^\( *\)# \(Modeline *\).*|$(textif "$X_MODELINE" "\1\2  $X_MODELINE" "&")|
s|^\( *\)# \(Virtual *\).*|$(textif "$X_VIRTUAL" "\1\2  $X_VIRTUAL" "&")|
s|^\( *\)# \(Modes *\).*|$(textif "$X_MODES" "\1\2  $X_MODES" "&")|
"
}
