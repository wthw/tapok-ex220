# TP-Link EX220 Liberation

Freeing a TP-Link EX220 Wi-Fi 6 router
from ISP lock by flashing it with OpenWrt firmware.

## Background

Ucom provided this router in a locked state - management is exclusively through Aginet - a proprietary cloud platform.
A factory reset attempt left the device in a broken state: the admin password appears stuck
and neither I nor the ISP (I supposed) can manage it normally.

## Hardware

| Component | Details |
|-----------|---------|
| CPU   | MediaTek MT7621AT (quad-core MIPS 1004Kc) |
| RAM   | 128 MB DRAM |
| Flash | 16 MB SPI NOR — Winbond W25Q128BV (SOIC-8) |
| Wi-Fi | Dual-band Wi-Fi 6 — MT7915 (5 GHz) + MT7916 (2.4 GHz) |
| Bootloader   | U-Boot 2018.09 |
| Architecture | ramips/mt7621 (same as Archer AX23 v1) |

## OpenWrt Support

**Supported.** Page: https://openwrt.org/toh/tp-link/ex220_v1 (marked "Under Construction")

- Install is **only possible via UART + TFTP** — factory image is signed, no web-UI upgrade path
- Known good version: `23.05.4` (issues with `24.10.0`), testing r34469-862a4edfa6 (ca. 2026-05-17),
  latest stable of 2026-07-05 is [25.12.5 built 2026-06-30](https://downloads.openwrt.org/releases/25.12.5/targets/ramips/mt7621/)
- Files (downloads.openwrt.org/snapshots/targets/ramips/mt7621/ - `cd bin/ && ./checkfile.sh`):
  - `openwrt-ramips-mt7621-tplink_ex220-v1-initramfs-kernel.bin`
  - `openwrt-ramips-mt7621-tplink_ex220-v1-squashfs-sysupgrade.bin`
  - `https://downloads.openwrt.org/snapshots/targets/ramips/mt7621/sha256sums` - grep / save

## Approach: UART and U-Boot

Bypass any password entirely. Load OpenWrt initramfs image over TFTP in U-Boot console.

**Hardware needed:** USB-to-UART adapter (CP2102 or similar, 3.3 V logic)

**UART settings:** 115200 baud, 8N1, 3.3 V — connect GND + RX + TX only, **do NOT connect VCC**

**Steps:**
- [ ] Open router case
- [ ] Locate UART header on PCB (pads labeled, may need to solder pins)
- [ ] Connect USB-UART adapter (GND→GND, PC-RX→router-TX, PC-TX→router-RX)
- [ ] Open serial terminal at 115200 8N1
- [ ] Power on router, press any key immediately to interrupt boot → select "0. U-Boot console"
- [ ] Set up TFTP server on PC at 192.168.1.2, place `initramfs.bin` in root
- [ ] Run in U-Boot:
  ```
  setenv ipaddr 192.168.1.1
  setenv serverip 192.168.1.2
  tftpboot 0x80010000 initramfs.bin
  bootm 0x80010000
  ```
- [ ] After boot, press Enter → OpenWrt 'root' shell (no password)
- [ ] Backup all stock MTD partitions before flashing
- [ ] SCP sysupgrade image to `/tmp`, then: `sysupgrade -v /tmp/sysupgrade.bin`

## Tools & Materials

| Tool | Purpose |
|------|---------|
| USB-to-UART adapter (CP2102, 3.3 V) | UART console / U-Boot access    |
| `minicom` or `screen`               | Serial terminal                 |
| `tftpd` / `tftp-hpa`                | Serve initramfs image to U-Boot |

## References

- [OpenWrt EX220 v1 page](https://openwrt.org/toh/tp-link/ex220_v1)
- [xakcop.com — Reversing TP-Link EX220 (A1 Bulgaria)](https://xakcop.com/post/ex220/)
- [OpenWrt install guide for EX220 (Windows, gist)](https://gist.github.com/ro99/77579b1d22fcde9ca72e0180b17bbc9d)

## Post-install: upgrade, LuCI

Package manager: [`apk` (25.12+)](https://openwrt.org/docs/guide-user/additional-software/apk)
```
apk update && apk upgrade
apk add luci
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start
```
WebUI: `https://192.168.1.1/`

## Log

| Date | Action | Result |
|------|--------|--------|
| — | Factory reset attempt | Password stuck, device unmanageable |
| 2026-04-17 | Project started, initial research    | See `notes/research.md` |
| 2026-05-10 | [angled 1x4 pin UART header installed](notes/UART-OpenWrt-flash.md#gallery) | Jumper wires connected, VCC and GND pin verified |
| 2026-05-17 | CH341 UART connected, U-Boot console reached | Boot menu confirmed, selected option 0 |
| 2026-05-17 | Load *initramfs* via TFTP                    | OpenWrt shell (BusyBox v1.37.0)        |
| 2026-05-17 | Back ip all 13 MTD partitions via netcat     | [`dumps/`](dumps/) — full 16 MiB flash |
| 2026-05-17 | Flash *sysupgrade* image                     | OpenWrt installed                      |
| 2026-05-30 | Clarify flash layout and MTD terms etc.      | [MTD-layout](notes/MTD-layout.md)      |
| 2026-07-05 | `apk update/upgrade/add luci`- see *Post-install* | EX-220 put on home LAN            |
