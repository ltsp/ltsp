# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Call mksquashfs to generate the image

mksquashfs_main() {
    local ef_upstream ef_local kernel_src

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
    if [ "$IN_PLACE" = "1" ]; then
        kernel_src="$_COW_DIR"
    else
        kernel_src="$BASE_DIR/images/$_IMG_NAME.img"
    fi
    echo "Running: ltsp kernel $kernel_src"
    re "$0" kernel ${KERNEL_INITRD:+-k "$KERNEL_INITRD"} "$kernel_src"
}
