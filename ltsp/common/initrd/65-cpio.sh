# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

cpio_main() {
    local script

    # Syntax check all the shell scripts
    while read -r script <&3; do
        sh -n "$script" || die "Syntax error in initrd script: $script"
    done 3<<EOF
$(find "$_DST_DIR" -name '*.sh')
EOF
    # Create the initrd
    re cd "$_DST_DIR"
    {
        find . ! -name ltsp.img | cpio -oH newc | gzip > "$_DST_DIR/ltsp.img"
        # Avoid the awful "NNN blocks" message of cpio
    } 2>&1 | sed '/^[0-9]* blocks$/d' 1>&2
    re cd - >/dev/null
    re mkdir -p "$TFTP_DIR/ltsp"
    re mv "$_DST_DIR/ltsp.img" "$TFTP_DIR/ltsp/"
    re rm -r "$_DST_DIR"
    echo "Generated ltsp.img:"
    re ls -l "$TFTP_DIR/ltsp/ltsp.img"
}
