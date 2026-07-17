Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 flatpak override --unset-env=LD_PRELOAD

run0 flatpak install -y flathub com.google.Chrome

run0 flatpak override --env=LD_PRELOAD=/var/run/host/usr/lib64/glibc-hwcaps/x86-64-v3/libhardened_malloc.so

run0 flatpak override --unset-env=LD_PRELOAD com.google.Chrome

run0 flatpak override --nofilesystem=xdg-documents --nofilesystem=xdg-music --nofilesystem=xdg-videos --nofilesystem=xdg-pictures --nosocket=x11 com.google.Chrome

mkdir -p ~/.var/app/com.google.Chrome/config

echo "--ozone-platform-hint=auto" > ~/.var/app/com.google.Chrome/config/chrome-flags.conf

echo "--enable-features=VaapiVideoDecodeLinuxGL" >> ~/.var/app/com.google.Chrome/config/chrome-flags.conf

## Script Logic ##
# File: recipe.yml (BlueBuild Recipe module config)
# Add this under modules:
modules:
  - type: default-flatpaks
    system:
      install:
        - com.google.Chrome

# File: config/files/usr/share/flatpak/overrides/com.google.Chrome (System override file)
[Context]
shared=network
filesystems=!host;home;xdg-download
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

# File: config/files/usr/lib/tmpfiles.d/google-chrome-flatpak-overrides.conf
C+ /var/lib/flatpak/overrides/com.google.Chrome 0644 root root - /usr/share/flatpak/overrides/com.google.Chrome

# File: config/files/etc/skel/.var/app/com.google.Chrome/config/chrome-flags.conf (Default flags for new users)
--ozone-platform-hint=auto
--enable-features=VaapiVideoDecodeLinuxGL

# File: config/files/usr/etc/opt/chrome/policies/managed/google-chrome-policies.json
{
  "DefaultCookiesSetting": 4,
  "DefaultJavaScriptSetting": 1,
  "DefaultNotificationsSetting": 2,
  "DefaultGeolocationSetting": 2,
  "DefaultMediaStreamingSetting": 2,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "DuckDuckGo",
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "ExtensionInstallBlocklist": ["*"],
  "HomepageLocation": "https://duckduckgo.com",
  "RestoreOnStartup": 5,
  "SafeBrowsingEnabled": true,
  "SitePerProcess": true,
  "SSLVersionMin": "tls1.2"
}
