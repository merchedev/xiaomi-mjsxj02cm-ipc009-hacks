# 03 — UART and U-Boot

## Open the camera

You need to open the camera to reach the UART pads. The exact disassembly
varies slightly between units, but the UART pads are in the same area on
the MJSXJ02CM board.

See `images/mjsxj02cm_uart.jpg` for the pad location.

> **Warning:** unplug the camera before opening it. Do not touch the board
> while it is powered.

## Solder the wires

Solder three wires to:

- **TX** (camera transmit)
- **RX** (camera receive)
- **GND**

Do not solder VCC.

A good solder joint is essential. A loose GND is the most common cause of
"no output on UART".

## Connect your adapter

### Raspberry Pi

```text
Pi GPIO14 (TX)  -> camera RX
Pi GPIO15 (RX)  -> camera TX
Pi GND          -> camera GND
```

Enable the UART:

```bash
sudo raspi-config
# Interface Options -> Serial Port
#   Login shell over serial: No
#   Serial hardware: Yes
sudo reboot
```

Check:

```bash
ls -l /dev/serial0
```

Add your user to `dialout` if needed:

```bash
sudo usermod -aG dialout "$USER"
```

Log out and back in.

### USB-TTL adapter

```text
Adapter TX   -> camera RX
Adapter RX   -> camera TX
Adapter GND  -> camera GND
Adapter VCC  -> not connected
```

Set the adapter to **3.3 V**.

Device names:

| OS | Device |
|----|--------|
| Linux | `/dev/ttyUSB0` or `/dev/ttyACM0` |
| macOS | `/dev/tty.usbserial-XXXX` |
| Windows | `COM3`, `COM4`, ... |

### Windows with PuTTY

```text
Session -> Serial
Serial line: COM3
Speed:       115200
Connection -> Serial
  Data bits: 8
  Stop bits: 1
  Parity:    None
  Flow control: None
```

## Serial settings

Always use:

```text
Baud rate:     115200
Data bits:     8
Parity:        None
Stop bits:     1
Flow control:  None
```

## Enter U-Boot

The camera's U-Boot does not show a visible autoboot countdown on firmware
4.3.7_0417. You still need to hold Enter while the camera powers on.

### Using the script

```bash
# Raspberry Pi
python3 scripts/uboot_interrupt.py

# Linux USB-TTL
python3 scripts/uboot_interrupt.py --port /dev/ttyUSB0

# macOS USB-TTL
python3 scripts/uboot_interrupt.py --port /dev/tty.usbserial-XXXX

# Windows
python scripts/uboot_interrupt.py --port COM3
```

Power the camera on while the script is running. The script sends Enter
every 50 ms and stops when it sees:

```text
MStar #
```

### Manually with PuTTY/Tera Term

1. Open the serial connection.
2. Hold Enter.
3. Power the camera on.
4. Keep holding Enter until the prompt appears.
5. Release Enter.

It can take several attempts. Do not give up after the first try.

## Send commands

Use `scripts/uboot_cmd.py`:

```bash
python3 scripts/uboot_cmd.py "sf probe 0"
```

Or type directly in your terminal.

The script sends the command one character at a time to avoid truncation on
flaky adapters.

## Useful U-Boot commands

```text
sf probe 0                                  Detect the SPI flash
sf read <addr> <offset> <len>               Read flash to RAM
sf erase <offset> <len>                     Erase flash
sf write <addr> <offset> <len>              Write RAM to flash
fatload mmc 0:1 <addr> <file>               Load a file from the SD card
reset                                       Reboot
```

There is no `boot` command on this U-Boot. To boot manually:

```text
sf read 0x21000000 0x50000 0x260000
bootm 0x21000000
```
