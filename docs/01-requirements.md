# 01 — Requirements

## Camera

| Item | Value |
|------|-------|
| Model name | MJSXJ02CM |
| Internal model | IPC009 |
| Tested firmware | 4.3.7_0417 |
| Flash | 16 MB SPI NOR |

Other firmware versions may work, but they have not been tested. If your
firmware is different, make a backup first and compare the partition layout
with the one described in `04-flash-rootfs.md`.

## Hardware

- Camera and its original power supply.
- MicroSD card, 8 GB or more, formatted as **FAT32**, single partition.
- A **3.3 V UART connection**:
  - Raspberry Pi (any model with UART), or
  - USB-TTL adapter (FT232RL, CP2102, CH340, PL2303), or
  - another 3.3 V board.
- Three dupont wires or soldered wires.
- Soldering iron, flux, and a small Phillips screwdriver.
- A computer with Python 3 and git.

## Software

On Linux/macOS:

```bash
python3 --version
git --version
```

On Windows:

- Python 3 from <https://www.python.org/>
- Git for Windows from <https://git-scm.com/>
- PuTTY or Tera Term (optional, if you prefer a GUI terminal)
- The driver for your USB-TTL chip

If you want to rebuild the rootfs:

```bash
# Debian/Ubuntu/Raspberry Pi OS
sudo apt install squashfs-tools

# macOS
brew install squashfs
```

## Voltage warning

The camera UART is **3.3 V**. A 5 V signal on TX can damage the camera.

- If your adapter has a voltage jumper, set it to **3.3 V**.
- If your adapter is 5 V only, use a level shifter.
- Never connect VCC to the camera.

## Before you start

1. Make sure you have a valid 16 MB backup. See `02-backup.md`.
2. Read all the steps once before touching the hardware.
3. Do not skip the backup.
