# Deep Research Runbook: Network Authentication Loop Repair, KDE Wallet Neutralization & Host God Mode Control

## Executive Summary & Root Cause Analysis

### The Flaw: Immutable OS Network Authentication Brick
On immutable Fedora architectures (SecureBlue, Kinoite, Bazzite), NetworkManager defaults to requesting Wi-Fi / 802.1X passwords from a desktop user-space secret agent (`kwalletd5` / `kwalletd6` via D-Bus `org.freedesktop.secrets`).

When **Autologin** is enabled or PAM authentication desynchronizes (e.g., changing login passwords or user account divergence):
1. SDDM logs the user in without prompting for a password.
2. KDE Wallet fails to auto-unlock via PAM because no login password was provided to PAM.
3. NetworkManager prompts KWallet for connection secrets; KWallet blocks indefinitely or fails silently.
4. Subsequent network authentication attempts across **all interfaces** (USB tethering, Wi-Fi, Ethernet) fail continuously.
5. Because OSTree rollbacks only affect `/usr` and `/boot`, the corrupted `/var/home` and `/etc/NetworkManager/system-connections` persistent volumes retain the broken state across rollbacks, deceiving users into thinking the OS is permanently bricked.

---

## 🛠️ The Permanent 3-Phase Fix

### Phase 1: Decouple NetworkManager from Desktop Keyrings
Store Wi-Fi and 802.1X passwords as **System Connections** directly in `/etc/NetworkManager/system-connections/` with `wifi-sec.psk-flags 0` and `connection.permissions ""`.

```bash
# Example for honeypot Wi-Fi
nmcli connection modify "honeypot" wifi-sec.psk-flags 0
nmcli connection modify "honeypot" connection.permissions ""
nmcli connection modify "honeypot" wifi-sec.psk "tag82358235"
systemctl restart NetworkManager
```

This forces NetworkManager to read credentials directly from disk at system boot before SDDM or KDE session initializes, achieving immunity from KWallet/PAM crashes.

---

### Phase 2: Obliterate & Mask KDE Wallet
Neutralize KWallet D-Bus activation and systemd units for target users:

```bash
# Execute automated script
sudo bash .backend/files/ventoy-vector-key/rescue-engine/bin/obliterate_kde_wallet.sh agent-42
```

---

### Phase 3: Tailscale + Mullvad VPN Split-Tunnel Override
Eliminate the WireGuard / Tailscale routing deadlock and killswitch conflict by wrapping `tailscaled` with `mullvad-exclude`:

`/etc/systemd/system/tailscaled.service.d/override.conf`:
```ini
[Unit]
After=mullvad-daemon.service
Wants=mullvad-daemon.service

[Service]
ExecStart=
ExecStart=/usr/bin/mullvad-exclude /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=${PORT} $FLAGS
```

Apply override:
```bash
systemctl daemon-reload
systemctl restart tailscaled
```

---

## 🎮 Host OS "God Mode" Screen & Input Controller

- **Source Code**: [.backend/files/ventoy-vector-key/rescue-engine/bin/host_god_screen_controller.c](file:///.backend/files/ventoy-vector-key/rescue-engine/bin/host_god_screen_controller.c)
- **Binary**: `.backend/files/ventoy-vector-key/rescue-engine/bin/host_god_screen_controller`
- **Usage Commands**:
  ```bash
  # Relative mouse movement
  ./.backend/files/ventoy-vector-key/rescue-engine/bin/host_god_screen_controller --move 100 100

  # Mouse left click
  ./.backend/files/ventoy-vector-key/rescue-engine/bin/host_god_screen_controller --click

  # Send ENTER key (keycode 28)
  ./.backend/files/ventoy-vector-key/rescue-engine/bin/host_god_screen_controller --key 28
  ```
