# 05 — Install the hack apps

## Get the hack files

The hack applications are in `ipc009_hack.zip` from the original
repository:

```text
https://github.com/tsunglung/xiaomi-360-hacks/tree/master/mjsxj02cm
```

## Copy them to the SD card

Unzip the file to the **root** of the SD card. The result must be:

```text
SDCARD/
  manu_test/
    configure_services.sh
    ...
  hacks/
  scripts/
```

The exact folder names matter. The autostart patch expects:

```text
/mnt/sdcard/manu_test/configure_services.sh
```

## Optional PTZ and ONVIF add-on

If you want pan/tilt control from Frigate, Home Assistant or an ONVIF client,
unzip `ipc009_ptz_hack.zip` to the **root** of the same SD card as well. Merge
the folders; do not replace the base hack.

It adds:

```text
hacks/motor_control/
hacks/onvif_srvd/
hacks/webctl/
hacks/ptz.conf
scripts/install_ptz_services.sh
scripts/optimize_ram.sh
```

The PTZ add-on does not modify the rootfs. It is optional and can be removed
later. See [`09-onvif-ptz.md`](09-onvif-ptz.md) for the full installation,
Frigate/Home Assistant configuration and troubleshooting.

On a 64 MB camera, read [`11-ram-optimization.md`](11-ram-optimization.md)
before enabling ONVIF together with the stock cloud services.

## What the files do

| Path | Purpose |
|------|---------|
| `manu_test/configure_services.sh` | Starts RTSP, web, WebSocket and any optional PTZ services |
| `hacks/` | Supporting binaries and configs |
| `scripts/` | Helper scripts from the original hack |

## Test manually

Before enabling autostart, test the services manually.

1. Insert the SD card into the camera and boot it.
2. Log in over telnet or UART as `root`.
3. Run:

```sh
/mnt/sdcard/manu_test/configure_services.sh &
```

4. Wait a few seconds.
5. Check the ports:

```sh
netstat -tln
```

Expected:

```text
0.0.0.0:80      web config (optional; may be disabled for RAM)
0.0.0.0:4558    WebSocket (optional; may be disabled for RAM)
0.0.0.0:5000    ONVIF PTZ (only if the PTZ add-on is installed)
0.0.0.0:8081    web PTZ (only if the PTZ add-on is installed)
0.0.0.0:8554    RTSP
```

6. Check the processes:

```sh
ps | grep -E "rtsp|web-config|websocket|framegrabber|motord|onvif_srvd|httpd"
```

If the services are running, continue with `06-autostart.md`.

## If `framegrabber` fails

The stock DATA partition ships `libshbf.so.0.2` and
`libshbfev.so.0.2`, but `framegrabber` expects version `0.1`.

Create the symlinks:

```sh
ln -sf libshbf.so.0.2 /mnt/data/lib/libshbf.so.0.1
ln -sf libshbfev.so.0.2 /mnt/data/lib/libshbfev.so.0.1
```

The autostart patch does this automatically at boot.
