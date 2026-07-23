#!/usr/bin/env bash
# Ventoy Multiboot Installer Script for USB Drive (e.g. PNY USB 3.2.1 FD)
set -euo pipefail

echo "=================================================="
echo "[VENTOY] Multiboot USB Provisioning Script"
echo "=================================================="

TARGET_DEV="${1:-}"

if [ -z "$TARGET_DEV" ]; then
    echo "Usage: $0 /dev/sdX"
    echo ""
    echo "Available disk devices:"
    lsblk -p -d -n -o NAME,SIZE,MODEL,TRAN | grep -v "nvme" || true
    echo ""
    exit 1
fi

if [ ! -b "$TARGET_DEV" ]; then
    echo "Error: Device '$TARGET_DEV' is not a valid block device."
    exit 1
fi

echo "[WARNING] ALL DATA ON '$TARGET_DEV' WILL BE DESTROYED!"
echo "Targeting device: $TARGET_DEV"

# 1. Download Ventoy if not already present
VENTOY_VERSION="1.0.99"
VENTOY_DIR="/tmp/ventoy-${VENTOY_VERSION}"

if [ ! -d "$VENTOY_DIR" ]; then
    echo "[*] Fetching Ventoy release v${VENTOY_VERSION}..."
    curl -L "https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/ventoy-${VENTOY_VERSION}-linux.tar.gz" -o /tmp/ventoy.tar.gz
    tar -xzf /tmp/ventoy.tar.gz -C /tmp/
fi

# 2. Install Ventoy to target device (GPT / SecureBoot enabled)
echo "[*] Installing Ventoy (GPT layout, SecureBoot enabled) to $TARGET_DEV..."
bash "$VENTOY_DIR/Ventoy2Disk.sh" -i -g -s "$TARGET_DEV"

# 3. Mount Ventoy Partition 1
VENTOY_PART="${TARGET_DEV}1"
if [ ! -b "$VENTOY_PART" ]; then
    VENTOY_PART="${TARGET_DEV}p1"
fi

MNT_DIR="/mnt/ventoy_usb"
mkdir -p "$MNT_DIR"
echo "[*] Mounting Ventoy data partition ($VENTOY_PART) to $MNT_DIR..."
mount "$VENTOY_PART" "$MNT_DIR"

# 4. Create directory structure for ISO images
mkdir -p "$MNT_DIR/ISOs/Bazzite"
mkdir -p "$MNT_DIR/ISOs/SecureBlue"
mkdir -p "$MNT_DIR/ISOs/Windows"
mkdir -p "$MNT_DIR/Scripts"

echo "[*] Downloading ISO manifests and checksums..."

cat << 'EOF' > "$MNT_DIR/ISOs/README_ISOS.md"
# Multiboot Ventoy ISO Directory Structure

Place ISO images into the respective folders:
- `/ISOs/Bazzite/`      : Pristine Bazzite KDE (bazzite-kde.iso)
- `/ISOs/SecureBlue/`   : SecureBlue Kinoite KDE Hardened (secureblue-kinoite.iso)
- `/ISOs/Windows/`      : Windows 11 24H2 ISO (Win11_24H2_English_x64.iso)

## Recommended Fetch Commands:
1. Bazzite KDE:
   curl -L "https://download.bazzite.gg/bazzite-kde-stable.iso" -o ISOs/Bazzite/bazzite-kde.iso
2. SecureBlue Kinoite:
   curl -L "https://github.com/secureblue/secureblue/releases/download/latest/secureblue-kinoite-nvidia-open-hardened.iso" -o ISOs/SecureBlue/secureblue-kinoite.iso
EOF

# Copy repository scripts for offline recovery
echo "[*] Copying recovery scripts to Ventoy partition..."
cp -r /var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/scripts/* "$MNT_DIR/Scripts/" 2>/dev/null || true

sync
umount "$MNT_DIR"
rmdir "$MNT_DIR"

echo "=================================================="
echo "[SUCCESS] Ventoy Multiboot USB successfully provisioned on $TARGET_DEV!"
echo "=================================================="
