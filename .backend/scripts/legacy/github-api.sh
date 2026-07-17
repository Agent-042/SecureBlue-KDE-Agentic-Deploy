#!/usr/bin/env bash
# scripts/github-api.sh — Minimal curl-based GitHub REST API helper.
#
# Requires GITHUB_PAT to be exported. Load it first with:
#   source scripts/env-init.sh
#
# Sourcing this file defines helper functions. Example usage:
#   source scripts/github-api.sh
#   gh_list_repos <owner>
#   gh_get_file <owner> <repo> <path> [ref]
#   gh_create_or_update_file <owner> <repo> <path> <commit-message> <content>

set -euo pipefail

if [[ -z "${GITHUB_PAT:-}" ]]; then
  echo "GITHUB_PAT is not set. Run: source scripts/env-init.sh" >&2
  # Return if sourced, exit if executed.
  return 1 2>/dev/null || exit 1
fi

GH_API_BASE="https://api.github.com"

# Internal wrapper: always sends the authorization header.
gh_curl() {
  curl -sSL \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github.v3+json" \
    "$@"
}

# List public repositories for a user or organization.
gh_list_repos() {
  local owner="${1:?owner required}"
  gh_curl "${GH_API_BASE}/users/${owner}/repos?per_page=100"
}

# Get the contents metadata (and base64-decoded content) for a file.
gh_get_file() {
  local owner="${1:?owner required}"
  local repo="${2:?repo required}"
  local path="${3:?path required}"
  local ref="${4:-}"
  local url="${GH_API_BASE}/repos/${owner}/${repo}/contents/${path}"
  [[ -n "${ref}" ]] && url+="?ref=${ref}"
  gh_curl "${url}"
}

# Create a new file or update an existing one.
gh_create_or_update_file() {
  local owner="${1:?owner required}"
  local repo="${2:?repo required}"
  local path="${3:?path required}"
  local message="${4:?commit message required}"
  local content="${5:?content required}"
  local sha=""

  # Try to fetch the existing blob's sha so we can update it.
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
