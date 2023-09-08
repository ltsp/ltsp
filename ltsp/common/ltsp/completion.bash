# /bin/bash -n
# This file is part of LTSP, https://ltsp.org
# Copyright 2023 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Bash completion for LTSP.
# Symlink to /usr/share/bash-completion/completions/ltsp

# For example, if we tab with these parameters and cursor: ltsp 1 -2 thre|  4
# then: $0 = bash, $1 = ltsp, $2 = thre, $3 = -2
# COMP_WORDS: an array of all the words typed after the name of the program,
# e.g.. COMP_WORDS=([0]="ltsp" [1]="1" [2]="-2" [3]="thre" [4]="4")
# COMP_CWORD: an index of the COMP_WORDS array pointing to the word the current
# cursor is at, e.g. COMP_CWORD=3
# COMP_LINE: the current command line, e.g. COMP_LINE='ltsp 1 -2 thre  4'
# The expected output goes in $COMPREPLY.
# COMPREPLY: An array variable from which bash reads the possible completions
# compgen -W: autocompletes a word from the list, e.g. when half-typed
_ltsp_complete() {
    local _prog curr _prev applet compparam words

    _prog=$1
    curr=$2
    _prev=$3
    for applet in "${COMP_WORDS[@]}" ""; do
        case "$applet" in
        dnsmasq | image | info | initrd | ipxe | kernel | nfs) break ;;
        esac
    done
    compparam="-W"
    case "$applet" in
    dnsmasq) words="--dns= --proxy-dhcp= --real-dhcp= --dns-server= --tftp=" ;;
    image)
        words="--backup= --cleanup= --ionice= --kernel-initrd= --mksquashfs-params= --revert="
        compparam="-fW"
        ;;
    info) words= ;;
    initrd) words= ;;
    ipxe) words="--binaries=" ;;
    kernel)
        words="--kernel-initrd="
        compparam="-fW"
        ;;
    nfs) words="--nfs-home= --nfs-tftp=" ;;
    *) words="--base-dir= --help --home-dir= --overwrite= --tftp-dir= --version dnsmasq image info initrd ipxe kernel nfs" ;;
    esac
    COMPREPLY=()
    if [ -n "$words" ]; then
        # https://www.shellcheck.net/wiki/SC2207
        while IFS='' read -r line; do COMPREPLY+=("$line"); done < <(compgen "$compparam" "$words" -- "$curr")
    fi
}

complete -F _ltsp_complete ltsp
