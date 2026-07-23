#!/usr/bin/env bash
# ASUS ROG Zephyrus G16 Screen Brightness Repair & Kernel/Modprobe Automation
set -euo pipefail

echo "[*] Initializing ASUS ROG Zephyrus G16 Screen Brightness Repair..."

# 1. Enforce NVIDIA Brightness Registry Dwords
mkdir -p /etc/modprobe.d/
cat <<EOF > /etc/modprobe.d/nvidia-g16-backlight.conf
# Enable NVIDIA EC & Display Backlight Control for ASUS ROG G16
options nvidia NVreg_RegistryDwords="EnableBrightnessControl=1"
options nvidia_wmi_ec_backlight
EOF
echo "[+] Wrote /etc/modprobe.d/nvidia-g16-backlight.conf"

# 2. Append ACPI Backlight Kernel Boot Parameters via rpm-ostree kargs
if command -v rpm-ostree >/dev/null 2>&1; then
    echo "[*] Appending G16 backlight kernel parameters via rpm-ostree kargs..."
    rpm-ostree kargs \
        --append-if-missing="acpi_backlight=native" \
        --append-if-missing="nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1" || true
fi

# 3. Create udev rule for unprivileged backlight adjustments
mkdir -p /etc/udev/rules.d/
cat <<EOF > /etc/udev/rules.d/99-g16-backlight.rules
# Grant video group & user access to all sysfs backlight brightness controls
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/usr/bin/chmod 0666 /sys/class/backlight/%k/brightness"
EOF
udevadm control --reload-rules && udevadm trigger --subsystem-match=backlight || true
echo "[+] Configured udev rule /etc/udev/rules.d/99-g16-backlight.rules"

# 4. Direct Sysfs Brightness Adjustment Function
set_brightness_percent() {
    local PCT="${1:-80}"
    for bl_dir in /sys/class/backlight/*; do
        if [ -d "$bl_dir" ]; then
            local max_b
            max_b=$(cat "$bl_dir/max_brightness" 2>/dev/null || echo 255)
            local target_b=$(( max_b * PCT / 100 ))
            echo "$target_b" > "$bl_dir/brightness" 2>/dev/null || true
            echo "[+] Set $bl_dir brightness to $target_b ($PCT%)"
        fi
    done
}

set_brightness_percent 80

echo "[+] ASUS ROG Zephyrus G16 Screen Brightness Repair Complete!"
