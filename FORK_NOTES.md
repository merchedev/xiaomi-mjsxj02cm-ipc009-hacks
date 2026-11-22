# Fork notes

This repository is a focused fork of
[`tsunglung/xiaomi-360-hacks`](https://github.com/tsunglung/xiaomi-360-hacks).

## Why this fork exists

The original project supports several Xiaomi camera models. This fork
focuses on **one model only**:

```text
Xiaomi MJSXJ02CM / IPC009
Firmware 4.3.7_0417
```

The goal is to give owners of this exact camera a guide that works from
start to finish, without having to read issues, guess offsets or debug
init scripts.

## What changed

### Documentation

- New English guide written for people who have never hacked a camera.
- Step-by-step instructions for:
  - Raspberry Pi UART
  - USB-TTL adapters on Linux, macOS and Windows
  - Backup and restore
  - Flashing and verification
  - Frigate and go2rtc integration
  - Optional ONVIF PTZ and web PTZ
  - Local image flip for ceiling mounts
  - RAM optimization on 64 MB cameras
  - Changing Wi-Fi without opening the camera
- Troubleshooting section based on real failures.

### Autostart fix

The original rootfs does not start the hack services automatically on
firmware 4.3.7_0417. This fork adds a patched `S60service` that:

- Removes the `/tmp/factory_mode` exit.
- Runs `mount -a`.
- Mounts `/mnt/sdcard` again.
- Creates the `libshbf`/`libshbfev` symlinks.
- Starts `configure_services.sh` directly.

See `patches/S60service.ipc009-4.3.7` and `docs/06-autostart.md`.

### Correct flash size

The original README uses `0x674000` for the ROOTFS write. The actual image
is larger (`0x689000`). Writing less truncates the squashfs and causes:

```text
squashfs: unable to read id index table
Kernel panic - not syncing: VFS: Unable to mount root fs
```

This fork documents the correct size and includes a script that prints it
automatically.

### Optional PTZ and ONVIF add-on

The optional `mjsxj02cm/ipc009_ptz_hack.zip` adds:

- `motord` for the pan/tilt motors.
- ONVIF Profile S PTZ on port 5000.
- A web PTZ page on port 8081.
- `ptz.conf` for the control directions.

The add-on lives on the SD card, not in the rootfs. It is optional and can be
removed. See `docs/09-onvif-ptz.md`.

The `start_onvif.sh` supervisor is included in `patches/` because the upstream
community script daemonizes `onvif_srvd` and uses a `killall` on `motord` that
can deadlock runit.

### Local image flip for ceiling mounts

The camera can rotate the image 180° without the Xiaomi cloud:

```sh
mortoxc set nvram default flip on
```

The setting is local and survived a reboot in testing on firmware 4.3.7_0417.
The PTZ controls are inverted with `INVERT_PAN`/`INVERT_TILT` in `ptz.conf`.
See `docs/10-flip.md`.

This avoids both the Xiaomi cloud/OTA risk and a full 1080p transcode in
Frigate.

### RAM optimization

The fork documents the 64 MB memory budget and provides an optional script
that disables the web configuration server, the WebSocket server and the
unused stock cloud services while keeping `fetch_av`, `miio_client`, RTSP,
ONVIF and the PTZ daemons.

See `docs/11-ram-optimization.md`.

### Wi-Fi guide

`docs/12-wifi.md` documents the custom `/mnt/data/wpa.conf` method and the
stock Xiaomi NVRAM method, including DHCP reservations and rollback. It does
not include any real SSIDs or passwords.

### Scripts

- `scripts/uboot_cmd.py` — reliable U-Boot command sender.
- `scripts/uboot_interrupt.py` — holds Enter to stop autoboot.
- `scripts/cam_capture.py` — captures the boot log.
- `scripts/rebuild_rootfs.sh` — applies the patch and repacks the rootfs.
- `scripts/install_ptz_services.sh` — camera-side PTZ service installer.
- `scripts/optimize_ram.sh` — camera-side RAM optimization.
- `scripts/verify_ptz.sh` — host-side PTZ/ONVIF/RTSP verification.

## What this fork does not include

- Binaries for other camera models.
- Personal data, IP addresses, SSIDs, MAC addresses, credentials, miIO tokens
  or camera serial numbers.
- A prebuilt patched rootfs. The original `rootfs_new.bin` and
  `ipc009_hack.zip` are included under `mjsxj02cm/`, but the patched image
  is generated locally with `scripts/rebuild_rootfs.sh`.
- The optional PTZ binaries are third-party files. See
  `THIRD_PARTY_NOTICES.md` for sources and licenses.

## Upstream

If you want to support other models, use the original project:

```text
https://github.com/tsunglung/xiaomi-360-hacks
```

## License

GNU General Public License v3.0. See `LICENSE`.
