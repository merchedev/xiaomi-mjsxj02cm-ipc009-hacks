#!/usr/bin/env python3
"""Hold Enter on the camera's UART to stop U-Boot's autoboot.

Power the camera on *while this script is running*. It sends CR every 50 ms
and stops as soon as it sees the U-Boot prompt (`MStar #`, `SigmaStar #` or
`GM #`).

Examples:
    python3 uboot_interrupt.py
    python3 uboot_interrupt.py --port /dev/ttyUSB0
    python3 uboot_interrupt.py --port /dev/tty.usbserial-XXXX
    python3 uboot_interrupt.py --port COM3
"""

import argparse
import os
import select
import sys
import time

try:
    import termios
except ImportError:  # Windows
    termios = None

DEFAULT_PORT = {
    "posix": "/dev/serial0",
    "nt": "COM3",
}

PROMPTS = (b"MStar #", b"SigmaStar #", b"GM #")


def open_serial(port, baud):
    if os.name == "nt":
        import serial  # pyserial

        return serial.Serial(port, baud, timeout=0.02)

    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    iflag, oflag, cflag, lflag, ispeed, ospeed, cc = attrs

    iflag &= ~(
        termios.IGNBRK
        | termios.BRKINT
        | termios.PARMRK
        | termios.ISTRIP
        | termios.INLCR
        | termios.IGNCR
        | termios.ICRNL
        | termios.IXON
        | termios.IXOFF
        | termios.IXANY
    )
    oflag &= ~termios.OPOST
    lflag &= ~(
        termios.ECHO
        | termios.ECHONL
        | termios.ICANON
        | termios.ISIG
        | termios.IEXTEN
    )
    cflag &= ~(termios.CSIZE | termios.PARENB | termios.CSTOPB)
    cflag |= termios.CS8 | termios.CREAD | termios.CLOCAL
    cc[termios.VMIN] = 0
    cc[termios.VTIME] = 0

    speed = getattr(termios, f"B{baud}")
    termios.tcsetattr(
        fd, termios.TCSANOW, [iflag, oflag, cflag, lflag, speed, speed, cc]
    )
    return fd


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--port",
        default=DEFAULT_PORT.get(os.name, "/dev/serial0"),
        help="Serial device (default: /dev/serial0 on Linux/macOS, COM3 on Windows)",
    )
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument(
        "--timeout",
        type=float,
        default=180.0,
        help="How long to keep trying (seconds)",
    )
    args = parser.parse_args()

    fd = open_serial(args.port, args.baud)
    out = bytearray()
    start = time.time()
    last_send = 0.0
    found = False

    try:
        while time.time() - start < args.timeout:
            if os.name == "nt":
                chunk = fd.read(4096)
                if chunk:
                    out.extend(chunk)
                    sys.stdout.write(chunk.decode("latin1", "ignore"))
                    sys.stdout.flush()
            else:
                r, _, _ = select.select([fd], [], [], 0.02)
                if r:
                    try:
                        chunk = os.read(fd, 4096)
                    except OSError:
                        chunk = b""
                    if chunk:
                        out.extend(chunk)
                        sys.stdout.write(chunk.decode("latin1", "ignore"))
                        sys.stdout.flush()

            if any(p in out for p in PROMPTS):
                found = True
                break

            if time.time() - last_send > 0.05:
                if os.name == "nt":
                    fd.write(b"\r")
                else:
                    os.write(fd, b"\r")
                last_send = time.time()
    finally:
        if os.name != "nt":
            os.close(fd)
        else:
            fd.close()

    if found:
        print("\n\nU-Boot prompt detected. You can now run uboot_cmd.py.")
    else:
        print("\n\nTimed out without seeing a U-Boot prompt.")
        sys.exit(1)


if __name__ == "__main__":
    main()
