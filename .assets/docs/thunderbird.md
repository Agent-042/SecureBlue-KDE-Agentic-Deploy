Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub org.mozilla.Thunderbird

run0 flatpak override --nodevice=all --nofilesystem=home --nofilesystem=host --filesystem=xdg-documents --filesystem=xdg-download org.mozilla.Thunderbird

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - org.mozilla.Thunderbird

# File: config/files/usr/share/flatpak/overrides/org.mozilla.Thunderbird (System override file)
[Context]
shared=network
filesystems=!host;!home;xdg-documents;xdg-download
devices=!all
features=!background

[Session Bus Policy]
org.freedesktop.secrets=none
org.freedesktop.Notifications=talk
org.kde.*=none
org.gnome.*=none
com.canonical.*=none

[System Bus Policy]
org.freedesktop.Avahi=none
