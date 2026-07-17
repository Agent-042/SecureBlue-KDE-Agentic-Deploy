Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# OLED G16 Tuning applies display dimming and burn-in protection.
# No manual commands required; the dimming script runs automatically.

## Script Logic ##
# File: modules/oled-g16-tuning/module.yml
type: files
files:
  - source: oled-g16-tuning/usr
    destination: /usr

# File: config/files/usr/bin/g16-oled-dim.sh
#!/bin/bash
# OLED dimming and burn-in protection for G16
# Adjusts brightness based on idle time

# File: config/files/usr/share/doc/secureblue-kde-agentic/G16_TUNING.md
# Documentation for G16-specific hardware tuning
