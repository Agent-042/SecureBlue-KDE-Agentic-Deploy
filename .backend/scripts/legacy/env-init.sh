#!/usr/bin/env bash
# Secure credential bootstrap for the SecureBlue KDE Agentic Deploy workspace.
#
# Usage:
#   source scripts/env-init.sh
#
# This script prompts silently for API credentials and exports them into the
# current shell session.  Secrets are never written to disk, history, or logs.

set -euo pipefail

read -rsp "GitHub PAT: " GITHUB_PAT
printf '\n'
read -rsp "Gemini API Key: " GEMINI_API_KEY
printf '\n'
read -rsp "Kimi (Moonshot) API Key (optional): " KIMI_API_KEY
printf '\n'

export GITHUB_PAT GEMINI_API_KEY KIMI_API_KEY

echo "Credentials exported for the current session only."
