#!/usr/bin/env bash
# Post-commit helper: regenerate docs/live_status.md from swarm_ledger.json and push.
# Intended to be installed as .git/hooks/post-commit or run manually.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

readonly LEDGER="swarm_ledger.json"
readonly STATUS_FILE="docs/live_status.md"

# Guard against infinite recursion when this script commits the status file.
if git log -1 --pretty=%B | grep -qE '\[live-status\]|\[skip live-status\]'; then
    exit 0
fi

# Only publish when the ledger exists and is in a terminal/verified state.
if [[ ! -f "$LEDGER" ]]; then
    echo "Ledger not found; skipping live-status update."
    exit 0
fi

LEDGER_STATUS="$(jq -r '.status // "unknown"' "$LEDGER" 2>/dev/null || echo unknown)"
if [[ "$LEDGER_STATUS" != "verified" ]]; then
    echo "Ledger status is '$LEDGER_STATUS'; skipping live-status push until verified."
    exit 0
fi

mkdir -p docs

{
    echo "# SecureBlue KDE Agentic Deploy — Live Status"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    jq -r '"**Current turn:** \(.current_turn) | **Status:** \(.status) | **Last action by:** \(.last_action_by)"' "$LEDGER"
    echo ""
    echo "**Target files:** $(jq -r '.target_file' "$LEDGER")"
    echo ""
    echo "## Verification log"
    echo ""
    echo "| Timestamp | Agent | Action | Result |"
    echo "|-----------|-------|--------|--------|"
    jq -r '.verification_logs[] | "| \(.timestamp) | \(.agent) | \(.action) | \(.result) |"' "$LEDGER"
} > "$STATUS_FILE"

git add "$STATUS_FILE"
if git diff --cached --quiet; then
    echo "No live-status changes to commit."
    exit 0
fi

git commit -m "docs: update live_status.md [live-status]"
git push origin "$(git branch --show-current)"
