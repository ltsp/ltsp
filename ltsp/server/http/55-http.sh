# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Configure HTTP exports for LTSP

HTTP_IMAGES=${HTTP_IMAGES:-1}
HTTP_TFTP=${HTTP_TFTP:-1}
HTTP_INDEX=${HTTP_INDEX:-0}

http_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "I::i::t::" -l \
        "http-index::,http-images::,http-tftp::" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -I|--http-index) shift; HTTP_INDEX=${1:-1} ;;
            -i|--http-images) shift; HTTP_IMAGES=${1:-1} ;;
            -t|--http-tftp) shift; HTTP_TFTP=${1:-1} ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    test "$#" = "0" || usage 1
    run_main_functions "$_SCRIPTS" "$@"
}

http_main() {
    re mkdir -p "$BASE_DIR" "$TFTP_DIR/ltsp"

    if [ -d "/etc/nginx/conf.d" ]; then
        re install_template "ltsp-nginx.conf" "/etc/nginx/conf.d/ltsp.conf" "\
s|location /ltsp/images/ { root /srv/ltsp/..;|$(textifb "$HTTP_IMAGES" "location /ltsp/images/ { root $BASE_DIR/..;" "#&")|
s|location /ltsp/ { root /srv/tftp;|$(textifb "$HTTP_TFTP" "location /ltsp/ { root $TFTP_DIR;" "#&")|
s|autoindex [^;]*|$(textifb "$HTTP_INDEX" "autoindex on" "autoindex off")|
"
    fi
    if [ -d /etc/apache2/conf-available ]; then

        if [ "${HTTP_IMAGES:-0}" = "1" ]; then
            re install_template "ltsp-images.conf" "/etc/apache2/conf-enabled/ltsp-images.conf" "\
s|^/srv/ltsp|$BASE_DIR|
s|+Indexes|$(textifb "$HTTP_INDEX" "+Indexes" "-Indexes")|
"
	else
            rm -f "/etc/apache2/conf-enabled/ltsp-images.conf"
        fi

        if [ "${HTTP_TFTP:-0}" = "1" ]; then
            re install_template "ltsp-tftp.conf" "/etc/apache2/conf-enabled/ltsp-tftp.conf" "\
s|^/srv/tftp/ltsp|$TFTP_DIR|
s|+Indexes|$(textifb "$HTTP_INDEX" "+Indexes" "-Indexes")|
"
	else
            rm -f "/etc/apache2/conf-enabled/ltsp-tftp.conf"
        fi
    fi

    if systemctl is-active -q nginx; then
        re systemctl restart nginx
        echo "Restarted nginx"
    fi
    if systemctl is-active -q apache2; then
        re systemctl restart apache2
        echo "Restarted apache2"
    fi

}
