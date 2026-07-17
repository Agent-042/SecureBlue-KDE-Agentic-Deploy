Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub com.github.wwmm.easyeffects

run0 flatpak override --nosocket=wayland --nosocket=x11 --nosocket=fallback-x11 --nodevice=all --nofilesystem=home --nofilesystem=host --filesystem=xdg-run/pipewire-0 com.github.wwmm.easyeffects

mkdir -p ~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - com.github.wwmm.easyeffects

# File: config/files/usr/share/flatpak/overrides/com.github.wwmm.easyeffects (System override file)
[Context]
shared=!network
sockets=pulseaudio
filesystems=!host;!home;xdg-run/pipewire-0
devices=!all
features=!background

[Session Bus Policy]
org.freedesktop.secrets=none
org.freedesktop.Notifications=none
org.kde.*=none
org.gnome.*=none
com.canonical.*=none

[System Bus Policy]
org.freedesktop.Avahi=none

# File: modules/audio-eq/module.yml
type: files
files:
  - source: audio-eq/usr
    destination: /usr

# File: files/audio-eq/usr/etc/easyeffects/output/G16 Speaker Clarity.json
# Preset configuration applied system-wide for G16 speaker tuning

# File: files/audio-eq/usr/etc/xdg/autostart/g16-easyeffects-clarity.desktop
# Auto-starts EasyEffects with the G16 clarity preset on login

# File: files/audio-eq/usr/bin/g16-easyeffects-autostart.sh
#!/bin/bash
flatpak run com.github.wwmm.easyeffects --gapplication-service &
sleep 2
flatpak run com.github.wwmm.easyeffects -l "G16 Speaker Clarity"
