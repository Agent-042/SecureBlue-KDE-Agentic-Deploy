#!/usr/bin/env python3
import paramiko
import sys
import time

OPENWRT_IP = "192.168.1.1"
PASSWORDS = ["Daddy-Cum-Zaddy!@#", "Lick-My-Ass!@#", "goodlife", "admin", "root"]

def run_remote_config():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    connected = False
    active_password = None
    
    for pwd in PASSWORDS:
        try:
            print(f"[*] Attempting SSH connection to {OPENWRT_IP} with password: '{pwd}'...")
            client.connect(OPENWRT_IP, username="root", password=pwd, timeout=4)
            connected = True
            active_password = pwd
            print(f"[+] SUCCESS: Authenticated on OpenWrt with password: '{pwd}'")
            break
        except paramiko.AuthenticationException:
            continue
        except Exception as e:
            print(f"[!] Connection attempt error: {e}")
            continue
            
    if not connected:
        print("[!] Could not authenticate on OpenWrt via SSH.")
        return False
        
    commands = """
# 1. iPhone DHCP Static Lease
uci set dhcp.iphone=host
uci set dhcp.iphone.name='iPhone'
uci set dhcp.iphone.mac='E6:2D:C5:95:DA:D6'
uci set dhcp.iphone.ip='192.168.1.197'
uci set dhcp.iphone.leasetime='infinite'
uci commit dhcp

# 2. Configure Wired WAN & Wireless Repeater Network Interfaces
uci set network.wan=interface
uci set network.wan.device='eth0'
uci set network.wan.proto='dhcp'
uci set network.wan.metric='10'

uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.metric='20'
uci commit network

# 3. Add Repeater Client for SSID honeypot
uci set wireless.repeater_honeypot=wifi-iface
uci set wireless.repeater_honeypot.device='radio0'
uci set wireless.repeater_honeypot.mode='sta'
uci set wireless.repeater_honeypot.network='wwan'
uci set wireless.repeater_honeypot.ssid='honeypot'
uci set wireless.repeater_honeypot.encryption='psk2'
uci commit wireless

# 4. Restart Services
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo 'OPENWRT_CONFIG_APPLIED_SUCCESSFULLY'
"""
    print("[+] Executing configuration payload on OpenWrt...")
    stdin, stdout, stderr = client.exec_command(f'sh -c "{commands}"')
    
    out = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')
    
    print("--- OpenWrt Output ---")
    print(out)
    if err:
        print(err)
        
    client.close()
    return True

if __name__ == "__main__":
    run_remote_config()
