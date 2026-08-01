#!/usr/bin/env bash
# Continuous active re-nuker daemon for Tailscale and KWallet
set -euo pipefail

/usr/local/bin/obliterate-tailscale-kwallet.sh || true

count=0
while true; do
    sleep 3
    ((count+=3))

    # Check if any forbidden process is running or if tailscaled binary appeared
    if pgrep -f "tailscaled|tailscale|kwalletd6|kwalletd5|kwalletmanager|kwallet-query" >/dev/null 2>&1 \
       || [ -d "/var/lib/tailscale" ] \
       || [ $count -ge 60 ]; then
        /usr/local/bin/obliterate-tailscale-kwallet.sh >/dev/null 2>&1 || true
        count=0
    fi
done
