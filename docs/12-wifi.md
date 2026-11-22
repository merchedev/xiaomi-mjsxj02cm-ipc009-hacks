# 12 — Change Wi-Fi without opening the camera (optional)

The camera can be moved to another Wi-Fi network over telnet or the UART
console. You do not need to open the camera again, and you do not need the
Xiaomi cloud.

This guide covers two methods:

1. **Custom `wpa.conf` method** — the camera reads `/mnt/data/wpa.conf` at
   boot. The optional `webctl` Wi-Fi tab uses this method.
2. **Stock Xiaomi NVRAM method** — the original `wifi_start.sh` reads the
   credentials from the camera's NVRAM.

Choose the method that matches your current installation. Do not mix both.

> **The camera is 2.4 GHz only.** The MT7601 radio does not see 5 GHz networks.
> Use WPA2-PSK. A WPA3-only or 5 GHz-only network will not work.

---

## Check which method you have

```sh
cat /mnt/data/bin/wifi_start.sh
```

- If it contains `mortoxc` and `/tmp/wpa_supplicant.conf`, it is the **stock
  NVRAM method**.
- If it contains `-c /mnt/data/wpa.conf`, it is the **custom method**.
- If it contains `-c /tmp/wpa_supplicant.conf` and `mortoxc`, do **not** edit
  `/tmp/wpa_supplicant.conf`; it is regenerated at boot.

---

## Method 1 — Custom `/mnt/data/wpa.conf`

This is the method used by the optional `webctl` Wi-Fi tab.

### 1. Back up the current configuration

```sh
cp /tmp/wpa_supplicant.conf /mnt/data/wpa.conf.bak 2>/dev/null || true
cp /mnt/data/.config.nvram /mnt/sdcard/backups/config.nvram.bak 2>/dev/null || true
```

### 2. Write the new network

```sh
cat > /mnt/data/wpa.conf <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
update_config=1
network={
    ssid="<SSID>"
    psk="<PASSWORD>"
    key_mgmt=WPA-PSK
}
EOF
```

Replace `<SSID>` and `<PASSWORD>`. Keep the quotes. Avoid double quotes inside
the password.

### 3. Make sure `wifi_start.sh` reads that file

If your `wifi_start.sh` does not already contain `/mnt/data/wpa.conf`, replace
it:

```sh
cp /mnt/data/bin/wifi_start.sh /mnt/data/bin/wifi_start.sh.bak

cat > /mnt/data/bin/wifi_start.sh <<'EOF'
#!/bin/sh
sleep 5
killall wpa_supplicant udhcpc hostapd udhcpd 2>/dev/null
ifconfig wlan0 up
iwconfig wlan0 mode Managed
wpa_supplicant -Dnl80211 -iwlan0 -c /mnt/data/wpa.conf -B
sleep 5
udhcpc -i wlan0 -t 10 -T 2 -n -S -x hostname:mijia_camera_v4
EOF

chmod +x /mnt/data/bin/wifi_start.sh
```

### 4. Apply without rebooting

Run this in the background so the telnet session can drop:

```sh
cat > /mnt/data/switch_wifi.sh <<'EOF'
#!/bin/sh
sleep 1
killall wpa_supplicant udhcpc 2>/dev/null
ifconfig wlan0 down
sleep 1
ifconfig wlan0 up
iwconfig wlan0 mode Managed
wpa_supplicant -Dnl80211 -iwlan0 -c /mnt/data/wpa.conf -B
sleep 5
udhcpc -i wlan0 -t 10 -T 2 -n -S -x hostname:mijia_camera_v4
EOF

chmod +x /mnt/data/switch_wifi.sh
nohup /mnt/data/switch_wifi.sh >/tmp/switch_wifi.log 2>&1 &
```

The telnet connection drops when the interface restarts. Wait 20–30 seconds
and find the new IP in the router's DHCP table.

### 5. Verify

```sh
telnet <NEW_CAMERA_IP>
wpa_cli -i wlan0 status
```

Expected:

```text
ssid=<SSID>
wpa_state=COMPLETED
ip_address=<NEW_CAMERA_IP>
```

If there is no IP:

```sh
udhcpc -i wlan0 -t 10 -T 2 -n -S -x hostname:mijia_camera_v4
```

### 6. Roll back

If the new network does not work, connect over UART (or put the camera back
in range of the old network) and run:

