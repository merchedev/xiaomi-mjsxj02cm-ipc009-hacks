#!/usr/bin/env python3
"""Capture the camera's UART boot log to a file.

Run this before powering the camera on. It writes everything received on the
serial port to the log file until you press Ctrl-C.

Examples:
    python3 cam_capture.py
    python3 cam_capture.py --port /dev/ttyUSB0 --log boot.log
    python3 cam_capture.py --port /dev/tty.usbserial-XXXX
    python3 cam_capture.py --port COM3
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

        return serial.Serial(port, baud, timeout=0.2)

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
    parser.add_argument("--log", default="boot.log", help="Output log file")
    args = parser.parse_args()

    fd = open_serial(args.port, args.baud)
    print(f"Capturing {args.port} at {args.baud} baud to {args.log}")
    print("Power on the camera now. Press Ctrl-C to stop.")

    try:
        with open(args.log, "wb") as log:
            while True:
                if os.name == "nt":
                    chunk = fd.read(4096)
                    if chunk:
                        log.write(chunk)
                        log.flush()
                else:
                    r, _, _ = select.select([fd], [], [], 0.2)
                    if r:
                        try:
                            chunk = os.read(fd, 4096)
                        except OSError:
                            chunk = b""
                        if chunk:
                            log.write(chunk)
                            log.flush()
    except KeyboardInterrupt:
        pass
    finally:
        if os.name != "nt":
            os.close(fd)
        else:
            fd.close()
        print(f"\nLog saved to {args.log}")


if __name__ == "__main__":
    main()
