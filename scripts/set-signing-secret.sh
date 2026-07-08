#!/usr/bin/env bash
# scripts/set-signing-secret.sh
# Upload the local cosign.key to GitHub Actions as SIGNING_SECRET.
# Requires GITHUB_PAT to be exported (source scripts/env-init.sh).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [[ ! -f cosign.key ]]; then
    echo "error: cosign.key not found. Run scripts/generate-cosign-keys.sh first." >&2
    exit 1
fi

if [[ -z "${GITHUB_PAT:-}" ]]; then
    echo "error: GITHUB_PAT is not set. Run: source scripts/env-init.sh" >&2
    exit 1
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo "Setting SIGNING_SECRET via gh CLI..."
    gh secret set SIGNING_SECRET --body "$(cat cosign.key)"
else
    echo "gh is not authenticated. Set GITHUB_PAT and run 'gh auth login' first," >&2
    echo "or manually paste the contents of cosign.key into GitHub Actions secrets." >&2
    exit 1
fi

echo "SIGNING_SECRET uploaded. You can now safely remove the local cosign.key file:"
echo "  shred -u cosign.key"
