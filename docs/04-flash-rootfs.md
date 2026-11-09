# 04 — Flash the rootfs

## Partition layout

```text
BOOT    0x000000 - 0x050000
KERNEL  0x050000 - 0x260000
ROOTFS  0x260000 - 0x9B0000
DATA    0x9B0000 - 0xFE0000
CONFIG  0xFE0000 - 0xFF0000
FACTORY 0xFF0000 - 0x1000000
```

The ROOTFS partition is `0x750000` bytes long:

```text
0x9B0000 - 0x260000 = 0x750000
```

## Get a rootfs image

### Option A — original image

From the original repository:

```text
https://github.com/tsunglung/xiaomi-360-hacks/tree/master/mjsxj02cm
```

File: `rootfs_new.bin`.

This image works, but the hack services do not start automatically. Use
the patch in `06-autostart.md` if you want autostart.

### Option B — patched image (recommended)

```bash
git clone https://github.com/<YOUR_GITHUB_USER>/xiaomi-mjsxj02cm-ipc009-hacks.git
cd xiaomi-mjsxj02cm-ipc009-hacks
./scripts/rebuild_rootfs.sh /path/to/rootfs_new.bin
```

The script prints the exact size. For the current image:

```text
Size: 6852608 bytes (0x689000)
```

## Prepare the SD card

1. Format as **FAT32**, single partition.
2. Copy the image to the root of the card.
3. Rename it to `rootfs_new.bin`.
4. Remove macOS metadata files:

```bash
find /Volumes/SDCARD -name '._*' -delete
```

5. Eject the card safely.

## Flash

1. Insert the SD card into the camera.
2. Power on and stop U-Boot.
3. At `MStar #`:

```text
fatload mmc 0:1 0x21000000 rootfs_new.bin
sf probe 0
sf erase 0x260000 0x750000
sf write 0x21000000 0x260000 0x689000
reset
```

### Why the size matters

The original README uses `0x674000`. That is **6,766,592 bytes**, but the
actual file is **6,852,608 bytes** (`0x689000`).

If you write only `0x674000` bytes, the squashfs is truncated. The kernel
then panics with:

```text
squashfs: unable to read id index table
```

Always use the real file size. You can calculate it:

```bash
python3 - <<'PY'
import os
size = os.path.getsize("rootfs_new.bin")
print(f"{size} bytes = 0x{size:X}")
PY
```

### Expected U-Boot output

```text
reading rootfs_new.bin
6852608 bytes read
...
SF: 6852608 bytes @ 0x260000 Written: OK
```

If the number is smaller, the command was truncated. Re-run it with
`scripts/uboot_cmd.py` or type it again carefully.

## First boot

After `reset`, the camera boots the hacked rootfs. You should see:

```text
Welcome to Mijia_camera.
mijia_camera login:
```

If you see a kernel panic instead, the rootfs is corrupt or truncated.
Re-enter U-Boot and flash again.

## Verify the rootfs

After boot, log in as `root` (empty password) and check:

```sh
mount | grep mnt/data
ls /mnt/data/bin/factory
/mnt/data/bin/factory get model
```

Expected:

```text
chuangmi.camera.ipc009
```

If `factory` works, the DATA partition is intact.
