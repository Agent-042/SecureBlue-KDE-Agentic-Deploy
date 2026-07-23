#!/usr/bin/env bash
# Obliterate KDE Wallet & Enforce System-Level Network Connections
set -euo pipefail

TARGET_USER="${1:-agent-42}"
USER_HOME="/var/home/${TARGET_USER}"

echo "[*] Obliterating KDE Wallet for target user: ${TARGET_USER}..."

if [ -d "${USER_HOME}" ]; then
    # 1. Destroy existing wallet files
    rm -rf "${USER_HOME}/.local/share/kwalletd/"
    rm -rf "${USER_HOME}/.kde/share/apps/kwallet/"

    # 2. Write persistent kwalletrc disabling wallet
    mkdir -p "${USER_HOME}/.config"
    cat <<EOF > "${USER_HOME}/.config/kwalletrc"
[Wallet]
Enabled=false
[Migration]
MigrateTo3rdParty=true
[KSecretD]
Enabled=false
EOF

    # 3. Mask D-Bus service triggers
    mkdir -p "${USER_HOME}/.local/share/dbus-1/services/"
    ln -sf /dev/null "${USER_HOME}/.local/share/dbus-1/services/org.kde.kwalletd5.service"
    ln -sf /dev/null "${USER_HOME}/.local/share/dbus-1/services/org.kde.kwalletd6.service"

    # Fix ownership
    chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config" "${USER_HOME}/.local"
    echo "[+] User-space KDE Wallet neutralized for ${TARGET_USER}."
else
    echo "[!] Target user home directory ${USER_HOME} not found, skipping user file edits."
fi

# 4. Enforce system connections for NetworkManager
echo "[*] Enforcing system-level secret storage across all NetworkManager profiles..."
for nm_file in /etc/NetworkManager/system-connections/*.nmconnection; do
    if [ -f "$nm_file" ]; then
        echo "[+] Processing $nm_file..."
        sed -i 's/psk-flags=1/psk-flags=0/g' "$nm_file" || true
        sed -i 's/psk-flags=2/psk-flags=0/g' "$nm_file" || true
    fi
done

systemctl restart NetworkManager
echo "[+] NetworkManager restarted with system-level secrets enforced."
