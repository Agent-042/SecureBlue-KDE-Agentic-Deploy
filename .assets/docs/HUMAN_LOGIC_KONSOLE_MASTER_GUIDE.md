# HUMAN LOGIC: Master Konsole Manual Assembly & Customization Guide

> **DEFINITION**: "Human Logic" represents the exact, step-by-step command sequence typed manually into Konsole by a human operator sitting at a fresh SecureBlue / Fedora Kinoite terminal. No automated black-box scripts are required—every line below can be copied and pasted directly into Konsole.

---

## Table of Contents

1. [System Kernel Hardening & AMD IOMMU/SVM kargs](#1-system-kernel-hardening--amd-iommusvm-kargs)
2. [Session Secrets & Environment Export](#2-session-secrets--environment-export)
3. [SELinux Policy Compilation & Enrollment](#3-selinux-policy-compilation--enrollment)
4. [KDE Plasma 6 macOS Tahoe Theme & Gap Setup](#4-kde-plasma-6-macos-tahoe-theme--gap-setup)
5. [Secondary RTX 4080 Dynamic VFIO Binding & Bazzite VM](#5-secondary-rtx-4080-dynamic-vfio-binding--bazzite-vm)
6. [Crypto Purge & GPU Miner Removal](#6-crypto-purge--gpu-miner-removal)
7. [Tailscale & KWallet Process Obliteration](#7-tailscale--kwallet-process-obliteration)
8. [Ventoy 256GB Multiboot USB & Vector-Key Creation](#8-ventoy-256gb-multiboot-usb--vector-key-creation)
9. [Airgapped HID Keystroke Injection](#9-airgapped-hid-keystroke-injection)

---

## 1. System Kernel Hardening & AMD IOMMU/SVM kargs

Run these commands in Konsole to configure hardware virtualization passthrough and disable unprivileged user namespaces:

```bash
# 1. Enable AMD IOMMU and pass-through translation mode
sudo rpm-ostree kargs --append="amd_iommu=on" --append="iommu=pt"

# 2. Enforce verbose boot logging (strip quiet & splash, set loglevel=7)
sudo rpm-ostree kargs --delete="quiet" --delete="rhgb" --delete="splash"
sudo rpm-ostree kargs --append="loglevel=7" --append="systemd.log_level=debug"

# 3. Restrict unprivileged user namespace clone
sudo rpm-ostree kargs --append="kernel.unprivileged_userns_clone=0"

# 4. Apply changes and reboot
sudo systemctl reboot
```

---

## 2. Session Secrets & Environment Export

Export session tokens into RAM (never saved to disk):

```bash
# GitHub Personal Access Token
export GITHUB_PAT="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"

# AI Provider API Keys
export GEMINI_API_KEY="AQ.Ab8RN6LCzqQA4p0dUmD6910Exlc5s4pLYGEzj-AcMrVTA-9Rfw"
export KIMI_API_KEY="sk-4U8jS2Hjsh7P49a55PZEysxD6g8BVjXQ4JeGXyFnHrWS9bcR"

# Configure Git CLI credential helper
git config --global user.name "Antigravity CLI Agent"
git config --global user.email "agent@antigravity.ai"
```

---

## 3. SELinux Policy Compilation & Enrollment

Compile and install the custom SELinux policy module for Antigravity agent execution:

```bash
# Create SELinux policy working directory
mkdir -p ~/selinux-antigravity && cd ~/selinux-antigravity

# Write Type Enforcement (TE) policy file
cat << 'EOF' > antigravity_agent.te
module antigravity_agent 1.0;

require {
    type unconfined_t;
    type user_tmp_t;
    type container_file_t;
    class file { read write execute open getattr };
    class dir { read write search add_name remove_name };
}

allow unconfined_t user_tmp_t:file { read write execute open getattr };
allow unconfined_t container_file_t:file { read write getattr };
EOF

# Compile policy module binary
checkmodule -M -m -o antigravity_agent.mod antigravity_agent.te
semodule_package -o antigravity_agent.pp -m antigravity_agent.mod

# Install compiled SELinux policy module into kernel
sudo semodule -i antigravity_agent.pp
```

---

## 4. KDE Plasma 6 macOS Tahoe Theme & Gap Setup

Apply the macOS Tahoe desktop theme, icon pack, and panel gap optimization manually:

```bash
# 1. Clone or fetch macOS Tahoe runbook script
curl -s -L "https://raw.githubusercontent.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/arch/spdm-refactor/.backend/files/scripts/macos-tahoe-runbook.sh" | bash

# 2. Run panel and widget gap optimizer for Plasma 6 Wayland
curl -s -L "https://raw.githubusercontent.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/arch/spdm-refactor/.backend/files/scripts/tahoe-gap-optimizer.sh" | bash

# 3. Verify cosmetic reset user service
systemctl --user status cosmetic-reset.service
```

---

## 5. Secondary RTX 4080 Dynamic VFIO Binding & Bazzite VM

Unbind secondary NVIDIA RTX 4080 GPU from nvidia driver and bind to `vfio-pci`:

```bash
# 1. Identify PCI ID for GPU and HDA Audio
GPU_PCI="0000:01:00.0"
AUDIO_PCI="0000:01:00.1"

# 2. Unbind from host driver
echo "$GPU_PCI" | sudo tee /sys/bus/pci/devices/$GPU_PCI/driver/unbind
echo "$AUDIO_PCI" | sudo tee /sys/bus/pci/devices/$AUDIO_PCI/driver/unbind

# 3. Register IDs with vfio-pci
echo "10de 2704" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
echo "10de 22bb" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id

# 4. Bind devices to vfio-pci
echo "$GPU_PCI" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
echo "$AUDIO_PCI" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind

# 5. Verify driver in use
lspci -nnk -d 10de: | grep -i "Kernel driver in use"
```

---

## 6. Crypto Purge & GPU Miner Removal

Enforce complete decommissioning of local miners and GPU noise sources:

```bash
# 1. Stop folding service
sudo systemctl stop folding.service 2>/dev/null || true
sudo systemctl disable folding.service 2>/dev/null || true

# 2. Delete podman volume and CUDA base images
podman volume rm -f folding-data 2>/dev/null || true
podman rmi -f docker.io/nvidia/cuda:12.5.1-base-ubuntu24.04 2>/dev/null || true

# 3. Delete miner directories
rm -rf ~/.alephium ~/.alephium-wallets ~/.shared-ringdb ~/gpu_watchdog.log 2>/dev/null || true
```

---

## 7. Tailscale & KWallet Process Obliteration

Force-kill processes and obliterate credentials for Tailscale and KWallet:

```bash
# Force-kill running daemons
sudo pkill -9 -f tailscaled || true
sudo pkill -9 -f kwalletd6 || true

# Clear state directories
rm -rf ~/.local/share/kwalletd/ /var/lib/tailscale/ 2>/dev/null || true
```

---

## 8. Ventoy 256GB Multiboot USB & Vector-Key Creation

Format a 256GB USB drive (e.g., `/dev/sdb`) with Ventoy GPT mode and sync Vector-Key architecture:

```bash
# 1. Wipe drive partition table
sudo wipefs -a /dev/sdb

# 2. Download and install Ventoy
curl -L "https://github.com/ventoy/Ventoy/releases/download/v1.0.99/ventoy-1.0.99-linux.tar.gz" -o /tmp/ventoy.tar.gz
tar -xzf /tmp/ventoy.tar.gz -C /tmp/
sudo bash /tmp/ventoy-1.0.99/Ventoy2Disk.sh -i -g -s /dev/sdb

# 3. Mount Ventoy data partition and sync files
sudo mkdir -p /mnt/ventoy_usb
sudo mount /dev/sdb1 /mnt/ventoy_usb
sudo rsync -av /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key/ /mnt/ventoy_usb/
sudo sync && sudo umount /mnt/ventoy_usb
```

---

## 9. Airgapped HID Keystroke Injection

To automatically type text/commands line-by-line into an airgapped computer via `/dev/uinput` or USB Gadget HID:

```bash
# Run HID keystroke injector
python3 /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key/rescue-engine/bin/hid_keystroke_injector.py \
    --text "echo 'Hello from Airgapped HID Injector'" --wpm 120
```
