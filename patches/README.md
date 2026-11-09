# Patches

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
