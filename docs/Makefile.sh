#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Use go-md2man to convert the .md files into manpages;
# put the output in ./man/man[0-9] subdirectories, to make packaging easier,
# and to be able to test with: `MANPATH=man man ltsp kernel`

# To get a list of all lts.conf parameters, run:
# echo $(grep -r LTSP.CONF | sed 's/.*LTSP.CONF://' | tr ' ' '\n' | sort -u)

footer() {
    cat <<EOF
## COPYRIGHT
Copyright 2019 the LTSP team, see AUTHORS

## SEE ALSO
**ltsp**(8), **ltsp.conf**(5), **ltsp-dnsmasq**(8), **ltsp-image**(8),
**ltsp-info**(8), **ltsp-initrd**(8), **ltsp-ipxe**(8), **ltsp-kernel**(8),
**ltsp-nfs**(8)
EOF
}

set -e
cd "${1%/*}"
if command -v dpkg-parsechangelog >/dev/null; then
    VERSION=$(dpkg-parsechangelog -l ../debian/changelog -S VERSION)
else
    VERSION=$(. ../ltsp/common/ltsp/55-ltsp.sh && echo "$_VERSION")
fi
date=$(date "+%Y-%m-%d")
rm -rf man
for mp in *.[0-9].md; do
    applet_section=${mp%.md}
    applet=${applet_section%.[0-9]}
    section=${applet_section#$applet.}
    description=$(sed -n '2s/.*- \(.*\)/\1/p' "$mp")
    mkdir -p "man/man$section"
    # TODO: omit the current applet from SEE ALSO
    if command -v ronn >/dev/null; then
        ronn --manual "LTSP Manual" --organization "LTSP $VERSION" \
            --date "$date" > "man/man$section/$applet.$section" <<EOF
$applet($section) -- $description
=====================================
$(sed "1,2d" "$mp")
$(footer)
EOF
        test -d ../../ltsp.github.io/docs/ || continue
        mkdir -p "../../ltsp.github.io/docs/$applet"
        ronn --html --manual "LTSP Manual" --organization "LTSP $VERSION" \
            --date "$date" > "../../ltsp.github.io/docs/$applet/index.html" <<EOF
$applet($section) -- $description
=====================================
$(sed "1,2d" "$mp")
$(footer)
EOF
    else
        go-md2man > "man/man$section/$applet.$section" <<EOF
$applet $section $date "LTSP $VERSION"
=====================================
$(cat "$mp")
$(footer)
EOF
        # TODO: work around https://github.com/cpuguy83/go-md2man/issues/26
        sed 's/\\~/~/g' -i "man/man$section/$applet.$section"
    fi
done
