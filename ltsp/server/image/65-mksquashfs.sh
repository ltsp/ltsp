# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Call mksquashfs to generate the image
# @LTSP.CONF: ADD_IMAGE_EXCLUDES OMIT_IMAGE_EXCLUDES

mksquashfs_main() {
    local ie

    # Unset IONICE means use the default; IONICE="" means don't use anything
    if [ -z "${IONICE+nonempty}" ]; then
        is_command nice && IONICE=nice
        if is_command ionice && ionice -c3 true 2>/dev/null; then
            IONICE="$IONICE ionice -c3"
        fi
    fi
    re mkdir -p "$BASE_DIR/images"
    ie=$(image_excludes)
    # image_excludes can't call exit_command because of the subshell
    test "${ie%.tmp}" != "$ie" && exit_command "rw rm '$ie'"
    # -regex might be nicer: https://stackoverflow.com/questions/57304278
    re $IONICE mksquashfs  "$_COW_DIR" "$BASE_DIR/images/$_IMG_NAME.img.tmp" \
        -noappend -wildcards -ef "$ie" $MKSQUASHFS_PARAMS
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
    echo "Running: ltsp kernel ${IN_PLACE:+-I"$IN_PLACE"} $kernel_src"
    re "$0" kernel ${KERNEL_INITRD:+-k "$KERNEL_INITRD"} "${IN_PLACE:+-I"$IN_PLACE"}" \
        "$kernel_src"
}

# Handle ADD_IMAGE_EXCLUDES and OMIT_IMAGE_EXCLUDES
image_excludes() {
    local src dst inp out

    if [ -f /etc/ltsp/image.excludes ]; then
        src=/etc/ltsp/image.excludes
    else
        src="$_APPLET_DIR/image.excludes"
    fi
    if [ -z "$ADD_IMAGE_EXCLUDES$OMIT_IMAGE_EXCLUDES" ]; then
        echo "$src"
        return 0
    fi
    dst=$(re readlink -f "$_COW_DIR/../image.excludes.tmp")
    # comm requires all input to be sorted in the current locale
    re sort "$src" > "$dst"
    if [ -f "$OMIT_IMAGE_EXCLUDES" ]; then
        inp=$(re sort "$OMIT_IMAGE_EXCLUDES")
    else
        inp=$(echo "$OMIT_IMAGE_EXCLUDES" | re sort)
    fi
    out=$(echo "$inp" | re comm - "$dst" -13)
    {
        if [ -f "$ADD_IMAGE_EXCLUDES" ]; then
            cat "$ADD_IMAGE_EXCLUDES"
        else
            echo "$ADD_IMAGE_EXCLUDES"
        fi
        echo "$out"
    } | grep -v '^#' | re sort -u > "$dst"
    echo "$dst"
}
