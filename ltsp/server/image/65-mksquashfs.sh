# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Call mksquashfs to generate the image

mksquashfs_main() {
    local ef_merged

    # Unset IONICE means use the default; IONICE="" means don't use anything
    if [ -z "${IONICE+nonempty}" ]; then
        is_command nice && IONICE=nice
        if is_command ionice && ionice -c3 true 2>/dev/null; then
            IONICE="$IONICE ionice -c3"
        fi
    fi

    re mkdir -p "$BASE_DIR/images"

    ef_merged="$BASE_DIR/images/$_IMG_NAME.excludes"
    if [ -f /etc/ltsp/image.excludes ]; then
        cat /etc/ltsp/image.excludes > "$ef_merged"
    else
        cat "$_APPLET_DIR/image.excludes" > "$ef_merged"
    fi

    # Append local image excludes
    if [ -f /etc/ltsp/image-local.excludes ]; then
        cat /etc/ltsp/image-local.excludes >> "$ef_merged"
    fi
    echo "$ADD_IMAGE_EXCLUDES" | tr ' ' '\n' >> "$ef_merged"

    # Remove OMIT_IMAGE_EXCLUDES
    while read line; do
        for pattern in $OMIT_IMAGE_EXCLUDES; do
            test "$line" = "$pattern" ||
            echo "$line"
        done
    done <"$ef_merged" >"$ef_merged.tmp"
    mv "$ef_merged.tmp" "$ef_merged"

    # -regex might be nicer: https://stackoverflow.com/questions/57304278
    re $IONICE mksquashfs  "$_COW_DIR" "$BASE_DIR/images/$_IMG_NAME.img.tmp" \
        -noappend -wildcards -ef "$ef_merged" $MKSQUASHFS_PARAMS

    rm -f "$ef_merged"

    if [ "$BACKUP" != 0 ] && [ -f "$BASE_DIR/images/$_IMG_NAME.img" ]; then
        re mv "$BASE_DIR/images/$_IMG_NAME.img" "$BASE_DIR/images/$_IMG_NAME.img.old"
    fi
    re mv "$BASE_DIR/images/$_IMG_NAME.img.tmp" "$BASE_DIR/images/$_IMG_NAME.img"
    # Unmount everything and continue with the next image
    rw at_exit -EXIT
    echo "Running: ltsp kernel $BASE_DIR/images/$_IMG_NAME.img"
    re "$0" kernel ${KERNEL_INITRD:+-k "$KERNEL_INITRD"} "$BASE_DIR/images/$_IMG_NAME.img"
}
