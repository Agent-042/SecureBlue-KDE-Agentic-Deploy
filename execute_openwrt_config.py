#!/usr/bin/env python3
import paramiko

OPENWRT_IP = "192.168.1.1"
PASSWORD = "Daddy-Cum-Zaddy!@#"

def run_blueprint():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    print(f"[*] Connecting to OpenWrt router {OPENWRT_IP}...")
    client.connect(OPENWRT_IP, username="root", password=PASSWORD, timeout=5)
    print("[+] SSH Authentication Successful.")

    commands = """
# 1. Interface & Metric Optimization (Disable ISP DNS)
uci set network.wan.metric='10'
uci set network.wan.peerdns='0'
uci set network.wwan.metric='20'
uci set network.wwan.peerdns='0'
uci commit network

# 2. DNSMasq Hardening
uci set dhcp.@dnsmasq[0].noresolv='0'
uci set dhcp.@dnsmasq[0].localuse='1'
uci set dhcp.@dnsmasq[0].strictorder='1'
uci set dhcp.@dnsmasq[0].domainneeded='1'
uci set dhcp.@dnsmasq[0].boguspriv='1'
uci delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'

# 3. Static DHCP Leases (Workstation & iPhone)
uci set dhcp.iphone=host
uci set dhcp.iphone.name='iphone.lan'
uci set dhcp.iphone.mac='E6:2D:C5:95:DA:D6'
uci set dhcp.iphone.ip='192.168.1.197'
uci set dhcp.iphone.leasetime='infinite'

uci set dhcp.workstation=host
uci set dhcp.workstation.name='workstation.lan'
uci set dhcp.workstation.mac='74:56:3C:3D:D7:59'
uci set dhcp.workstation.ip='192.168.1.141'
uci set dhcp.workstation.leasetime='infinite'
uci commit dhcp

# 4. fw4 Firewall Rules & NAT
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'
uci set firewall.wan.masquerade='1'
uci set firewall.wan.input='REJECT'
uci set firewall.wan.forward='REJECT'

uci commit firewall
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo 'OPENWRT_BLUEPRINT_APPLIED_SUCCESSFULLY'
"""
    stdin, stdout, stderr = client.exec_command(f'sh -c "{commands}"')
    print("--- Execution Output ---")
    print(stdout.read().decode('utf-8'))
    client.close()
    return True

if __name__ == "__main__":
    run_blueprint()
