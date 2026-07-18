Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 rpm-ostree install -y mullvad-vpn

run0 systemctl enable --now mullvad-daemon

run0 mullvad auto-connect set on

run0 mullvad lockdown-mode set on

run0 mullvad relay set tunnel-protocol udp2tcp

run0 mullvad connect

## Script Logic ##
# File: modules/mullvad-vpn/module.yml
# Adds the Mullvad RPM repository and installs the VPN package
type: rpm-ostree
repos:
  - https://repository.mullvad.net/rpm/stable/mullvad.repo
keys:
  - https://repository.mullvad.net/rpm/mullvad-keyring.asc
install:
  - mullvad-vpn

# File: modules/mullvad-bootstrap/module.yml
# One-shot bootstrap service that locks in udp2tcp and enables lockdown mode
type: files
files:
  - source: mullvad-bootstrap/usr
    destination: /usr

# File: modules/mullvad-bootstrap/usr/bin/mullvad-bootstrap.sh
#!/bin/bash
set -euo pipefail
while ! mullvad status &>/dev/null; do
  sleep 5
done
mullvad auto-connect set on
mullvad lockdown-mode set on
mullvad relay set tunnel-protocol udp2tcp
mullvad connect

# File: modules/mullvad-bootstrap/usr/lib/systemd/system/mullvad-bootstrap.service
[Unit]
Description=Mullvad VPN Bootstrap
After=mullvad-daemon.service
Wants=mullvad-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/bin/mullvad-bootstrap.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

# File: modules/network-lockdown/usr/etc/mullvad-vpn/settings.json
# Pre-seeded daemon settings for lockdown mode
{
  "autoConnect": true,
  "blockWhenDisconnected": true,
  "tunnelProtocol": "udp2tcp"
}

# File: modules/network-lockdown/usr/etc/NetworkManager/dispatcher.d/99-chrome-split-tunnel
#!/bin/bash
# Routes Chrome traffic outside the VPN tunnel while keeping system locked down
if [ "$2" = "up" ] && [ "$CONNECTION_ID" = "mullvad" ]; then
  ip rule add from 172.17.17.0/24 lookup main prio 1000 || true
fi
