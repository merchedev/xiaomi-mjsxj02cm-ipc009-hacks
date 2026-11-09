# 08 — Restore the original firmware

## Before you start

You need your original 16 MB backup (`flashbak.bin`). If you do not have
it, stop here. Restoring a backup from a different camera is not safe: the
MAC address, calibration data and factory partitions are unique to each
unit.

## Steps

1. Copy `flashbak.bin` to the root of the SD card (FAT32).
2. Insert the SD card into the camera.
3. Power on and stop U-Boot.
4. At `MStar #`:

```text
fatload mmc 0:1 0x21000000 flashbak.bin
sf probe 0
sf erase 0x0 0x1000000
sf write 0x21000000 0x0 0x1000000
reset
```

5. The camera reboots with the original firmware.

## Verify

After reboot, the camera should behave like a stock camera again:

- No telnet on port 23.
- No web config on port 80.
- No RTSP on port 8554.
- The Xiaomi app should be able to pair it again.

## If the restore fails

- Confirm the backup is exactly 16,777,216 bytes.
- Confirm `fatload` reads the full size:
  ```text
  16777216 bytes read
  ```
- Confirm `sf write` reports:
  ```text
  SF: 16777216 bytes @ 0x0 Written: OK
  ```
- If the camera does not boot, repeat the erase and write.
- If UART is dead, check GND and the soldering.

## Partial restore

If you only want to restore the DATA partition, you can extract it from the
backup:

```bash
dd if=flashbak.bin of=data_stock.img bs=1 skip=$((0x9B0000)) count=$((0x630000))
```

Then from the camera:

```sh
umount /mnt/data
flashcp -v /tmp/data_stock.img /dev/mtd3
```

This is useful if the rootfs is fine but the DATA partition is corrupt.
