# PROJECT VECTOR-KEY: 256GB Hybrid Rescue & Auto-Deployment Multiboot USB

> **PURPOSE**: Complete architectural specification and provisioning manifest for a 256GB Ventoy-Plus offline fleet rescue, zero-touch auto-installer, and local AI diagnostic flash drive targeting SecureBlue KDE, Bazzite Nvidia, Windows 11 Enterprise, and Qubes OS Dom0.

---

## 1. Directory & Partition Architecture

```
[ VENTOY PARTITION 1 (ExFAT/NTFS, ~230GB) ]
  ├── /ventoy/
  │    ├── ventoy.json               # Auto-install ISO-to-Answer File mappings
  │    └── ventoy_grub.cfg           # Custom verbose GRUB2 submenus (quiet/splash stripped)
  ├── /ISO/
  │    ├── SecureBlue-KDE-offline.iso # SecureBlue Kinoite KDE Hardened ISO
  │    ├── Bazzite-Nvidia.iso        # Bazzite OS Nvidia Gaming ISO
  │    ├── Windows11-enterprise.iso  # Windows 11 Enterprise ISO
  │    └── Qubes-OS.iso              # Qubes OS Dom0 ISO
  ├── /unattend/
  │    ├── secureblue-ks.cfg         # Anaconda Kickstart (Btrfs, no quiet, loglevel=7, run0 admin)
  │    ├── win11_autounattend.xml    # Windows 11 Answer File (Bypass TPM/RAM/OOBE, local admin)
  │    └── qubes-dom0-ks.cfg         # Qubes OS Kickstart with G16 SecureBoot Injection
  ├── /rescue-engine/
  │    ├── models/                   # Qwen2.5-Coder-7B-Instruct (Q4_K_M GGUF)
  │    ├── docs-rag/                 # Offline uBlue, SecureBlue, KDE & VFIO Markdown docs
  │    └── bin/
  │         ├── harvester.sh         # Zero-touch hardware diagnostic & log harvester
  │         └── rag_assistant.py     # Standalone offline RAG CLI diagnostic engine
  └── /logs/                         # Target directory for auto-dumped system error logs

[ VENTOY PARTITION 2 (VFAT, ~32MB) ]
  └── EFI Bootloader (UEFI Secure Boot enabled)
```

---

## 2. Key Features & Implementation Highlights

### A. Zero-Touch Automated ISO Installations
- **SecureBlue & Bazzite**: Handled via `/unattend/secureblue-ks.cfg`. Wipes disks non-interactively, builds Btrfs subvolumes (`@`, `@home`, `@var`), disables `quiet`/`splash`, enforces `loglevel=7` for verbose boot debugging, and configures `run0` admin rules.
- **Windows 11 Enterprise**: Handled via `/unattend/win11_autounattend.xml`. Bypasses TPM 2.0, RAM, CPU, SecureBoot, and OOBE checks, skips Microsoft Account creation, auto-provisions local `admin`, and configures VFIO display driver staging.
- **Qubes OS Dom0**: Handled via `/unattend/qubes-dom0-ks.cfg`. Auto-provisions Dom0 and injects G16 SecureBoot variables into Xen/GRUB boot configs.

### B. Custom Verbose GRUB Submenu (`/ventoy/ventoy_grub.cfg`)
- All `quiet`, `splash`, and `rhgb` boot arguments are explicitly stripped across all menu entries.
- Adds `loglevel=7 systemd.log_level=debug` to display full kernel boot traces during hardware failures.

### C. Zero-Touch Error Log Harvester (`harvester.sh`)
- Automated execution mounts the USB drive's `/logs/` partition and dumps `dmesg`, `journalctl -p err`, `lspci`, `smartctl`, `dmidecode`, and SELinux denials (`audit.log`) directly into timestamped log folders (`/logs/diag_$TIMESTAMP`).

### D. Offline Local AI & RAG Engine (`rag_assistant.py`)
- Runs `Qwen2.5-Coder-7B-Instruct` (Q4_K_M) with a ~4.5 GB RAM footprint.
- Queries embedded vector database of uBlue, SecureBlue, KDE, and VFIO docs stored on the USB drive to diagnose hardware/kernel errors offline.

---

## 3. Provisioning Execution Command

To format and provision a target 256GB USB drive (e.g., `/dev/sdb`):

```bash
sudo bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key/install_vector_key_to_usb.sh /dev/sdb
```
