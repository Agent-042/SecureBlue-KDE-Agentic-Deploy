# SecureBlue, Ventoy Multi-Drive Deployment, Hardware Enablement & Security Guide

**Date:** August 15, 2026
**Target Hardware:** ASUS ROG Zephyrus G16 (Intel Arrow Lake-P Arc 140T + NVIDIA RTX 5080 Mobile Blackwell GB203M)
**Host Distro:** SecureBlue KDE (Kinoite / Fedora Silverblue atomic Composefs)
**Agentic Session:** Antigravity (Google DeepMind) — root terminal access, multi-session

---

## 1. Ventoy ISO Manifest (All 4 USB Keys — 28.9 GB each)

All four USB drives (`/dev/sda1–sdd1`) are kept in sync with identical payloads.

| File | Size | Boot Method | Role |
|:-----|:-----|:-----------|:-----|
| `Win11_24H2_Enterprise_LTSC_x64_en-us.iso` | 4.8 GB | **Normal Mode** (UEFI WinPE) | Windows 11 Enterprise LTSC 24H2 — official clean media, hardware bypass enabled |
| `nixos-plasma6-24.11-x86_64-linux.iso` | 3.2 GB | **GRUB Mode** (loopback.cfg) | NixOS 24.11 KDE Plasma 6 — fully declarative, RAM-usable live OS |
| `secureblue-kinoite-main-hardened.iso` | 4.9 GB | **GRUB Mode** (linux/initrd) | SecureBlue KDE Plasma 6 Hardened immutable atomic OS |
| `secureblue-silverblue-main-hardened.iso` | 4.4 GB | **GRUB Mode** (linux/initrd) | SecureBlue GNOME Hardened immutable atomic OS |
| `Qubes-R4.3.1-x86_64.iso` | 7.9 GB | **GRUB Mode** (multiboot2/Xen) | Qubes OS R4.3.1 Xen hypervisor — requires GRUB multiboot2 |
| `tails-amd64-7.10.1.img` | 1.79 GB | **Normal Mode** (.img native) | Tails 7.10.1 anonymous live OS — persistence-capable |

**Total used: ~27 GB | Free: ~2 GB per drive after Tails sync**

> Tails is distributed as a raw `.img` disk image (not ISO) — Ventoy handles it via native `img_pt` mode (Normal Mode). Do NOT attempt to GRUB-boot Tails.

---

## 2. Ventoy Configuration (ventoy.json key settings)

```json
"VTOY_DEFAULT_MENU_MODE": "2"   // GRUB mode is now the DEFAULT boot path
"VTOY_SECONDARY_BOOT_MENU": "1" // Secondary menu still accessible for Normal Mode
"VTOY_WIN11_BYPASS_CHECK": "1"  // Windows 11 TPM/CPU bypass enabled
"VTOY_DEFAULT_HIGH_RESOLUTION": "1"
"VTOY_GFX_MODE": "1920x1080;1600x1200;1366x768;1024x768"
"VTOY_MENU_TIMEOUT": "15"       // 15s countdown to default selection
```

**kparam (global kernel flags stripped from all Linux ISOs):**
- `-quiet` — removes quiet boot suppression → full verbose output enforced
- `-rhgb` — removes Red Hat graphical boot → text console log visible at all times

---

## 3. ventoy_grub.cfg — Boot Mode Architecture

GRUB mode is the recommended and default boot path. Rationale:

| Distro | Why GRUB required/preferred |
|:-------|:---------------------------|
| **Qubes OS** | `multiboot2` is mandatory for Xen hypervisor — UEFI cannot chain Xen directly |
| **SecureBlue** | GRUB gives direct kernel parameter control, verbose logging, bypasses animated splash |
| **NixOS** | Uses `configfile (loop)/boot/grub/loopback.cfg` — delegates to NixOS's own multi-entry GRUB menu (normal, nomodeset, copytoram, debug) |
| **Tails** | Raw `.img` — handled by Ventoy Normal Mode natively |
| **Windows 11** | WinPE UEFI chain — Normal Mode only |

### NixOS loopback.cfg delegation
NixOS 24.11 ships `/boot/grub/loopback.cfg` which exposes 4 entries: normal, nomodeset, copytoram, and debug. The `ventoy_grub.cfg` entry uses `configfile` to source this directly, preserving the full NixOS menu.

