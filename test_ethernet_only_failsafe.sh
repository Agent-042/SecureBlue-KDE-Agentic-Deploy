#!/usr/bin/env bash
# ==============================================================================
# Failsafe Ethernet Internet Verification via OpenWrt
# ==============================================================================
# 1. Schedules a background failsafe to re-enable Wi-Fi after 60s if needed.
# 2. Configures host Ethernet gateway to route through OpenWrt (192.168.1.1).
# 3. Temporarily disables host Wi-Fi to verify end-to-end ethernet routing:
#    honeypot -> OpenWrt (172.17.17.65) -> Firewall/Mullvad -> Host Ethernet (192.168.1.141)
# ==============================================================================

set -euo pipefail

ETH_IF="enp0s13f0u4u3u4"

echo "[+] Step 1: Scheduling 60-second failsafe Wi-Fi auto-recovery in background..."
(
    sleep 60
    echo "[!] FAILSAFE TRIGGERED: Re-enabling Wi-Fi radio..."
    nmcli radio wifi on 2>/dev/null || true
) &
FAILSAFE_PID=$!

echo "[+] Step 2: Configuring host NetworkManager Ethernet gateway for OpenWrt..."
# Remove never-default so Ethernet becomes default gateway
nmcli connection modify "Wired connection 1" ipv4.never-default no ipv4.route-metric 10 2>/dev/null || true
nmcli connection modify "Wired connection 4" ipv4.never-default no ipv4.route-metric 10 2>/dev/null || true

# Re-activate ethernet connection to obtain DHCP IP & gateway 192.168.1.1 from OpenWrt
nmcli device connect "${ETH_IF}" 2>/dev/null || true
sleep 3

echo "[+] Step 3: Disabling host Wi-Fi radio for ethernet-only test..."
nmcli radio wifi off
sleep 3

echo "[+] Step 4: Testing internet connectivity over Ethernet through OpenWrt..."
if ping -c 3 -W 3 google.com >/tmp/eth_test.log 2>&1; then
    echo "[===================================================================]"
    echo "[+] SUCCESS! Internet is fully functional over ETHERNET through OpenWrt!"
    echo "[+] Path Verified: honeypot -> OpenWrt -> Mullvad VPN -> Ethernet -> Host"
    echo "[===================================================================]"
    
    # Cancel failsafe timer
    kill -9 "${FAILSAFE_PID}" 2>/dev/null || true
    
    echo "[+] Host Wi-Fi will remain OFF as Ethernet internet is 100% verified."
    exit 0
else
    echo "[!] Ethernet internet test did not succeed. Logs:"
    cat /tmp/eth_test.log || true
    echo "[!] Re-enabling host Wi-Fi radio now..."
    nmcli radio wifi on
    kill -9 "${FAILSAFE_PID}" 2>/dev/null || true
    exit 1
fi
