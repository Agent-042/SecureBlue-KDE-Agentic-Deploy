#!/bin/bash
# dummy-plug-chromestick-setup.sh
# Configures Chrome TV Stick Streaming Device as an HDMI Dummy Plug & Android Staging Node

set -euo pipefail

echo "================================================================="
echo " CHROME TV STICK HARDWARE DUMMY PLUG & ANDROID STAGING NODE     "
echo "================================================================="

HDMI_STATUS_FILE="/sys/class/drm/card1-HDMI-A-1/status"

# 1. Inspect HDMI Connector State
if [ -f "$HDMI_STATUS_FILE" ]; then
    CURRENT_STATE=$(cat "$HDMI_STATUS_FILE")
    echo "[1/3] HDMI Connector (/sys/class/drm/card1-HDMI-A-1): $CURRENT_STATE"
    if [ "$CURRENT_STATE" != "connected" ]; then
        echo " -> Forcing active HDMI Dummy Plug status for Wayland/KVM display offloading..."
        echo "on" > "$HDMI_STATUS_FILE" 2>/dev/null || echo " -> Note: Kernel DRM connector force requires edid_firmware parameter in bootloader."
    fi
else
    echo "[1/3] Searching all DRM connectors..."
    ls -la /sys/class/drm/card*
fi

# 2. Check USB ADB / Fastboot Interfaces
echo "[2/3] Checking USB ADB and Fastboot endpoints..."
if command -v adb >/dev/null 2>&1; then
    adb devices -l
fi
if command -v fastboot >/dev/null 2>&1; then
    fastboot devices
fi

# 3. Create Virtual Wayland Headless Output Config for Looking Glass
echo "[3/3] Registering Headless HDMI Dummy Plug Resolution Profile (1920x1080@60Hz)..."
mkdir -p /etc/kms-edid
cat << 'EOF' > /etc/kms-edid/dummy-plug-1080p.conf
# Virtual EDID & DRM Connector Config for Chrome TV Stick Dummy Plug
connector=HDMI-A-1
status=forced-on
resolution=1920x1080@60
looking_glass_ivshmem_device=/dev/shm/looking-glass
EOF

echo "================================================================="
echo " DUMMY PLUG STAGING COMPLETE                                     "
echo "================================================================="
