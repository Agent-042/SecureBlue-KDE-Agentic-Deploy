#!/bin/bash
# G16 IRONCLAD NETWORK DEPLOYMENT
set -euo pipefail

TARGET_USER="agent-42"
USER_HOME="/var/home/${TARGET_USER}"

echo "[*] Decoupling NetworkManager from KWallet..."
for conn in $(nmcli -t -f NAME connection show); do
    nmcli connection modify "$conn" connection.permissions "" 2>/dev/null || true
    nmcli connection modify "$conn" wifi-sec.psk-flags 0 2>/dev/null || true
done
systemctl restart NetworkManager

echo "[*] Eradicating KWallet configurations and databases..."
rm -rf "${USER_HOME}/.local/share/kwalletd/" "${USER_HOME}/.kde/share/apps/kwallet/"

echo "[*] Building the KWallet Prison..."
mkdir -p "${USER_HOME}/.config" "${USER_HOME}/.local/share/dbus-1/services/"
cat <<EOF > "${USER_HOME}/.config/kwalletrc"
[Wallet]
Enabled=false
[Migration]
MigrateTo3rdParty=true
[KSecretD]
Enabled=false
EOF

ln -sf /dev/null "${USER_HOME}/.local/share/dbus-1/services/org.kde.kwalletd5.service"
ln -sf /dev/null "${USER_HOME}/.local/share/dbus-1/services/org.kde.kwalletd6.service"
chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}"

echo "[*] Masking Systemd & Neutering PAM..."
sudo -u "${TARGET_USER}" XDG_RUNTIME_DIR="/run/user/1000" systemctl --user mask plasma-kwallet-pam plasma-kwalletd || true

# Strip KWallet from PAM stack in /etc/ (OSTree mutable layer)
sed -i '/pam_kwallet/d' /etc/pam.d/sddm 2>/dev/null || true
sed -i '/pam_kwallet/d' /etc/pam.d/sddm-autologin 2>/dev/null || true
sed -i '/pam_kwallet/d' /etc/pam.d/login 2>/dev/null || true

echo "[+] G16 Network is now IRONCLAD."
