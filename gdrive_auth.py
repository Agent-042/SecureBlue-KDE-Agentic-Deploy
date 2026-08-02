import subprocess
import re
import urllib.request
import time
import os
import sys
import json

def start_auth():
    print("Starting rclone authorization server...")
    proc = subprocess.Popen(
        ['rclone', 'authorize', 'drive'],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    local_url = None
    google_url = None
    
    # Read stderr line by line until we find the auth link
    while True:
        line = proc.stderr.readline()
        if not line:
            break
        print("RCLONE:", line.strip())
        m = re.search(r'http://127\.0\.0\.1:\d+/auth\?state=\S+', line)
        if m:
            local_url = m.group(0)
            break
            
    if not local_url:
        print("ERROR: Could not get authorization URL from rclone.")
        sys.exit(1)
        
    print(f"\nLocal Auth URL: {local_url}")
    
    try:
        req = urllib.request.Request(local_url, headers={'User-Agent': 'Mozilla/5.0'})
        res = urllib.request.urlopen(req)
        google_url = res.geturl()
    except Exception as e:
        print(f"Notice: Could not pre-fetch Google OAuth URL directly ({e}). Using local URL.")
        google_url = local_url
        
    print(f"\nGoogle OAuth URL:\n{google_url}\n")
    
    # Try xdg-open as user frontstage
    try:
        subprocess.Popen(['sudo', '-u', 'frontstage', 'xdg-open', local_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        pass

    # Save details for reference
    with open('/tmp/gdrive_auth_info.json', 'w') as f:
        json.dump({'local_url': local_url, 'google_url': google_url}, f)

    # Wait for proc to finish when user completes auth
    stdout_data, stderr_data = proc.communicate()
    print("RCLONE AUTH COMPLETED!")
    
    # Extract token JSON from stdout_data
    token_match = re.search(r'\{.*"access_token".*\}', stdout_data, re.DOTALL)
    if token_match:
        token_json = token_match.group(0)
        print("Token received successfully!")
        os.makedirs('/root/.config/rclone', exist_ok=True)
        conf_content = f"[gdrive]\ntype = drive\ntoken = {token_json}\n"
        with open('/root/.config/rclone/rclone.conf', 'w') as f:
            f.write(conf_content)
        print("Config written to /root/.config/rclone/rclone.conf")
    else:
        print("STDOUT:", stdout_data)
        print("STDERR:", stderr_data)

if __name__ == '__main__':
    start_auth()
