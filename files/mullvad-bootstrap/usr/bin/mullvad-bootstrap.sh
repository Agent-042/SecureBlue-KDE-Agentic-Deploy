#!/usr/bin/env bash
# mullvad-bootstrap.sh
# Wait for the Mullvad daemon to become responsive, then lock in udp2tcp
# obfuscation and enable lockdown mode.
set -euo pipefail

# Give the daemon a few seconds to start listening.
for i in {1..30}; do
  if mullvad status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

mullvad relay set obfuscation mode udp2tcp || true
mullvad lockdown-mode set on || true
