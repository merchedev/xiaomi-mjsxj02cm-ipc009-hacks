# 02 — Back up the flash

**This is the most important step.** The backup is your only way back if
something goes wrong.

## What you are backing up

The camera has a 16 MB SPI NOR flash:

```text
0x000000 - 0x050000  BOOT
0x050000 - 0x260000  KERNEL
0x260000 - 0x9B0000  ROOTFS
0x9B0000 - 0xFE0000  DATA
0xFE0000 - 0xFF0000  CONFIG
0xFF0000 - 0x1000000 FACTORY
```

You will read the whole 16 MB (`0x1000000`) to RAM and then transfer it to
your computer.

## Step 1 — Enter U-Boot

Connect UART and hold Enter while powering the camera on.

Using the included script:

```bash
python3 scripts/uboot_interrupt.py
```

With a USB-TTL adapter:

```bash
python3 scripts/uboot_interrupt.py --port /dev/ttyUSB0
python3 scripts/uboot_interrupt.py --port /dev/tty.usbserial-XXXX
python3 scripts/uboot_interrupt.py --port COM3
```

Wait for the prompt:

```text
MStar #
```

## Step 2 — Read the flash into RAM

```text
sf probe 0
sf read 0x21000000 0x0 0x1000000
```

Expected output:

```text
SF: 16777216 bytes @ 0x0 Read: OK
```

If the size is different, stop and check the flash detection.

## Step 3 — Transfer the data to your computer

There are three practical methods.

### Method A — hex dump over UART

At the U-Boot prompt:

```text
md.b 0x21000000 0x1000000
```

This prints the whole 16 MB as hexadecimal lines. It takes a long time
(30–60 minutes at 115200 baud). Capture the serial output to a file.

Example on Linux/macOS with `picocom`:

```bash
picocom -b 115200 /dev/ttyUSB0 | tee flashdump.txt
```

Then convert the hex dump to binary. A minimal Python converter:

```python
#!/usr/bin/env python3
import re
import sys

hex_bytes = []
with open(sys.argv[1], "r", errors="ignore") as f:
    for line in f:
        # U-Boot md.b lines look like:
        # 21000000: 00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff  ................
        m = re.match(r"^[0-9a-fA-F]{8}:\s+((?:[0-9a-fA-F]{2}\s+){1,16})", line)
        if m:
            hex_bytes.extend(m.group(1).split())

data = bytes(int(b, 16) for b in hex_bytes)
with open(sys.argv[2], "wb") as out:
    out.write(data)

print(f"Wrote {len(data)} bytes to {sys.argv[2]}")
```

Usage:

```bash
python3 hex2bin.py flashdump.txt flashbak.bin
```

### Method B — `fatwrite` (if your U-Boot supports it)

Check:

```text
help fatwrite
```

If the command exists:

```text
fatwrite mmc 0:1 0x21000000 flashbak.bin 0x1000000
```

The file appears on the SD card.

### Method C — `mmc write` (advanced)

If you have a second SD card and your U-Boot supports `mmc write`, you can
write the RAM contents to raw sectors of the card:

```text
mmc write 0x21000000 0x0 0x8000
```

`0x8000` is 32768 sectors of 512 bytes = 16 MB.

Then read the card on your computer with `dd`:

```bash
sudo dd if=/dev/sdX of=flashbak.bin bs=512 count=32768
```

Replace `/dev/sdX` with the correct device. **Be careful:** choosing the
wrong device can destroy your computer's disk.

## Step 4 — Verify the backup

The file must be exactly:

```text
16,777,216 bytes
```

Check:

```bash
wc -c flashbak.bin
```

Expected:

```text
16777216 flashbak.bin
```

You can also check the partition strings:

```bash
strings -a flashbak.bin | grep -E "BOOT|KERNEL|ROOTFS|DATA|CONFIG|FACTORY"
```

Expected:

```text
BOOT
KERNEL
ROOTFS
DATA
CONFIG
FACTORY
```

If the size is wrong or the strings are missing, do not continue. Repeat
the backup.

## Step 5 — Store the backup safely

Keep at least two copies:

- One on your computer.
- One on an external drive or cloud storage.

Do not store it only on the SD card you use for flashing.
