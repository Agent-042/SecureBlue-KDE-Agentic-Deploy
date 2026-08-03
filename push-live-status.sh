#!/usr/bin/env bash
# Unified commit, doc-sync, and push automation script for main.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
LEDGER="${REPO_ROOT}/.backend/swarm_ledger.json"
STATUS_MD="${REPO_ROOT}/.assets/docs/live_status.md"

cd "$REPO_ROOT"

# 1. Determine commit message
COMMIT_MSG="${1:-}"
if [[ -z "$COMMIT_MSG" && -f "$LEDGER" ]]; then
  # Extract the last action from swarm_ledger.json using Python
  COMMIT_MSG=$(python3 - "$LEDGER" <<'PY'
import json, sys
try:
    ledger = json.loads(open(sys.argv[1]).read())
    logs = ledger.get("verification_logs", [])
    if logs:
        print(f"Agentic Deploy: {logs[-1].get('action', 'Update codebase')}")
    else:
        print("Agentic Deploy: sync and update")
except Exception:
    print("Agentic Deploy: automated sync")
PY
  )
fi
COMMIT_MSG="${COMMIT_MSG:-Automated Agentic-OS sync}"

# 2. Stage all current changes
echo "Staging all changes..."
git add -A

# 3. Commit outstanding codebase changes (if any exist)
if ! git diff --cached --quiet; then
  echo "Committing codebase changes: '${COMMIT_MSG}'"
  git commit -m "${COMMIT_MSG}"
else
  echo "No outstanding codebase changes to commit."
fi

# Avoid recursive loops when this script is run via post-commit hooks
if git log -1 --pretty=%s | grep -q '^\[live-status\]'; then
  echo "Latest commit is already a live-status sync. Pushing to origin..."
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git push origin HEAD
  exit 0
fi

if [[ -f "$LEDGER" ]]; then
  echo "Regenerating documentation (${STATUS_MD}) from ledger..."
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

  # Stage and commit the updated live-status file if it changed
  if ! git diff --quiet -- "$STATUS_MD"; then
    echo "Staging and committing regenerated documentation..."
    git add "$STATUS_MD"
    git commit -m "[live-status] sync .assets/docs/live_status.md with .backend/swarm_ledger.json"
  else
    echo "Documentation is already up-to-date."
  fi
fi

# 5. Always push to remote main/HEAD safely
echo "Pushing latest commits to remote..."
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git push origin HEAD
