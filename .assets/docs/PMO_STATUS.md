# PMO Status Tracker — SecureBlue KDE Agentic Deploy
# Project Management Office — BuildBlue Pulse
# Hierarchy: Human → PMO (BuildBlue Pulse) → Project Managers → Endpoint Agents
# Last Updated: 2026-07-19 03:25 CST

## Human Action Items — What You Need To Do

| Priority | Item | Status | Action Required |
|----------|------|--------|-----------------|
| **P0** | Bazzite ISO install on G16 | ⏳ IN PROGRESS | Wait for Kimi Code 2.7 completion |
| **P0** | Google AI Studio re-steer | 🟡 PENDING | Deliver prompt with corrections URL (see below) |
| **P1** | Signal/ louder notifications | 💡 IDEA | Approve/setup if desired |
| **P2** | AMD Workstation passthrough | ⏸️ PAUSED | Antigriguity on standby awaiting direction |
| **P3** | Tahoe cosmetic pre-baking | ⏸️ BACKLOG | Lowest priority |

**Current blocker:** Kimi Code 2.7 is downloading Bazzite ISO. No action needed from you until she reports back.

---

## Agent Hierarchy & Roster

```
HUMAN (Agent-042) — Final authority, merge approvals, direction
    └── BuildBlue Pulse (PMO) — Round-the-clock monitor & auditor
            └── Google AI Studio (Project Manager — Burst Implementation)
                    ├── Kimi Code 2.7 (G16 Endpoint Agent)
                    └── Antigriguity CLI (AMD Workstation Endpoint Agent)
```

| Agent | Role | Target | Current Mission | Status |
|-------|------|--------|-----------------|--------|
| **Human** | Final Authority | Both machines | Approve merges, direct strategy | 🟢 ACTIVE |
| **BuildBlue Pulse** | PMO / Auditor | Cloud | 30-min audits, error detection, re-steer prep | 🟢 MONITORING |
| **Google AI Studio** | Project Manager | Cloud | Burst implementation, metaprompt delegation | 🟡 RE-STEER NEEDED |
| **Kimi Code 2.7** | Endpoint Agent | G16 (RTX 5080) | Bazzite ISO install + passthrough | ⏳ DOWNLOADING |
| **Antigriguity CLI** | Endpoint Agent | AMD Workstation (RTX 4080) | Scaffold audit complete | ⏸️ STANDBY |

---

## Project Goals (Priority Order)

### Active Sprint: Bazzite GPU Passthrough
**Goal:** Running Bazzite gaming VM with RTX 5080 passthrough on G16  
**Success Criteria:** `nvidia-smi` shows RTX 5080 inside VM  
**ETA:** 1–2 hours after ISO download completes  
**Owner:** Kimi Code 2.7 (endpoint) + Google AI Studio (burst PM)

### Parallel Track: Cosign Image Signing ✅ COMPLETE
**Goal:** Signed SecureBlue images with verified rebase  
**Status:** Merged to `main` at `d346e97`  
**Verification:** `cosign.pub` updated, `COSIGN_PRIVATE_KEY` in GitHub secrets  
**Owner:** Antigriguity CLI + BuildBlue Pulse audit

### Backlog: AMD Workstation Passthrough
**Goal:** Replicate G16 success on AMD Workstation (RTX 4080)  
**Blocker:** G16 must succeed first (lessons learned transfer)  
**Owner:** Antigriguity CLI (when activated)

### Backlog: Tahoe Cosmetic Pre-Baking
**Goal:** macOS-style theme embedded in BlueBuild image  
**Priority:** Lowest  
**Owner:** Unassigned

---

## Known Problems & Risks

| Severity | Problem | Impact | Mitigation | Owner |
|----------|---------|--------|------------|-------|
| **CRITICAL** | Google AI Studio generated wrong OVMF path | VM would not boot if committed | Corrections doc pushed to `pmo/corrections` | PMO |
| **CRITICAL** | Google AI Studio missing `<video none/>` | Black screen in VM | Corrections doc issued | PMO |
| **HIGH** | Google AI Studio wrong CPU topology | VM performance issues or instability | Corrections doc issued | PMO |
| **HIGH** | kvmfr as kernel arg (not module param) | Looking Glass shared memory fails | Corrections doc issued | PMO |
| **MEDIUM** | No loud notification channel | You might miss critical alerts | Proposing Signal integration | Human decision |
| **LOW** | Backlight keys still dead on G16 | Minor UX annoyance | Deep research paused, not blocking | Kimi Code 2.7 |

---

## Credential Registry

