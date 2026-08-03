Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub com.github.zocker_160.SyncThingy

run0 flatpak override --nosocket=wayland --nosocket=x11 --nonet --nofilesystem=home --nofilesystem=host --filesystem=xdg-documents --filesystem=xdg-download com.github.zocker_160.SyncThingy

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - com.github.zocker_160.SyncThingy

# File: config/files/usr/share/flatpak/overrides/com.github.zocker_160.SyncThingy (System override file)
[Context]
shared=network
filesystems=!host;!home;xdg-documents;xdg-download
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
