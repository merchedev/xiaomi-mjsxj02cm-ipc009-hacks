# 11 — RAM optimization for 64 MB cameras

The MJSXJ02CM / IPC009 has **64 MB of RAM**. The stock Xiaomi cloud stack, the
RTSP stack, the optional web configuration server and ONVIF can fit together
only with very little free memory. When memory runs out, the Linux OOM killer
kills processes and the camera becomes unstable.

Typical symptoms:

```text
dmesg | grep -i oom
```

```text
Killed process ... (web-config-serv)
Killed process ... (configure_servi)
```

You may also see:

- ONVIF port 5000 disappears after a few seconds.
- The `onvif_srvd` runit service restarts in a loop.
- `web-config` or `configure_services.sh` is killed during boot.
- The camera responds slowly or the RTSP stream drops.

This guide disables services that are **not needed for local RTSP + ONVIF +
PTZ**. It is optional, but recommended on 64 MB cameras when you install the
PTZ add-on. It is fully reversible.

> This guide does not touch the rootfs. It only changes service enable files
> and moves service definitions inside `/mnt/data`.

---

## What stays running

Keep these; the video stream needs them:

| Service | Why |
|---------|-----|
| `fetch_av` | Vendor video pipeline |
| `miio_client` | Local camera client |
| `miio_client_helper` | Helper for `miio_client` |
| `mortox` / `mortoxd` | Local key/value and notification bus |
| `rtspserver` + framegrabbers | RTSP stream on 8554 |
| `motord` | PTZ motors |
| `onvif_srvd` | ONVIF PTZ on 5000 |
| `busybox httpd` (webctl) | Optional web PTZ on 8081 |

The RTSP stream and the ONVIF PTZ continue to work after the optimization.

---

## What to disable

### 1. The heavy hack services

These are useful for initial setup but not needed for Frigate/ONVIF:

- `web-config` — the browser configuration UI on port 80 (Go server).
- `websocket-stream-server` — the auxiliary WebSocket stream on port 4558.

The web PTZ page on port 8081 comes from `webctl`, not from `web-config`.

### 2. The stock Xiaomi cloud services

These are not needed for local RTSP/ONVIF/PTZ:

```text
miio_agent
miio_algo
miio_cloud
miio_devicekit
miio_miss
miio_nas
miio_ota
miio_qrcode
miio_record
miio_sdcard
```

Keep `fetch_av`, `miio_client`, `miio_client_helper` and `mortox`.

> `miio_ota` is the firmware updater. Keeping it disabled is also a good way
> to avoid an accidental OTA that could replace the patched rootfs.

---

## Backup

Run on the camera:

```sh
mkdir -p /mnt/sdcard/backups
tar cf /mnt/sdcard/backups/runit_before_ram.tar -C /mnt/data/etc runit
cp /mnt/sdcard/hacks/web-config/meta/service/.enable \
   /mnt/sdcard/backups/web-config.enable.bak 2>/dev/null || true
cp /mnt/sdcard/hacks/websocket-stream-server/meta/service/.enable \
   /mnt/sdcard/backups/websocket-stream-server.enable.bak 2>/dev/null || true
```

The camera's BusyBox `tar` does not support `-z`; use an uncompressed tar.

---

## Apply the optimization

You can run the included script:

```sh
sh /mnt/sdcard/scripts/optimize_ram.sh
```

Or do it manually.

### 1. Disable `web-config` and `websocket`

```sh
HACKS=/mnt/sdcard/hacks
SV=/mnt/sdcard/hacks/runit/bin/sv

mv -f "$HACKS/web-config/meta/service/.enable" \
      "$HACKS/web-config/meta/service/.enable.disabled" 2>/dev/null || true
mv -f "$HACKS/websocket-stream-server/meta/service/.enable" \
      "$HACKS/websocket-stream-server/meta/service/.enable.disabled" 2>/dev/null || true

for d in web-config-run \
         websocket-stream-server-websocket-stream-server \
         websocket-stream-server-framegrabber-mainstream \
         websocket-stream-server-framegrabber-substream; do
    "$SV" down "/mnt/data/etc/runit/$d" 2>/dev/null || true
done

rm -rf /mnt/data/etc/runit/web-config-run \
       /mnt/data/etc/runit/websocket-stream-server-*
```

