Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Network Lockdown is applied at the image layer. No manual commands required.
# It pre-seeds Mullvad daemon settings and configures Chrome split-tunnel routing.

## Script Logic ##
# File: modules/network-lockdown/module.yml
type: files
files:
  - source: network-lockdown/usr
    destination: /usr

# File: config/files/usr/etc/mullvad-vpn/settings.json
{
  "autoConnect": true,
  "blockWhenDisconnected": true,
  "tunnelProtocol": "udp2tcp"
}

# File: config/files/usr/etc/NetworkManager/dispatcher.d/99-chrome-split-tunnel
#!/bin/bash
if [ "$2" = "up" ] && [ "$CONNECTION_ID" = "mullvad" ]; then
  ip rule add from 172.17.17.0/24 lookup main prio 1000 || true
fi
