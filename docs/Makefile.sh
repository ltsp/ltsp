#!/bin/bash
# This file is part of LTSP, https://ltsp.org
# Copyright 2019-2022 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Use go-md2man, pandoc or ronn to convert the .md files into manpages;
# put the output in ./man/man[0-9] subdirectories, to make packaging easier,
# and to be able to test with: `MANPATH=man man ltsp kernel`
# A more extensive way to test is:
# MAN_GENERATOR=pandoc ./Makefile.sh
# mandoc -T html man/man5/ltsp.conf.5 > man/man5/ltsp.conf.5.html
# man man/man5/ltsp.conf.5.html
# yelp man/man5/ltsp.conf.5
# For mandoc automatic anchors to work properly, use **parameter**=_value_,
# not **parameter=**_value_.
# Regarding formatting, remember the `man man` advice:
# bold text          type exactly as shown.
# italic text        replace with appropriate argument.
# [-abc]             any or all arguments within [ ] are optional.
# -a|-b              options delimited by | cannot be used together.
# argument ...       argument is repeatable.
# [expression] ...   entire expression within [ ] is repeatable.

# To get a list of all ltsp.conf parameters, run:
# echo $(grep -r LTSP.CONF | sed 's/.*LTSP.CONF://' | tr ' ' '\n' | sort -u)

# Normally I'd use `set -eu` but that explodes with this script
set -o pipefail

_APPLET=
_DATE=
_DESCRIPTION=
_MANUAL="LTSP Manual"
_ORGANIZATION=
_SECTION=
_TITLE=
_VERSION=
_EOT=$(printf "\004")

footer() {
    sed "s/\*\*$_APPLET\*\*($_SECTION)//;s/, , /, /;s/, $//;s/^, //" <<EOF

## COPYRIGHT

Copyright 2019-2022 the LTSP team, see AUTHORS.

## SEE ALSO

**ltsp**(8), **ltsp.conf**(5), **ltsp-dnsmasq**(8), **ltsp-image**(8),
**ltsp-info**(8), **ltsp-initrd**(8), **ltsp-ipxe**(8), **ltsp-kernel**(8),
**ltsp-nfs**(8), **ltsp-remoteapps**(8)

Online documentation is available on <https://ltsp.org>
EOF
}

is_command() {
    command -v "$@" >/dev/null
}

# Unresolved issues:
# - Bullets in yelp
wrap_md2man() {
    local applet_up found_name line

    # preprocess | go-md2man | postprocess
    {
        applet_up=$(echo "$_APPLET" | awk '{ print toupper($0) }')
        # https://github.com/cpuguy83/go-md2man/blob/master/go-md2man.1.md
        cat <<EOF
# $applet_up $_SECTION "$_DATE" "LTSP $_VERSION" "$_MANUAL"
EOF
        found_name=0
        while IFS="" read -r line; do
            case "$line" in
            '## NAME')
                found_name=1
                ;;
                # Work around https://github.com/cpuguy83/go-md2man/issues/80
            *'_  ')
                printf "%s\n: \n\n" "${line%  }"
                continue
                ;;
            esac
            test "$found_name" = 0 && continue
            printf "%s\n" "$line"
        done
        footer
        # Work around https://github.com/cpuguy83/go-md2man/issues/79
    } | sed 's/<\(http[^>]*\)>/\1/g' | go-md2man -in /dev/stdin -out /dev/stdout | {
        # Work around https://github.com/cpuguy83/go-md2man/issues/26
        # and https://github.com/cpuguy83/go-md2man/issues/47
        # They're still an issue with go-md2man 2.0.0+ds-5
        sed -e 's/\\~/~/g;s/\\_/_/g' | tr '\n' "$_EOT" |
            sed "s/$_EOT$_EOT.fi$_EOT/$_EOT.fi$_EOT/g" | tr "$_EOT" '\n'
    }
}

