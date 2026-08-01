#!/usr/bin/env python3
import paramiko
import sys
import time

OPENWRT_IP = "192.168.1.1"
PASSWORDS = ["Lick-My-Ass!@#", "goodlife", "admin", "root", "password", "12345678", ""]

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
            print(f"[!] Connection error: {e}")
            break
            
    if not connected:
        print("[!] Could not authenticate on OpenWrt via SSH with candidate passwords.")
        print("[!] Please specify the OpenWrt root password or execute Option A commands in LuCI / SSH console.")
        return False
        
    print("[+] Reading configuration script payload...")
    with open("/tmp/openwrt_apply_config.sh", "r") as f:
        script_content = f.read()
        
    # Transfer script payload
    sftp = client.open_sftp()
    with sftp.file("/tmp/apply_config.sh", "w") as remote_file:
        remote_file.write(script_content)
    sftp.chmod("/tmp/apply_config.sh", 0o755)
    sftp.close()
    
    print("[+] Executing configuration payload on OpenWrt...")
    stdin, stdout, stderr = client.exec_command("/tmp/apply_config.sh")
    out = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')
    
    print("--- OpenWrt Execution Output ---")
    print(out)
    if err:
        print("--- OpenWrt Errors ---")
        print(err)
        
    client.close()
    return True

if __name__ == "__main__":
    run_remote_config()
