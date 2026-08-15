# SecureBlue, Ventoy Multi-Drive Deployment & Security Architecture Guide

**Date:** August 15, 2026  
**Target Hardware:** ASUS ROG Zephyrus G16 (Intel Arrow Lake-P Arc 140T + NVIDIA RTX 5080 Mobile GB203M)  
**Primary Host Distro:** SecureBlue KDE (Kinoite / Fedora Silverblue atomic derivative)

---

## 1. Multi-Drive Ventoy Standardized Layout (All 4 Drives Synchronized)

All 4 attached USB drives (`/dev/sda`, `/dev/sdb`, `/dev/sdc`, `/dev/sdd` — 28.9 GB each) are synchronized with identical, optimized partition and ISO configurations:

### ISO Manifest (`/ISOs/`):
| File | Size | Role & Architecture |
| :--- | :--- | :--- |
| `Win11_24H2_Enterprise_LTSC_x64_en-us.iso` | **4.8 GB** | Official Microsoft Windows 11 Enterprise LTSC 24H2 (Zero bloatware, minimal telemetry, enterprise lifecycle) |
| `nixos-plasma6-24.11-x86_64-linux.iso` | **3.2 GB** | NixOS 24.11 with KDE Plasma 6 (Declarative live environment with full hardware support & Nix package management) |
| `secureblue-kinoite-main-hardened.iso` | **4.9 GB** | SecureBlue KDE Plasma hardened immutable atomic OS |
| `secureblue-silverblue-main-hardened.iso` | **4.4 GB** | SecureBlue GNOME hardened immutable atomic OS |
| `Qubes-R4.3.1-x86_64.iso` | **7.9 GB** | Qubes OS 4.3.1 Xen-based security compartmentalization |
| **Free / Unallocated Storage** | **~4.0 GB** | Persistent user storage, custom driver injects, and file transfers |

* **Removed Bloat / Duplicates**: Redundant desktop variants (`secureblue-cosmic` and `secureblue-sericea`) were pruned from all 4 drives, recovering **8.7 GB per drive**.

---

## 2. Live Environment Optimization Analysis (SecureBlue, Qubes, NixOS)

### A. Can SecureBlue or Qubes Live ISOs be made fully persistent without installing to internal NVMe?
1. **SecureBlue (OSTree/Container-based)**:
   - SecureBlue ISOs are Anaconda-based installers intended to deploy an immutable Composefs/OSTree image to disk.
   - **Ventoy Live Persistence Plugin (`persistence.dat`)**: You can attach a Ventoy persistence image to Fedora/Silverblue via `ventoy.json`. However, because SecureBlue enforces read-only root and strict SELinux labels, overlay persistence in live mode is non-trivial and may fail validation.
2. **Qubes OS**:
   - Qubes uses Xen hypervisor architecture with dedicated domain templates. Running Qubes entirely as a non-installed live image is not supported by Qubes upstream because domain virtualization requires permanent LVM thin-pools or direct block storage.
3. **NixOS (The Objectively Superior Live Solution)**:
   - NixOS ISO includes a fully functional live user environment (`nixos`), live hardware detection, Nix package manager (`nix-shell`, `nix run`), and live declarative reconfigurability via `/etc/nixos/configuration.nix` in RAM without touching internal NVMe drives.

---

## 3. SecureBoot & MOK Hierarchy on ASUS ROG G16

Checking enrolled keys on the machine (`mokutil --list-enrolled`):
- **Key 1**: `Fedora Secure Boot CA 20200709` (Standard Red Hat shim trust)
- **Key 2**: `secureblue secureboot key` (SecureBlue kernel/module trust)
- **Key 3**: `Ventoy Secure Boot Root CA` (Ventoy EFI chainloader trust)
- **Microsoft UEFI CA**: Built into ASUS BIOS firmware.

### Chain of Trust:
- **Windows 11**: Booted via Microsoft UEFI CA signature on `bootmgfw.efi`.
- **Ventoy**: Booted via enrolled Key 3 (`Ventoy Secure Boot Root CA`).
- **NixOS Live**: Executed via Ventoy GRUB in UEFI mode.

---

## 4. GitHub Fine-Grained PAT & Agent Security Policy

### PAT Audit & Restrictions Analysis:
- **Token**: `github_pat_11CH3Z7II0...`
- **Scope**: User `Agent-042` | Repository `SecureBlue-KDE-Agentic-Deploy`
- **Current Permission**: **Full Admin / Push**

### Why the Token Cannot Self-Restrict via API:
1. **API Token Scoping**: GitHub does not permit a PAT to modify its own scope or reduce its own permission levels via REST API endpoints. Modifying token permissions requires logging into GitHub Web UI under *Account Settings → Developer Settings → Personal Access Tokens*.
2. **Repository Protection on Private Repos**: GitHub Free tier blocks branch protection rulesets on private repositories (`403: Upgrade to GitHub Pro or make this repository public`).

### Recommended Action for Human Admin:
1. **Public vs Private**: If the repository is made Public (or account upgraded to GitHub Pro), enable Branch Protection on `main` to require Pull Requests.
2. **Multi-Agent Setup**: Generate distinct fine-grained tokens with `Contents: Read/Write` and `Administration: No Access` to prevent accidental repository deletion or settings changes by autonomous CLI agents.
