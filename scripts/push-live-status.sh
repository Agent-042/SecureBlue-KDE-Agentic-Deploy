#!/usr/bin/env bash
# Post-commit hook: keep docs/live_status.md in sync with swarm_ledger.json.
# Safe to run from .git/hooks/post-commit: skips when the current commit
# already carries the [live-status] marker to avoid infinite recursion.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
LEDGER="${REPO_ROOT}/swarm_ledger.json"
STATUS_MD="${REPO_ROOT}/docs/live_status.md"

cd "$REPO_ROOT"

# Avoid recursive live-status commits triggered by the post-commit hook.
# Only the subject line is checked so the marker can be mentioned in body text.
if git log -1 --pretty=%s | grep -q '^\[live-status\]'; then
  exit 0
fi

if [[ ! -f "$LEDGER" ]]; then
  echo "push-live-status: ledger not found: $LEDGER" >&2
  exit 0
fi

# Skip if the ledger is unchanged since the last live-status commit.
# This avoids timestamp-only churn in docs/live_status.md.
LAST_STATUS_COMMIT=$(git log --grep='^\[live-status\]' -1 --pretty=%H 2>/dev/null || true)
if [[ -n "$LAST_STATUS_COMMIT" ]] && git diff --quiet "$LAST_STATUS_COMMIT" -- "$LEDGER"; then
  exit 0
fi

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

if git diff --quiet -- "$STATUS_MD"; then
  exit 0
fi

git add "$STATUS_MD"
git commit -m "[live-status] sync docs/live_status.md with swarm_ledger.json"
git push origin HEAD
