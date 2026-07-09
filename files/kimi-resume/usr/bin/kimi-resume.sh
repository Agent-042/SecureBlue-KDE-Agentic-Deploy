#!/usr/bin/env bash
# Kimi Code CLI workspace resume helper.
# Run this after first login on a fresh deployment to restore the project repo
# and verify that the persistent Agentic-OS workspace is linked.

set -euo pipefail

readonly REPO_URL="https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy.git"
readonly WORKSPACE_LINK="${HOME}/Agentic-OS"
readonly REPO_DIR="${WORKSPACE_LINK}/SecureBlue-KDE-Agentic-Deploy"

# Ensure the persistent workspace symlink exists.
if [[ ! -L "${WORKSPACE_LINK}" ]]; then
    /usr/bin/agentic-workspace-init.sh
fi

# Clone or update the project repo.
if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "Updating existing repo at ${REPO_DIR}..."
    git -C "${REPO_DIR}" pull --ff-only
else
    echo "Cloning project repo into ${REPO_DIR}..."
    mkdir -p "${REPO_DIR}"
    git clone "${REPO_URL}" "${REPO_DIR}"
fi

# Verify Kimi Code CLI is available.
if command -v kimi >/dev/null 2>&1; then
    echo "Kimi Code CLI: $(kimi --version 2>/dev/null || echo 'installed')"
else
    echo "Kimi Code CLI not found in PATH."
    echo "Install it manually (e.g., via the official installer) and re-run this script."
    echo "Session state in ~/.kimi-code/ should be backed up before any future immutability changes."
fi

echo "Resume complete. Project workspace: ${REPO_DIR}"
