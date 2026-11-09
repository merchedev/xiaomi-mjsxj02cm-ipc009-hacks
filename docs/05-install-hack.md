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

## What the files do

| Path | Purpose |
|------|---------|
| `manu_test/configure_services.sh` | Starts RTSP, web and WebSocket services |
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
0.0.0.0:80      web config
0.0.0.0:4558    WebSocket
0.0.0.0:8554    RTSP
```

6. Check the processes:

```sh
ps | grep -E "rtsp|web-config|websocket|framegrabber"
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
