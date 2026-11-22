# Patches

This directory contains both rootfs patches and SD-card script replacements.
Read the installation notes in the linked document before applying one.

## `start_onvif.sh.ipc009`

Replacement for `/mnt/sdcard/hacks/onvif_srvd/start_onvif.sh` (SD card, not
rootfs). It is the supervisor used by the optional ONVIF/PTZ add-on.

It fixes three practical problems:

1. `onvif_srvd` daemonizes. A normal runit service would see the parent exit
   and restart it in a loop. The supervisor keeps a wrapper loop alive.
2. The original community script does `killall -9 motord` on every start. If
   `motord` is blocked in the motor driver, the kill can hang and ONVIF never
   starts. The supervisor keeps `motord` independent and starts it only when
   it is missing.
3. `motord` needs `LD_LIBRARY_PATH=/mnt/data/lib` to find
   `libdevice_kit.so`.

It also reads `/mnt/sdcard/hacks/ptz.conf`:

```sh
INVERT_PAN=0
INVERT_TILT=0
```

Set both to `1` for a ceiling-mounted camera with the image flipped.

### How to apply

```sh
cp patches/start_onvif.sh.ipc009 \
   /Volumes/SDCARD/hacks/onvif_srvd/start_onvif.sh
chmod +x /Volumes/SDCARD/hacks/onvif_srvd/start_onvif.sh
```

Then restart the ONVIF service. See `docs/09-onvif-ptz.md` and
`docs/10-flip.md`.

## `ptz.cgi.ipc009`

Replacement for `/mnt/sdcard/hacks/webctl/www/cgi-bin/ptz.cgi` (SD card, not
rootfs).

It reads the same `/mnt/sdcard/hacks/ptz.conf` and swaps the left/right and
up/down commands when `INVERT_PAN` or `INVERT_TILT` is `1`. The web page reads
the file on every request, so no service restart is needed after changing the
directions.

### How to apply

```sh
cp patches/ptz.cgi.ipc009 \
   /Volumes/SDCARD/hacks/webctl/www/cgi-bin/ptz.cgi
chmod +x /Volumes/SDCARD/hacks/webctl/www/cgi-bin/ptz.cgi
```

See `docs/09-onvif-ptz.md` and `docs/10-flip.md`.

## `S60service.ipc009-4.3.7`

Replacement for `/etc/init.d/S60service` on the Xiaomi MJSXJ02CM / IPC009
with firmware 4.3.7_0417.

It fixes three problems that prevent the hack from starting automatically:

1. The stock `S60service` exits when `/tmp/factory_mode` exists, and
   `S49factory` always creates that file.
2. `S49factory` unmounts `/mnt/sdcard` when it finishes, so
   `/mnt/sdcard/manu_test/configure_services.sh` is not available.
3. `/mnt/data` is not guaranteed to be mounted when `S60service` runs.

The patch:

- Removes the `/tmp/factory_mode` exit.
- Runs `mount -a`.
- Mounts `/mnt/sdcard` again.
- Creates the `libshbf`/`libshbfev` symlinks.
- Starts `configure_services.sh` directly.

### How to apply

Use `scripts/rebuild_rootfs.sh`:

```bash
./scripts/rebuild_rootfs.sh /path/to/rootfs_new.bin
```

Or apply it manually after extracting the squashfs:

```bash
unsquashfs -f -d rootfs rootfs_new.bin
cp patches/S60service.ipc009-4.3.7 rootfs/etc/init.d/S60service
chmod +x rootfs/etc/init.d/S60service
mksquashfs rootfs rootfs_new_patched.bin -comp xz -noappend
```

### Compatibility

This patch is specific to the partition layout and init scripts of the
MJSXJ02CM / IPC009 firmware 4.3.7_0417. Do not use it on other models
without checking their `S49factory` and `S60service` first.
