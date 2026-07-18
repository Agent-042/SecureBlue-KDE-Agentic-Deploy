#!/usr/bin/env bash
# push-live-status.sh
# Post-commit hook: keep docs/live_status.md in sync with swarm_ledger.json,
# then push the result. Safe from .git/hooks/post-commit.
# SPDM Manifest: Self-Parsing Deployment Manifest format.

if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

# <MANIFEST_START>
# Post-commit hook script — no build-phase commands required.
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

REPO_ROOT="$(git rev-parse --show-toplevel)"
LEDGER="${REPO_ROOT}/.backend/swarm_ledger.json"
STATUS_MD="${REPO_ROOT}/.assets/docs/live_status.md"

cd "$REPO_ROOT"

if git log -1 --pretty=%s | grep -q '^\[live-status\]'; then
  git push origin HEAD
  exit 0
fi

if [[ -f "$LEDGER" ]]; then
  LAST_STATUS_COMMIT=$(git log --grep='^\[live-status\]' -1 --pretty=%H 2>/dev/null || true)
  LEDGER_CHANGED=true
  if [[ -n "$LAST_STATUS_COMMIT" ]] && git diff --quiet "$LAST_STATUS_COMMIT" -- "$LEDGER"; then
    LEDGER_CHANGED=false
  fi

  if [[ "$LEDGER_CHANGED" == true ]]; then
    python3 - "$LEDGER" "$STATUS_MD" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ledger_path = Path(sys.argv[1])
status_path = Path(sys.argv[2])

ledger = json.loads(ledger_path.read_text())
logs = ledger.get("verification_logs", [])

turn = ledger.get("current_turn", "kimi")
status = ledger.get("status", "unknown")
last_by = ledger.get("last_action_by", "kimi")
target = ledger.get("target_file", "")

generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

lines = [
    "# SecureBlue KDE Agentic Deploy — Live Status",
    "",
    f"Generated: {generated}",
    "",
    f"**Current turn:** {turn} | **Status:** {status} | **Last action by:** {last_by}",
    "",
    f"**Target files:** {target}",
    "",
    "## Verification log",
    "",
    "| Timestamp | Agent | Action | Result |",
    "|-----------|-------|--------|--------|",
]

for entry in logs:
    ts = entry.get("timestamp", "")
    agent = entry.get("agent", "").replace("|", "\\|")
    action = entry.get("action", "").replace("|", "\\|")
    result = entry.get("result", "").replace("|", "\\|")
    lines.append(f"| {ts} | {agent} | {action} | {result} |")

lines.append("")
status_path.parent.mkdir(parents=True, exist_ok=True)
status_path.write_text("\n".join(lines))
PY

    if ! git diff --quiet -- "$STATUS_MD"; then
      git add "$STATUS_MD"
      git commit -m "[live-status] sync .assets/docs/live_status.md with .backend/swarm_ledger.json"
    fi
  fi
fi

git push origin HEAD
