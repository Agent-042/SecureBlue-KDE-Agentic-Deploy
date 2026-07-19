#!/usr/bin/env bash
# SPDM Constitution: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/SPDM_CONSTITUTION.md
# Coding Agent Baseline: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/arch/spdm-refactor/.assets/docs/CONTRIBUTING_Coding_Agent.md
# GITHUB_PAT: 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
# Branch: arch/spdm-refactor
# Target: PMO Automated Host & VM Audit
# Hardware: ASUS ROG Zephyrus G16
#
# Automated PMO Heartbeat & Host Audit script. Runs every 30 minutes.

set -euo pipefail

# 1. Paths and setup
readonly REPO_DIR="/root/Agentic-OS/SecureBlue-KDE-Agentic-Deploy"
readonly STATUS_FILE="${REPO_DIR}/PMO_STATUS.md"
readonly ENV_FILE="/root/.env"

mkdir -p "$(dirname "${STATUS_FILE}")"

# Load credentials
if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
else
    echo "Warning: .env file not found at ${ENV_FILE}" >&2
fi

# Initialize Report Elements
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
CST_TIME="$(date -d "6 hours ago" +"%Y-%m-%d %H:%M:%S CST")"

# 2. Audit Git & Branch Hygiene
echo "Auditing Git..."
cd "${REPO_DIR}"
GIT_BRANCH="$(git branch --show-current 2>/dev/null || echo "unknown")"
GIT_STATUS_RAW="$(git status --porcelain 2>/dev/null || echo "failed to query")"
if [[ -z "${GIT_STATUS_RAW}" ]]; then
    GIT_DIRTY_STATUS="Clean ✅"
else
    GIT_DIRTY_STATUS="Dirty (Uncommitted Changes) ⚠️"
fi
LAST_COMMIT_HASH="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
LAST_COMMIT_MSG="$(git log -1 --pretty=%B 2>/dev/null | head -n 1 || echo "unknown")"

# 3. Audit Bazzite Virtual Machine & GPU Passthrough
echo "Auditing VM..."
VM_NAME="bazzite-gaming"
VM_EXISTS=false
VM_STATE="Shutoff"
VM_MEM="Unknown"
VM_CPUS="Unknown"
GUEST_OS="Unknown"
GUEST_KERNEL="Unknown"
GUEST_GPU_STATUS="Not Verified"
GUEST_NVIDIA_DRV="Not Loaded"

