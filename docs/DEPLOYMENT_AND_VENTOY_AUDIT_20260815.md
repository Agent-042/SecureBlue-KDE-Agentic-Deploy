# SecureBlue, Ventoy Multi-Drive Deployment, Hardware Enablement & Security Guide

**Date:** August 15, 2026  
**Target Hardware:** ASUS ROG Zephyrus G16 (Intel Arrow Lake-P Arc 140T + NVIDIA RTX 5080 Mobile Blackwell GB203M)  
**Host Distro:** SecureBlue KDE (Kinoite / Fedora Silverblue atomic Composefs)

---

## 1. Multi-Drive Ventoy Standardized Payload (All 4 USB Keys Synced)

All 4 attached USB drives (`/dev/sda1`, `/dev/sdb1`, `/dev/sdc1`, `/dev/sdd1` — 28.9 GB each) feature identical, optimized ISO configurations:

### ISO Manifest (`/ISOs/`):
| File | Size | Role & Architectural Details |
| :--- | :--- | :--- |
| `Win11_24H2_Enterprise_LTSC_x64_en-us.iso` | **4.8 GB** | Official Microsoft Windows 11 Enterprise LTSC 24H2 (Cleanest baseline, no consumer bloat, HWID/KMS ready) |
| `nixos-plasma6-24.11-x86_64-linux.iso` | **3.2 GB** | NixOS 24.11 with KDE Plasma 6 (Full declarative live environment, instant RAM package deployment via `nix-shell`) |
| `secureblue-kinoite-main-hardened.iso` | **4.9 GB** | SecureBlue KDE Plasma hardened immutable atomic OS |
| `secureblue-silverblue-main-hardened.iso` | **4.4 GB** | SecureBlue GNOME hardened immutable atomic OS |
| `Qubes-R4.3.1-x86_64.iso` | **7.9 GB** | Qubes OS R4.3.1 Xen-based security compartmentalization |
| **Free Storage** | **~4.0 GB** | Persistent user storage, custom driver injects, and file transfers |

---

## 2. Desktop Environment Security & Usability: XFCE vs KDE Plasma 6 vs GNOME

### Why XFCE is NOT recommended for the ASUS ROG G16:
1. **Lack of Mature Wayland Support**: XFCE remains fundamentally tied to X11 (with experimental Wayland work in progress). Under X11, display isolation between applications does not exist (any window can log keystrokes/screen contents from another window).
2. **Display Scaling & Mixed DPI Issues**: The ASUS ROG Zephyrus G16 features a high-DPI OLED display (2.5K / 240Hz). XFCE's X11 rendering lacks smooth fractional scaling and per-monitor dynamic refresh rate (VRR), causing blurry text and severe screen tearing.
3. **Plasma 6 Superiority**: Plasma 6 on Wayland provides per-window memory isolation, modern Wayland security protocols, native fractional scaling (125%/150%), HDR, and dynamic GPU power management between Intel Arc and NVIDIA dGPU.

---

## 3. Making Qubes OS More Installable on Modern G16 Hardware

### Current Hardware Challenges on ASUS G16:
- Intel Core Ultra / Arrow Lake-P hybrid CPU architecture + Xen hypervisor ACPI power management.
- NVIDIA RTX 5080 Mobile (Blackwell) display handoff.
- SecureBoot MOK verification.

### Optimizations Applied to Ventoy for Qubes:
1. **Dedicated Loopback Entry (`ventoy_grub.cfg`)**:
   - Chainloads Xen directly via `multiboot2 (loop)/images/pxeboot/xen.gz` with kernel options `inst.stage2=hd:LABEL=Ventoy iso-scan/filename=$isofile`.
2. **Kernel Parameters for Modern Laptop Compatibility**:
   - `x2apic=true`: Enables extended APIC mode for Xen on modern Intel hybrid CPUs.
   - `iommu=no-igfx` (or `qubes.skip_autostart`): Prevents early kernel panics during installer GUI initialization when probing secondary discrete GPUs.
   - Stripped `quiet` and `rhgb` across all boots to ensure verbose hardware initialization diagnostics.
3. **SecureBoot Support**: The Ventoy MOK certificate is enrolled in NVRAM (`Key 3`), allowing the bootloader to load Xen without disabling system SecureBoot.

---

## 4. Ventoy Boot Modes: Normal vs GRUB Mode

### The Technical Distinction:
* **Normal Mode (Default)**:
  - Ventoy hooks into BIOS/UEFI runtime services directly (using disk emulation via `int 13h` or UEFI block I/O protocols).
  * **Pros**: Fastest, preserves native installer boot menus.
  * **When it fails**: Some hardened or complex multi-stage kernels (like Xen in Qubes or specialized Linux initrds) fail to locate the virtual CD-ROM driver after transitioning to protected/long mode.
* **GRUB Mode**:
  - Ventoy passes direct control to the embedded GRUB2 interpreter to parse the ISO's internal `grub.cfg` file using native GRUB loopback modules.
  * **Pros**: Superior compatibility for multi-kernel and hypervisor images (like Qubes, NixOS, and Debian).
  * **Verdict**: GRUB mode is fully justified whenever Normal Mode encounters an "ISO-scan failed" or "dracut timeout" error.

---

## 5. Summary of System Audit & Cleanups

1. **`sudoedit` Red Status**: Clarified as a dangling symlink caused by SecureBlue removing `sudo` in favor of `run0`.
2. **Kimi Root Modifications Audited**: All `/etc/systemd/user/` drop-ins and browser repo configurations were verified and justified.
3. **Verbosity**: `quiet` and `rhgb` permanently stripped via Ventoy `kparam` on all 4 drives.
