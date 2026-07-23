#!/usr/bin/env bash
# Zero-Touch Hardware Diagnostic & Error Log Harvester
# Target: Automated system error dumps directly to USB /logs/ partition
set -euo pipefail

echo "=================================================="
echo "[HARVESTER] Zero-Touch Hardware & Log Harvester"
echo "=================================================="

# Detect Ventoy USB mount or fallback
TARGET_USB=$(lsblk -o NAME,LABEL | grep -i "VENTOY" | head -n 1 | awk '{print $1}')
MNT_DIR="/mnt/ventoy_usb"

if [ -n "$TARGET_USB" ] && [ -b "/dev/${TARGET_USB}" ]; then
    mkdir -p "$MNT_DIR"
    mount "/dev/${TARGET_USB}" "$MNT_DIR" 2>/dev/null || true
    LOG_BASE="$MNT_DIR/logs"
else
    LOG_BASE="/var/roothome/SecureBlue-KDE-Agentic-Deploy/.backend/files/ventoy-vector-key/logs"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_OUT="$LOG_BASE/diag_${TIMESTAMP}"
mkdir -p "$LOG_OUT"

echo "[*] Harvesting hardware topology and PCI devices..."
lspci -nnk > "$LOG_OUT/pci_devices.log" 2>&1 || true
lscpu > "$LOG_OUT/cpu_architecture.log" 2>&1 || true
lsusb -v > "$LOG_OUT/usb_devices.log" 2>&1 || true

echo "[*] Extracting kernel error logs and previous boot journal..."
dmesg -level=err,warn > "$LOG_OUT/kernel_errors.log" 2>&1 || true
journalctl -b -1 -p err > "$LOG_OUT/prev_boot_errors.log" 2>&1 || true
journalctl -b 0 -p err > "$LOG_OUT/current_boot_errors.log" 2>&1 || true

echo "[*] Dumping SELinux denials (audit.log)..."
if [ -f /var/log/audit/audit.log ]; then
    grep -i "denied" /var/log/audit/audit.log > "$LOG_OUT/selinux_denials.log" 2>&1 || true
fi

echo "[*] Checking NVMe SMART health..."
smartctl --all /dev/nvme0n1 > "$LOG_OUT/nvme_health.log" 2>&1 || true

echo "[*] Extracting SMBIOS / DMI hardware topology..."
dmidecode > "$LOG_OUT/smbios_hw.log" 2>&1 || true

if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    sync
    umount "$MNT_DIR" 2>/dev/null || true
fi

echo "=================================================="
echo "[SUCCESS] Diagnostics harvested to: $LOG_OUT"
echo "=================================================="
