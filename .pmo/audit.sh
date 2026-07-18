#!/usr/bin/env bash
# PMO Audit Script — BuildBlue Pulse (Simplified)
# Run this every 30 minutes to monitor agent progress and repository health

set -euo pipefail

REPO_URL="https://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@github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy"
WORK_DIR="/tmp/pmo-audit-$(date +%s)"
REPORT_FILE="/root/.openclaw/workspace/.pmo/last-audit-report.md"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
ALERTS=""

mkdir -p "$WORK_DIR" "$(dirname "$REPORT_FILE")"

# Clone with shallow history
git clone --depth 10 "$REPO_URL.git" "$WORK_DIR" 2>/dev/null || {
    echo "ERROR: Failed to clone repository" >&2
    exit 1
}

cd "$WORK_DIR"

# Check bazzite-deploy.sh for critical errors
check_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then return; fi
    
    # Wrong OVMF path
    if grep -q '/usr/share/OVMF/OVMF_CODE' "$file" 2>/dev/null; then
        ALERTS="${ALERTS}\\n- CRITICAL: ${file} has WRONG OVMF path (/usr/share/OVMF/)"
    fi
    
    # Missing video none in XML contexts
    if [[ "$file" == *.xml ]] && ! grep -q "<model type='none'/>" "$file" 2>/dev/null; then
        ALERTS="${ALERTS}\\n- CRITICAL: ${file} missing <video><model type='none'/></video>"
    fi
    
    # Deprecated /dev/shm/looking-glass
    if grep -q '/dev/shm/looking-glass' "$file" 2>/dev/null; then
        ALERTS="${ALERTS}\\n- WARNING: ${file} uses deprecated /dev/shm/looking-glass"
    fi
    
    # sudo instead of run0
    if grep -q '^sudo ' "$file" 2>/dev/null; then
        ALERTS="${ALERTS}\\n- WARNING: ${file} uses 'sudo' instead of 'run0'"
    fi
}

# Check key files
check_file "bazzite-deploy.sh"
check_file "rebase.sh"

# Check for any XML files
find . -name "*.xml" -type f | while read -r f; do
    check_file "$f"
done

# Check latest commits
BAZZITE_LATEST=$(git log --oneline -1 origin/feat/bazzite-vm-scaffold 2>/dev/null || echo "N/A")
COSIGN_LATEST=$(git log --oneline -1 origin/feat/cosign-signing 2>/dev/null || echo "N/A")
MAIN_LATEST=$(git log --oneline -1 origin/main 2>/dev/null || echo "N/A")

# Check for nvidia-smi reports in commit messages
KIMI_REPORT=$(git log --all --grep='nvidia-smi' --oneline 2>/dev/null | head -5 || true)

# Generate report
cat > "$REPORT_FILE" <<EOF
# PMO Audit Report — ${TIMESTAMP}

## Repository State
- feat/bazzite-vm-scaffold: ${BAZZITE_LATEST}
- feat/cosign-signing: ${COSIGN_LATEST}
- main: ${MAIN_LATEST}

## Alerts
$(if [[ -n "$ALERTS" ]]; then echo -e "$ALERTS"; else echo "No critical alerts."; fi)

## Agent Activity
$(if [[ -n "$KIMI_REPORT" ]]; then echo "Kimi Code 2.7 nvidia-smi reports found:"; echo "\`\`\`"; echo "$KIMI_REPORT"; echo "\`\`\`"; else echo "No nvidia-smi reports from Kimi Code 2.7 yet."; fi)

## Action Items
$(if echo "$ALERTS" | grep -q 'CRITICAL'; then 
    echo "- **IMMEDIATE ACTION REQUIRED**: Critical errors detected"
    echo "- Recommend halting agent and issuing re-steer prompt"
elif echo "$ALERTS" | grep -q 'WARNING'; then
    echo "- Review warnings above"
else
    echo "- All clear. Monitoring continues."
fi)

---
*Next audit: $(date -u -d '+30 minutes' '+%H:%M UTC')*
EOF

# Cleanup
rm -rf "$WORK_DIR"

# Output
if [[ -n "$ALERTS" ]]; then
    echo -e "PMO_AUDIT_ALERTS:\n${ALERTS}"
else
    echo "PMO_AUDIT_OK: No critical issues detected at ${TIMESTAMP}"
fi
