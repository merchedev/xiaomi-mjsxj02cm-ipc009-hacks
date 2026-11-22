# 06 — Enable autostart

This is the main fix in this fork. The original hack starts the services
manually, but on firmware 4.3.7_0417 they do not start at boot. Three
things go wrong.

## Root causes

### 1. `S49factory` creates `/tmp/factory_mode`

`/etc/init.d/S49factory` ends with:

```sh
touch /tmp/factory_mode
```

The stock `/etc/init.d/S60service` starts with:

```sh
start)
    [ -f /tmp/factory_mode ] && exit 1
    do_start
    ;;
```

So `S60service` always exits before starting anything.

### 2. `S49factory` unmounts `/mnt/sdcard`

`S49factory` mounts the SD card to check for factory files, then unmounts
it:

```sh
umount /mnt/sdcard
```

When `S60service` later looks for
`/mnt/sdcard/manu_test/configure_services.sh`, the SD card is no longer
mounted.

### 3. `/mnt/data` may not be mounted yet

The stock `S60service` does not call `mount -a`. If `/mnt/data` is not
mounted, `/mnt/data/scripts/post_init.sh` does not exist.

## The patch

The patched `S60service`:

- Removes the `/tmp/factory_mode` check.
- Runs `mount -a`.
- Mounts `/mnt/sdcard` again.
- Creates the `libshbf`/`libshbfev` symlinks.
- Starts `configure_services.sh` directly.

Full file: `patches/S60service.ipc009-4.3.7`.

Key part:

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

    CUSTOM_POST_INIT=/mnt/data/scripts/post_init.sh
    if [ -x ${CUSTOM_POST_INIT} ]; then
        ${CUSTOM_POST_INIT} &
    fi
}
```

## PTZ services at boot

The autostart patch calls `configure_services.sh` after mounting the SD card.
That script installs every service directory under `hacks/*/meta/service` that
contains a `.enable` file.

The optional PTZ add-on provides:

| Service directory | What it starts |
|-------------------|----------------|
| `onvif_srvd/meta/service` | `start_onvif.sh`, which starts `motord` and the ONVIF server on port 5000 |
| `webctl/meta/service` | `busybox httpd` for the web PTZ page on port 8081 |

The `start_onvif.sh` supervisor keeps the daemonized ONVIF server alive and
reads `/mnt/sdcard/hacks/ptz.conf` for the PTZ directions. The web PTZ CGI
reads the same file.

No rootfs change is needed for the PTZ services. They are installed from the
SD card on every boot. See [`09-onvif-ptz.md`](09-onvif-ptz.md).

## Rebuild the rootfs

```bash
./scripts/rebuild_rootfs.sh /path/to/rootfs_new.bin
```

This creates `rootfs_new_patched.bin` with the patch already applied.

Then flash it following `04-flash-rootfs.md`.

## Verify autostart

1. Insert the SD card with the hack files.
2. Reboot the camera.
3. Wait for it to connect to WiFi.
4. Check the ports:

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

5. Check the processes:

```sh
ps | grep -E "rtsp|web-config|websocket|framegrabber|motord|onvif_srvd|httpd"
```

If they are running without manual intervention, autostart works.

## If it still does not start

- Confirm the SD card contains `/manu_test/configure_services.sh`.
- Confirm the SD card is inserted at boot.
- Check the boot log for errors:

```sh
dmesg | grep -i sdcard
```

- Run the patched `S60service` manually to see the error:

```sh
/etc/init.d/S60service start
```

- Check that the patch is inside the running rootfs:

```sh
grep -n "factory_mode" /etc/init.d/S60service
```

If it prints a match, the old rootfs is still running. Re-flash the
patched image.