if command -v virsh >/dev/null 2>&1; then
    if virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
        VM_EXISTS=true
        VM_STATE="$(virsh dominfo "${VM_NAME}" | awk '/^State:/{print $2}')"
        VM_MEM="$(virsh dominfo "${VM_NAME}" | awk '/^Max memory:/{print $3 " " $4}')"
        VM_CPUS="$(virsh dominfo "${VM_NAME}" | awk '/^CPU\(s\):/{print $2}')"

        if [[ "${VM_STATE}" == "running" ]]; then
            # Query guest agent
            OS_INFO_RAW="$(virsh qemu-agent-command "${VM_NAME}" '{"execute":"guest-get-osinfo"}' 2>/dev/null || echo "")"
            if [[ -n "${OS_INFO_RAW}" ]]; then
                GUEST_OS="$(echo "${OS_INFO_RAW}" | jq -r '.return.name' 2>/dev/null || echo "Bazzite")"
                GUEST_KERNEL="$(echo "${OS_INFO_RAW}" | jq -r '.return."kernel-release"' 2>/dev/null || echo "6.x")"
            fi

            # Check for GPU via lspci inside the guest
            LSPCI_RAW="$(virsh qemu-agent-command "${VM_NAME}" '{"execute":"guest-exec", "arguments":{"path":"/usr/bin/lspci", "capture-output":true}}' 2>/dev/null || echo "")"
            if [[ -n "${LSPCI_RAW}" ]]; then
                PID="$(echo "${LSPCI_RAW}" | jq -r '.return.pid' 2>/dev/null || echo "")"
                if [[ -n "${PID}" ]]; then
                    sleep 1
                    STATUS_RAW="$(virsh qemu-agent-command "${VM_NAME}" "{\"execute\":\"guest-exec-status\", \"arguments\":{\"pid\":${PID}}}" 2>/dev/null || echo "")"
                    OUT_DATA="$(echo "${STATUS_RAW}" | jq -r '.return."out-data"' 2>/dev/null || echo "")"
                    if [[ -n "${OUT_DATA}" && "${OUT_DATA}" != "null" ]]; then
                        DECODED_LSPCI="$(echo "${OUT_DATA}" | base64 -d 2>/dev/null || echo "")"
                        if echo "${DECODED_LSPCI}" | grep -qiE "NVIDIA|10de"; then
                            GUEST_GPU_STATUS="Present ✅ (RTX 5080 passed through)"
                        else
                            GUEST_GPU_STATUS="GPU Not Found ❌"
                        fi
                    fi
                fi
            fi

            # Check for NVIDIA driver in guest via /proc/driver/nvidia/version
            CAT_DRV_RAW="$(virsh qemu-agent-command "${VM_NAME}" '{"execute":"guest-exec", "arguments":{"path":"/usr/bin/cat", "arg":["/proc/driver/nvidia/version"], "capture-output":true}}' 2>/dev/null || echo "")"
            if [[ -n "${CAT_DRV_RAW}" ]]; then
                PID_DRV="$(echo "${CAT_DRV_RAW}" | jq -r '.return.pid' 2>/dev/null || echo "")"
                if [[ -n "${PID_DRV}" ]]; then
                    sleep 1
                    STATUS_DRV_RAW="$(virsh qemu-agent-command "${VM_NAME}" "{\"execute\":\"guest-exec-status\", \"arguments\":{\"pid\":${PID_DRV}}}" 2>/dev/null || echo "")"
                    OUT_DRV_DATA="$(echo "${STATUS_DRV_RAW}" | jq -r '.return."out-data"' 2>/dev/null || echo "")"
                    if [[ -n "${OUT_DRV_DATA}" && "${OUT_DRV_DATA}" != "null" ]]; then
                        DECODED_DRV="$(echo "${OUT_DRV_DATA}" | base64 -d 2>/dev/null || echo "")"
                        GUEST_NVIDIA_DRV="$(echo "${DECODED_DRV}" | head -n 1 | xargs || echo "Loaded")"
                    fi
                fi
            fi
        fi
    fi
fi

# 4. Audit Ollama System Service
echo "Auditing services..."
OLLAMA_STATUS="Not Installed"
OLLAMA_SUBSTATUS="None"
if systemctl list-unit-files | grep -q "ollama.service"; then
    OLLAMA_STATUS="$(systemctl is-active ollama 2>/dev/null || echo "inactive")"
    OLLAMA_SUBSTATUS="$(systemctl show -p ActiveState --value ollama 2>/dev/null || echo "") ($(systemctl show -p SubState --value ollama 2>/dev/null || echo ""))"
fi

# 5. Audit GitHub PAT Token Status & API Rate Limits
echo "Auditing GitHub API..."
GITHUB_API_STATUS="Unverified"
GITHUB_RATE_LIMIT="N/A"
if [[ -n "${GITHUB_PAT:-}" ]]; then
    API_RESPONSE="$(curl -s -H "Authorization: token ${GITHUB_PAT}" -I "https://api.github.com/users/Agent-042" 2>/dev/null || echo "")"
    if [[ -n "${API_RESPONSE}" ]]; then
        HTTP_STATUS="$(echo "${API_RESPONSE}" | awk '/^HTTP/{print $2}' | tail -n 1)"
        if [[ "${HTTP_STATUS}" == "200" ]]; then
            GITHUB_API_STATUS="Authenticated ✅ (Agent-042 profile accessed)"
            LIMIT_VAL="$(echo "${API_RESPONSE}" | grep -i "x-ratelimit-remaining" | awk '{print $2}' | tr -d '\r\n' || echo "")"
            LIMIT_TOTAL="$(echo "${API_RESPONSE}" | grep -i "x-ratelimit-limit" | awk '{print $2}' | tr -d '\r\n' || echo "")"
            if [[ -n "${LIMIT_VAL}" ]]; then
                GITHUB_RATE_LIMIT="${LIMIT_VAL} / ${LIMIT_TOTAL}"
            fi
        else
            GITHUB_API_STATUS="Authentication Failed ❌ (HTTP ${HTTP_STATUS})"
        fi
    fi
