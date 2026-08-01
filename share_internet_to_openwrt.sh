#!/usr/bin/env bash
set -euo pipefail

WAN_IF="wlo1"
LAN_IF="${1:-enp0s13f0u4u3u4}"

echo "[+] Enabling IP Forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[+] Setting up NAT Masquerade from ${WAN_IF} to ${LAN_IF}..."
iptables -t nat -A POSTROUTING -o "${WAN_IF}" -j MASQUERADE 2>/dev/null || true
iptables -A FORWARD -i "${WAN_IF}" -o "${LAN_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i "${LAN_IF}" -o "${WAN_IF}" -j ACCEPT 2>/dev/null || true

echo "[+] Internet sharing active from ${WAN_IF} to ${LAN_IF}."
