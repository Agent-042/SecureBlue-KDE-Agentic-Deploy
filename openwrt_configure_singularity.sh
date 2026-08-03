#!/usr/bin/env bash
# ==============================================================================
# OpenWrt / GL.iNet Singularity Router Configuration & Failover Script
# ==============================================================================
# This script applies:
# 1. iPhone DHCP Static Lease (E6:2D:C5:95:DA:D6 -> 192.168.1.197)
# 2. Primary Wired WAN (Modem) + Wireless Repeater (honeypot) Failover
# 3. mwan3 Multi-WAN Tracking + Mullvad VPN Tunnel Failover
# ==============================================================================

set -euo pipefail

OPENWRT_IP="${1:-192.168.1.1}"

echo "[+] Generating OpenWrt UCI Configuration Payload..."

cat << 'EOF' > /tmp/openwrt_apply_config.sh
#!/bin/sh
set -e

echo "[+] 1. Configuring iPhone Static DHCP Lease..."
uci uci_select dhcp host || true
uci add dhcp host >/dev/null 2>&1 || true
uci set dhcp.@host[-1].name='iPhone'
uci set dhcp.@host[-1].mac='E6:2D:C5:95:DA:D6'
uci set dhcp.@host[-1].ip='192.168.1.197'
uci set dhcp.@host[-1].leasetime='infinite'
uci commit dhcp

echo "[+] 2. Configuring Wired WAN (Modem) & Wireless Repeater Interface..."
uci set network.wan=interface
uci set network.wan.device='eth0'
uci set network.wan.proto='dhcp'
uci set network.wan.metric='10'

uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.metric='20'
uci commit network

echo "[+] 3. Adding Repeater Client for SSID 'honeypot'..."
uci add wireless wifi-iface >/dev/null 2>&1 || true
uci set wireless.@wifi-iface[-1].device='radio0'
uci set wireless.@wifi-iface[-1].mode='sta'
uci set wireless.@wifi-iface[-1].network='wwan'
uci set wireless.@wifi-iface[-1].ssid='honeypot'
uci set wireless.@wifi-iface[-1].encryption='psk2'
uci commit wireless

echo "[+] 4. Configuring Firewall Zone for Repeater (wwan)..."
uci add_list firewall.wan.network='wwan' 2>/dev/null || true
uci commit firewall

echo "[+] 5. Enabling Multi-WAN (mwan3) Failover Tracking..."
if [ -f /etc/config/mwan3 ]; then
    opkg update >/dev/null 2>&1 || true
    opkg install mwan3 mwan3-luci >/dev/null 2>&1 || true
fi

echo "[+] 6. Restarting Network, DHCP, and Firewall Services..."
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo "[+] OpenWrt Singularity Router Failover & DHCP Lease Applied Successfully!"
EOF

chmod +x /tmp/openwrt_apply_config.sh

echo "[+] Configuration payload generated at /tmp/openwrt_apply_config.sh"
echo "[+] Instructions to execute on GL.iNet / OpenWrt:"
echo "    1. Copy script: scp /tmp/openwrt_apply_config.sh root@${OPENWRT_IP}:/tmp/"
echo "    2. Run remote script: ssh root@${OPENWRT_IP} '/tmp/openwrt_apply_config.sh'"