The `.enable.disabled` files tell `configure_services.sh` to skip these
services on the next boot.

### 2. Disable the stock cloud services

```sh
mkdir -p /mnt/data/etc/perp.disabled

for s in miio_agent miio_algo miio_cloud miio_devicekit miio_miss \
         miio_nas miio_ota miio_qrcode miio_record miio_sdcard; do
    /usr/sbin/perpctl -b /etc/perp down "$s" 2>/dev/null || true
    mv "/mnt/data/etc/perp/$s" "/mnt/data/etc/perp.disabled/$s" 2>/dev/null || true
done

sync
```

On the next boot, `perpboot` reads only `/etc/perp` (a link to
`/mnt/data/etc/perp`), so the moved services do not start.

### 3. Check the result

```sh
free
ps
ls /mnt/data/etc/perp
```

Expected remaining `perp` services:

```text
fetch_av
miio_client
miio_client_helper
mortox
```

Expected memory:

```text
             total       used       free     shared    buffers     cached
Mem:         61156      ~40000     ~10000    ...
```

Exact numbers depend on the firmware and the running clients.

---

## Verify RTSP and ONVIF

The video stream must still work:

```sh
netstat -tln | grep -E ':(5000|8081|8554) '
```

Expected:

```text
0.0.0.0:5000
0.0.0.0:8081
0.0.0.0:8554
```

From a computer with `ffprobe`:

```sh
ffprobe -v error -rtsp_transport tcp \
  -show_entries stream=codec_name,width,height \
  -of default=noprint_wrappers=1 \
  rtsp://<CAMERA_IP>:8554/mainstream
```

Expected on this firmware:

```text
codec_name=hevc
width=1920
height=1088
```

Check that there are no new OOM messages and that ONVIF stays up:

```sh
dmesg | grep -i -E 'oom|killed process'
sv status /mnt/data/etc/runit/onvif_srvd-run
```

The `sv` binary is at `/mnt/sdcard/hacks/runit/bin/sv`.

---

## Re-enable a service

### `web-config` or `websocket`

```sh
HACKS=/mnt/sdcard/hacks
mv -f "$HACKS/web-config/meta/service/.enable.disabled" \
      "$HACKS/web-config/meta/service/.enable"
mv -f "$HACKS/websocket-stream-server/meta/service/.enable.disabled" \
      "$HACKS/websocket-stream-server/meta/service/.enable"
/mnt/sdcard/manu_test/configure_services.sh
reboot
```

`configure_services.sh` without arguments removes and reinstalls all runit
services from the SD card. Use it only when you want to reload the full set.

### Stock cloud services

```sh
mkdir -p /mnt/data/etc/perp
mv /mnt/data/etc/perp.disabled/miio_cloud /mnt/data/etc/perp/
# repeat for the services you need
reboot
```

> Re-enabling the full cloud stack together with ONVIF may trigger the OOM
> killer again on 64 MB cameras. Re-enable only what you actually need.

---

## Notes

- The RTSP stream does not depend on `web-config`, `websocket` or the cloud
  services. It depends on `fetch_av`, `miio_client` and the RTSP server.
- The web PTZ page on 8081 is served by `webctl` and remains available.
- The ONVIF PTZ on 5000 remains available.
- The camera's image flip (`mortoxc set nvram default flip on`) is independent
  of this optimization; see [`10-flip.md`](10-flip.md).
- `miio_ota` stays disabled. Do not re-enable it unless you intentionally want
  to allow a firmware update.
- If you restore the original firmware, the moved `perp` services are not used;
  the stock firmware has its own boot sequence.

---

## No personal data

This guide uses placeholders:

- `<CAMERA_IP>`
- `<SSID>`
- `<PASSWORD>`

Do not commit real IP addresses, MAC addresses, SSIDs, passwords, tokens or
serial numbers.
