Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub com.yubico.yubioath

run0 flatpak override --nonet --nosocket=wayland --nosocket=x11 --nofilesystem=home --nofilesystem=host com.yubico.yubioath

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - com.yubico.yubioath

# File: config/files/usr/share/flatpak/overrides/com.yubico.yubioath (System override file)
[Context]
shared=!network
features=!background
devices=all
sockets=pcsc
filesystems=!home;!host

[Session Bus Policy]
org.freedesktop.Notifications=none
org.kde.*=none
org.gnome.*=none
com.canonical.*=none

[System Bus Policy]
org.freedesktop.Avahi=none
