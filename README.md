# Xiaomi MJSXJ02CM (IPC009) — local RTSP hack

This repository is a focused fork of
[`tsunglung/xiaomi-360-hacks`](https://github.com/tsunglung/xiaomi-360-hacks)
for **one camera only**:

| Item | Value |
|------|-------|
| Camera model | Xiaomi Mi Home Security Camera 360° 1080p |
| Model name | **MJSXJ02CM** |
| Internal model | **IPC009** |
| Tested firmware | **4.3.7_0417** |
| Result | Telnet, web config, WebSocket and RTSP, all started automatically at boot |

The goal is simple: keep the camera completely local. No Xiaomi cloud, no
account, no mobile app after the initial setup.

> **Warning**
> You must open the camera and solder three wires. This voids the warranty.
> You must make a full flash backup before writing anything. If you skip the
> backup and something goes wrong, the camera can become unusable.
> Follow the steps in order and do not skip the backup.

---

## Table of contents

1. [What you get](#what-you-get)
2. [What you need](#what-you-need)
3. [Choose your UART connection](#choose-your-uart-connection)
4. [Step 1 — Back up the flash](#step-1--back-up-the-flash)
5. [Step 2 — Enter U-Boot](#step-2--enter-u-boot)
6. [Step 3 — Flash the hacked rootfs](#step-3--flash-the-hacked-rootfs)
7. [Step 4 — Install the hack files on the SD card](#step-4--install-the-hack-files-on-the-sd-card)
8. [Step 5 — Enable autostart](#step-5--enable-autostart)
9. [Step 6 — Verify RTSP](#step-6--verify-rtsp)
10. [Step 7 — Use it with Frigate or go2rtc](#step-7--use-it-with-frigate-or-go2rtc)
11. [Troubleshooting](#troubleshooting)
12. [Restore the original firmware](#restore-the-original-firmware)
13. [Credits and license](#credits-and-license)

---

## What you get

After the hack, the camera exposes:

| Service | Port | Purpose |
|---------|------|---------|
| Telnet | 23 | Root shell (no password by default) |
| Web config | 80 | Browser UI to configure the hack |
| WebSocket | 4558 | Auxiliary stream |
| RTSP | 8554 | Main video stream |

RTSP URLs:

```text
rtsp://<CAMERA_IP>:8554/mainstream
rtsp://<CAMERA_IP>:8554/substream
```

Replace `<CAMERA_IP>` with the IP address your router gives to the camera.

---

## What you need

- Xiaomi **MJSXJ02CM / IPC009** camera.
- A **3.3 V UART connection**. You can use a Raspberry Pi or a USB-TTL
  adapter. See the next section.
- A **microSD card** (8 GB or more is fine) formatted as **FAT32** with a
  single partition.
- A computer with:
  - `git`
  - Python 3
  - `squashfs-tools` (`unsquashfs` and `mksquashfs`) only if you want to
    rebuild the rootfs yourself.
- A small Phillips screwdriver and basic soldering tools.
- **Patience.** The first flash is the risky part.

> **Never connect the camera's VCC pin to your adapter.** You only need
> **TX**, **RX** and **GND**. The camera is powered by its own power supply.

---

## Choose your UART connection

You need to talk to the camera's UART at **115200 baud, 8 data bits, no
parity, 1 stop bit (8N1)**, with **flow control disabled**.

### Option A — Raspberry Pi (the method used to write this guide)

This is the method used during development. It works with a Raspberry Pi 3,
4, Zero or any model with a usable UART.

Wiring:

```text
Raspberry Pi GPIO14 (TX)  ->  camera RX
Raspberry Pi GPIO15 (RX)  ->  camera TX
Raspberry Pi GND          ->  camera GND
```

Enable the UART on the Pi:

```bash
sudo raspi-config
# Interface Options -> Serial Port
#   "Would you like a login shell to be accessible over serial?" -> No
#   "Would you like the serial port hardware to be enabled?"     -> Yes
sudo reboot
```

After reboot, the port is usually `/dev/serial0`.

Check it:

```bash
ls -l /dev/serial0
```

You may need to add your user to the `dialout` group:

```bash
sudo usermod -aG dialout "$USER"
```

Log out and back in for the group change to apply.

### Option B — USB-TTL adapter

Any **3.3 V** USB-TTL adapter works. Common chips:

| Adapter | Voltage | Notes |
|---------|---------|-------|
| FT232RL | 3.3 V / 5 V selectable | Very reliable. **Set the jumper to 3.3 V.** |
| CP2102 | 3.3 V | Cheap and common. Good choice. |
| CH340 | 3.3 V / 5 V | Very cheap. Some units are 5 V only; check before buying. |
| PL2303 | 3.3 V / 5 V | Works, but older drivers can be problematic on modern OSes. |

Wiring:

```text
Adapter TX   ->  camera RX
Adapter RX   ->  camera TX
Adapter GND  ->  camera GND
Adapter VCC  ->  do not connect
```

Device names:

| OS | Typical device |
|----|----------------|
| Linux | `/dev/ttyUSB0` or `/dev/ttyACM0` |
| macOS | `/dev/tty.usbserial-XXXX` or `/dev/tty.SLAB_USBtoUART` |
| Windows | `COM3`, `COM4`, ... (check Device Manager) |

On Linux, add your user to `dialout`:

```bash
sudo usermod -aG dialout "$USER"
```

On macOS, no extra group is usually needed.

On Windows, install the driver for your chip (FTDI, Silicon Labs, WCH or
Prolific) and use **PuTTY** or **Tera Term** with:

```text
Connection type: Serial
Speed:           115200
Data bits:       8
Parity:          None
Stop bits:       1
Flow control:    None
```

### Option C — Other boards

Any board with a **3.3 V** UART can work: Arduino with a 3.3 V level shifter,
ESP32, ESP8266, another camera, etc. The important part is the voltage:
**3.3 V only**. A 5 V TX signal can damage the camera's UART input.

---

## Step 1 — Back up the flash

**Do not skip this step.**

The camera has a 16 MB SPI NOR flash. You will read the whole flash through
U-Boot and save it on your computer. This backup is your only way back if
something goes wrong.

### 1.1 Enter U-Boot

Connect UART, open your serial terminal at **115200 8N1**, then power the
camera on while **holding Enter**.

With the included script:

```bash
# Raspberry Pi
python3 scripts/uboot_interrupt.py

# USB-TTL on Linux
python3 scripts/uboot_interrupt.py --port /dev/ttyUSB0

# USB-TTL on macOS
python3 scripts/uboot_interrupt.py --port /dev/tty.usbserial-XXXX

# Windows (PowerShell)
python scripts/uboot_interrupt.py --port COM3
```

When you see the prompt, stop the script with `Ctrl-C`. The prompt looks
like one of these:

```text
MStar #
SigmaStar #
GM #
```

If you use PuTTY/Tera Term instead, hold Enter while powering on until the
prompt appears.

### 1.2 Read the flash into RAM

At the U-Boot prompt:

```text
sf probe 0
sf read 0x21000000 0x0 0x1000000
```

This reads 16 MB (`0x1000000`) from flash offset `0x0` into RAM at
`0x21000000`.

### 1.3 Send the RAM contents to your computer

The exact method depends on your setup.

**Option A — Raspberry Pi with the camera still connected**

You can dump the flash over the same UART. This is slow but reliable. The
repository does not include a dump script because the method used during
development was ad-hoc. If you need it, the idea is:

1. Use U-Boot `md.b 0x21000000 0x1000000` to print the memory as hex.
2. Capture the serial output to a file.
3. Convert the hex dump back to binary with a small Python script.

**Option B — USB-TTL adapter**

Same idea: capture the output of `md.b` and convert it.

**Option C — SD card (if your U-Boot supports `fatwrite`)**

Some U-Boot builds support `fatwrite`. Check with:

```text
help fatwrite
```

If it exists:

```text
fatwrite mmc 0:1 0x21000000 flashbak.bin 0x1000000
```

If it does not exist, use the hex dump method.

> **Important:** verify that the backup is exactly **16,777,216 bytes**
> (`0x1000000`). Do not continue until you have a valid backup.

A known-good backup looks like this:

```text
Size: 16,777,216 bytes
```

Keep it somewhere safe. You will need it if you ever want to restore the
camera.

---

## Step 2 — Enter U-Boot

If you are not already at the U-Boot prompt, repeat the procedure from
Step 1.1: hold Enter while powering the camera on.

The camera's U-Boot does **not** print a visible "hit any key" countdown on
this firmware, but holding Enter during boot still stops it. The included
`uboot_interrupt.py` script does this automatically.

---

## Step 3 — Flash the hacked rootfs

You have two choices:

- Use the pre-built `rootfs_new.bin` from the original repository.
- Rebuild it with the autostart patch from this fork.

### 3.1 Get a rootfs image

**Option A — use the original image**

The original image is included in this repository:

```text
mjsxj02cm/rootfs_new.bin
```

It also comes from the original project:

```text
https://github.com/tsunglung/xiaomi-360-hacks/tree/master/mjsxj02cm
```

This image works, but it does **not** start the hack automatically. You will
need to start the services manually after every boot, or apply the patch in
Step 5.

**Option B — build the patched image (recommended)**

```bash
git clone https://github.com/<YOUR_GITHUB_USER>/xiaomi-mjsxj02cm-ipc009-hacks.git
cd xiaomi-mjsxj02cm-ipc009-hacks
./scripts/rebuild_rootfs.sh /path/to/rootfs_new.bin
```

The script creates `rootfs_new_patched.bin` and prints the exact U-Boot
commands with the correct size.

### 3.2 Copy the image to the SD card

Format the SD card as **FAT32** with a single partition, then copy the image
to the root of the card and rename it to `rootfs_new.bin`.

Example on macOS/Linux:

```bash
cp rootfs_new_patched.bin /Volumes/SDCARD/rootfs_new.bin
sync
```

On Windows, copy the file with Explorer.

Make sure there are no macOS metadata files (`._*`) on the card:

```bash
find /Volumes/SDCARD -name '._*' -delete
```

### 3.3 Flash it

Insert the SD card into the camera, power it on, and stop U-Boot again.

At the `MStar #` prompt:

```text
fatload mmc 0:1 0x21000000 rootfs_new.bin
sf probe 0
sf erase 0x260000 0x750000
sf write 0x21000000 0x260000 <SIZE>
reset
```

Replace `<SIZE>` with the hexadecimal size printed by
`rebuild_rootfs.sh`. For the current patched image it is:

```text
0x689000
```

> **Do not use `0x674000`.**
> That value comes from the original README and is smaller than the actual
> file. Writing less than the file size truncates the squashfs and the
> camera panics with:
>
> ```text
> squashfs: unable to read id index table
> ```
>
> If you already did this, the camera is not permanently bricked. Re-enter
> U-Boot and flash again with the correct size.

`0x750000` is the full ROOTFS partition (`0x260000` to `0x9B0000`). Erasing
the whole partition is safe and avoids leftover data.

After `reset`, the camera boots the hacked rootfs. You should see the normal
boot log and eventually a login prompt.

---

## Step 4 — Install the hack files on the SD card

The hack applications are included in this repository:

```text
mjsxj02cm/ipc009_hack.zip
```

They also come from the original project:

```text
https://github.com/tsunglung/xiaomi-360-hacks/tree/master/mjsxj02cm
```

Unzip it to the **root** of the SD card. The card must look like this:

```text
SDCARD/
  manu_test/
    configure_services.sh
    ...
  hacks/
  scripts/
```

The important file is:

```text
/mnt/sdcard/manu_test/configure_services.sh
```

This is the script that starts the RTSP server, the web server and the
WebSocket server.

> **Note:** if you use the original rootfs without the autostart patch,
> you will need to run this script manually after every boot:
>
> ```sh
> /mnt/sdcard/manu_test/configure_services.sh &
> ```

---

## Step 5 — Enable autostart

This is the part that the original repository does not handle correctly on
firmware 4.3.7_0417. Three things go wrong:

1. `S49factory` creates `/tmp/factory_mode`, and the stock `S60service`
   exits immediately when that file exists.
2. `S49factory` unmounts `/mnt/sdcard` when it finishes, so
   `/mnt/sdcard/manu_test/configure_services.sh` is not available when
   `S60service` runs.
3. `/mnt/data` is not guaranteed to be mounted when `S60service` runs.

The patch in `patches/S60service.ipc009-4.3.7` fixes all three:

- Removes the `/tmp/factory_mode` exit.
- Runs `mount -a` for `/mnt/data`.
- Mounts `/mnt/sdcard` again.
- Creates the `libshbf`/`libshbfev` symlinks that `framegrabber` needs.
- Starts `configure_services.sh` directly.

### 5.1 Rebuild the rootfs with the patch

If you already built `rootfs_new_patched.bin` in Step 3, you are done. The
patch is already inside the image.

If you used the original `rootfs_new.bin`, rebuild it now:

```bash
./scripts/rebuild_rootfs.sh /path/to/rootfs_new.bin
```

Then repeat Step 3.3 with the new image.

### 5.2 What the patch does

For reference, the patched `S60service` looks like this:

```sh
do_start() {
    rl=$(runlevel -p)
    runlevel -s $rl
    telnetd

    mount -a
    mount /dev/mmcblk0p1 /mnt/sdcard 2>/dev/null || \
        mount /dev/mmcblk0 /mnt/sdcard 2>/dev/null || true

    ln -sf libshbf.so.0.2 /mnt/data/lib/libshbf.so.0.1
    ln -sf libshbfev.so.0.2 /mnt/data/lib/libshbfev.so.0.1

    if [ -x /mnt/sdcard/manu_test/configure_services.sh ]; then
        /mnt/sdcard/manu_test/configure_services.sh &
    fi
}
```

The full file is in `patches/S60service.ipc009-4.3.7`.

---

## Step 6 — Verify RTSP

After the camera boots, find its IP address in your router's DHCP table or
from the boot log.

From a computer on the same network:

```bash
ffplay -rtsp_transport tcp "rtsp://<CAMERA_IP>:8554/mainstream"
```

or with VLC:

```text
Media -> Open Network Stream -> rtsp://<CAMERA_IP>:8554/mainstream
```

If the stream opens, the hack is working.

You can also check the web config UI:

```text
http://<CAMERA_IP>/
```

And telnet:

```bash
telnet <CAMERA_IP>
```

Login as `root`. The default root password is empty on this hack.

> **Security note:** telnet with no password is convenient during setup but
> dangerous on a shared network. See the security section below.

---

## Step 7 — Use it with Frigate or go2rtc

### Frigate

Add the camera to your `config.yml`:

```yaml
cameras:
  xiaomi:
    ffmpeg:
      inputs:
        - path: rtsp://<CAMERA_IP>:8554/mainstream
          roles:
            - detect
            - record
```

Restart Frigate and check the logs.

### go2rtc

Add the stream to `go2rtc.yaml`:

```yaml
streams:
  xiaomi: rtsp://<CAMERA_IP>:8554/mainstream
```

Then open the go2rtc web UI and test the stream.

> **Network note:** the camera must be reachable from the Frigate/go2rtc
> host. If you cannot ping the camera but it has an IP address, check
> whether your router isolates wireless clients. Many routers have an
> option called "AP isolation", "client isolation" or "guest network
> isolation". Disable it or put the camera and the server on the same
> network segment.

### Security

The hack services have **no authentication by default**. If your network is
not fully trusted, at minimum:

- Do not expose ports 23, 80, 4558 or 8554 to the internet.
- Keep the camera on a separate VLAN or guest network if possible.
- Change the telnet root password if your build supports it.
- Use firewall rules so only your NVR can reach port 8554.

---

## Troubleshooting

### The camera does not send anything on UART

- Check **GND** first. A loose GND is the most common cause.
- Check that TX and RX are crossed: adapter TX to camera RX, adapter RX to
  camera TX.
- Confirm **3.3 V** logic. Do not use 5 V.
- Confirm **115200 8N1**, no flow control.
- Try another USB cable or adapter.

### I see garbage characters instead of text

- Wrong baud rate. Use **115200**.
- Wrong voltage or bad GND.
- Loose wire.

### U-Boot does not stop

- Hold Enter **while** powering the camera on, not after.
- Use `scripts/uboot_interrupt.py`, which sends Enter every 50 ms.
- Some adapters need a small delay before the first character; the script
  handles this.
- If it still does not stop, power-cycle and try again. It can take a few
  attempts.

### `sf write` writes fewer bytes than expected

The command was truncated. Use `scripts/uboot_cmd.py`, which sends the
command one character at a time, and double-check the size. The correct
size for the patched image is printed by `rebuild_rootfs.sh`.

### Kernel panic: `squashfs: unable to read id index table`

The rootfs was truncated. Re-enter U-Boot and flash again with the correct
size:

```text
sf erase 0x260000 0x750000
sf write 0x21000000 0x260000 0x689000
```

### Kernel panic: `VFS: Unable to mount root fs`

Same cause as above: the rootfs is corrupt or truncated. Re-flash it.

### Services do not start automatically

- Confirm you are using the patched rootfs (`rootfs_new_patched.bin`).
- Confirm the SD card contains `/manu_test/configure_services.sh`.
- Confirm the SD card is inserted at boot.
- Check the boot log for `Xiaomi Hacks enabled` or `configure_services`.

### Services start but there is no video

- Check that `framegrabber` is running:
  ```sh
  ps | grep framegrabber
  ```
- Check the symlinks:
  ```sh
  ls -l /mnt/data/lib/libshbf.so.0.1
  ls -l /mnt/data/lib/libshbfev.so.0.1
  ```
- Check the RTSP port:
  ```sh
  netstat -tln
  ```

### I cannot reach the camera from my computer

- Confirm the camera and the computer are on the same subnet.
- Check the router's DHCP table for the camera's IP.
- Disable AP/client isolation on the router.
- Try pinging the camera. If ping fails but the camera has an IP, it is
  almost always a router isolation issue.

### The camera boots but telnet asks for a password

The default hack root password is empty. Press Enter. If that does not
work, use the UART console instead and check `/etc/passwd`.

---

## Restore the original firmware

If you want to go back to the stock firmware:

1. Copy your `flashbak.bin` (the 16 MB backup) to the SD card.
2. Enter U-Boot.
3. Run:

```text
fatload mmc 0:1 0x21000000 flashbak.bin
sf probe 0
sf erase 0x0 0x1000000
sf write 0x21000000 0x0 0x1000000
reset
```

The camera returns to the exact state of the backup.

> **Never flash a backup from a different camera.** The MAC address,
> calibration data and factory partitions are unique to each unit.

---

## Credits and license

- Original project: [`tsunglung/xiaomi-360-hacks`](https://github.com/tsunglung/xiaomi-360-hacks)
- This fork: focused on MJSXJ02CM / IPC009 firmware 4.3.7_0417.
- License: **GNU General Public License v3.0** (see `LICENSE`).

The original project and this fork are provided as-is, with no warranty.
You are responsible for your own hardware.
