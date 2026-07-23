# Test Environment Plaintext Credentials & Configuration Ledger

> [!NOTE]
> This is a plaintext configuration ledger for the staging/testing environment. These credentials are intentionally stored in plaintext for automated agent scripts, quick local reference, and fleet orchestration.

## 1. Network Credentials

### Honeypot Staging Network
- **SSID**: `honeypot`
- **Security Type**: WPA3-SAE
- **Pre-Shared Key (PSK)**: `tag82358235`
- **Device Interface**: `wlp13s0_ap` (or PCIe `mt7921e` module)
- **Assigned Gateway IP**: `172.17.17.1`

### BlueLink Emergency Access Point (AP)
- **SSID**: `BlueLink`
- **Security Type**: WPA2-PSK (AP Mode)
- **Pre-Shared Key (PSK)**: `BlueSky99!!`
- **Interface**: Local Virtual Access Point bridge (shared IPv4 routing)
- **Cloned MAC Address**: `82:59:D6:E2:3E:8D`

---

## 2. Virtual Machine (Bazzite) Credentials

### Guest Operating System
- **VM Domain Name**: `bazzite-vm`
- **Guest Username**: `bazzite`
- **Guest Password**: `bazzite`
- **Privilege Escalation**: Passwordless `sudo` / `run0` (configured within the guest)

---

## 3. Host & Fleet Tailscale Infrastructure

### Hypervisor Host (Node-42 / G16 Host)
- **Tailscale IPv4**: `100.82.139.39`
- **Tailscale Name**: `node-42`
- **OS Platform**: SecureBlue KDE Fedora (Atomic/Immutable)
- **Default Remote Shell Port**: `22` (SSH)

---

## 4. Virtual Machine Network Definitions

### Private Bridged Link (isolated-vm-net)
- **Hypervisor Gateway IP**: `192.168.123.1` (on `virbr1`)
- **DHCP IP Allocation Range**: `192.168.123.2` - `192.168.123.254`
- **Bazzite Gaming VM Mapping**: `192.168.123.42` (`52:54:00:cc:6b:35`)
- **Bazzite Standard VM MAC**: `52:54:00:ca:f6:8c`
