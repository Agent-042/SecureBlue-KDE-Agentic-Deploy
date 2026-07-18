Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Audio EQ module deploys a system-wide EasyEffects preset for G16 speaker clarity.
# EasyEffects is installed as a Flatpak; see guides/easyeffects.md for manual install steps.
# The preset auto-loads on login via XDG autostart.

## Script Logic ##
# File: modules/audio-eq/module.yml
type: files
files:
  - source: audio-eq/usr
    destination: /usr

# File: files/audio-eq/usr/etc/easyeffects/output/G16 Speaker Clarity.json
# System-wide EasyEffects preset tuned for G16 laptop speakers

# File: files/audio-eq/usr/etc/xdg/autostart/g16-easyeffects-clarity.desktop
[Desktop Entry]
Name=G16 EasyEffects Clarity
Exec=/usr/bin/g16-easyeffects-autostart.sh
Type=Application
Terminal=false
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true

# File: files/audio-eq/usr/bin/g16-easyeffects-autostart.sh
#!/bin/bash
flatpak run com.github.wwmm.easyeffects --gapplication-service &
sleep 2
flatpak run com.github.wwmm.easyeffects -l "G16 Speaker Clarity"
