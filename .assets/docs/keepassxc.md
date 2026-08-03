Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub org.keepassxc.KeePassXC

run0 flatpak override --nonet --nofilesystem=home --nofilesystem=host --nodevice=all --nofeature=background org.keepassxc.KeePassXC

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - org.keepassxc.KeePassXC

# File: config/files/usr/share/flatpak/overrides/org.keepassxc.KeePassXC (System override file)
[Context]
shared=!network
filesystems=!home;!host;xdg-documents;xdg-download
devices=!all
features=!background

[Session Bus Policy]
org.freedesktop.Notifications=none
org.kde.*=none
org.gnome.*=none
com.canonical.*=none

[System Bus Policy]
org.freedesktop.Avahi=none