# Unresolved issues:
# - Bullets are <dl> with • being a <dt>, shown in a separate line in mandoc
# - ADD_IMAGE_EXCLUDES is not a <dt>
# - Which makes mandoc produce multiple <dl> lists instead of one
# - Bullets in yelp
wrap_pandoc() {
    local found_name line

    # preprocess | pandoc | postprocess
    {
        # Generate metadata
        cat <<EOF
---
title: $_TITLE
section: $_SECTION
header: $_MANUAL
footer: $_ORGANIZATION
date: $_DATE
---
EOF
        found_name=0
        while IFS="" read -r line; do
            case "$line" in
            '## NAME')
                found_name=1
                ;;
                # Replace soft line breaks after list definitions with paragraphs
            *'_  ')
                printf "%s\n\n" "${line%  }"
                continue
                ;;
            esac
            test "$found_name" = 0 && continue
            printf "%s\n" "$line"
        done
        footer
    } | pandoc -s -f markdown -t man |
        {
            # Change <h2> to <h1>, and simpifly some macros for yelp
            # https://man7.org/linux/man-pages/man7/groff_char.7.html
            sed -e 's/^.SS/.SH/' -e 's/\\\[dq]/"/g;s/\\\[lq]/"/g;s/\\\[rq]/"/g;s/\\\[ti]/~/g;s/\\\[at]/@/g;s/\\\[ha]/^/g;s/\\\[en]/--/g' # -e 's/\\\[bu]/*/g'
        }

}

# Unresolved issues:
# - Bullets are <dl> with a big ○ as a <dt>, shown in a separate line in mandoc
# - Bullets in yelp
# - Big space around code in yelp
wrap_ronn() {
    local indent found_synopsis line

    # preprocess | ronn | postprocess
    {
        # Ronn needs a special `# title` with no `## NAME` section, see
        #  https://manpages.debian.org/ronn-format
        cat <<EOF
# $_APPLET($_SECTION) -- $_DESCRIPTION

EOF
        indent=0
        found_synopsis=0
        while IFS="" read -r line; do
            case "$line" in
            '## SYNOPSIS')
                found_synopsis=1
                ;;
                # Replace fenched blocks with indented blocks
            '```')
                indent=0
                continue
                ;;
            '```'*)
                indent=1
                continue
                ;;
            esac
            # Skip `# title` and `## NAME` sections
            test "$found_synopsis" = 0 && continue
            if [ "$indent" -gt 0 ]; then
                printf "    %s\n" "$line"
            else
                printf "%s\n" "$line"
            fi
        done
        footer
    } | ronn --manual "$_MANUAL" --organization "$_ORGANIZATION" --date "$_DATE" |
        {
            # work around #72
            sed -e "s/\\\'/'/g"
        }

}

main() {
    local cmd mp var

    set -e
    if [ -n "$MAN_GENERATOR" ]; then
        cmd="$MAN_GENERATOR"
    elif is_command go-md2man; then
        cmd=md2man
    elif is_command pandoc; then
        cmd=pandoc
    elif is_command ronn; then
        cmd=ronn
    else
        echo "Install go-md2man, pandoc or ronn to generate the man pages" >&2
        exit 1
    fi
    echo "Using $cmd to generate the man pages"

    cd "${1%/*}"
    if is_command dpkg-parsechangelog; then
        _VERSION=$(dpkg-parsechangelog -l ../debian/changelog -S VERSION)
    else
        _VERSION=$(. ../ltsp/common/ltsp/55-ltsp.sh && echo "$_VERSION")
    fi
    if [ -n "$SOURCE_DATE_EPOCH" ]; then
        _DATE=$(date -u -d"@$SOURCE_DATE_EPOCH" "+%Y-%m-%d")
    else
        _DATE=$(date "+%Y-%m-%d")
    fi
    _ORGANIZATION="LTSP $_VERSION"
    rm -rf man
    for mp in *.[0-9].md; do
        var=${mp%.md}
        _APPLET=${var%.[0-9]}
        _SECTION=${var#"$_APPLET".}
        _TITLE=$(echo "$_APPLET($_SECTION)" | awk '{ print toupper($0) }')
        _DESCRIPTION=$(sed -n '/## NAME/,+2s/.* - \(.*\)/\1/p' "$mp")
        mkdir -p "man/man$_SECTION"
        "wrap_$cmd" <"$mp" >"man/man$_SECTION/$_APPLET.$_SECTION"
    done
}

main "$@"
