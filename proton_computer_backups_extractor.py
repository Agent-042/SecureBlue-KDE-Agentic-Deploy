#!/usr/bin/env python3
import hmac, hashlib, struct, time, base64, requests, json, sys, os, subprocess, re
from concurrent.futures import ThreadPoolExecutor, as_completed

LOCKFILE = "/var/run/proton_computer_backups.lock"

SECRET = "5J4XTLC2YSQG7XFXAX7EMYXPPTOYYN4W"
USERNAME = "jack.derleth@protonmail.com"
PASSWORD = "Suck-My-Ballz-69-420!!"
LOCAL_STAGE = "/var/tmp/Proton_Drive_Local_Staging/Computer_Backups"
os.makedirs(LOCAL_STAGE, exist_ok=True)
RCLONE_CONF_PATH = "/root/.config/rclone/rclone.conf"

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

def load_credentials():
    """
    Performance Optimization:
    Load existing credentials from cached rclone configuration.
    """
    if not os.path.exists(RCLONE_CONF_PATH):
        return None, None
    try:
        with open(RCLONE_CONF_PATH, "r") as f:
            conf = f.read()
    except Exception:
        return None, None

    token_match = re.search(r'client_access_token\s*=\s*(\w+)', conf)
    uid_match = re.search(r'client_uid\s*=\s*(\w+)', conf)

    if token_match and uid_match:
        return token_match.group(1), uid_match.group(1)
    return None, None

def fetch_shares_with_retry():
    """
    Performance Optimization:
    Try using existing credentials from the rclone configuration first.
    This avoids performing a redundant login & 2FA generation, which involves
    slow external subprocesses and network roundtrips to the Proton auth servers.
    We only perform a full login refresh if cached credentials don't exist, are
    unreadable, or return a non-200 status code from the Proton API.
    """
    access_token, uid = load_credentials()

    if access_token and uid:
        try:
            headers = {
                "Authorization": f"Bearer {access_token}",
                "x-pm-uid": uid,
                "x-pm-appversion": "Other",
                "x-pm-apiversion": "3",
                "Accept": "application/vnd.protonmail.v1+json"
            }
            r = requests.get("https://drive-api.proton.me/drive/shares", headers=headers, timeout=15)
            if r.status_code == 200:
                print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Successfully used cached credentials.")
                return r
            print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Cached credentials invalid (Status: {r.status_code}). Refreshing...")
        except Exception as e:
            print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Failed to use cached credentials ({e}). Refreshing...")

    # Fallback to refreshing session and retrying
    refresh_rclone_session()

    access_token, uid = load_credentials()
    if not access_token or not uid:
        raise RuntimeError("Failed to obtain credentials after session refresh.")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "x-pm-uid": uid,
        "x-pm-appversion": "Other",
        "x-pm-apiversion": "3",
        "Accept": "application/vnd.protonmail.v1+json"
    }
    r = requests.get("https://drive-api.proton.me/drive/shares", headers=headers, timeout=15)
    return r

def acquire_lock():
    try:
        import fcntl
        lock_fd = open(LOCKFILE, 'w')
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return lock_fd
    except (IOError, PermissionError):
        print("Computer Backups Extractor already running or lock file permission denied.")
        sys.exit(0)

def main():
    # Performance Safety:
    # We must assign the returned file descriptor to a variable to keep it alive
    # and prevent garbage collection, which would prematurely close the file and release the lock.
    _lock_fd = acquire_lock()

    r = fetch_shares_with_retry()
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Shares API response status: {r.status_code}")

    shares = r.json().get("Shares", [])
    computer_shares = [s for s in shares if s.get("Type") == 3]

    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] Total Computer Backup Shares Detected: {len(computer_shares)}")
    for idx, cs in enumerate(computer_shares, 1):
        print(f" - Backup Share #{idx}: ShareID={cs.get('ShareID')}")
        print(f"   Root LinkID={cs.get('LinkID')}")

if __name__ == '__main__':
    main()
