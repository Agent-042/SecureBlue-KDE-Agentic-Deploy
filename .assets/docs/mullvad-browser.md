Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub net.mullvad.MullvadBrowser

run0 flatpak override --nofilesystem=xdg-documents --nofilesystem=xdg-pictures --nofilesystem=xdg-music --nofilesystem=xdg-videos --nodevice=all --nosocket=pulseaudio net.mullvad.MullvadBrowser

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - net.mullvad.MullvadBrowser

# File: config/files/usr/share/flatpak/overrides/net.mullvad.MullvadBrowser (System override file)
[Context]
filesystems=!home;!host;xdg-download;xdg-run/pipewire-0;xdg-run/pulse
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
