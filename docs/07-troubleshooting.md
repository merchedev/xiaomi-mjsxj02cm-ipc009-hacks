# 07 — Troubleshooting

## UART

### No output at all

1. Check **GND** first. This is the most common failure.
2. Check TX/RX crossing:
   - Adapter TX -> camera RX
   - Adapter RX -> camera TX
3. Confirm 3.3 V logic.
4. Confirm 115200 8N1, no flow control.
5. Try another cable or adapter.

### Garbage characters

- Wrong baud rate.
- Bad GND.
- Loose wire.
- 5 V adapter on a 3.3 V input.

### The camera boots but I cannot type

- The UART RX line may be disconnected. Check the wire from adapter TX to
  camera RX.
- The camera console may be on a different UART. On this model it is the
  one exposed on the test pads.

## U-Boot

### It does not stop at `MStar #`

- Hold Enter **while** powering on.
- Use `scripts/uboot_interrupt.py`.
- Try several times.
- Some adapters send a break or garbage on open; open the port first, then
  power the camera.

### `sf probe` fails

- Check the flash detection message:
  ```text
  Flash is detected (0x090F, 0x1C, 0x70, 0x18)
  ```
- If it fails, the SPI flash may be damaged or the board may have a power
  problem.

### `fatload` cannot find the file

- The SD card must be FAT32, single partition.
- The file must be in the root of the card.
- Check the exact name: `rootfs_new.bin`.
- Remove macOS metadata:
  ```bash
  find /Volumes/SDCARD -name '._*' -delete
  ```

## Flashing

### `sf write` writes fewer bytes than expected

The command was truncated. Use `scripts/uboot_cmd.py` or type the command
again slowly.

### Kernel panic: `squashfs: unable to read id index table`

The rootfs is truncated. Re-flash with the real size:

```text
sf erase 0x260000 0x750000
sf write 0x21000000 0x260000 0x689000
```

### Kernel panic: `VFS: Unable to mount root fs`

Same cause: corrupt or truncated rootfs. Re-flash.

### The camera goes back to U-Boot after reset

The rootfs did not boot. Check:

```text
sf read 0x21000000 0x260000 0x100
md.b 0x21000000 0x40
```

A valid squashfs starts with `hsqs` (`68 73 71 73`). If you see something
else, the write failed.

## Services

### Services do not start at boot

- Confirm you are running the patched rootfs.
- Check:
  ```sh
  grep -n "factory_mode" /etc/init.d/S60service
  ```
  If it finds a match, you are still on the stock `S60service`.
- Check the SD card is mounted:
  ```sh
  mount | grep sdcard
  ```
- Check the script exists:
  ```sh
  ls -l /mnt/sdcard/manu_test/configure_services.sh
  ```

### `framegrabber` fails with a library error

Create the symlinks:

```sh
ln -sf libshbf.so.0.2 /mnt/data/lib/libshbf.so.0.1
ln -sf libshbfev.so.0.2 /mnt/data/lib/libshbfev.so.0.1
```

### Ports are open but there is no video

- Check the camera sensor is detected:
  ```sh
  dmesg | grep -i isp
  ```
- Check `framegrabber`:
  ```sh
  ps | grep framegrabber
  ```
- Check the RTSP log output. The server usually prints the stream URLs:
  ```text
  rtsp://<CAMERA_IP>:8554/mainstream
  rtsp://<CAMERA_IP>:8554/substream
  ```

### I cannot reach the camera from my computer

- Check the camera has an IP:
  ```sh
  ifconfig wlan0
  ```
- Check the computer and camera are on the same subnet.
- Check the router for **AP isolation** / **client isolation**.
- Try pinging the camera. If it has an IP but ping fails, it is almost
  always a router isolation issue.

## Network

### The camera connects to the wrong WiFi network

If your router broadcasts more than one SSID (for example, an old 2.4 GHz
network and a newer one), the camera may connect to the wrong one.

- Temporarily disable the unwanted SSID, or
- Reset the camera's WiFi configuration and pair it again, or
- Check the boot log for the SSID it joins:
  ```text
  network id / ssid / bssid / flags
  0   <SSID>   any   [CURRENT]
  ```

## Recovery

### The camera does not boot at all

1. Connect UART.
2. Hold Enter while powering on.
3. If you get `MStar #`, restore the backup:
   ```text
   fatload mmc 0:1 0x21000000 flashbak.bin
   sf probe 0
   sf erase 0x0 0x1000000
   sf write 0x21000000 0x0 0x1000000
   reset
   ```
4. If you do not get a prompt, check GND and the UART wiring again.

### I lost my backup

Without a backup, recovery is much harder. The camera may still be
recoverable by flashing a known-good image for the same model and firmware,
but the MAC address and calibration data will not match. Avoid this
situation: make the backup first.
