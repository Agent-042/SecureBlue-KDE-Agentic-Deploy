# HUMAN LOGIC: Manual Konsole Assembly Guide for SecureBlue KDE Workstation

> **CONCEPT**: While BuildBlue handles OCI container build logic, **Human Logic** represents the step-by-step command sequence typed manually into Konsole to assemble, configure, and verify this exact workstation environment.

---

## Table of Contents

1. [Initial System Hardening & Kernel Arguments](#1-initial-system-hardening--kernel-arguments)
2. [Secrets & Environment Initialization](#2-secrets--environment-initialization)
3. [SELinux Policy Compilation & Enrollment](#3-selinux-policy-compilation--enrollment)
4. [KDE Plasma 6 macOS Tahoe Theme Setup](#4-kde-plasma-6-macos-tahoe-theme-setup)
5. [VFIO & Bazzite VM Passthrough Setup](#5-vfio--bazzite-vm-passthrough-setup)
6. [Crypto Purge & GPU Noise Reduction](#6-crypto-purge--gpu-noise-reduction)
7. [Tailscale & KWallet Obliteration](#7-tailscale--kwallet-obliteration)
8. [Ventoy Multiboot USB Creation](#8-ventoy-multiboot-usb-creation)

---

## 1. Initial System Hardening & Kernel Arguments

Execute these commands in Konsole to configure kernel arguments for IOMMU, SVM, and unprivileged user namespace restriction:

```bash
# 1. Enable AMD IOMMU and SVM virtualization passthrough
sudo rpm-ostree kargs --append="amd_iommu=on" --append="iommu=pt"

# 2. Restrict unprivileged user namespace clone for miner containment
sudo rpm-ostree kargs --append="kernel.unprivileged_userns_clone=0"

# 3. Apply changes and reboot
sudo systemctl reboot
```

---

## 2. Secrets & Environment Initialization

Never write raw API keys to disk. Always load them into session memory:

```bash
# Export GitHub Personal Access Token
export GITHUB_PAT="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"

# Export AI Provider Keys
export GEMINI_API_KEY="AQ.Ab8RN6LCzqQA4p0dUmD6910Exlc5s4pLYGEzj-AcMrVTA-9Rfw"
export KIMI_API_KEY="sk-4U8jS2Hjsh7P49a55PZEysxD6g8BVjXQ4JeGXyFnHrWS9bcR"

# Verify environment variables
echo "GitHub PAT set: ${GITHUB_PAT:0:10}..."
echo "Gemini Key set: ${GEMINI_API_KEY:0:10}..."
```

---

## 3. SELinux Policy Compilation & Enrollment

Compile and install custom SELinux modules for Antigravity agent CLI permissions:

```bash
# Navigate to SELinux policy directory
cd /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/selinux/antigravity/ 2>/dev/null || cd ~/selinux-antigravity/

# Compile TE policy into PP binary module
checkmodule -M -m -o antigravity.mod antigravity.te
semodule_package -o antigravity.pp -m antigravity.mod

# Install policy into kernel
sudo semodule -i antigravity.pp
```

---

## 4. KDE Plasma 6 macOS Tahoe Theme Setup

Execute the idempotent macOS Tahoe skin installer directly in Konsole:

```bash
# Run canonical macOS Tahoe runbook installer
bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/scripts/macos-tahoe-runbook.sh

# Optimize widget and panel gap spacing for Plasma 6 Wayland
bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/scripts/tahoe-gap-optimizer.sh

# Verify automatic cosmetic reset service state
systemctl --user status cosmetic-reset.service
```

---

## 5. VFIO & Bazzite VM Passthrough Setup

Bind secondary RTX 4080 GPU to VFIO and launch Bazzite VM:

```bash
# 1. Unbind RTX 4080 from nvidia driver and bind to vfio-pci
sudo bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/vfio-bind-secondary-gpu.sh

# 2. Check VFIO binding status
lspci -nnk -d 10de: | grep -i "Kernel driver in use"

# 3. Launch Bazzite Gaming VM with libvirt passthrough XML
sudo virsh define /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/vfio-workstation/bazzite-gaming-passthrough.xml
sudo virsh start bazzite-gaming
```

---

## 6. Crypto Purge & GPU Noise Reduction

Enforce complete removal of crypto miners and GPU fan noise culprits:

```bash
# Execute automated crypto purge
sudo bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/scripts/post-reboot-crypto-purge.sh

# Confirm no miner containers are active
podman ps -a
```

---

## 7. Tailscale & KWallet Obliteration

To kill processes and erase residual state for Tailscale and KWallet:

```bash
# Execute process kill and directory obliteration
sudo bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/scripts/nuke-tailscale-kwallet.sh
```

---

## 8. Ventoy Multiboot USB Creation

Format a USB flash drive (e.g. `/dev/sdb`) with Ventoy multiboot:

```bash
# Run Ventoy setup targeting the attached USB drive
sudo bash /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/scripts/setup-ventoy-multiboot.sh /dev/sdb
```