> **SECURITY:** Private repo. Keys stored for agent automation only.
> **Rotation due:** 2026-08-19

| Service | Key Prefix | Location | Scope |
|---------|-----------|----------|-------|
| GitHub | `ghp_...` | `.credentials/agent-keys.sh` | Repo read/write, Actions read |
| Google AI Studio | `AQ.Ab8...` | `.credentials/agent-keys.sh` | Gemini API burst tasks |
| Kimi/Moonshot | `sk-4U8...` | `.credentials/agent-keys.sh` | Kimi Code 2.7 context API |

---

## Monitoring Infrastructure

**Audit Script:** `.pmo/audit.sh`  
**Frequency:** Every 30 minutes (background session `amber-harbor`)  
**Log:** `.pmo/audit.log`  

### What I Check
- Wrong OVMF paths (`/usr/share/OVMF/`)
- Missing `<video><model type='none'/>`
- Deprecated `/dev/shm/looking-glass`
- `sudo` instead of `run0`
- New commits from endpoint agents

### Alert Thresholds
- **CRITICAL:** Wrong OVMF, missing video none, sudo usage → Immediate alert to you
- **WARNING:** Deprecated APIs, style issues → Logged, batched in digest
- **INFO:** Normal agent activity → Silent unless you ask

---

## Re-Steer Prompt For Google AI Studio

**What to tell him:**

```
Google AI Studio — read this corrections document before producing any further Bazzite code:
https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/pmo/corrections/.assets/docs/PMO_CORRECTIONS.md

It contains 12 errors detected in your previous output and the exact fixes.
Apply all corrections. Then proceed with burst implementation.

Current priority: G16 Bazzite passthrough (RTX 5080).
Base your work on: https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy/blob/feat/bazzite-vm-scaffold/bazzite-deploy.sh
```

**That's it.** He reads the file, applies corrections, continues working. No copy-paste needed.

---

## Communication Channels

| Channel | Status | Best For | Limitation |
|---------|--------|----------|------------|
| **Kimi Web App** | 🟢 ACTIVE | Current primary | No push notifications, check manually |
| **OpenClaw** | 🟢 ACTIVE | Scheduled tasks, heartbeats | Requires gateway running |
| **Signal** | 💡 PROPOSED | Loud alerts, urgent interrupts | Requires setup (see below) |
| **Feishu Bot** | ⏸️ CONFIGURED | Push notifications (previously used) | Not currently active |

### Signal Integration Proposal

If you want louder notifications than the Kimi app:

1. **Install Signal** on your phone
2. **Link OpenClaw** via Signal bridge (I can guide setup)
3. **I will send:** CRITICAL alerts only (agent errors, build failures, merge blockers)
4. **I will NOT send:** Routine digests, heartbeat OKs, non-urgent updates

**Cost:** One-time setup. Benefit: You know immediately if something breaks.

**Your call.** Say "set up Signal" and I'll configure it. Or stick with Kimi web + scheduled digests.

---

## Branch Status

| Branch | Purpose | Status | Merge Readiness |
|--------|---------|--------|-----------------|
| `main` | Production | 🟢 ACTIVE | Base for all work |
| `feat/bazzite-vm-scaffold` | Bazzite VM | 🟡 DEVELOP | Needs nvidia-smi confirmation |
| `pmo/corrections` | AI Studio fixes | 🟢 PUBLISHED | Living document |
| `feat/cosign-signing` | Signing (merged) | ✅ MERGED | Into `main` at `d346e97` |
| `arch/spdm-refactor` | SPDM restructure (merged) | ✅ MERGED | Into `main` |

---

## Recent Activity Log

| Time | Event | Actor |
|------|-------|-------|
| 03:22 | `feat/cosign-signing` merged to `main` | BuildBlue Pulse (approved by Human) |
| 03:20 | `pmo/corrections` branch pushed | BuildBlue Pulse |
| 02:49 | First PMO audit: OK | BuildBlue Pulse |
| 02:46 | Human approved PMO role transition | Human |
| 01:59 | Antigriguity CLI scaffold audit complete | Antigriguity CLI |
| 01:45 | Kimi Code 2.7 ISO download started | Kimi Code 2.7 |

---

## Next Scheduled Actions

| Time | Action |
|------|--------|
| 03:30 | 30-min audit cycle #2 |
| 04:00 | Check Kimi Code 2.7 ISO progress |
| 08:00 | Morning digest (if overnight activity) |
| TBD | Merge `feat/bazzite-vm-scaffold` → `main` (after nvidia-smi success) |
| TBD | Activate Antigriguity CLI for AMD Workstation (after G16 success) |
