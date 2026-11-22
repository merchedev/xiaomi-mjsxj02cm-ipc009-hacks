# 10 — Flip the image and invert the PTZ (ceiling mount)

If the camera is mounted upside down on a ceiling, the image is upside down and
the PTZ arrows move in the opposite direction. Both problems can be fixed
**on the camera**, without the Xiaomi cloud, without a firmware update and
without transcoding in Frigate.

This guide covers two independent settings:

1. **Image flip** — rotates the video 180° inside the camera.
2. **PTZ direction** — inverts the left/right and up/down controls so that the
   arrows match the flipped image.

The image flip is done with the vendor's local key/value bus. The PTZ
direction is done with `ptz.conf`, which is read by both the ONVIF server and
the web PTZ page.

> **Tested on:** MJSXJ02CM / IPC009, firmware 4.3.7_0417.
> The `nvram` flip survived a reboot in testing.

---

## Part 1 — Flip the image (local, no cloud)

### The command

Log in over telnet:

```sh
telnet <CAMERA_IP>
# user: root
# password: leave empty
```

Run:

```sh
mortoxc set nvram default flip on
```

The image should rotate 180° within a second or two. Check it in Frigate, VLC
or the web PTZ page.

Verify the stored value:

```sh
mortoxc get nvram default flip
```

Expected:

```text
on
```

### Persistence

The `nvram` layer is persistent. In our test the value was still `on` after a
reboot, and the image stayed flipped.

If a future firmware change or a re-pair resets it, run the command again, or
use one of the fallbacks below.

### Revert

```sh
mortoxc set nvram default flip off
```

The image returns to normal.

### Why this works (and why it does not need the cloud)

The camera's video pipeline process is `fetch_av`. It registers a local
notification for the key **`flip`** with `libmortox_register_notification` and
applies `set_video_Vflip` / `set_video_normal`.

`mortoxd` is a small local key/value and notification daemon. It listens on
`/tmp/mortox.socket`. `mortoxc` is its command-line client. The default
configuration in `/mnt/data/.config.def` contains:

```text
flip=off
```

The chain is:

```text
mortoxc set nvram default flip on
        |
        v
mortoxd (local socket /tmp/mortox.socket)
        |
        v
fetch_av flip_status_cb -> set_video_Vflip
        |
        v
camera video pipeline -> RTSP / WebSocket / ONVIF clients
```

No `miio_cloud`, no Mi Home account, no OTA and no Frigate transcode are
involved.

The `miio_client` may return `user ack timeout` for `get_prop ["flip"]` when
the cloud services are disabled. That is a different path (the cloud/user
acknowledgement). It does not affect the local `mortoxc` flip.

### If `nvram` does not persist

Try the `mem` layer first (runtime only):

```sh
mortoxc set mem default flip on
```

If `mem` works but is lost after a reboot, make it persistent with one of
these options:

**Option A — edit the default configuration**

```sh
cp /mnt/data/.config.def /mnt/sdcard/backups/.config.def.bak
sed -i 's/^flip=off$/flip=on/' /mnt/data/.config.def
```

Then reboot and check the image.

**Option B — set it at boot**

Create a small script on the SD card:

```sh
cat > /mnt/sdcard/scripts/set_flip.sh <<'EOF'
#!/bin/sh
sleep 20
/mnt/data/bin/mortoxc set mem default flip on
EOF
chmod +x /mnt/sdcard/scripts/set_flip.sh
```

Call it from `configure_services.sh`, from `post_init.sh`, or from a small
runit service. The `sleep 20` gives `fetch_av` and `mortoxd` time to start.

### Do not use the cloud if you want to avoid OTA

The Mi Home app can also rotate the image, but using it normally means
re-enabling the Xiaomi cloud. An OTA update could replace the patched rootfs.
The local `mortoxc` command avoids that risk completely.

If you ever re-enable the cloud:

- Keep `miio_ota` disabled.
- Do not press "Update firmware".
- Do not reset, remove or re-pair the camera.
- Only change the rotation setting.

---

## Part 2 — Invert the PTZ arrows

Flipping the image does **not** change the physical motor axes. After a 180°
image rotation, left/right and up/down are reversed. This is expected.

The PTZ direction is controlled by:

```text
/mnt/sdcard/hacks/ptz.conf
```

Default:

```sh
INVERT_PAN=0
INVERT_TILT=0
```

For a ceiling-mounted camera with the image flipped, use:

```sh
INVERT_PAN=1
INVERT_TILT=1
```

