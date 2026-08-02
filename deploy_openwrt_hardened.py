#!/usr/bin/env python3
import os
import paramiko
import sys

OPENWRT_IP = "192.168.1.1"
PASSWORD = os.environ.get("OPENWRT_ROUTER_PASSWORD")

def deploy_hardened_openwrt_appliance():
    if not PASSWORD:
        raise ValueError("Security Error: OPENWRT_ROUTER_PASSWORD environment variable is not set.")
    print(f"[*] Connecting to OpenWrt router {OPENWRT_IP} via SSH...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(OPENWRT_IP, username="root", password=PASSWORD, timeout=5)
    print("[+] SSH Authentication Successful.")

    commands = """
# ==== STAGE 6.1: Kernel Hardening (sysctl) ====
cat << 'EOF' > /tmp/sysctl_hardening.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
EOF

cat /tmp/sysctl_hardening.conf >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf 2>/dev/null || true

# ==== STAGE 6.2: Zone-Based Firewall Hardening (fw4) ====
# Set restrictive defaults
uci set firewall.@defaults[0].input='DROP'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='DROP'
uci set firewall.@defaults[0].synflood_protect='1'

# 6.4: Disable Hardware & Software Flow Offloading for VPN compatibility
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci set firewall.@defaults[0].flow_offloading='0'

# Configure LAN Zone (REJECT for diagnostics)
uci set firewall.lan.input='REJECT'
uci set firewall.lan.output='ACCEPT'
uci set firewall.lan.forward='ACCEPT'

# Configure WAN Zone (DROP for stealth)
uci set firewall.wan.input='DROP'
uci set firewall.wan.output='ACCEPT'
uci set firewall.wan.forward='DROP'
uci set firewall.wan.masq='1'
uci set firewall.wan.mtu_fix='1'

# Create VPN Zone (Mullvad)
uci -q delete firewall.vpn
uci set firewall.vpn="zone"
uci set firewall.vpn.name="vpn"
uci set firewall.vpn.input="DROP"
uci set firewall.vpn.output="ACCEPT"
uci set firewall.vpn.forward="DROP"
uci set firewall.vpn.masq="1"
uci set firewall.vpn.mtu_fix="1"
uci add_list firewall.vpn.network="mullvad"

# 7.4: VPN Kill-Switch: Forward LAN strictly to VPN (Delete LAN->WAN forwarding)
uci -q delete firewall.lan_vpn
uci set firewall.lan_vpn="forwarding"
uci set firewall.lan_vpn.src="lan"
uci set firewall.lan_vpn.dest="vpn"

# Delete any existing lan->wan forwarding rules
for idx in $(uci show firewall | grep 'forwarding' | grep 'dest=.wan.' | cut -d'.' -f2 | cut -d'=' -f1); do
    uci -q delete firewall.$idx
done

# ==== STAGE 6.3: Advanced Ingress Filtering (BCP38 Bogon Filter) ====
mkdir -p /etc/nftables.d
cat << 'EOF' > /etc/nftables.d/10-bcp38-filter.nft
# /etc/nftables.d/10-bcp38-filter.nft
set rfc1918_bogons {
    type ipv4_addr
    flags interval
    elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }
}

chain bcp38_ingress {
    type filter hook ingress device wan priority filter -500;
    ip saddr @rfc1918_bogons drop comment "BCP38 Drop"
}
EOF

# ==== STAGE 7.2 & 7.3: Mullvad WireGuard VPN & Static Endpoint Route ====
uci -q delete network.mullvad
uci set network.mullvad="interface"
uci set network.mullvad.proto="wireguard"
uci set network.mullvad.private_key="SKPpzGfUzIf+C4vtV4KO7e4ekkDOdemSDcpZAuSg+GU="
uci set network.mullvad.listen_port="51820"
uci set network.mullvad.addresses="10.64.0.1/32"

uci -q delete network.mullvad_peer
uci set network.mullvad_peer="wireguard_peer"
uci set network.mullvad_peer.public_key="x6eE8E9i9Rk1hB4fJmJ2Q0kK1+E9R1G/84nC0G+XwWw="
uci set network.mullvad_peer.endpoint_host="198.54.135.202"
uci set network.mullvad_peer.endpoint_port="51820"
uci set network.mullvad_peer.allowed_ips="0.0.0.0/0"
uci set network.mullvad_peer.persistent_keepalive="25"
uci set network.mullvad_peer.route_allowed_ips="0"

# Static Route to Prevent Routing Deadlock for Mullvad Server Endpoint
uci -q delete network.vpn_endpoint_route
uci set network.vpn_endpoint_route="route"
uci set network.vpn_endpoint_route.interface="wan"
uci set network.vpn_endpoint_route.target="198.54.135.202"
uci set network.vpn_endpoint_route.netmask="255.255.255.255"

uci commit network

# ==== STAGE 7.5: Hardened DNS & Anti-Leak Infrastructure ====
uci -q delete dhcp.@dnsmasq[0]
uci set dhcp.@dnsmasq[0]="dnsmasq"
uci set dhcp.@dnsmasq[0].domain="lan"
uci set dhcp.@dnsmasq[0].local="/lan/"
uci set dhcp.@dnsmasq[0].expandhosts="1"
uci set dhcp.@dnsmasq[0].authoritative="1"
uci set dhcp.@dnsmasq[0].noresolv="1"
uci set dhcp.@dnsmasq[0].localservice="0"
uci set dhcp.@dnsmasq[0].rebind_protection="0"
uci set dhcp.@dnsmasq[0].cachesize="1000"
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server="10.64.0.1"

# Firewall DNS Interception & DoT Block
uci -q delete firewall.dns_int
uci set firewall.dns_int="redirect"
uci set firewall.dns_int.name="Intercept-DNS"
uci set firewall.dns_int.family="any"
uci set firewall.dns_int.proto="tcp udp"
uci set firewall.dns_int.src="lan"
uci set firewall.dns_int.src_dport="53"
uci set firewall.dns_int.dest_port="53"
uci set firewall.dns_int.target="DNAT"
uci set firewall.dns_int.dest_ip="10.64.0.1"

uci -q delete firewall.block_dot
uci set firewall.block_dot="rule"
uci set firewall.block_dot.name="Block-Client-DoT"
uci set firewall.block_dot.src="lan"
uci set firewall.block_dot.dest="wan"
uci set firewall.block_dot.proto="tcp udp"
uci set firewall.block_dot.dest_port="853"
uci set firewall.block_dot.target="REJECT"

# ==== STAGE 8: Segregated Access Control & Static Leases ====
uci -q delete dhcp.workstation
uci set dhcp.workstation="host"
uci set dhcp.workstation.name="workstation"
uci set dhcp.workstation.mac="74:56:3C:3D:D7:59"
uci set dhcp.workstation.ip="192.168.1.141"
uci set dhcp.workstation.leasetime="infinite"

uci -q delete dhcp.iphone
uci set dhcp.iphone="host"
uci set dhcp.iphone.name="iphone"
uci set dhcp.iphone.mac="E6:2D:C5:95:DA:D6"
uci set dhcp.iphone.ip="192.168.1.197"
uci set dhcp.iphone.leasetime="infinite"

uci commit dhcp

# Allow Admin Management from Workstation (192.168.1.141)
uci -q delete firewall.allow_admin_ssh
uci set firewall.allow_admin_ssh="rule"
uci set firewall.allow_admin_ssh.name="Allow-Admin-SSH"
uci set firewall.allow_admin_ssh.src="lan"
uci set firewall.allow_admin_ssh.src_ip="192.168.1.141"
uci set firewall.allow_admin_ssh.dest_port="22"
uci set firewall.allow_admin_ssh.proto="tcp"
uci set firewall.allow_admin_ssh.target="ACCEPT"

uci -q delete firewall.allow_admin_https
uci set firewall.allow_admin_https="rule"
uci set firewall.allow_admin_https.name="Allow-Admin-HTTPS"
uci set firewall.allow_admin_https.src="lan"
uci set firewall.allow_admin_https.src_ip="192.168.1.141"
uci set firewall.allow_admin_https.dest_port="443"
uci set firewall.allow_admin_https.proto="tcp"
uci set firewall.allow_admin_https.target="ACCEPT"

uci commit firewall

# ==== Apply Network & Firewall Services ====
/etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart

echo 'HARDENED_OPENWRT_APPLIANCE_DEPLOYED_SUCCESSFULLY'
"""

    stdin, stdout, stderr = client.exec_command(f'sh -c "{commands}"')
    print("--- Deployment Output ---")
    print(stdout.read().decode('utf-8'))
    client.close()
    return True

if __name__ == "__main__":
    deploy_hardened_openwrt_appliance()
