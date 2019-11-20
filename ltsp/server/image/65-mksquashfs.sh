# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Call mksquashfs to generate the image

mksquashfs_main() {
    local ef_upstream ef_local ef_merged

    # Unset IONICE means use the default; IONICE="" means don't use anything
    if [ -z "${IONICE+nonempty}" ]; then
        is_command nice && IONICE=nice
        if is_command ionice && ionice -c3 true 2>/dev/null; then
            IONICE="$IONICE ionice -c3"
        fi
    fi
    if [ -f /etc/ltsp/image-local.excludes ]; then
        ef_local=/etc/ltsp/image-local.excludes
    else
        unset ef_local
    fi
    if [ -f /etc/ltsp/image.excludes ]; then
        ef_upstream=/etc/ltsp/image.excludes
    else
        ef_upstream="$_APPLET_DIR/image.excludes"
    fi
    re mkdir -p "$BASE_DIR/images"

    # If variables set, we need to generate new image.excludes
    if [ -n "$ADD_IMAGE_EXCLUDES" ] || [ -n "$OMIT_IMAGE_EXCLUDES" ]; then
        ef_merged="$(re mktemp)"
        exit_command "rm -f $ef_merged"
        re cat "$ef_upstream" > "$ef_merged"
        ef_upstream="$ef_merged"
        if [ -n "$ef_local" ]; then
            re cat "$ef_local" >> "$ef_merged"
            unset ef_local
        fi
        add_image_excludes "$ef_merged"
        omit_image_excludes "$ef_merged"
    fi

    # -regex might be nicer: https://stackoverflow.com/questions/57304278
    re $IONICE mksquashfs  "$_COW_DIR" "$BASE_DIR/images/$_IMG_NAME.img.tmp" \
        -noappend -wildcards ${ef_upstream:+-ef "$ef_upstream"} \
        ${ef_local:+-ef "$ef_local"} $MKSQUASHFS_PARAMS
    if [ "$BACKUP" != 0 ] && [ -f "$BASE_DIR/images/$_IMG_NAME.img" ]; then
        re mv "$BASE_DIR/images/$_IMG_NAME.img" "$BASE_DIR/images/$_IMG_NAME.img.old"
    fi
    re mv "$BASE_DIR/images/$_IMG_NAME.img.tmp" "$BASE_DIR/images/$_IMG_NAME.img"
    # Unmount everything and continue with the next image
    rw at_exit -EXIT
    echo "Running: ltsp kernel $BASE_DIR/images/$_IMG_NAME.img"
    re "$0" kernel ${KERNEL_INITRD:+-k "$KERNEL_INITRD"} "$BASE_DIR/images/$_IMG_NAME.img"
}

# Append local image excludes with ADD_IMAGE_EXCLUDES
add_image_excludes() {
    test -n "$ADD_IMAGE_EXCLUDES" ||
        return 0
    echo "$ADD_IMAGE_EXCLUDES" | tr ' ' '\n' >> "$1"
}

# Remove image excludes specified in OMIT_IMAGE_EXCLUDES
omit_image_excludes() {
    test -n "$OMIT_IMAGE_EXCLUDES" ||
        return 0
    (
        set -f
        while read line; do
            for pattern in $OMIT_IMAGE_EXCLUDES; do
                test "$line" = "$pattern" ||
                echo "$line"
            done
        done <"$1" >"$1.tmp"
        mv "$1.tmp" "$1"
    )
}
