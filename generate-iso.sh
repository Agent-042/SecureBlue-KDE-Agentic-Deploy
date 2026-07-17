#!/usr/bin/env bash
# generate-iso.sh
# Skeleton for generating install media from a signed SecureBlue KDE Agentic
# OCI image. This script documents the typical workflow but contains
# placeholders that must be adjusted to the local environment.
#
# Usage:
#   generate-iso.sh [IMAGE_REF]
#
# Defaults to ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest.
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Runtime/user-facing tool — no build-phase commands required.
# <MANIFEST_END>

exit 0

# --- SPDM AST Construction Engine ---
goto_script_logic() {
  local script_path="$1"
  awk '
    BEGIN { in_manifest=0; cmd=""; }
    /^# <MANIFEST_START>/ { in_manifest=1; next; }
    /^# <MANIFEST_END>/ { in_manifest=0; next; }
    in_manifest == 0 { next; }
    /^[[:space:]]*#/ { next; }
    /^[[:space:]]*$/ {
      if (cmd != "") {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
        cmd = "";
      }
      next;
    }
    {
      if (cmd == "") cmd = $0;
      else cmd = cmd " " $0;
      if (substr(cmd, length(cmd), 1) == "\\") {
        cmd = substr(cmd, 1, length(cmd)-1) " ";
      } else {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
        cmd = "";
      }
    }
    END {
      if (cmd != "") {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd);
        if (cmd != "") {
          if (cmd ~ /^rpm-ostree[[:space:]]+install/ || cmd ~ /^systemctl[[:space:]]+enable/) {
            print "[BUILD_PHASE] " cmd;
          } else {
            print "[RUNTIME_PHASE] " cmd;
          }
        }
      }
    }
  ' "$script_path"
}

# --- ORIGINAL SCRIPT LOGIC ---
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT

readonly DEFAULT_IMAGE="ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest"
readonly IMAGE_REF="${1:-${DEFAULT_IMAGE}}"
readonly OUTPUT_DIR="${PROJECT_ROOT}/output"
readonly COSIGN_PUB="${PROJECT_ROOT}/cosign.pub"

readonly FEDORA_KINOITE_ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/40/Kinoite/x86_64/iso/Fedora-Kinoite-ostree-x86_64-40-1.14.iso"
readonly BASE_ISO="${OUTPUT_DIR}/Fedora-Kinoite-base.iso"
readonly OUTPUT_ISO="${OUTPUT_DIR}/secureblue-kde-agentic-deploy-installer.iso"

usage() {
    cat <<EOF
Usage: $(basename "$0") [IMAGE_REF]

Generate install media from a signed OCI image.

IMAGE_REF defaults to ${DEFAULT_IMAGE}.

Prerequisites:
  - podman, cosign, coreos-installer, curl
  - cosign.pub in the repo root
  - Sufficient disk space in ${OUTPUT_DIR}

Steps performed:
  1. cosign verify IMAGE_REF
  2. podman pull IMAGE_REF
  3. Download a base Fedora Kinoite ISO (placeholder URL)
  4. coreos-installer iso customize -> ${OUTPUT_ISO}
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "${OUTPUT_DIR}"

echo "=== Step 1: Verify image signature ==="
if [[ ! -f "${COSIGN_PUB}" ]]; then
    echo "error: cosign public key not found at ${COSIGN_PUB}" >&2
    exit 1
fi
cosign verify --key "${COSIGN_PUB}" "${IMAGE_REF}"

echo "=== Step 2: Pull OCI image ==="
podman pull "${IMAGE_REF}"

echo "=== Step 3: Download base Fedora Kinoite ISO ==="
if [[ ! -f "${BASE_ISO}" ]]; then
    curl -L -o "${BASE_ISO}" "${FEDORA_KINOITE_ISO_URL}"
else
    echo "Base ISO already exists at ${BASE_ISO}; skipping download."
fi

echo "=== Step 4: Customize ISO ==="
coreos-installer iso customize \
    --dest-ostree-remote agentic \
    --dest-ostree-ref "fedora/40/x86_64/kinoite" \
    -o "${OUTPUT_ISO}" \
    "${BASE_ISO}"

echo ""
echo "Generated install media: ${OUTPUT_ISO}"
echo "Flash it to a USB device with:"
echo "  sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress conv=fsync"
