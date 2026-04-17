# CLAUDE.md — TP-Link EX220 Liberation Project

## Project purpose

This is a personal hardware-hacking and documentation project. The goal is to:
1. Recover admin access to a TP-Link EX220 router locked by ISP (Ucom)
2. Flash OpenWrt on it
3. Document every finding for future reference and community benefit

The working directory holds notes, scripts, firmware dumps, and analysis artifacts.

## How to help

- Help research firmware structure, exploit techniques, OpenWrt compatibility, and flash chip details
- Help write shell scripts or Python for firmware analysis (`binwalk`, `dd`, `hexdump`, `flashrom` wrappers)
- Help interpret UART output, U-Boot logs, and kernel boot messages
- Suggest the least-invasive viable path first (software > UART/bootloader > hardware desoldering)
- Keep `README.md` log table up to date when new steps are completed

## What NOT to do

- Do not suggest approaches that could permanently brick the device without warning
- Do not skip safety notes when recommending voltage levels (UART is 3.3 V, not 5 V)
- Do not generate speculative firmware patches without grounding them in actual dump analysis

## File conventions

- `dumps/` — raw flash reads (binary), named `<date>_<attempt>.bin`
- `notes/` — freeform research notes per topic (markdown)
- `scripts/` — helper scripts for analysis or flashing
- `images/` — photos of PCB, chip markings, UART pinouts

## Current state (as of 2026-04-17)

- Router is post-factory-reset with stuck admin password
- Cloud management appears broken too
- No disassembly performed yet
- No UART access attempted yet
- OpenWrt wiki page for EX220 exists — support status to be confirmed
