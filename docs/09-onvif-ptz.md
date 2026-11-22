# 09 — ONVIF PTZ and web PTZ (optional)

This guide adds **pan/tilt control** to the camera without using the Xiaomi
cloud. It is optional: the base hack already provides telnet and RTSP.

After this guide the camera can expose:

| Service | Port | Purpose |
|---------|------|---------|
| ONVIF Profile S | 5000 | PTZ control for Frigate, Home Assistant and ONVIF clients |
| Web PTZ | 8081 | Small browser page to move the camera and check the network |
| RTSP | 8554 | Existing video stream, unchanged |

The PTZ add-on does not change the rootfs. All files live on the SD card and
survive a rootfs reflash.

> **Warning**
> The PTZ binaries are specific to the **MJSXJ02CM / IPC009**. Do not copy them
> to another camera model.

---

## What you need

- A camera with the base hack already installed and working.
- The base `ipc009_hack.zip` already unzipped on the SD card.
- The optional `ipc009_ptz_hack.zip` from this repository.
- Telnet access as `root` (the default root password is empty).
- Optional: a Frigate or Home Assistant host that can reach `<CAMERA_IP>`.

The camera and the Frigate/Home Assistant host must be able to reach each
other. If the camera is on a separate Wi-Fi AP or VLAN, add routing or port
forwarding first. The RTSP port 8554 must be reachable before ONVIF is useful.

---

## Back up first

Run these commands on the camera:

```sh
mkdir -p /mnt/sdcard/backups
tar cf /mnt/sdcard/backups/runit_before_ptz.tar -C /mnt/data/etc runit
cp /mnt/sdcard/manu_test/configure_services.sh \
   /mnt/sdcard/backups/configure_services.sh.bak
```

> The BusyBox `tar` on this camera does **not** support `-z`. Use an
> uncompressed `tar` file, as shown above.

---

## What is in `ipc009_ptz_hack.zip`

```text
hacks/motor_control/
  motord                 motor daemon
  event                  command file read by motord
  status                 last known status (not always updated)

hacks/onvif_srvd/
  onvif_srvd             ONVIF server
  start_onvif.sh         supervisor used by runit
  meta/service/.enable   tells configure_services.sh to install it
  meta/service/run       runit entry point

hacks/webctl/
  bin/                   WiFi helper used by the optional web page
  meta/service/          runit service for the web page
  www/                   web page and CGI scripts

hacks/ptz.conf           PTZ direction configuration
scripts/install_ptz_services.sh
scripts/optimize_ram.sh
README.txt
```

`motord` uses `libdevice_kit.so`, which is already present in
`/mnt/data/lib` on this firmware. The `start_onvif.sh` supervisor sets
`LD_LIBRARY_PATH=/mnt/data/lib` for it.

---

## Install

### 1. Copy the files to the SD card

Unzip `ipc009_ptz_hack.zip` to the **root** of the same FAT32 SD card, next to
the existing `hacks/` folder. Merge the folders; do not replace the base hack.

On macOS/Linux:

```sh
unzip ipc009_ptz_hack.zip -d /Volumes/SDCARD
```

On Windows, extract the zip with Explorer to the SD card root.

The result should contain:

```text
SDCARD/
  hacks/
    motor_control/
    onvif_srvd/
    webctl/
    ptz.conf
  scripts/
    install_ptz_services.sh
    optimize_ram.sh
  manu_test/
    configure_services.sh
```

### 2. Install the services

Insert the card and boot the camera, then log in over telnet:

```sh
telnet <CAMERA_IP>
# user: root
# password: leave empty
```

Run:

```sh
sh /mnt/sdcard/scripts/install_ptz_services.sh
```

Alternatively, install the two services manually:

```sh
/mnt/sdcard/manu_test/configure_services.sh onvif_srvd
/mnt/sdcard/manu_test/configure_services.sh webctl
```

Wait 10–15 seconds.

### 3. Check that the services are running

```sh
ps | grep -E 'motord|onvif_srvd|httpd' | grep -v grep
netstat -tln | grep -E ':(5000|8081|8554) '
```

Expected:

```text
0.0.0.0:5000    ONVIF
0.0.0.0:8081    web PTZ
0.0.0.0:8554    RTSP
```

The process list should show `./motord`, `./onvif_srvd ...` and
`busybox httpd ... -p 8081`.

