#!/usr/bin/env python3
import paramiko

OPENWRT_IP = "192.168.1.1"
PASSWORD = "Daddy-Cum-Zaddy!@#"

def run_openwrt_mullvad_blueprint():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    print(f"[*] Connecting to OpenWrt router {OPENWRT_IP}...")
    client.connect(OPENWRT_IP, username="root", password=PASSWORD, timeout=5)
    print("[+] SSH Authentication Successful.")

    commands = """
# ==== DHCP / dnsmasq hardening ====
uci -q delete dhcp.@dnsmasq[0]
uci set dhcp.@dnsmasq[0]="dnsmasq"
uci set dhcp.@dnsmasq[0].domain="lan"
uci set dhcp.@dnsmasq[0].local="/lan/"
uci set dhcp.@dnsmasq[0].expandhosts="1"
uci set dhcp.@dnsmasq[0].authoritative="1"

# DNS leak prevention: only Mullvad DNS, no peer DNS
uci set dhcp.@dnsmasq[0].noresolv="1"
uci set dhcp.@dnsmasq[0].localservice="0"
uci set dhcp.@dnsmasq[0].rebind_protection="0"
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server="10.64.0.1"

# LAN DHCP range & options
uci -q delete dhcp.lan
uci set dhcp.lan="dhcp"
uci set dhcp.lan.interface="lan"
uci set dhcp.lan.start="100"
uci set dhcp.lan.limit="150"
uci set dhcp.lan.leasetime="12h"
uci set dhcp.lan.dhcp_option="6,10.64.0.1"

# Static leases
uci -q delete dhcp.iphone
uci set dhcp.iphone="host"
uci set dhcp.iphone.name="iphone"
uci set dhcp.iphone.mac="E6:2D:C5:95:DA:D6"
uci set dhcp.iphone.ip="192.168.1.197"
uci set dhcp.iphone.leasetime="infinite"

uci -q delete dhcp.workstation
uci set dhcp.workstation="host"
uci set dhcp.workstation.name="workstation"
uci set dhcp.workstation.mac="74:56:3C:3D:D7:59"
uci set dhcp.workstation.ip="192.168.1.141"
uci set dhcp.workstation.leasetime="infinite"

uci commit dhcp

# ==== Network: WireGuard Mullvad ====
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

uci -q delete network.mullvad_dns_route
uci set network.mullvad_dns_route="route"
uci set network.mullvad_dns_route.interface="mullvad"
uci set network.mullvad_dns_route.target="10.64.0.1"
uci set network.mullvad_dns_route.netmask="255.255.255.255"

uci commit network

# ==== Firewall zones, forwarding, DNS redirect ====
# LAN zone
uci -q delete firewall.lan
uci set firewall.lan="zone"
uci set firewall.lan.name="lan"
uci set firewall.lan.input="ACCEPT"
uci set firewall.lan.output="ACCEPT"
uci set firewall.lan.forward="ACCEPT"
uci add_list firewall.lan.network="lan"

# WAN zone (wan + wwan)
uci -q delete firewall.wan
uci set firewall.wan="zone"
uci set firewall.wan.name="wan"
uci set firewall.wan.input="REJECT"
uci set firewall.wan.output="ACCEPT"
uci set firewall.wan.forward="REJECT"
uci set firewall.wan.masq="1"
uci set firewall.wan.mtu_fix="1"
uci add_list firewall.wan.network="wan"
uci add_list firewall.wan.network="wwan"

# VPN zone (Mullvad)
uci -q delete firewall.vpn
uci set firewall.vpn="zone"
uci set firewall.vpn.name="vpn"
uci set firewall.vpn.input="REJECT"
uci set firewall.vpn.output="ACCEPT"
uci set firewall.vpn.forward="REJECT"
uci set firewall.vpn.masq="1"
uci set firewall.vpn.mtu_fix="1"
uci add_list firewall.vpn.network="mullvad"

# Forwarding: LAN -> VPN only (kill-switch)
uci -q delete firewall.lan_vpn
uci set firewall.lan_vpn="forwarding"
uci set firewall.lan_vpn.src="lan"
uci set firewall.lan_vpn.dest="vpn"

# Intercept all LAN DNS and send to Mullvad DNS
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

uci commit firewall

# ==== mwan3 configuration ====
uci -q delete mwan3.wan
uci set mwan3.wan="interface"
uci set mwan3.wan.enabled="1"
uci set mwan3.wan.family="ipv4"
uci set mwan3.wan.initial_state="online"
uci set mwan3.wan.track_method="ping"
uci set mwan3.wan.reliability="1"
uci set mwan3.wan.timeout="2"
uci set mwan3.wan.interval="5"
uci set mwan3.wan.down="3"
uci set mwan3.wan.up="5"
uci -q delete mwan3.wan.track_ip
uci add_list mwan3.wan.track_ip="1.1.1.1"
uci add_list mwan3.wan.track_ip="8.8.8.8"

uci -q delete mwan3.wwan
uci set mwan3.wwan="interface"
uci set mwan3.wwan.enabled="1"
uci set mwan3.wwan.family="ipv4"
uci set mwan3.wwan.initial_state="online"
uci set mwan3.wwan.track_method="ping"
uci set mwan3.wwan.reliability="1"
uci set mwan3.wwan.timeout="2"
uci set mwan3.wwan.interval="5"
uci set mwan3.wwan.down="3"
uci set mwan3.wwan.up="5"
uci -q delete mwan3.wwan.track_ip
uci add_list mwan3.wwan.track_ip="1.0.0.1"
uci add_list mwan3.wwan.track_ip="9.9.9.9"

uci -q delete mwan3.wan_m1
uci set mwan3.wan_m1="member"
uci set mwan3.wan_m1.interface="wan"
uci set mwan3.wan_m1.metric="10"
uci set mwan3.wan_m1.weight="1"

uci -q delete mwan3.wwan_m2
uci set mwan3.wwan_m2="member"
uci set mwan3.wwan_m2.interface="wwan"
uci set mwan3.wwan_m2.metric="20"
uci set mwan3.wwan_m2.weight="1"

uci -q delete mwan3.failover
uci set mwan3.failover="policy"
uci add_list mwan3.failover.use_member="wan_m1"
uci add_list mwan3.failover.use_member="wwan_m2"
uci set mwan3.failover.last_resort="unreachable"

uci -q delete mwan3.alltraffic
uci set mwan3.alltraffic="rule"
uci set mwan3.alltraffic.src_ip="0.0.0.0/0"
uci set mwan3.alltraffic.dest_ip="0.0.0.0/0"
uci set mwan3.alltraffic.use_policy="failover"

uci -q delete mwan3.wireguard
uci set mwan3.wireguard="rule"
uci set mwan3.wireguard.src_interface="mullvad"
uci set mwan3.wireguard.proto="all"
uci set mwan3.wireguard.dest_ip="0.0.0.0/0"
uci set mwan3.wireguard.use_policy="failover"

uci commit mwan3

# ==== Apply Services ====
/etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart
/etc/init.d/mwan3 restart 2>/dev/null || true

echo 'OPENWRT_MULLVAD_KILLSWITCH_MWAN3_DEPLOYED_SUCCESSFULLY'
"""
    stdin, stdout, stderr = client.exec_command(f'sh -c "{commands}"')
    print("--- Execution Output ---")
    print(stdout.read().decode('utf-8'))
    client.close()
    return True

if __name__ == "__main__":
    run_openwrt_mullvad_blueprint()