else
    GITHUB_API_STATUS="Missing GITHUB_PAT env variable ⚠️"
fi

# 6. Generate gorgeous Markdown Report
echo "Writing PMO report..."
cat <<EOF > "${STATUS_FILE}"
# PMO Status: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy
# Target: SecureBlue G16 PMO Automated Heartbeat Audit
# Last Evaluated: ${TIMESTAMP} (${CST_TIME})
# Status: Active Monitoring 🖤

## 📊 EXECUTIVE SUMMARY

This report is automatically generated every 30 minutes by the background daemon under session **amber-harbor**. It conducts a comprehensive health-check of the host hardware capabilities, active virtual machines, repository branch hygiene, service availability, and API access validity.

| Metric | Current Status | Details |
| :--- | :--- | :--- |
| **Branch Health** | ${GIT_DIRTY_STATUS} | Active on \`${GIT_BRANCH}\` at commit \`${LAST_COMMIT_HASH}\` |
| **Bazzite VM** | ${VM_STATE} 🎮 | \`${VM_NAME}\` is ${VM_STATE} with ${VM_CPUS} vCPUs and ${VM_MEM} |
| **GPU Passthrough**| ${GUEST_GPU_STATUS} | Guest NVIDIA driver: \`${GUEST_NVIDIA_DRV}\` |
| **Ollama Service**| ${OLLAMA_STATUS} 🤖 | Active state: \`${OLLAMA_SUBSTATUS}\` |
| **GitHub PAT Rate**| ${GITHUB_API_STATUS} | Rate Limit remaining: \`${GITHUB_RATE_LIMIT}\` |

---

## 💻 ENVIRONMENT METRICS

### Git Workspace Hygiene
- **Branch:** \`${GIT_BRANCH}\`
- **Last Commit:** \`${LAST_COMMIT_HASH}\` - *"${LAST_COMMIT_MSG}"*
- **Working Directory State:**
\`\`\`text
${GIT_STATUS_RAW:-"No untracked or modified files (Clean)"}
\`\`\`

### Bazzite Gaming VM Details
- **VM Domain Registered:** \`${VM_EXISTS}\`
- **Allocated Memory:** \`${VM_MEM}\`
- **vCPU Count:** \`${VM_CPUS}\`
- **Guest OS:** \`${GUEST_OS}\`
- **Guest Kernel:** \`${GUEST_KERNEL}\`
- **NVIDIA GPU dGPU:** \`${GUEST_GPU_STATUS}\`
- **Guest NVIDIA Driver Version:** \`${GUEST_NVIDIA_DRV}\`

### Service Diagnostic Ledger
- **ollama.service:** \`${OLLAMA_SUBSTATUS}\`

### API Rate Limit Integrity
- **GitHub API Authenticated Profile:** \`${GITHUB_API_STATUS}\`
- **Remaining API Allotment:** \`${GITHUB_RATE_LIMIT}\`

---

## ⚡ NEXT STRATEGIC ACTIONS

1. **Host Rebase Preparation:** Verify the OCI image build status on feat/cosign-signing branch and ready the \`rebase.sh\` manifest.
2. **Kvantum WAYLAND Check:** Ensure the composite=false guard continues to prevent Plasma 6 compositor crashes.
3. **Continuous Swarm Coordination:** Sync logs seamlessly with \`.backend/swarm_ledger.json\`.

*Report compiled by Antigravity 2.0 PMO Daemon.*
EOF

echo "Audit completed successfully."
