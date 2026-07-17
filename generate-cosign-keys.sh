#!/usr/bin/env bash
# generate-cosign-keys.sh
# Generate a cosign-compatible ECDSA P-256 keypair using openssl.
# This avoids needing podman/docker or root privileges on an immutable host.
# The private key (cosign.key) is gitignored and must be kept secret.
# The public key (cosign.pub) is committed to the repo for image verification.
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
cd "$PROJECT_ROOT"

if [[ -f cosign.key ]]; then
    echo "cosign.key already exists. Remove it first if you want to regenerate." >&2
    exit 1
fi

if [[ -f cosign.pub ]]; then
    echo "cosign.pub already exists. Remove it first if you want to regenerate." >&2
    exit 1
fi

echo "Generating cosign-compatible ECDSA P-256 keypair..."
openssl ecparam -genkey -name prime256v1 -noout -out cosign.key
openssl ec -in cosign.key -pubout -out cosign.pub

chmod 600 cosign.key
chmod 644 cosign.pub

echo ""
echo "Generated:"
echo "  cosign.key  -> PRIVATE KEY (gitignored; keep secret)"
echo "  cosign.pub  -> PUBLIC KEY (commit this file)"
echo ""
echo "Next steps:"
echo "  1. git add cosign.pub"
echo "  2. Set the contents of cosign.key as the GitHub secret SIGNING_SECRET:"
echo "       source env-init.sh && set-signing-secret.sh"
