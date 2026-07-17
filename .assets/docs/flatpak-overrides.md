Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# This module applies hardened permissions to all default-installed Flatpaks.
# It is applied automatically during image build; no manual steps required.

## Script Logic ##
# File: modules/flatpak-overrides/module.yml
type: files
files:
  - source: flatpak-overrides/usr
    destination: /usr

# Files deployed to: config/files/usr/etc/flatpak/overrides/<app-id>
# Each override file contains Context, Session Bus Policy, and System Bus Policy
# sections that lock down the respective Flatpak application.
#
# See individual app guides for the exact override content per application:
#   - guides/google-chrome.md
#   - guides/mullvad-browser.md
#   - guides/keepassxc.md
#   - guides/easyeffects.md
#   - guides/thunderbird.md
#   - guides/element-riot.md
#   - guides/vscodium.md
#   - guides/syncthingy.md
#   - guides/yubico-authenticator.md
