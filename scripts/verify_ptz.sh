#!/bin/sh
# Verify the optional ONVIF/PTZ endpoints from a computer.
#
# Usage:
#   ./scripts/verify_ptz.sh <CAMERA_IP>
#
# This script is read-only. It does not move the camera.
# It prints the commands you can run to test a movement.

set -u

IP=${1:-}
if [ -z "$IP" ]; then
    echo "Usage: $0 <CAMERA_IP>" >&2
    exit 1
fi

echo "== HTTP endpoints =="
if command -v curl >/dev/null 2>&1; then
    for port in 8081 5000; do
        code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' \
               "http://$IP:$port/" 2>/dev/null || true)
        if [ "$code" = "000" ] || [ -z "$code" ]; then
            echo "port $port: closed or unreachable"
        else
            echo "port $port: open (HTTP $code)"
        fi
    done
else
    echo "curl not found; test ports 8081 and 5000 manually."
fi

echo
echo "== RTSP =="
if command -v ffprobe >/dev/null 2>&1; then
    ffprobe -v error -rtsp_transport tcp \
        -show_entries stream=codec_name,width,height \
        -of default=noprint_wrappers=1 \
        "rtsp://$IP:8554/mainstream" 2>&1 || true
else
    echo "ffprobe not found; test rtsp://$IP:8554/mainstream manually."
fi

echo
echo "== Web PTZ =="
echo "Open: http://$IP:8081/"
echo "Test a direction with:"
echo "  curl 'http://$IP:8081/cgi-bin/ptz.cgi?dir=left&steps=1'"
echo "  curl 'http://$IP:8081/cgi-bin/ptz.cgi?dir=right&steps=1'"
echo "  curl 'http://$IP:8081/cgi-bin/ptz.cgi?dir=up&steps=1'"
echo "  curl 'http://$IP:8081/cgi-bin/ptz.cgi?dir=down&steps=1'"
echo "The exact command depends on INVERT_PAN/INVERT_TILT in ptz.conf."

echo
echo "== Frigate ONVIF block =="
cat <<EOF
    onvif:
      host: $IP
      port: 5000
      user: admin
      password: admin
EOF