The file is read by:

- `start_onvif.sh` — the ONVIF server used by Frigate and Home Assistant.
- `ptz.cgi` — the web PTZ page on port 8081.

### Direction table

| Control | `INVERT_PAN=0` / `INVERT_TILT=0` | `INVERT_PAN=1` / `INVERT_TILT=1` |
|---------|----------------------------------|----------------------------------|
| left | `pan forward` | `pan reverse` |
| right | `pan reverse` | `pan forward` |
| up | `tilt forward` | `tilt reverse` |
| down | `tilt reverse` | `tilt forward` |

For a ceiling mount use the right-hand column.

### Apply the new directions

The web page reads `ptz.conf` on every request, so no restart is needed for
port 8081.

The ONVIF server reads `ptz.conf` when it starts. Restart it:

```sh
/mnt/sdcard/hacks/runit/bin/sv down /mnt/data/etc/runit/onvif_srvd-run
sleep 2
killall onvif_srvd
/mnt/sdcard/hacks/runit/bin/sv up /mnt/data/etc/runit/onvif_srvd-run
```

The `killall` is needed because `onvif_srvd` daemonizes. The `motord` daemon
is not touched and keeps running.

Wait about 10 seconds, then check:

```sh
/mnt/sdcard/hacks/runit/bin/sv status /mnt/data/etc/runit/onvif_srvd-run
netstat -tln | grep 5000
ps | grep onvif_srvd | grep -v grep
```

The process command line should contain the inverted commands:

```text
--move_left  ... pan reverse
--move_right ... pan forward
--move_up    ... tilt reverse
--move_down  ... tilt forward
```

Now test the arrows in Frigate. The direction should match the flipped image.

If only one axis is wrong, change only that flag:

```sh
# Only horizontal is wrong
INVERT_PAN=1
INVERT_TILT=0

# Only vertical is wrong
INVERT_PAN=0
INVERT_TILT=1
```

Restart ONVIF after any change.

### Revert to a normal mount

```sh
mortoxc set nvram default flip off

cat > /mnt/sdcard/hacks/ptz.conf <<'EOF'
INVERT_PAN=0
INVERT_TILT=0
EOF

/mnt/sdcard/hacks/runit/bin/sv down /mnt/data/etc/runit/onvif_srvd-run
sleep 2
killall onvif_srvd
/mnt/sdcard/hacks/runit/bin/sv up /mnt/data/etc/runit/onvif_srvd-run
```

---

## Troubleshooting

### The image does not flip

```sh
ps | grep -E 'fetch_av|mortoxd' | grep -v grep
mortoxc get nvram default flip
mortoxc get mem default flip
```

- `fetch_av` and `mortoxd` must be running.
- Try `mortoxc set mem default flip on`, then `mortoxc set nvram default flip on`.
- Check that the value is `on`, not `1` or `true`.

### The image flips back after a reboot

The `nvram` value did not persist. Use the `.config.def` edit or the boot
script from Part 1.

### The image is flipped but the arrows are still wrong

Set `INVERT_PAN` and `INVERT_TILT` in `ptz.conf` and restart ONVIF. The web page
does not need a restart.

### Frigate still moves the wrong way

- Frigate uses the ONVIF server, not the web page.
- Confirm the ONVIF process command line shows the inverted commands.
- Restart the ONVIF service again.
- If only one axis is wrong, change only that flag.

### The camera moves but the image is mirrored, not rotated

The `flip` setting is the vendor's 180° image mode. If your build produces a
mirror instead of a rotation, use the go2rtc restream described in
[`09-onvif-ptz.md`](09-onvif-ptz.md) and the Frigate guide. Do not combine
both at the same time.

### `user ack timeout`

This is a Xiaomi miIO/cloud message. The local `mortoxc` path does not use it.
Ignore it for the flip. It does not mean the flip failed.

---

## Risk

- `mortoxc set nvram` writes one key in the camera's local configuration. It
  does not touch the rootfs, the bootloader or the cloud.
- It is reversible with `mortoxc set nvram default flip off`.
- The `.config.def` edit is also local; back it up first.
- No OTA is triggered. Keep `miio_ota` disabled if you use the cloud for
  anything else.
- The camera keeps streaming during the change; a short glitch is normal.

---

## No personal data

Use placeholders in your own notes:

- `<CAMERA_IP>`
- `<SSID>`
- `<PASSWORD>`

Do not commit real IP addresses, MAC addresses, SSIDs, passwords, miIO tokens
or camera serial numbers.
