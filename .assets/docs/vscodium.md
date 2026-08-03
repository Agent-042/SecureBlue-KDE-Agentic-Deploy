> **Note:** This file contains the technical details for VSCodium's installation and Flatpak overrides. For a complete overview of how VSCodium is integrated into the SecureBlue image, please see [vscodium-integration.md](./vscodium-integration.md).

Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub com.vscodium.codium

run0 flatpak override --nodevice=all --nofilesystem=home --nofilesystem=host --filesystem=xdg-documents --filesystem=xdg-download com.vscodium.codium

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - com.vscodium.codium

# File: config/files/usr/share/flatpak/overrides/com.vscodium.codium (System override file)
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
