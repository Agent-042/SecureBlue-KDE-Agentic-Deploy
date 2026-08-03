#!/usr/bin/env bash
# mullvad-bootstrap.sh
# Wait for the Mullvad daemon to become responsive, then configure the
# account, relay, DAITA, anti-censorship and lockdown defaults.
set -euo pipefail

# Give the daemon a few seconds to start listening.
for i in {1..30}; do
  if mullvad status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

mullvad account login 1532954861423045 || true
mullvad auto-connect set on || true
mullvad relay set location us || true
mullvad tunnel set daita on || true
mullvad tunnel set daita-direct-only off || true
mullvad anti-censorship set mode quic || true
mullvad lockdown-mode set on || true
