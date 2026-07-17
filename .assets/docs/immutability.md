Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Immutability settings are applied at the image layer.
# No manual commands required.
# SDDM is configured with a redacted theme; powerdevil policies enforce screen lock.

## Script Logic ##
# File: modules/immutability/module.yml
type: files
files:
  - source: immutability/usr
    destination: /usr

# File: config/files/usr/etc/sddm.conf.d/redacted.conf
[Theme]
Current=redacted

# File: config/files/usr/etc/xdg/powerdevilrc
[General]
configVersion=2

[Module-BrightnessControl]
# No manual brightness control

[Module-Display]
# Display settings locked

[Module-HandleButtonEvents]
# Power button behavior locked

[Module-SuspendAndShutdown]
# Sleep/hibernate policies locked