If port 5000 is not listening, see [Troubleshooting](#troubleshooting).

### 4. Configure the PTZ directions

Open `/mnt/sdcard/hacks/ptz.conf`:

```sh
cat /mnt/sdcard/hacks/ptz.conf
```

Default:

```sh
INVERT_PAN=0
INVERT_TILT=0
```

For a camera mounted upside down on a ceiling, with the image flip enabled,
set both values to `1`:

```sh
INVERT_PAN=1
INVERT_TILT=1
```

See [`10-flip.md`](10-flip.md) for the full explanation and the direction
table.

---

## Verify

### Web PTZ page

Open this URL from a computer on the same network:

```text
http://<CAMERA_IP>:8081/
```

The page has buttons for left, right, up and down. The page is optional; the
main control path for Frigate and Home Assistant is ONVIF.

You can also test a direction with `curl`:

```sh
curl 'http://<CAMERA_IP>:8081/cgi-bin/ptz.cgi?dir=left&steps=1'
```

The response is JSON, for example:

```json
{"ok":true,"cmd":"pan reverse 1"}
```

The exact `cmd` depends on `ptz.conf`.

### RTSP

The RTSP stream must still work. From a computer with `ffprobe`:

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

If your camera is configured for H.264, `codec_name` will be `h264`.

### ONVIF

The ONVIF server uses the default credentials:

```text
user: admin
password: admin
```

You can test it from a computer with Python:

```sh
python3 -m venv /tmp/onvif-venv
/tmp/onvif-venv/bin/pip install onvif-zeep
/tmp/onvif-venv/bin/python - <<'PY'
from onvif import ONVIFCamera

cam = ONVIFCamera('<CAMERA_IP>', 5000, 'admin', 'admin')
print(cam.devicemgmt.GetDeviceInformation())

media = cam.create_media_service()
profiles = media.GetProfiles()
print([p.token for p in profiles])

ptz = cam.create_ptz_service()
req = ptz.create_type('ContinuousMove')
req.ProfileToken = profiles[0].token
req.Velocity = {'PanTilt': {'x': 0.5, 'y': 0.0}}
ptz.ContinuousMove(req)
ptz.Stop({'ProfileToken': profiles[0].token})
PY
```

The last two calls move the camera briefly. Use a small movement and be ready
to stop it.

> The ONVIF profile advertises H.264 even when the RTSP stream is H.265. This
> is a limitation of the small ONVIF server. Frigate uses the RTSP URL from
> `ffmpeg.inputs`, so its video stream is not affected.

---

## Frigate

Add the `onvif` block to the camera that already has the RTSP stream:

```yaml
cameras:
  xiaomi:
    ffmpeg:
      inputs:
        - path: rtsp://<CAMERA_IP>:8554/mainstream
          roles:
            - detect
            - record

    onvif:
      host: <CAMERA_IP>
      port: 5000
      user: admin
      password: admin
```

Restart Frigate. The PTZ controls should appear in the camera view.

- The RTSP path is the camera's original stream. The ONVIF block is only for
  pan/tilt.
- If the arrows move in the wrong direction, set `INVERT_PAN` and
  `INVERT_TILT` in `ptz.conf` and restart the ONVIF service.
- If Frigate does not show PTZ controls, see [Troubleshooting](#troubleshooting).

The camera must be reachable from the Frigate host at both ports:

```text
TCP 8554  RTSP
TCP 5000  ONVIF
```

If it is not reachable, fix routing/firewall first. Do not expose these ports
to the internet.

---

## Home Assistant

Add the ONVIF integration:

| Field | Value |
|-------|-------|
| Host | `<CAMERA_IP>` |
| Port | `5000` |
| Username | `admin` |
| Password | `admin` |

Then use the `onvif.ptz` service or the buttons created by the integration.

If the ONVIF integration does not expose PTZ, the web PTZ page can be called
from a REST command:

```yaml
rest_command:
  xiaomi_ptz_left:
    url: "http://<CAMERA_IP>:8081/cgi-bin/ptz.cgi?dir=left&steps=5"
  xiaomi_ptz_right:
    url: "http://<CAMERA_IP>:8081/cgi-bin/ptz.cgi?dir=right&steps=5"
  xiaomi_ptz_up:
    url: "http://<CAMERA_IP>:8081/cgi-bin/ptz.cgi?dir=up&steps=5"
  xiaomi_ptz_down:
    url: "http://<CAMERA_IP>:8081/cgi-bin/ptz.cgi?dir=down&steps=5"
```

Create buttons or scripts in Home Assistant that call these commands. The
commands follow `ptz.conf`, so ceiling-mounted cameras keep the correct
directions.

---

## PTZ directions

The image flip and the motor directions are independent:

- `mortoxc set nvram default flip on` flips only the **image**.
- `INVERT_PAN` and `INVERT_TILT` in `ptz.conf` flip the **controls**.

The full table and the ceiling-mount procedure are in
[`10-flip.md`](10-flip.md).

Short version:

```sh
cat > /mnt/sdcard/hacks/ptz.conf <<'EOF'
INVERT_PAN=1
INVERT_TILT=1
EOF
```

Then restart the ONVIF service:

```sh
/mnt/sdcard/hacks/runit/bin/sv down /mnt/data/etc/runit/onvif_srvd-run
sleep 2
killall onvif_srvd
/mnt/sdcard/hacks/runit/bin/sv up /mnt/data/etc/runit/onvif_srvd-run
```

The web PTZ CGI reads `ptz.conf` on every request; it does not need a restart.

---

## Troubleshooting

### Port 5000 is not listening

Check the service and the process:

```sh
/mnt/sdcard/hacks/runit/bin/sv status /mnt/data/etc/runit/onvif_srvd-run
ps | grep -E 'onvif_srvd|motord' | grep -v grep
netstat -tln | grep 5000
```

Check for an OOM kill:

```sh
dmesg | grep -i -E 'oom|killed process'
```

If the camera has 64 MB of RAM, see
[`11-ram-optimization.md`](11-ram-optimization.md). The stock cloud services
and the optional `web-config`/`websocket` services can starve ONVIF.

### `sv status` says `down: ... normally up, want up`

The `onvif_srvd` binary daemonizes. A plain runit `run` script would exit as
soon as the daemon is forked, and runit would restart it in a loop. The
provided `start_onvif.sh` keeps a supervisor loop alive and restarts only the
daemon when it disappears.

Make sure you are using the `start_onvif.sh` from this repository, not the
original script from the Russian package.

### `GetConfigurations` returns an empty list

Some ONVIF clients call `GetConfigurations` and expect a PTZ configuration.
This small server advertises the PTZ service and accepts `ContinuousMove`,
`RelativeMove` and `AbsoluteMove`, but the configuration list can be empty.
Frigate may still show the controls. If it does not, use the web PTZ page or
the Home Assistant REST fallback above.

### `motord` is running but the `status` file contains `0`

The `status` file is not reliable on this firmware. Use the camera movement,
the web page or the ONVIF client to verify. The `motord` debug log shows the
real motor commands:

```sh
ps | grep motord
```

### The image is upside down

See [`10-flip.md`](10-flip.md). The local fix is:

```sh
mortoxc set nvram default flip on
```

Do not use the Xiaomi cloud for this if you want to avoid OTA updates.

### Frigate does not show the PTZ controls

- Confirm `onvif` is under the correct camera in Frigate and the camera was
  restarted.
- Confirm Frigate can reach `<CAMERA_IP>:5000`.
- Try the web PTZ page from the Frigate host:
  `http://<CAMERA_IP>:8081/`.
- Use the Home Assistant REST fallback or the web page if the Frigate UI does
  not expose the controls.

### The camera reports `user ack timeout`

That error comes from the Xiaomi miIO/cloud path. It is not used by the local
`mortoxc` flip or by the ONVIF PTZ server. See [`10-flip.md`](10-flip.md).

---

## Security

- The ONVIF server defaults to `admin` / `admin`. Change it if your build
  supports `--user` / `--password` in `start_onvif.sh`, then update Frigate
  and Home Assistant.
- The web PTZ page on port 8081 has **no authentication**.
- The RTSP stream on port 8554 has **no authentication**.
- Keep ports 5000, 8081 and 8554 on the local network only. Do not expose
  them to the internet.
- The optional `web-config` page on port 80 and the WebSocket server on 4558
  are not needed for ONVIF or Frigate. On 64 MB cameras they should be
  disabled; see [`11-ram-optimization.md`](11-ram-optimization.md).

---

## Rollback

Stop and remove the two services:

```sh
SV=/mnt/sdcard/hacks/runit/bin/sv
$SV down /mnt/data/etc/runit/onvif_srvd-run
$SV down /mnt/data/etc/runit/webctl-run
rm -rf /mnt/data/etc/runit/onvif_srvd-run /mnt/data/etc/runit/webctl-run
```

Restore the runit backup:

```sh
rm -rf /mnt/data/etc/runit
tar xf /mnt/sdcard/backups/runit_before_ptz.tar -C /mnt/data/etc
reboot
```

Remove the optional files:

```sh
rm -rf /mnt/sdcard/hacks/motor_control
rm -rf /mnt/sdcard/hacks/onvif_srvd
rm -rf /mnt/sdcard/hacks/webctl
rm -f  /mnt/sdcard/hacks/ptz.conf
```

The rootfs is not modified. The base RTSP/telnet hack keeps working.

---

## Credits

- The PTZ package is based on the community `install.zip` published with the
  Russian MJSXJ02CM guide at `it-board.ru`.
- `onvif_srvd` is the upstream ONVIF server project; see
  [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
- `motord` and `webctl` come from the same community package.
- The base rootfs/telnet/RSTP hack is from `tsunglung/xiaomi-360-hacks`.
- The local miIO/PTZ context and the `flip`/`miio_rpc` prior art are described
  in `666dsa666/mjsxj02cm-hacks`.

See [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) for links and
licenses.

---

## No personal data

This guide uses placeholders only:

- `<CAMERA_IP>`
- `<SSID>`
- `<PASSWORD>`
- `<FRIGATE_HOST>`

Never commit real SSIDs, passwords, IP addresses, MAC addresses, device
tokens or camera serial numbers to the repository.
