#!/usr/bin/env bash
# scripts/generate-cosign-keys.sh
# Generate a cosign-compatible ECDSA P-256 keypair using openssl.
# This avoids needing podman/docker or root privileges on an immutable host.
# The private key (cosign.key) is gitignored and must be kept secret.
# The public key (cosign.pub) is committed to the repo for image verification.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
echo "       source scripts/env-init.sh && scripts/set-signing-secret.sh"
