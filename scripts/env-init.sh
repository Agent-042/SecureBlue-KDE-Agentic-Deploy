#!/usr/bin/env bash
# scripts/env-init.sh — Secure shell-session secret loader.
#
# IMPORTANT:
#   - This script prompts for secrets and exports them only for the current
#     shell session. It does NOT write them to disk.
#   - Do NOT redirect this script's output to a file, do NOT commit anything
#     it prints, and do NOT source it from ~/.bashrc or any startup file.
#   - Source it only when you need the credentials in the current shell:
#       source scripts/env-init.sh
#
# This file is tracked in git intentionally; only the values you type are
# secret. Keep them out of the repository.

set -euo pipefail

# Refuse execution; must be sourced so exports survive in the parent shell.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced, not executed." >&2
  echo "Usage: source ${BASH_SOURCE[0]}" >&2
  exit 1
fi

read -rsp "GitHub Personal Access Token (GITHUB_PAT): " GITHUB_PAT
echo >&2

read -rsp "Gemini API Key (GEMINI_API_KEY): " GEMINI_API_KEY
echo >&2

export GITHUB_PAT GEMINI_API_KEY

echo "GITHUB_PAT and GEMINI_API_KEY exported for this shell session only." >&2
echo "They will be lost when this shell exits." >&2
