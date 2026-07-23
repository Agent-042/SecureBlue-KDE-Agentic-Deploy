# ASUS ROG Zephyrus G16 Screen Brightness Repair & Hardware Control Runbook

## Overview
On ASUS ROG Zephyrus G16 laptops (Intel Core Ultra 9 + NVIDIA RTX 4080/4090 Hybrid MUX architecture) running immutable Fedora/SecureBlue Kinoite, screen brightness controls can become non-responsive due to conflict between `intel_backlight`, `nvidia_wmi_ec_backlight`, and `asus_wmi`.

---

## 🔧 Root Causes & Technical Resolution

### 1. Modprobe NVIDIA Backlight Options
Enable NVIDIA Embedded Controller (EC) & Display Backlight Control:
`/etc/modprobe.d/nvidia-g16-backlight.conf`:
```ini
options nvidia NVreg_RegistryDwords="EnableBrightnessControl=1"
options nvidia_wmi_ec_backlight
```

### 2. OSTree Kernel Arguments
Append ACPI native backlight parameters to the OSTree deployment bootloader:
```bash
sudo rpm-ostree kargs \
    --append-if-missing="acpi_backlight=native" \
    --append-if-missing="nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1"
```

### 3. Sysfs Permissive Udev Rule
Allow unprivileged users and desktop services to write directly to `/sys/class/backlight/*/brightness`:
`/etc/udev/rules.d/99-g16-backlight.rules`:
```ini
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/usr/bin/chmod 0666 /sys/class/backlight/%k/brightness"
```

---

## ⚡ One-Line Automated Execution
Run the automated repair script:
```bash
sudo bash .backend/files/ventoy-vector-key/rescue-engine/bin/fix_g16_screen_brightness.sh
```
