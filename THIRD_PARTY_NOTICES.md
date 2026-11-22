# Third-party notices and credits

This repository is a focused fork of
[`tsunglung/xiaomi-360-hacks`](https://github.com/tsunglung/xiaomi-360-hacks)
and is distributed under the GNU General Public License v3.0 (see `LICENSE`).

It also contains or references work from other projects. The original authors
retain their copyright and license rights. The links below are the upstream
sources; check each project for its exact license before redistributing.

---

## Base firmware and hack files

- **tsunglung/xiaomi-360-hacks** — base rootfs, `ipc009_hack.zip`,
  `rootfs_new.bin`, telnet and RTSP approach.
  <https://github.com/tsunglung/xiaomi-360-hacks>
- **crckmc/mija-framegrabber** — framegrabber lineage used by the RTSP stack.
  <https://github.com/crckmc/mija-framegrabber>
- **Live555** — RTSP/RTP library used by the RTSP server.
  <https://www.live555.com/live555/>
- **runit** — service supervision used by the SD-card hacks.
  <https://smarden.org/runit/>
- **Dropbear** — optional SSH server included in the base hack.
  <https://matt.ucc.asn.au/dropbear/dropbear.html>
- **BusyBox** — userland utilities used by the camera and the scripts.
  <https://busybox.net/>

The base hack files are distributed in the same spirit as the upstream
project. See the upstream repository and the files themselves for their
original notices.

---

## Optional PTZ / ONVIF add-on

The optional `mjsxj02cm/ipc009_ptz_hack.zip` contains binaries and scripts
from the community MJSXJ02CM guide published at:

- **it-board.ru — Xiaomi MJSXJ02CM ONVIF/RTSP guide**
  <https://it-board.ru/raznoe/361-vosstanovlenie-i-pereproshivka-xiaomi-mi-home-security-camera-360-1080p-mjsxj02cm-na-onvif-rtsp.html>
- The guide's `install.zip` is the source of `motor_control/motord`,
  `onvif_srvd`, and `webctl`.

The ONVIF server is based on the upstream **onvif_srvd** project:

- **onvif_srvd**
  <https://github.com/KoenVanDuffel/onvif_srvd>

The local miIO/PTZ context, the `miio_rpc` approach, and the `flip` setting
are described in:

- **666dsa666/mjsxj02cm-hacks**
  <https://github.com/666dsa666/mjsxj02cm-hacks>

The `flip` discovery in this fork (`fetch_av` + `mortoxd` + `mortoxc`) was
verified on the MJSXJ02CM / IPC009 firmware 4.3.7_0417. The upstream miIO
project and the camera's own binaries were used as reference.

---

## What this repository adds

The following files are original to this fork and are covered by the
repository's GPLv3 license:

- `docs/09-onvif-ptz.md`
- `docs/10-flip.md`
- `docs/11-ram-optimization.md`
- `docs/12-wifi.md`
- `patches/start_onvif.sh.ipc009`
- `patches/ptz.cgi.ipc009`
- `scripts/install_ptz_services.sh`
- `scripts/optimize_ram.sh`
- `scripts/verify_ptz.sh`
- The `ptz.conf` direction logic and the supervisor wrapper.

The third-party binaries in `ipc009_ptz_hack.zip` remain under their original
licenses. If you are the author of one of these components and want a change
to the attribution, open an issue.

---

## No personal data

This repository does not contain real:

- SSIDs or Wi-Fi passwords
- IP addresses, MAC addresses or hostnames
- miIO tokens or device serial numbers
- Xiaomi account identifiers
- Photos or recordings from the camera

All examples use placeholders such as `<CAMERA_IP>`, `<SSID>` and
`<PASSWORD>`.
