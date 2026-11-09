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

### Scripts

- `scripts/uboot_cmd.py` — reliable U-Boot command sender.
- `scripts/uboot_interrupt.py` — holds Enter to stop autoboot.
- `scripts/cam_capture.py` — captures the boot log.
- `scripts/rebuild_rootfs.sh` — applies the patch and repacks the rootfs.

## What this fork does not include

- Binaries for other camera models.
- Personal data, IP addresses, SSIDs, MAC addresses or credentials.
- A prebuilt patched rootfs. The original `rootfs_new.bin` and
  `ipc009_hack.zip` are included under `mjsxj02cm/`, but the patched image
  is generated locally with `scripts/rebuild_rootfs.sh`.

## Upstream

If you want to support other models, use the original project:

```text
https://github.com/tsunglung/xiaomi-360-hacks
```

## License

GNU General Public License v3.0. See `LICENSE`.
