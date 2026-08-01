Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Emergency Rescue module deploys g16-rescue.sh to /usr/bin.
# No manual commands required; the script is available immediately after rebase.
# Run it directly when troubleshooting connectivity or system issues:
run0 g16-rescue.sh

## Script Logic ##
# File: modules/emergency-rescue/module.yml
type: files
files:
  - source: emergency-rescue/usr
    destination: /usr

# File: config/files/usr/bin/g16-rescue.sh
#!/bin/bash
# Emergency rescue script for the G16 SecureBlue deployment.
# Provides: network diagnostics, rollback helpers, and rescue mode entry.
set -euo pipefail

echo "=== G16 Rescue Tool ==="
echo "1. Check network status"
echo "2. Test DNS resolution"
echo "3. Rollback to previous deployment"
echo "4. Enter emergency shell"
# ... (full script content as deployed in image)