`loglevel=7` is appended to `$isoboot` to maximize verbosity (overriding the default `loglevel=4` in the NixOS grub.cfg).

---

## 4. Stuttering Investigation & Fix (SecureBlue KDE Session)

### Root Cause 1: LD_PRELOAD — hardened_malloc on KWin/Plasmashell
`/etc/profile.d/hardened_malloc.sh` globally sets `LD_PRELOAD=libhardened_malloc.so libno_rlimit_as.so`.
This causes frame stalls in the Wayland compositor under hardened memory allocation.

**Fix (staged for next login):**
- `/etc/systemd/user/plasma-kwin_wayland.service.d/override.conf`:
  ```ini
  [Service]
  Environment=LD_PRELOAD=
  ExecStart=
  ExecStart=/usr/bin/kwin_wayland_wrapper
  ```
- `/etc/systemd/user/plasma-plasmashell.service.d/override.conf`:
  ```ini
  [Service]
  Environment=LD_PRELOAD=
  ```

### Root Cause 2: org_kde_powerdevil I2C permission denial loop
Powerdevil polls `/dev/i2c-15` (eDP-2, internal display) and `/dev/i2c-16` (DP-4, discrete output) every ~3 seconds for DDC/CI brightness control. Both devices were `root:root 600`, causing a continuous failed permission check that stalls powerdevil's event loop → input latency spikes.

**Fix (applied live + persistent via udev):**
```bash
# /etc/udev/rules.d/60-powerdevil-i2c.rules
SUBSYSTEM=="i2c-dev", KERNEL=="i2c-15", GROUP="i2c", MODE="0660"
SUBSYSTEM=="i2c-dev", KERNEL=="i2c-16", GROUP="i2c", MODE="0660"
```
- `i2c` system group created
- User `Plasma-Setup` added to `i2c` group (effective on next login)
- Live chmod applied: `chown root:i2c /dev/i2c-{15,16} && chmod 660`

**Next login**: both fixes will be fully active. The powerdevil error loop will stop, and kwin/plasmashell will run without hardened_malloc preload.

---

## 5. SecureBlue System Audit Notes

- `sudoedit` in `/usr/local/bin/` appears as a **dangling red symlink** (`ls -la` shows red) — expected. SecureBlue replaces `sudo` with `systemd-run0`. The symlink target no longer exists; it is cosmetically broken but functionally harmless.
- rpm-ostree immutable layout: system files in `/usr/` are read-only Composefs overlays. Changes must be applied via drop-in directories in `/etc/` or layered packages.
- All udev rules, systemd drop-ins, and group changes above are written to `/etc/` (writable layer) and survive `rpm-ostree` upgrades.

---

## 6. SecureBoot / MOK / Ventoy Signing

Ventoy's EFI binary is signed with the system's MOK (Machine Owner Key). The MOK also covers the Ventoy-shimmed GRUB. This means:
- SecureBoot remains **enabled**
- Ventoy loads via shim → MOK-verified GRUB → ISO boot chain
- Windows 11 benefits from the same shim path via Normal Mode
- Qubes: Xen loads via multiboot2 from Ventoy's MOK-verified GRUB — no additional signing required for the installer phase

---

## 7. GitHub PAT Security Assessment

The fine-grained PAT (`github_pat_11CH3Z7II0...`) has:
- **Contents: Read & Write** — can push commits to this repo
- **Metadata: Read** — can read repo info
- **No admin scope** — cannot modify branch protection, webhooks, or self-restrict token permissions via API (GitHub returns 403)

**Recommended restrictions for agentic CLI tooling:**
1. Set token expiration (30–90 days max)
2. Restrict to specific branches (e.g., `main` only with PR requirement for destructive ops)
3. Exclude `Delete` permissions — agentic tools should never have file deletion via API
4. Add a second "review" branch for agent commits — human merges to main

---

## 8. Session Management Notes

- All changes made as `root` via Antigravity agentic CLI (Google DeepMind)
- Kimi Code (prior session) changes were audited — no unjustified modifications found
- Session restart events occurred multiple times (API overload) — state was preserved via drive mounts and written files
- Tails `.img` sync to `sdb/sdc/sdd` is handled by background watcher script `/tmp/sync_tails.sh` (logs at `/tmp/sync_tails.log`)

---

*Documentation auto-generated by Antigravity agentic session — August 15, 2026*
