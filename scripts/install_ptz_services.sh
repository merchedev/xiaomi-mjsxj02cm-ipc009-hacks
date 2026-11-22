#!/bin/sh
# Install the optional ONVIF/PTZ services on the camera.
#
# Run this ON THE CAMERA as root, after unzipping ipc009_ptz_hack.zip to
# /mnt/sdcard and after the base ipc009_hack.zip is already installed.
#
# Usage:
#   sh /mnt/sdcard/scripts/install_ptz_services.sh
#   sh /mnt/sdcard/scripts/install_ptz_services.sh --optimize-ram
#
# The script does not touch the rootfs. It only adds runit services from the
# SD card and prints diagnostics.

set -u

HACKS=/mnt/sdcard/hacks
CONFIG=/mnt/sdcard/manu_test/configure_services.sh
BACKUP=/mnt/sdcard/backups
SV=/mnt/sdcard/hacks/runit/bin/sv
OPTIMIZE=0

[ "${1:-}" = "--optimize-ram" ] && OPTIMIZE=1

if [ ! -x "$CONFIG" ]; then
    echo "ERROR: $CONFIG not found." >&2
    echo "Install the base ipc009_hack.zip first." >&2
    exit 1
fi

for f in \
    "$HACKS/motor_control/motord" \
    "$HACKS/onvif_srvd/onvif_srvd" \
    "$HACKS/onvif_srvd/start_onvif.sh" \
    "$HACKS/webctl/meta/service/run" \
    "$HACKS/webctl/www/cgi-bin/ptz.cgi"
do
    if [ ! -e "$f" ]; then
        echo "ERROR: missing $f" >&2
        echo "Unzip ipc009_ptz_hack.zip to /mnt/sdcard first." >&2
        exit 1
    fi
done

# FAT32 does not store Unix permissions. The SD card mount on this camera
# presents files as executable, but chmod is harmless and helps after a copy.
chmod +x \
    "$HACKS/motor_control/motord" \
    "$HACKS/onvif_srvd/onvif_srvd" \
    "$HACKS/onvif_srvd/start_onvif.sh" \
    "$HACKS/onvif_srvd/meta/service/run" \
    "$HACKS/webctl/meta/service/run" \
    "$HACKS/webctl/www/cgi-bin/"*.cgi 2>/dev/null || true

mkdir -p "$BACKUP"
STAMP=$(date +%Y%m%d_%H%M%S)

echo "[1/4] Backing up the current service definitions"
tar cf "$BACKUP/runit_before_ptz_$STAMP.tar" -C /mnt/data/etc runit 2>/dev/null || true
cp -f "$CONFIG" "$BACKUP/configure_services.sh.$STAMP.bak" 2>/dev/null || true
cp -f "$HACKS/onvif_srvd/start_onvif.sh" \
      "$BACKUP/start_onvif.sh.$STAMP.bak" 2>/dev/null || true
cp -f "$HACKS/webctl/www/cgi-bin/ptz.cgi" \
      "$BACKUP/ptz.cgi.$STAMP.bak" 2>/dev/null || true

echo "[2/4] Installing onvif_srvd"
"$CONFIG" onvif_srvd || exit 1

echo "[3/4] Installing webctl"
"$CONFIG" webctl || exit 1

if [ "$OPTIMIZE" = "1" ]; then
    echo "[4/4] Applying RAM optimization"
    if [ -x /mnt/sdcard/scripts/optimize_ram.sh ]; then
        sh /mnt/sdcard/scripts/optimize_ram.sh || true
    else
        echo "WARNING: /mnt/sdcard/scripts/optimize_ram.sh not found"
    fi
else
    echo "[4/4] Skipping RAM optimization"
    echo "      Use --optimize-ram on 64 MB cameras if ONVIF is unstable."
fi

echo
echo "Waiting for the services..."
sleep 10

echo
echo "--- processes ---"
ps | grep -E 'motord|onvif_srvd|httpd' | grep -v grep || true

echo
echo "--- ports ---"
netstat -tln | grep -E ':(5000|8081|8554) ' || true

echo
echo "--- PTZ directions ---"
cat "$HACKS/ptz.conf" 2>/dev/null || true

echo
echo "Next steps:"
echo "  1. Set INVERT_PAN / INVERT_TILT in $HACKS/ptz.conf for your mount."
echo "  2. If port 5000 is not listening, reboot the camera and check:"
echo "     $SV status /mnt/data/etc/runit/onvif_srvd-run"
echo "  3. Add the ONVIF block to Frigate or Home Assistant."
echo "  4. See docs/09-onvif-ptz.md and docs/10-flip.md."
