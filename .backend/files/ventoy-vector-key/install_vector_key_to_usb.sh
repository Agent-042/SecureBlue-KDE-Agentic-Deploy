#!/usr/bin/env bash
# PROJECT VECTOR-KEY: Complete USB Installer & Sync Tool
# Formats target 256GB USB drive with Ventoy (GPT + UEFI Secure Boot) and syncs all ISOs, answer files, GRUB extensions, and RAG rescue engine.
set -euo pipefail

echo "=================================================="
echo "⚡ PROJECT VECTOR-KEY: 256GB Multiboot USB Installer"
echo "=================================================="

TARGET_DEV="${1:-}"

if [ -z "$TARGET_DEV" ]; then
    echo "Usage: $0 /dev/sdX"
    echo ""
    echo "Available block devices:"
    lsblk -p -d -n -o NAME,SIZE,MODEL,TRAN | grep -v "nvme" || true
    echo ""
    exit 1
fi

if [ ! -b "$TARGET_DEV" ]; then
    echo "Error: Device '$TARGET_DEV' is not a valid block device."
    exit 1
fi

echo "[!] WARNING: All data on '$TARGET_DEV' will be destroyed!"
echo "Targeting device: $TARGET_DEV"

# 1. Clear partition signatures and lockouts
echo "[*] Wiping partition signatures on $TARGET_DEV..."
wipefs -a "$TARGET_DEV" 2>/dev/null || true

# 2. Download Ventoy if not present
VENTOY_VERSION="1.0.99"
VENTOY_DIR="/tmp/ventoy-${VENTOY_VERSION}"

if [ ! -d "$VENTOY_DIR" ]; then
    echo "[*] Downloading Ventoy v${VENTOY_VERSION}..."
    curl -L "https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/ventoy-${VENTOY_VERSION}-linux.tar.gz" -o /tmp/ventoy.tar.gz
    tar -xzf /tmp/ventoy.tar.gz -C /tmp/
fi

# 3. Install Ventoy to target device (GPT mode + UEFI Secure Boot)
echo "[*] Installing Ventoy (GPT layout, UEFI Secure Boot support enabled) to $TARGET_DEV..."
bash "$VENTOY_DIR/Ventoy2Disk.sh" -i -g -s "$TARGET_DEV"

# 4. Mount Ventoy Partition 1
VENTOY_PART="${TARGET_DEV}1"
if [ ! -b "$VENTOY_PART" ]; then
    VENTOY_PART="${TARGET_DEV}p1"
fi

MNT_DIR="/mnt/ventoy_vector_key"
mkdir -p "$MNT_DIR"

echo "[*] Mounting Ventoy data partition ($VENTOY_PART) to $MNT_DIR..."
mount "$VENTOY_PART" "$MNT_DIR"

# 5. Sync Vector-Key files to Ventoy partition
SRC_DIR="/var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key"
echo "[*] Syncing Vector-Key architecture files to USB drive..."
rsync -av --progress "$SRC_DIR/" "$MNT_DIR/"

sync
umount "$MNT_DIR"
rmdir "$MNT_DIR"

echo "=================================================="
echo "[SUCCESS] PROJECT VECTOR-KEY successfully provisioned on $TARGET_DEV!"
echo "=================================================="
