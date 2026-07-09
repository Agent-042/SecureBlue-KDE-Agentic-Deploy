#!/usr/bin/env bash
# Username-agnostic persistent workspace bootstrap.
# Creates a per-user workspace under /var/lib/agentic-os/<user> and symlinks
# it as ~/Agentic-OS so project state survives reboots and rebases.

set -euo pipefail

readonly USER_NAME="${USER:-$(id -un)}"
readonly PERSIST_ROOT="/var/lib/agentic-os"
readonly USER_WORKSPACE="${PERSIST_ROOT}/${USER_NAME}"
readonly LINK_PATH="${HOME}/Agentic-OS"

mkdir -p "${USER_WORKSPACE}"

if [[ -L "${LINK_PATH}" ]]; then
    # Ensure the symlink points to the correct location.
    current_target="$(readlink -f "${LINK_PATH}" || true)"
    if [[ "${current_target}" != "${USER_WORKSPACE}" ]]; then
        rm "${LINK_PATH}"
        ln -s "${USER_WORKSPACE}" "${LINK_PATH}"
    fi
elif [[ -e "${LINK_PATH}" ]]; then
    echo "Agentic-OS path exists but is not a symlink; leaving it untouched." >&2
    exit 0
else
    ln -s "${USER_WORKSPACE}" "${LINK_PATH}"
fi
