#!/usr/bin/env bash
# github-api.sh — Minimal curl-based GitHub REST API helper.
#
# Requires GITHUB_PAT to be exported. Load it first with:
#   source env-init.sh
#
# Sourcing this file defines helper functions. Example usage:
#   source github-api.sh
#   gh_list_repos <owner>
#   gh_get_file <owner> <repo> <path> [ref]
#   gh_create_or_update_file <owner> <repo> <path> <commit-message> <content>
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Runtime/library script — no build-phase commands required.
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

if [[ -z "${GITHUB_PAT:-}" ]]; then
  echo "GITHUB_PAT is not set. Run: source env-init.sh" >&2
  return 1 2>/dev/null || exit 1
fi

GH_API_BASE="https://api.github.com"

gh_curl() {
  curl -sSL \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github.v3+json" \
    "$@"
}

gh_list_repos() {
  local owner="${1:?owner required}"
  gh_curl "${GH_API_BASE}/users/${owner}/repos?per_page=100"
}

gh_get_file() {
  local owner="${1:?owner required}"
  local repo="${2:?repo required}"
  local path="${3:?path required}"
  local ref="${4:-}"
  local url="${GH_API_BASE}/repos/${owner}/${repo}/contents/${path}"
  [[ -n "${ref}" ]] && url+="?ref=${ref}"
  gh_curl "${url}"
}

gh_create_or_update_file() {
  local owner="${1:?owner required}"
  local repo="${2:?repo required}"
  local path="${3:?path required}"
  local message="${4:?commit message required}"
  local content="${5:?content required}"
  local sha=""

  sha=$(gh_get_file "${owner}" "${repo}" "${path}" 2>/dev/null \
        | python3 -c 'import sys, json; print(json.load(sys.stdin).get("sha", ""))' 2>/dev/null || true)

  local b64content
  b64content=$(printf '%s' "${content}" | base64 -w0)

  local json_message
  json_message=$(python3 -c 'import sys, json; print(json.dumps(sys.stdin.read()))' <<<"${message}")

  local payload
  if [[ -n "${sha}" ]]; then
    payload=$(printf '{"message":%s,"content":"%s","sha":"%s"}' \
              "${json_message}" "${b64content}" "${sha}")
  else
    payload=$(printf '{"message":%s,"content":"%s"}' \
              "${json_message}" "${b64content}")
  fi

  gh_curl -X PUT \
    -H "Content-Type: application/json" \
    -d "${payload}" \
    "${GH_API_BASE}/repos/${owner}/${repo}/contents/${path}"
}
