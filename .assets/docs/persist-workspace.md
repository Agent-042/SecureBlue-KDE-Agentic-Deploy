Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
# Persist Workspace creates a username-agnostic workspace that survives reboots and rebases.
# No manual commands required; it initializes automatically on first login.
# The workspace is symlinked from /var/lib/agentic-workspace/ to ~/Workspace.

## Script Logic ##
# File: modules/persist-workspace/module.yml
type: files
files:
  - source: persist-workspace/usr
    destination: /usr

# File: config/files/usr/bin/agentic-workspace-init.sh
#!/bin/bash
# Creates and links persistent workspace directory
WORKSPACE_BASE="/var/lib/agentic-workspace"
USER_WORKSPACE="${HOME}/Workspace"
if [ ! -d "${WORKSPACE_BASE}" ]; then
  run0 mkdir -p "${WORKSPACE_BASE}"
  run0 chown -R "${USER}:$(id -gn)" "${WORKSPACE_BASE}" || true
fi
if [ ! -L "${USER_WORKSPACE}" ] && [ ! -e "${USER_WORKSPACE}" ]; then
  ln -s "${WORKSPACE_BASE}" "${USER_WORKSPACE}"
fi

# File: config/files/usr/lib/systemd/user/agentic-workspace-init.service
[Unit]
Description=Agentic Workspace Initialization
After=default.target

[Service]
Type=oneshot
ExecStart=/usr/bin/agentic-workspace-init.sh
RemainAfterExit=yes

[Install]
WantedBy=default.target

# File: config/files/usr/lib/tmpfiles.d/agentic-os.conf
# Ensures /var/lib/agentic-workspace exists with correct permissions
d /var/lib/agentic-workspace 0755 root root -
