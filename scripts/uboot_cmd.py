#!/usr/bin/env python3
"""Send one command to the camera's U-Boot prompt over a serial port.

Works on Linux, macOS and Windows (with Python installed).

Examples:
    # Raspberry Pi (GPIO UART)
    python3 uboot_cmd.py "sf probe 0"

    # USB-TTL adapter on Linux
    python3 uboot_cmd.py --port /dev/ttyUSB0 "sf probe 0"

    # USB-TTL adapter on macOS
    python3 uboot_cmd.py --port /dev/tty.usbserial-XXXX "sf probe 0"

    # Windows
    python3 uboot_cmd.py --port COM3 "sf probe 0"
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


def open_serial(port, baud):
    if os.name == "nt":
        import serial  # pyserial

        return serial.Serial(port, baud, timeout=0.05)

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


def flush_input(fd):
    while True:
        if os.name == "nt":
            fd.reset_input_buffer()
            return
        r, _, _ = select.select([fd], [], [], 0.05)
        if not r:
            return
        try:
            os.read(fd, 4096)
        except OSError:
            return


def write_all(fd, data):
    if os.name == "nt":
        fd.write(data)
        return
    os.write(fd, data)


def read_for(fd, seconds):
    out = bytearray()
    start = time.time()
    while time.time() - start < seconds:
        if os.name == "nt":
            chunk = fd.read(4096)
            if chunk:
                out.extend(chunk)
        else:
            r, _, _ = select.select([fd], [], [], 0.05)
            if r:
                try:
                    chunk = os.read(fd, 4096)
                except OSError:
                    chunk = b""
                if chunk:
                    out.extend(chunk)
    return bytes(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--port",
        default=DEFAULT_PORT.get(os.name, "/dev/serial0"),
        help="Serial device (default: /dev/serial0 on Linux/macOS, COM3 on Windows)",
    )
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--wait", type=float, default=3.0, help="Seconds to read after sending")
    parser.add_argument("command", help="Command to send to U-Boot")
    args = parser.parse_args()

    fd = open_serial(args.port, args.baud)
    try:
        flush_input(fd)
        # Send a newline first so U-Boot prints a fresh prompt.
        write_all(fd, b"\r")
        time.sleep(0.3)
        # Send the command slowly to avoid truncation on flaky adapters.
        for ch in args.command + "\r":
            write_all(fd, ch.encode())
            time.sleep(0.01)
        output = read_for(fd, args.wait)
        sys.stdout.write(output.decode("latin1", "ignore"))
        sys.stdout.flush()
    finally:
        if os.name != "nt":
            os.close(fd)
        else:
            fd.close()


if __name__ == "__main__":
    main()