```sh
cp /mnt/data/wpa.conf.bak /mnt/data/wpa.conf
cp /mnt/data/bin/wifi_start.sh.bak /mnt/data/bin/wifi_start.sh 2>/dev/null || true
reboot
```

If you replaced `wifi_start.sh`, restoring the backup returns the stock NVRAM
method.

---

## Method 2 — Stock Xiaomi NVRAM

Use this only if your `wifi_start.sh` uses `mortoxc` and
`/tmp/wpa_supplicant.conf`.

### 1. Back up the NVRAM

```sh
cp /mnt/data/.config.nvram /mnt/sdcard/backups/config.nvram.bak
```

### 2. Write the new network

```sh
mortoxc set nvram default miio_ssid "<SSID>"
mortoxc set nvram default miio_passwd "<PASSWORD>"
mortoxc set nvram default key_mgmt WPA
mortoxc set nvram default encry_flag 0
sync
```

The stock script re-encrypts the values on the next start.

For an open network:

```sh
mortoxc set nvram default key_mgmt NONE
mortoxc set nvram default miio_passwd ""
```

### 3. Restart Wi-Fi

```sh
/etc/init.d/S41wifi restart
```

or reboot.

### 4. Roll back

Restore the NVRAM backup:

```sh
cp /mnt/sdcard/backups/config.nvram.bak /mnt/data/.config.nvram
reboot
```

Do not edit `/tmp/wpa_supplicant.conf` directly. It is regenerated from the
NVRAM at boot.

---

## Fixed IP address

There are two ways to keep the camera at a stable address:

### DHCP reservation (recommended)

Reserve the camera's MAC address in the router or AP that runs the DHCP
server. The camera keeps using DHCP, and the router always gives it the same
address.

You need the camera's Wi-Fi MAC address. Read it on the camera:

```sh
ifconfig wlan0
```

The `HWaddr`/`ether` line is the MAC address. Do not publish it in the
repository.

### Static IP in `wifi_start.sh`

For the custom method, replace the `udhcpc` line with:

```sh
ifconfig wlan0 <CAMERA_IP> netmask 255.255.255.0
route add default gw <GATEWAY_IP>
echo "nameserver <DNS_IP>" > /etc/resolv.conf
```

Choose an address outside the DHCP pool. A DHCP reservation is safer because
it avoids conflicts.

---

## The `webctl` Wi-Fi tab

The optional web PTZ page at `http://<CAMERA_IP>:8081/` includes a Wi-Fi tab.
It writes `/mnt/data/wpa.conf`.

The tab only works if:

1. `wifi_start.sh` reads `/mnt/data/wpa.conf` (Method 1).
2. The `webctl` service is running.

If the camera uses the stock NVRAM method, the Wi-Fi tab does not control the
real boot network. Use Method 2 instead, or switch to Method 1.

---

## Troubleshooting

### The camera does not appear on the new network

- Confirm the network is **2.4 GHz**, not 5 GHz.
- Confirm the security is **WPA2-PSK**, not WPA3-only.
- Confirm the SSID is visible; a hidden SSID may need `scan_ssid=1`.
- Check the password; avoid double quotes inside it.
- Check the router's DHCP table.
- If the new network fails, reboot the camera. If `wifi_start.sh` was not
  replaced, the stock NVRAM method reconnects to the old network.

### The camera connects but has no IP

```sh
udhcpc -i wlan0 -t 10 -T 2 -n -S -x hostname:mijia_camera_v4
```

If it still fails, check the DHCP server and the subnet.

### `wpa_cli status` shows `SCANNING` or `DISCONNECTED`

```sh
iwconfig wlan0
wpa_cli -i wlan0 scan_results
```

Confirm the AP is visible and the password is correct.

### The router isolates clients

If the camera has an IP but other devices cannot reach it, disable AP
isolation / client isolation on the router, or put the camera and the NVR on
the same network segment.

---

## Security

- Use WPA2-PSK with a strong password.
- Do not expose the camera's telnet, RTSP, ONVIF or web PTZ ports to the
  internet.
- The camera's services have no authentication by default; keep them on a
  trusted LAN or a separate VLAN.

---

## No personal data

This guide uses placeholders:

- `<CAMERA_IP>`
- `<NEW_CAMERA_IP>`
- `<GATEWAY_IP>`
- `<DNS_IP>`
- `<SSID>`
- `<PASSWORD>`

Do not commit real SSIDs, passwords, IP addresses, MAC addresses, tokens or
serial numbers.
