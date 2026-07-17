Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Tahoe Theming applies macOS-inspired visual styling to KDE Plasma.
# No manual commands required; theming is applied at the image layer.
# Individual users can customize further via System Settings.

## Script Logic ##
# File: modules/tahoe-theming/module.yml
type: files
files:
  - source: tahoe-theming/defaults/xdg
    destination: /usr/etc/xdg
  - source: tahoe-theming/layout-templates
    destination: /usr/share/plasma/layout-templates
  - source: tahoe-theming/shells
    destination: /usr/share/plasma/shells
  - source: tahoe-theming/tahoe-cosmetic-reset
    destination: /usr/libexec/tahoe-cosmetic-reset
  - source: tahoe-theming/tahoe-cosmetic-reset.service
    destination: /usr/lib/systemd/user/tahoe-cosmetic-reset.service
  - source: tahoe-theming/tahoe-gap-optimizer
    destination: /usr/libexec/tahoe-gap-optimizer

# Key files deployed:
#   - /usr/etc/xdg/kdeglobals          → macOS-style color scheme and fonts
#   - /usr/etc/xdg/kwinrc              → Window decoration rules (Klassy, stoplight buttons)
#   - /usr/etc/xdg/kcm_style           → Kvantum theme engine selection
#   - /usr/etc/xdg/plasma-org.kde.plasma.desktop-appletsrc
#                                      → Panel layout and dock configuration
#   - /usr/share/plasma/layout-templates/
#                                      → Default desktop and panel layouts
#   - /usr/libexec/tahoe-cosmetic-reset → Per-login cosmetic reset script
#   - /usr/lib/systemd/user/tahoe-cosmetic-reset.service
#                                      → User service that runs the reset at login
