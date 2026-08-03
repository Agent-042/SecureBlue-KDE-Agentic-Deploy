#!/usr/bin/env bash
# Obliterate Tailscale and KWallet script
set -euo pipefail

echo "=================================================="
echo "[OBLITERATE] Executing active nuke for Tailscale and KWallet..."
echo "=================================================="

# 1. Kill any running processes
pkill -9 -f tailscaled 2>/dev/null || true
pkill -9 -f tailscale 2>/dev/null || true
pkill -9 -f kwalletd6 2>/dev/null || true
pkill -9 -f kwalletd5 2>/dev/null || true
pkill -9 -f kwalletmanager 2>/dev/null || true
pkill -9 -f kwallet-query 2>/dev/null || true

# 2. Mask systemd services
systemctl stop tailscaled.service 2>/dev/null || true
systemctl mask tailscaled.service 2>/dev/null || true
systemctl --global mask kwalletd5.service kwalletd6.service plasma-kwallet.service kwalletmanager.service tailscaled.service 2>/dev/null || true

# 3. Clean up systemd service unit overrides
rm -rf /etc/systemd/system/tailscaled.service.d /etc/systemd/system/tailscaled.service 2>/dev/null || true
systemctl mask tailscaled.service 2>/dev/null || true

# 4. Wipe state, log, socket, and cache directories
rm -rf /var/lib/tailscale /run/tailscale 2>/dev/null || true
for userdir in /var/home/* /var/roothome /root; do
    if [ -d "$userdir" ]; then
        rm -rf "$userdir/.local/share/tailscale" 2>/dev/null || true
        rm -rf "$userdir/.local/share/kwalletd" 2>/dev/null || true
        rm -rf "$userdir/.cache/tailscale" 2>/dev/null || true
        rm -rf "$userdir/.cache/kwallet*" 2>/dev/null || true

        # Force kwalletrc to Enabled=false
        mkdir -p "$userdir/.config" "$userdir/.local/share/dbus-1/services"
        cat << 'EOF' > "$userdir/.config/kwalletrc"
[Wallet]
Enabled=false
First Use=false
Use One Wallet=false

[Migration]
MigrateTo3rdParty=true

[KSecretD]
Enabled=false
EOF
        cat << 'EOF' > "$userdir/.config/kwalletmanagerrc"
[Wallet]
Enabled=false
EOF
        ln -sf /dev/null "$userdir/.local/share/dbus-1/services/org.kde.kwalletd5.service" 2>/dev/null || true
        ln -sf /dev/null "$userdir/.local/share/dbus-1/services/org.kde.kwalletd6.service" 2>/dev/null || true
    fi
done

# 5. Maintain dummy wrapper binaries in /usr/local/bin
WRAPPERS=("tailscale" "tailscaled" "kwalletd6" "kwalletd5" "kwallet-query" "kwalletmanager" "kwalletmanager5")
for bin in "${WRAPPERS[@]}"; do
    target="/usr/local/bin/$bin"
    if [ ! -f "$target" ] || grep -q -v "nuked" "$target" 2>/dev/null; then
        rm -f "$target" 2>/dev/null || true
        cat << EOF > "$target"
#!/bin/sh
echo "$bin has been nuked from this system." >&2
exit 1
EOF
        chmod 755 "$target"
    fi
done

# 6. Maintain DBus overrides
mkdir -p /etc/dbus-1/services
cat << 'EOF' > /etc/dbus-1/services/org.kde.kwalletd6.service
[D-BUS Service]
Name=org.kde.kwalletd6
Exec=/bin/false
EOF

cat << 'EOF' > /etc/dbus-1/services/org.kde.kwalletd5.service
[D-BUS Service]
Name=org.kde.kwalletd5
Exec=/bin/false
EOF

cat << 'EOF' > /etc/dbus-1/services/org.freedesktop.impl.portal.desktop.kwallet.service
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.kwallet
Exec=/bin/false
EOF

cat << 'EOF' > /etc/dbus-1/services/org.kde.kwalletmanager.service
[D-BUS Service]
Name=org.kde.kwalletmanager
Exec=/bin/false
EOF

# 7. System-wide kwalletrc
mkdir -p /etc/xdg
cat << 'EOF' > /etc/xdg/kwalletrc
[Wallet]
Enabled=false
First Use=false
Use One Wallet=false

[Migration]
MigrateTo3rdParty=true

[KSecretD]
Enabled=false
EOF

echo "[OBLITERATE] Tailscale and KWallet obliteration complete!"
