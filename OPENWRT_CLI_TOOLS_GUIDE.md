# OPENWRT AGENTIC CONTROL & CLI TOOLS GUIDE

> **Target Platform**: OpenWrt 24.10+ / Linux 6.12 (MediaTek Filogic 830)  
> **Primary Protocols**: SSH, JSON-RPC (`ubus`), UCI Batch Transactions  
> **GitHub Repository**: [`Agent-042/SecureBlue-KDE-Agentic-Deploy`](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy)  

---

```
                       ┌────────────────────────────────────────────────────────┐
                       │     OPENWRT AGENTIC CONTROL INTERFACE STACK            │
                       └───────────────────────────┬────────────────────────────┘
                                                   │
     ┌─────────────────────────────────────────────┴─────────────────────────────────────────────┐
     ▼                                                                                           ▼
┌────────────────────────────────────────┐                                     ┌────────────────────────────────────────┐
│ 1. UBUS JSON-RPC IPC BUS               │                                     │ 2. UCI BATCH TRANSACTION ENGINE        │
│ - ubus call system info                │                                     │ - uci batch << EOF                     │
│ - ubus call network.interface dump     │                                     │ - Transactional set/commit/revert     │
│ - Zero-Parsing Native JSON Responses   │                                     │ - Config validation before commit      │
└──────────────────┬─────────────────────┘                                     └──────────────────┬─────────────────────┘
                   │                                                                              │
                   └───────────────────────────────┬──────────────────────────────────────────────┘
                                                   │
                                                   ▼
                       ┌────────────────────────────────────────────────────────┐
                       │ 3. ADVANCED UTILITIES & FIREWALL CONTROL               │
                       │ - owipcalc (Subnet & CIDR Range Calculator)            │
                       │ - fw4 / nftables (Real-time Ruleset Verification)       │
                       │ - rpcd / uhttpd-mod-ubus (Remote HTTP JSON-RPC API)   │
                       └────────────────────────────────────────────────────────┘
```

---

## 1. Top 5 OpenWrt CLI Tools for AI/Agentic Control

Yes! Operating OpenWrt becomes **vastly cleaner, faster, and error-free** when using specialized OpenWrt tools instead of parsing plain text outputs:

### 1. `ubus` (OpenWrt Micro Bus IPC System) — **THE GAME CHANGER**
* **Why it's essential for AI agents**: `ubus` outputs native, structured **JSON** directly from the OpenWrt kernel & daemons. No regex or regex parsing required.
* **Key Commands**:
  ```bash
  # Get system memory, load, uptime, and filesystem status
  ubus call system info

  # Get live network interfaces, IP addresses, and throughput
  ubus call network.interface dump

  # Get active DHCP leases and MAC mappings
  ubus call dhcp leases

  # Get connected Wi-Fi clients & signal strength (RSSI)
  ubus call hostapd.wlan0 get_clients
  ```
* **Remote JSON-RPC over HTTP (`uhttpd-mod-ubus` / `rpcd`)**:  
  By enabling `luci-mod-rpc` or `uhttpd-mod-ubus`, an AI agent can issue HTTP POST requests to `http://192.168.1.1/ubus` with JSON payloads (`{"jsonrpc": "2.0", "method": "call", ...}`) without SSH overhead!

---

### 2. `uci batch` (Transactional Unified Configuration Engine)
* **Why it's essential for AI agents**: Instead of executing dozens of individual `uci set` commands over separate SSH calls, `uci batch` executes an entire multi-stage configuration block as a single atomic transaction.
* **Example Usage**:
  ```bash
  uci batch << 'EOF'
  set firewall.lan.input='REJECT'
  set firewall.wan.input='DROP'
  set network.mullvad=interface
  set network.mullvad.proto='wireguard'
  commit firewall
  commit network
  EOF
  ```

---

### 3. `owipcalc` (OpenWrt Built-in IP Calculator)
* **Why it's essential for AI agents**: Simplifies CIDR calculations, netmask conversions, broadcast addresses, and IP range parsing directly inside OpenWrt scripts without external Python or bash dependencies.
* **Example Usage**:
  ```bash
  # Calculate network ID and broadcast address for 192.168.1.141/24
  owipcalc 192.168.1.141/24 network broadcast

  # Check if an IP address is within a private RFC1918 range
  owipcalc 10.64.0.1 private && echo "Private IP"
  ```

---

### 4. `fw4` / `nft` CLI (Firewall 4 Ruleset Engine)
* **Why it's essential for AI agents**: `fw4` handles nftables rule generation in OpenWrt 24.10+.
* **Key Commands**:
  ```bash
  # Validate firewall configuration syntax before applying
  fw4 check

  # Print active nftables ruleset in human-readable or JSON format
  nft -j list ruleset

  # Atomically reload firewall rules
  fw4 reload
  ```

---

### 5. `luci-app-ttyd` / `ttyd` (Web Terminal Service)
* **Why it's essential for AI agents**: Runs a lightweight C-based web terminal daemon over WebSockets (port 7681 or reverse-proxied under LuCI), enabling instant browser-based terminal control for human and AI operators alike.

---

## 2. Comparison: Plain SSH Commands vs. `ubus` JSON API

| Capability | Standard Shell Commands | `ubus` JSON IPC API |
| :--- | :--- | :--- |
| **Output Format** | Plain text (requires regex parsing) | **Structured JSON** (direct dictionary parsing) |
| **Execution Latency** | Slow (spawns sub-shells) | **Ultra-Fast** (< 1ms IPC response) |
| **Reliability** | Fragile (breaks if string format changes) | **Stable API Contract** |
| **Transaction Safety** | Partial | **Atomic (`uci batch`)** |
| **Remote Access** | SSH only | **SSH or HTTP POST (`/ubus`)** |
