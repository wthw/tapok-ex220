# Research Notes — 2026-04-17

## OpenWrt Support

- **Page:** https://openwrt.org/toh/tp-link/ex220_v1 (exists, marked "Under Construction")
- **Status:** Working. Multiple users confirmed successful installs.
- **Architecture:** `ramips/mt7621` — nearly identical to Archer AX23 v1
- **Signed firmware:** Factory image must be signed → no web-UI sysupgrade from stock.
  Only path in is UART + U-Boot + TFTP.
- **Recommended version:** 23.05.4 (24.10.0 has reported issues)

## Hardware Details

- **CPU:** MediaTek MT7621AT — quad-core MIPS 1004Kc
- **RAM:** 128 MB DRAM
- **Flash:** 16 MB SPI NOR — **Winbond W25Q128BV**, SOIC-8 package
  - 13 MTD partitions: u-boot, config (encrypted), kernel, rootfs (squashfs), firmware, etc.
  - Config partition: AES-128-CBC, key `1528632946736109`, IV `1528632946736539`
    (found in A1 Bulgaria variant — Ucom variant may use different key)
- **Wi-Fi:** MT7915 (5 GHz) + MT7916 (2.4 GHz)
- **Bootloader:** U-Boot 2018.09 (Dec 27 2022 build)

## UART

- **Settings:** 115200 baud, 8N1, **3.3 V logic**
- **Header:** Pads on PCB, likely need to solder pins
- **Connection:** GND + TX + RX — **do NOT connect VCC from adapter to router**
- **Bootloader IP:** 192.168.0.1 (TFTP server should be at 192.168.0.2)
- Boot interrupt: press any key immediately at power-on → "0. U-Boot console"

## Known Credentials (ISP variants)

| Source | Username | Password | Context |
|--------|----------|----------|---------|
| A1 Bulgaria research | `root` | `aDm1n$TR8r` | Web UI default |
| A1 Bulgaria research | (root user) | `spbu100e` | Serial console (cracked from hash) |

These are ISP-specific. Ucom's variant may have different passwords set via TR-069.
Worth trying `aDm1n$TR8r` on the web UI before opening the case.

## Firmware Structure (A1 Bulgaria variant, likely similar)

```
/lib/libcmm.so  — contains dm_dumpCfg() for config extraction
/lib/libc.so    — uClibc v1.0.14
```

Config dump technique (requires shell): load `libcmm.so` dynamically, call `dm_dumpCfg()`.

## WPS PIN Vulnerability

Default Wi-Fi password == default WPS PIN. WPS PIN generation uses `srand()` seeded with
system timestamp — predictable if you know or can guess the boot time.

## TR-069 / ACS Redirect Method (EX230v/VX230v/EX530v — may apply to EX220)

1. Open browser dev console on router web UI
2. Run: `$.loadMain("/cwmp.htm")` — reveals hidden CWMP config page
3. Change ACS URL to point at local GenieACS server
4. Use GenieACS to set new superadmin password via TR-069 parameter push
5. **Limitation:** Requires existing web UI access — not useful in our bricked state

## Install Procedure Summary (UART path)

1. Solder header pins to UART pads
2. Connect CP2102 adapter: GND→GND, PC-RX→router-TX, PC-TX→router-RX
3. Open terminal at 115200 8N1
4. Set PC eth to 192.168.0.2/24
5. Start TFTP server, place `initramfs.bin` in root
6. Power on router, press key to interrupt → select U-Boot console
7. U-Boot commands:
   ```
   setenv ipaddr 192.168.0.1
   setenv serverip 192.168.0.2
   tftpboot 0x80010000 initramfs.bin
   bootm 0x80010000
   ```
8. System boots OpenWrt initramfs → press Enter for shell
9. Backup MTD partitions to PC via SCP/SSH
10. SCP sysupgrade image to `/tmp`
11. `sysupgrade -v /tmp/sysupgrade.bin` (or via LuCI at 192.168.1.1)

## Sources

- https://xakcop.com/post/ex220/ — full reverse engineering of A1 Bulgaria EX220
- https://openwrt.org/toh/tp-link/ex220_v1 — OpenWrt device page
- https://gist.github.com/ro99/77579b1d22fcde9ca72e0180b17bbc9d — Windows install guide
- https://gist.github.com/ataniazov/b774f8b58deb6a02f07c7327ca67c651 — TR-069/ACS jailbreak (EX230v etc.)
