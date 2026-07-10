#!/usr/bin/env bash
# install-mullvad-vpn.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add the official Mullvad repository and GPG key.
curl -fsSL --retry 3 \
  https://repository.mullvad.net/rpm/mullvad-keyring.asc \
  -o /etc/pki/rpm-gpg/mullvad-keyring.asc

cat > /etc/yum.repos.d/mullvad.repo <<'EOF'
[mullvad-stable]
name=Mullvad VPN Stable
baseurl=https://repository.mullvad.net/rpm/stable/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/mullvad-keyring.asc
EOF

rpm-ostree install -y mullvad-vpn

# Install the bootstrap service that applies udp2tcp + lockdown mode once the
# daemon is reachable.
install -Dm755 "${SCRIPT_DIR}/mullvad-bootstrap.sh" /usr/bin/mullvad-bootstrap.sh
install -Dm644 "${SCRIPT_DIR}/mullvad-bootstrap.service" \
  /usr/lib/systemd/system/mullvad-bootstrap.service
