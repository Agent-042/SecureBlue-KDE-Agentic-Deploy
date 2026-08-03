Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak install -y flathub im.riot.Riot

run0 flatpak override --nodevice=all --nofilesystem=home --nofilesystem=host --filesystem=xdg-download im.riot.Riot

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - im.riot.Riot

# File: config/files/usr/share/flatpak/overrides/im.riot.Riot (System override file)
[Context]
shared=network
filesystems=!host;!home;xdg-download
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
