#!/bin/sh
# Free RAM on 64 MB IPC009 cameras by disabling optional services.
#
# Run this ON THE CAMERA as root. It is reversible.
# See docs/11-ram-optimization.md for the full explanation.
#
# Usage:
#   sh /mnt/sdcard/scripts/optimize_ram.sh

set -u

HACKS=/mnt/sdcard/hacks
RUNIT=/mnt/data/etc/runit
SV=/mnt/sdcard/hacks/runit/bin/sv
PERP=/mnt/data/etc/perp
PERP_OFF=/mnt/data/etc/perp.disabled
BACKUP=/mnt/sdcard/backups

mkdir -p "$BACKUP" "$PERP_OFF"

echo "[1/3] Backing up service definitions"
tar cf "$BACKUP/runit_before_ram_$(date +%Y%m%d_%H%M%S).tar" \
       -C /mnt/data/etc runit 2>/dev/null || true
if [ -f "$HACKS/web-config/meta/service/.enable" ]; then
    cp -f "$HACKS/web-config/meta/service/.enable" \
          "$BACKUP/web-config.enable.bak"
fi
if [ -f "$HACKS/websocket-stream-server/meta/service/.enable" ]; then
    cp -f "$HACKS/websocket-stream-server/meta/service/.enable" \
          "$BACKUP/websocket-stream-server.enable.bak"
fi

echo "[2/3] Disabling optional hack services"
if [ -f "$HACKS/web-config/meta/service/.enable" ]; then
    mv -f "$HACKS/web-config/meta/service/.enable" \
          "$HACKS/web-config/meta/service/.enable.disabled"
fi
if [ -f "$HACKS/websocket-stream-server/meta/service/.enable" ]; then
    mv -f "$HACKS/websocket-stream-server/meta/service/.enable" \
          "$HACKS/websocket-stream-server/meta/service/.enable.disabled"
fi

for d in \
    web-config-run \
    websocket-stream-server-websocket-stream-server \
    websocket-stream-server-framegrabber-mainstream \
    websocket-stream-server-framegrabber-substream
do
    "$SV" down "$RUNIT/$d" 2>/dev/null || true
done

rm -rf "$RUNIT"/web-config-run \
       "$RUNIT"/websocket-stream-server-* 2>/dev/null || true

echo "[3/3] Disabling stock cloud services"
for s in \
    miio_agent \
    miio_algo \
    miio_cloud \
    miio_devicekit \
    miio_miss \
    miio_nas \
    miio_ota \
    miio_qrcode \
    miio_record \
    miio_sdcard
do
    /usr/sbin/perpctl -b /etc/perp down "$s" 2>/dev/null || true
    if [ -d "$PERP/$s" ]; then
        mv "$PERP/$s" "$PERP_OFF/$s" 2>/dev/null || true
    fi
done

sync

echo
echo "RAM optimization applied."
echo "Kept: fetch_av, miio_client, miio_client_helper, mortox, RTSP, ONVIF, motord, webctl."
echo
echo "Check:"
echo "  free"
echo "  ps"
echo "  netstat -tln | grep -E ':(5000|8081|8554) '"
echo "  dmesg | grep -i -E 'oom|killed process'"
echo
echo "Re-enable instructions are in docs/11-ram-optimization.md."
