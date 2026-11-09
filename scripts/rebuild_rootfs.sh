#!/bin/sh
# Rebuild the hacked rootfs with the IPC009 autostart patch.
#
# Requirements:
#   - unsquashfs and mksquashfs (squashfs-tools)
#   - the original rootfs_new.bin from this repository
#
# Usage:
#   ./rebuild_rootfs.sh /path/to/rootfs_new.bin
#
# The output is written to ./rootfs_new_patched.bin.
#
# After flashing, the script prints the exact U-Boot command with the real
# file size in hexadecimal. Never guess this size: a short write truncates
# the squashfs and the camera panics with:
#   squashfs: unable to read id index table

set -eu

ROOTFS_IN="${1:-}"
if [ -z "$ROOTFS_IN" ] || [ ! -f "$ROOTFS_IN" ]; then
    echo "Usage: $0 /path/to/rootfs_new.bin" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PATCH="$SCRIPT_DIR/../patches/S60service.ipc009-4.3.7"
WORKDIR="${TMPDIR:-/tmp}/ipc009-rootfs-build"
OUT="$SCRIPT_DIR/../rootfs_new_patched.bin"

if [ ! -f "$PATCH" ]; then
    echo "Patch not found: $PATCH" >&2
    exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "[1/4] Extracting $ROOTFS_IN"
unsquashfs -f -d "$WORKDIR/rootfs" "$ROOTFS_IN" >/dev/null

echo "[2/4] Applying S60service patch"
cp "$PATCH" "$WORKDIR/rootfs/etc/init.d/S60service"
chmod +x "$WORKDIR/rootfs/etc/init.d/S60service"

echo "[3/4] Repacking squashfs"
rm -f "$OUT"
mksquashfs "$WORKDIR/rootfs" "$OUT" -comp xz -noappend >/dev/null

echo "[4/4] Result"
SIZE=$(wc -c < "$OUT" | tr -d ' ')
HEX=$(printf '0x%X' "$SIZE")
echo "  File: $OUT"
echo "  Size: $SIZE bytes ($HEX)"
echo
echo "Use these U-Boot commands (replace rootfs_new.bin with this file on the SD card):"
echo
echo "  fatload mmc 0:1 0x21000000 rootfs_new.bin"
echo "  sf probe 0"
echo "  sf erase 0x260000 0x750000"
echo "  sf write 0x21000000 0x260000 $HEX"
echo "  reset"
echo
echo "The erase length 0x750000 is the whole ROOTFS partition (0x260000-0x9B0000)."
