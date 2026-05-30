# MTD Flash Layout — TP-Link EX220 v1 (ramips/mt7621)

Notes from working out how the flash is partitioned, where that partitioning
comes from, and what (if anything) the OpenWrt wiki FixMe actually needs.

---

## 1. What MTD is

**MTD = Memory Technology Devices** — a Linux kernel subsystem that presents raw
flash (NOR/NAND) through a uniform interface. Raw flash isn't a block device: you
can't overwrite a byte in place, you must *erase a whole block* (here 64 KiB) before
rewriting it. MTD abstracts that so bootloaders and filesystems can use the chip.

- The **term and API** (`/proc/mtd`, `/dev/mtdN`, `/dev/mtdblockN`, `drivers/mtd/`)
  are Linux-specific. The *idea* of abstracting raw flash is universal
  (U-Boot, etc. have their own equivalents).
- MTD is **pure software**. It talks to the physical chip but adds no hardware.
  The "partitions" are software-defined offset/size maps over one physical chip —
  not hardware partitions, and (on this device) **not** an on-flash partition table.

## 2. Where THIS device's layout comes from

Authoritative source = the in-tree device tree:
[`target/linux/ramips/dts/mt7621_tplink_ex220-v1.dts`](https://git.openwrt.org/openwrt/openwrt/tree/target/linux/ramips/dts/mt7621_tplink_ex220-v1.dts)

Chain of custody:

```
ex220-v1.dts  --(compiled at build time)-->  .dtb
   .dtb is embedded inside the initramfs FIT image (...ex220-v1-initramfs-kernel.bin)
   U-Boot `bootm` hands that embedded .dtb to the kernel
   kernel's `ofpart` parser reads the fixed-partitions table from the .dtb
```

So the base partition map is **hardcoded in source (DTS), baked into the booted
image's DTB**. U-Boot's only role is mechanical (load FIT, pass the DTB along).
There is **no U-Boot-managed partition structure**, no `mtdparts=` on the cmdline,
no RedBoot/FIS table on flash. Boot a different DTB → `/proc/mtd` changes;
the chip itself carries no map.

### Static vs runtime-derived

`/proc/mtd` shows **13** partitions = 10 static + 3 derived at runtime by the kernel:

- **10 static** — the `fixed-partitions` table in the DTS (mtd0–mtd9).
- **mtd10 `kernel`, mtd11 `rootfs`** — the `firmware` partition is tagged
  `compatible = "denx,fit"`; the kernel's **fit-fw** splitter opens it and carves
  these out by parsing the *FIT* [1] header on flash.
- **mtd12 `rootfs_data`** — the **squashfs-split** parser finds the boundary where
  the read-only SquashFS ends and the writable JFFS2 overlay begins.

None of the 3 derived ones appear in the DTS, and none come from U-Boot.

[1] **FIT = Flattened Image Tree** — U-Boot's modern multi-component image format.
It's a single file that bundles a kernel, one or more DTBs, and optionally a ramdisk,
each as a named sub-image, plus integrity hashes (you saw crc32/sha1 verified in the log)
and one or more "configurations" that select which kernel+DTB+ramdisk combo to boot.

Key points:
- It's built from an `.its` source (a device-tree-syntax description)
  with `mkimage`, producing an `.itb` blob. "Flattened tree" because
  it reuses the same flattened-device-tree (libfdt) structure
  as a DTB — that's why it's literally a tree of nodes.
- It replaced the old **legacy uImage**, which could only wrap one component
  with a 64-byte header. FIT can carry many, with hashes and
  (optionally) cryptographic signatures for verified/secure boot.
- This is exactly why your single-address `bootm 0x80010000` worked: the one blob
  at that address contained kernel + DTB together, so U-Boot picked `config@1`
  and wired up the embedded DTB itself — no separate fdt address needed.

It shows up twice in your device:
1. Your `initramfs.bin` and the stock firmware image are both FITs
   (the "Loading kernel from FIT Image … Using 'config@1'" lines).
2. On flash, the `firmware` partition is a FIT container
   (`compatible = "denx,fit"` in the DTS — "denx" being DENX Software, U-Boot's maintainers),
   which is what lets the kernel's fit-fw splitter find the kernel and rootfs inside it.

## 3. Flash layout table

Chip: **Winbond W25Q128BV**, 16 MiB SPI-NOR, 64 KiB erase block.
Everything except `firmware` is marked **read-only** in the DTS (protects vendor data).

| mtd   | Label        | Offset      | Size       | Size (KiB) | RO  | Source     | Notes |
|-------|--------------|-------------|------------|-----------:|-----|------------|-------|
| mtd0  | boot         | 0x000000    | 0x030000   |        192 | yes | DTS        | U-Boot (SPL + U-Boot) |
| mtd1  | boot-env     | 0x030000    | 0x010000   |         64 | yes | DTS        | U-Boot environment |
| mtd2  | factory      | 0x040000    | 0x010000   |         64 | yes | DTS        | factory data |
| mtd3  | config       | 0x050000    | 0x010000   |         64 | yes | DTS        | vendor config |
| mtd4  | isp_config   | 0x060000    | 0x010000   |         64 | yes | DTS        | ISP (Ucom) config |
| mtd5  | rom_file     | 0x070000    | 0x010000   |         64 | yes | DTS        | **MAC base @ 0xf100** (see §4) |
| mtd6  | cloud        | 0x080000    | 0x010000   |         64 | yes | DTS        | vendor cloud data |
| mtd7  | radio        | 0x090000    | 0x020000   |        128 | yes | DTS        | **Wi-Fi EEPROM + precal** (see §4) |
| mtd8  | config_bak   | 0x0b0000    | 0x010000   |         64 | yes | DTS        | config backup |
| mtd9  | firmware     | 0x0c0000    | 0xf30000   |     15 552 | no  | DTS        | `denx,fit` container (holds mtd10+mtd11) |
| mtd10 | kernel       | 0x0c0000    | 0x3e0000   |      3 968 | no  | fit-fw     | runtime split of `firmware` |
| mtd11 | rootfs       | 0x4a0000    | 0xb50000   |     11 584 | no  | fit-fw     | SquashFS; kernel sets as root |
| mtd12 | rootfs_data  | 0xfb0000    | 0x040000   |        256 | no  | sqfs-split | JFFS2 overlay (writable) |

Notes:
- mtd10 + mtd11 are *inside* mtd9 (`firmware`), not additional space.
- `firmware` ends at 0xff0000; the **top 64 KiB (0xff0000–0x1000000) is unpartitioned**.

### Ready-to-paste DokuWiki-table

For [OpenWrt wiki](https://openwrt.org/toh/tp-link/ex220_v1#flash_layout)
```
^ Flash layout ^^^^^^
^ mtd ^ Name ^ Offset ^ Size ^ R/O ^ Description ^
| mtd0  | boot        | 0x000000 | 0x030000 | ro | U-Boot SPL + U-Boot   |
| mtd1  | boot-env    | 0x030000 | 0x010000 | ro | U-Boot environment    |
| mtd2  | factory     | 0x040000 | 0x010000 | ro | factory data          |
| mtd3  | config      | 0x050000 | 0x010000 | ro | vendor config         |
| mtd4  | isp_config  | 0x060000 | 0x010000 | ro | ISP config            |
| mtd5  | rom_file    | 0x070000 | 0x010000 | ro | MAC address base (0xf100) |
| mtd6  | cloud       | 0x080000 | 0x010000 | ro | vendor cloud data     |
| mtd7  | radio       | 0x090000 | 0x020000 | ro | Wi-Fi EEPROM + pre-calibration |
| mtd8  | config_bak  | 0x0b0000 | 0x010000 | ro | config backup         |
| mtd9  | firmware    | 0x0c0000 | 0xf30000 |    | kernel + rootfs (FIT) |
| mtd10 | kernel      | 0x0c0000 | 0x3e0000 |    | (auto-split from firmware) |
| mtd11 | rootfs      | 0x4a0000 | 0xb50000 |    | SquashFS root         |
| mtd12 | rootfs_data | 0xfb0000 | 0x040000 |    | JFFS2 overlay         |
```

## 4. MAC & Wi-Fi calibration provenance

From the DTS `nvmem` cells:

- **MAC addresses** live in `rom_file` at **offset 0xf100** (`macaddr_rom_file_f100`,
  a 6-byte `mac-base`). Derived assignments:
  - `gmac0` (LAN/label MAC) = base + 0
  - `gmac1` (WAN)           = base + 1
  - Wi-Fi band@0           = base + 0
  - Wi-Fi band@1           = base + 2
- **Wi-Fi calibration** lives in `radio`: `eeprom@0` (0x0, 0xe00) and
  `precal@e10` (0xe10, 0x19c10), fed to the `mediatek,mt76` driver.

Cross-check with the stock [boot log](screenlog.0]: it read
`0x0007f100 length 0x6` ( = `rom_file` base 0x70000 + 0xf100 ),
i.e. the exact same 6-byte MAC.

OpenWrt reads it cleanly via nvmem; U-Boot doesn't touch `rom_file`, which is
why U-Boot fell back to a random MAC (`da:6d:...`) during boot — harmless.

→ As long as `dumps/rom_file` is non-blank at 0xf100, the real MAC is intact.

## 5. Does the OpenWrt wiki actually need my MTD map?

**Short answer: the table is welcome, though the data is known.** The flash
layout is already fully and authoritatively specified in the in-tree DTS, so anyone
could derive it without a dump. What your `/proc/mtd` adds is *confirmation* that the
running layout matches the DTS byte-for-byte — useful, but not new information.

Practical takeaway for the wiki FixMe:
- The [layout table](#ready-to-paste-dokuwiki-table) can be pasted
  to fill the `#flash_layout` FixMe.
- Source it from the `mt7621_tplink_ex220-v1.dts` (find in
  [dts/](https://git.openwrt.org/openwrt/openwrt/tree/target/linux/ramips/dts)
  or [2]) and note that a live `/proc/mtd` confirms it.

[2] [mt7621_tplink_ex220-v1.dts](https://raw.githubusercontent.com/openwrt/openwrt/refs/heads/main/target/linux/ramips/dts/mt7621_tplink_ex220-v1.dts)

## 6. Note on the boot log in this repo (`screenlog.0`)

That capture is a **stock-firmware boot console log**
(TP-Link Aginet, kernel 4.4.198, booted from flash 0xc0000).
It's the pre-liberation state; useful for hardware/MAC confirmation.

---

### One-line summary
`/proc/mtd` = `mt7621_tplink_ex220-v1.dts` compiled into a DTB carried by the
TFTP'd FIT image; 10 partitions are static from that DTS, 3 are split out at
runtime by the kernel — U-Boot supplies none of it.

May 30, 2026 Written with [Claude Opus 4.8 High](https://claude.ai/share/69658076-24d7-4f60-9256-d0647c2919be)
