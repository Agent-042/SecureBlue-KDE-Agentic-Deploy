#!/usr/bin/env python3
import hmac, hashlib, struct, time, base64, requests, json, sys, os, subprocess, re
from concurrent.futures import ThreadPoolExecutor, as_completed

LOCKFILE = "/var/run/proton_computer_backups.lock"
try:
    import fcntl
    lock_fd = open(LOCKFILE, 'w')
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except IOError:
    print("Computer Backups Extractor already running.")
    sys.exit(0)

SECRET = "5J4XTLC2YSQG7XFXAX7EMYXPPTOYYN4W"
USERNAME = "jack.derleth@protonmail.com"
PASSWORD = "Suck-My-Ballz-69-420!!"
LOCAL_STAGE = "/var/tmp/Proton_Drive_Local_Staging/Computer_Backups"
os.makedirs(LOCAL_STAGE, exist_ok=True)

def generate_totp(secret_b32):
    key = base64.b32decode(secret_b32, True)
    now = int(time.time()) // 30
    msg = struct.pack(">Q", now)
    h = hmac.new(key, msg, hashlib.sha1).digest()
    o = h[19] & 15
    val = (struct.unpack(">I", h[o:o+4])[0] & 0x7fffffff) % 1000000
    return f"{val:06d}"

def refresh_rclone_session():
    totp = generate_totp(SECRET)
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Refreshing Proton session with 2FA code {totp}...")
    subprocess.run(["rclone", "config", "delete", "protondrive"], capture_output=True)
    subprocess.run([
        "rclone", "config", "create", "protondrive", "protondrive",
        "username", USERNAME,
        "password", PASSWORD,
        "2fa", totp,
        "--non-interactive"
    ], capture_output=True)

refresh_rclone_session()

with open("/root/.config/rclone/rclone.conf", "r") as f:
    conf = f.read()

token_match = re.search(r'client_access_token\s*=\s*(\w+)', conf)
uid_match = re.search(r'client_uid\s*=\s*(\w+)', conf)

access_token = token_match.group(1)
uid = uid_match.group(1)

headers = {
    "Authorization": f"Bearer {access_token}",
    "x-pm-uid": uid,
    "x-pm-appversion": "Other",
    "x-pm-apiversion": "3",
    "Accept": "application/vnd.protonmail.v1+json"
}

r = requests.get("https://drive-api.proton.me/drive/shares", headers=headers)
print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Shares API response status: {r.status_code}")

shares = r.json().get("Shares", [])
computer_shares = [s for s in shares if s.get("Type") == 3]

print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Total Computer Backup Shares Detected: {len(computer_shares)}")
for idx, cs in enumerate(computer_shares, 1):
    print(f" - Backup Share #{idx}: ShareID={cs.get('ShareID')}")
    print(f"   Root LinkID={cs.get('LinkID')}")
