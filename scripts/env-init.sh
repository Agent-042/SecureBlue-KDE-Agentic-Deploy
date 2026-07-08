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
# If pasting long keys into Konsole crashes the terminal, put them in a file
# (one key per line, in the order below, or as KEY=VALUE pairs) and use:
#       source scripts/env-init.sh --from-file /path/to/keys.txt
#
# This file is tracked in git intentionally; only the values you type are
# secret. Keep them out of the repository.

set -euo pipefail

# Refuse execution; must be sourced so exports survive in the parent shell.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced, not executed." >&2
  echo "Usage: source ${BASH_SOURCE[0]} [--from-file /path/to/keys.txt]" >&2
  exit 1
fi

FROM_FILE=""
if [[ "${1:-}" == "--from-file" ]]; then
  FROM_FILE="${2:-}"
  if [[ -z "$FROM_FILE" || ! -f "$FROM_FILE" ]]; then
    echo "error: --from-file requires a readable file path" >&2
    return 1
  fi
fi

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"
  if [[ -n "$FROM_FILE" ]]; then
    # Try KEY=VALUE syntax first, then fall back to sequential lines.
    local value
    value=$(grep "^${var_name}=" "$FROM_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2- || true)
    if [[ -z "$value" ]]; then
      value=$(sed -n "${READ_LINE}p" "$FROM_FILE" 2>/dev/null || true)
      READ_LINE=$((READ_LINE + 1))
    fi
    if [[ -z "$value" ]]; then
      echo "error: could not read ${var_name} from ${FROM_FILE}" >&2
      return 1
    fi
    printf -v "$var_name" '%s' "$value"
  else
    read -rsp "${prompt_text}: " "$var_name"
    echo >&2
  fi
}

READ_LINE=1

prompt_secret GITHUB_PAT      "GitHub Personal Access Token (GITHUB_PAT)"
prompt_secret GEMINI_API_KEY  "Gemini API Key (GEMINI_API_KEY)"
prompt_secret KIMI_API_KEY    "Kimi API Key (KIMI_API_KEY)"

export GITHUB_PAT GEMINI_API_KEY KIMI_API_KEY

echo "GITHUB_PAT, GEMINI_API_KEY, and KIMI_API_KEY exported for this shell session only." >&2
echo "They will be lost when this shell exits." >&2
