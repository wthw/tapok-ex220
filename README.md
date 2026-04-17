# TP-Link EX220 Liberation

Documenting the process of freeing a TP-Link EX220 Wi-Fi 6 router from ISP (Ucom) lock and flashing it with OpenWrt firmware.

## Background

Ucom provided this router in a locked state — management is exclusively through TP-Link's proprietary cloud platform. A factory reset attempt left the device in a broken state: the admin password appears stuck and neither I nor the ISP can manage it normally.

## Hardware

| Component | Details |
|-----------|---------|
| CPU | MediaTek MT7621AT (quad-core MIPS 1004Kc) |
| RAM | 128 MB DRAM |
| Flash | 16 MB SPI NOR — Winbond W25Q128BV (SOIC-8) |
| Wi-Fi | Dual-band Wi-Fi 6 — MT7915 (5 GHz) + MT7916 (2.4 GHz) |
| Bootloader | U-Boot 2018.09 |
| Architecture | ramips/mt7621 (same as Archer AX23 v1) |

## OpenWrt Support

**Supported.** Page: https://openwrt.org/toh/tp-link/ex220_v1 (marked "Under Construction" but functional)

- Install is **only possible via UART + TFTP** — factory image is signed, no web-UI upgrade path
- Recommended firmware version: **23.05.4** (reports of issues with 24.10.0)
- Images needed:
  - `openwrt-23.05.4-ramips-mt7621-tplink_ex220-v1-initramfs-kernel.bin`
  - `openwrt-23.05.4-ramips-mt7621-tplink_ex220-v1-squashfs-sysupgrade.bin`

## Approach

### Path A — Try default/known credentials first (no hardware needed)

The default web interface credentials for TP-Link ISP firmware are:
- **Username:** `root`
- **Password:** `aDm1n$TR8r`

A1 Bulgaria's variant had the serial console password `spbu100e`. Ucom's variant may differ.
Config partition is AES-128-CBC encrypted (key `1528632946736109`, IV `1528632946736539`) — but this
requires shell access to extract.

- [ ] Try `root` / `aDm1n$TR8r` on the web UI (192.168.0.1 or 192.168.1.1)
- [ ] Try Telnet / SSH with same credentials

### Path B — UART + U-Boot (main viable path)

This bypasses any password entirely. UART gives access to the bootloader, which lets you load
an OpenWrt initramfs image over TFTP without knowing any credentials.

**Hardware needed:** USB-to-UART adapter (CP2102 or similar, 3.3 V logic)

**UART settings:** 115200 baud, 8N1, 3.3 V — connect GND + RX + TX only, **do NOT connect VCC**

**Steps:**
- [ ] Open router case
- [ ] Locate UART header on PCB (pads labeled, may need to solder pins)
- [ ] Connect USB-UART adapter (GND→GND, PC-RX→router-TX, PC-TX→router-RX)
- [ ] Open serial terminal at 115200 8N1
- [ ] Power on router, press any key immediately to interrupt boot → select "0. U-Boot console"
- [ ] Set up TFTP server on PC at 192.168.0.2, place `initramfs.bin` in root
- [ ] Run in U-Boot:
  ```
  setenv ipaddr 192.168.0.1
  setenv serverip 192.168.0.2
  tftpboot 0x80010000 initramfs.bin
  bootm 0x80010000
  ```
- [ ] After boot, press Enter → OpenWrt shell (no password required)
- [ ] Backup all stock MTD partitions before flashing
- [ ] SCP sysupgrade image to `/tmp`, then: `sysupgrade -v /tmp/sysupgrade.bin`

### Path C — Hardware flash surgery (last resort)

Only needed if UART is inaccessible or U-Boot is locked.

- [ ] Desolder or clip W25Q128BV (SOIC-8) SPI NOR flash
- [ ] Read with CH341A programmer + `flashrom`
- [ ] Analyze with `binwalk`, locate config partition, wipe/patch password area
- [ ] Re-flash original (patched) or OpenWrt image

### Path D — TR-069 ACS redirect (requires existing web UI access)

Works for EX230v/VX230v/EX530v — may apply to EX220. Requires admin web UI access first.
In browser console: `$.loadMain("/cwmp.htm")` to expose hidden CWMP settings page,
then redirect ACS URL to a local GenieACS instance to change superadmin password.
**Not viable in our case** (web UI access already lost).

## Tools & Materials

| Tool | Purpose |
|------|---------|
| USB-to-UART adapter (CP2102, 3.3 V) | UART console / U-Boot access |
| `minicom` or `screen` | Serial terminal |
| `tftpd` / `tftp-hpa` | Serve initramfs image to U-Boot |
| CH341A programmer + SOIC-8 clip | Flash read/write (Path C only) |
| `flashrom` | SPI flash access |
| `binwalk` | Firmware analysis |
| Soldering iron + flux | UART header pins |

## References

- [OpenWrt EX220 v1 page](https://openwrt.org/toh/tp-link/ex220_v1)
- [xakcop.com — Reversing TP-Link EX220 (A1 Bulgaria)](https://xakcop.com/post/ex220/)
- [OpenWrt install guide for EX220 (Windows, gist)](https://gist.github.com/ro99/77579b1d22fcde9ca72e0180b17bbc9d)
- [EX230v/VX230v/EX530v jailbreak via TR-069/ACS](https://gist.github.com/ataniazov/b774f8b58deb6a02f07c7327ca67c651)
- [flashrom project](https://www.flashrom.org/)
- [binwalk](https://github.com/ReFirmLabs/binwalk)

## Log

| Date | Action | Result |
|------|--------|--------|
| 2026-04-17 | Project started, initial research | See `notes/research.md` |
| — | Factory reset attempted | Password stuck, device unmanageable |
