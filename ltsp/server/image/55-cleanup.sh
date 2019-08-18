# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Remove sensitive data from image sources before calling mksquashfs

cleanup_main() {
    test "$CLEANUP" != "0" ||
        return 0
    re test "cleanup_main:$_COW_DIR" != "cleanup_main:"
    grep -qs "overlay.*lowerdir=$_COW_DIR" /proc/self/mountinfo ||
        die "Can't clean up without overlay: $_COW_DIR"
    echo "Cleaning up $_IMG_NAME before mksquashfs..."
    # You can override any of the functions with a higher numbered script
    re remove_printers
    re remove_users
    re resolv_conf
    re ssh_host_keys
    re ssl_cert
    re truncate_files
}

remove_printers() {
    test -f "$_COW_DIR/etc/cups/printers.conf" || return 0
    sed "/^#/!d" -i "$_COW_DIR/etc/cups/printers.conf"
}

remove_users() {
    mkdir -p "$_COW_DIR/tmp/pwempty" "$_COW_DIR/tmp/pwmerged"
    touch "$_COW_DIR/tmp/pwempty/passwd"
    touch "$_COW_DIR/tmp/pwempty/group"
    re "$_LTSP_DIR/client/login/pwmerge" --ltsp --quiet \
        "$_COW_DIR/tmp/pwempty" "$_COW_DIR/etc" "$_COW_DIR/tmp/pwmerged"
    chown --reference="$_COW_DIR/etc/shadow" \
        "$_COW_DIR/tmp/pwmerged/shadow" "$_COW_DIR/tmp/pwmerged/gshadow"
    re mv "$_COW_DIR/tmp/pwmerged/"* "$_COW_DIR/etc"
}

# Restore possible changes of `ltsp dnsmasq --dns=1`
resolv_conf() {
    test -f "$_COW_DIR/etc/systemd/resolved.conf.d/ltsp.conf" || return 0
    re rm -f "$_COW_DIR/etc/systemd/resolved.conf.d/ltsp.conf"
    re ln -sf "../run/systemd/resolve/stub-resolv.conf" \
        "$_COW_DIR/etc/resolv.conf"
}

# Replace the ssh server keys; sshd is masked by MASK_SYSTEM_SERVICES, and
# the sysadmin may override them with custom keys in /etc/ltsp/initrd/etc/ssh
ssh_host_keys() {
    local t

    for t in dsa ecdsa ed25519 rsa; do
        test -f "$_COW_DIR/etc/ssh/ssh_host_${t}_key" || continue
        if is_command ssh-keygen; then
            echo "Replacing $_COW_DIR/etc/ssh/ssh_host_${t}_key"
            re rm "$_COW_DIR/etc/ssh/ssh_host_${t}_key"
            ssh-keygen -qf "$_COW_DIR/etc/ssh/ssh_host_${t}_key" -N '' -t "$t"
        fi
    done
}

# Replace the snakeoil certificate
ssl_cert() {
    test -f "$_COW_DIR/etc/ssl/private/ssl-cert-snakeoil.key" || return 0
    is_command openssl || return 0
    re openssl req -batch -new -x509 -days 3650 -nodes -sha256 \
        -out "$_COW_DIR/etc/ssl/certs/ssl-cert-snakeoil.pem" \
        -keyout "$_COW_DIR/etc/ssl/private/ssl-cert-snakeoil.key"
}

truncate_files() {
    local f

    # Truncate log files except those in subdirectories as they're excluded.
    # But avoid using `truncate` on overlayfs (LP: #1494660).
    find "$_COW_DIR/var/log/" -maxdepth 1 -type f -exec tee {} + </dev/null

    for f in etc/fstab var/cache/debconf/passwords.dat; do
        if [ -s "$_COW_DIR/$f" ]; then
            tee "$_COW_DIR/$f" </dev/null
        fi
    done
}
