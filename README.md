# TP-Link EX220 Liberation

Documenting the process of freeing a TP-Link EX220 Wi-Fi 6 router from ISP (Ucom) lock and flashing it with OpenWrt firmware.

## Background

Ucom provided this router in a locked state — management is exclusively through TP-Link's proprietary cloud platform. A factory reset attempt left the device in a broken state: the admin password appears stuck and neither I nor the ISP can manage it normally.

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

**Supported.** Page: https://openwrt.org/toh/tp-link/ex220_v1 (marked "Under Construction" but functional)

- Install is **only possible via UART + TFTP** — factory image is signed, no web-UI upgrade path
- Recommended firmware version: **23.05.4** (reports of issues with 24.10.0)
- Images needed:
  - `openwrt-23.05.4-ramips-mt7621-tplink_ex220-v1-initramfs-kernel.bin`
  - `openwrt-23.05.4-ramips-mt7621-tplink_ex220-v1-squashfs-sysupgrade.bin`

## Approach: UART and U-Boot

Bypass any password entirely. Load OpenWrt initramfs image over TFTP
in U-Boot console.

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

## Log

| Date | Action | Result |
|------|--------|--------|
| — | Factory reset attempted | Password stuck, device unmanageable |
| 2026-04-17 | Project started, initial research    | See `notes/research.md` |
| 2026-05-10 | angled 1x4 pin UART header installed | Jumper wires connected, VCC and GND pin verified |
| 2026-05-17 | CH341 UART connected, U-Boot console reached | Boot menu confirmed, selected option 0 |
| 2026-05-17 | Initramfs loaded via TFTP (snapshot r34469)  | OpenWrt shell — note: router IP is **192.168.1.1**, not 192.168.0.1 |
| 2026-05-17 | All 13 MTD partitions backed up via netcat   | Saved to `dumps/` — full 16 MiB flash covered |
| 2026-05-17 | Sysupgrade image flashed | OpenWrt installed |
