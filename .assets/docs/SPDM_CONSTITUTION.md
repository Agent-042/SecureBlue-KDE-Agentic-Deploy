# SPDM Constitution: Self-Parsing Deployment Manifest

> **Version:** 1.0  
> **Last Updated:** 2026-07-18  
> **Branch:** `arch/spdm-refactor`  
> **Status:** Living Document — submit PRs to amend

---

## 1. PREAMBLE

This document is the single source of truth for how the BuildBlue project structures, audits, and maintains its deployment infrastructure. It is **not** a style guide. It is the **architecture of the system itself**. If you change this, you change how the system thinks.

Every agent, human, and external contributor who touches this repository is bound by the rules below. No exceptions. No appeals. The repository is the enforcement mechanism.

---

## 2. CORE PARADIGM: DUAL-STATE ARCHITECTURE

An SPDM is a single bash file functioning simultaneously as:

1. **The Human Layer:** A declarative, copy-pasteable command sequence that a human can read, understand, and execute line by line on a fresh SecureBlue system.
2. **The Machine Layer:** A self-parsing, imperative AST that a build agent (BlueBuild, OpenClaw, or any AWK-compatible parser) can execute during OCI image creation.

These two layers **must not leak into each other**. What is readable to humans must be parseable to machines. What is imperative to machines must be explicit to humans.

---

## 3. OSTree / IMMUTABLE FILESYSTEM CONSTRAINTS

SecureBlue is built on OSTree. This means the filesystem is **bipolar**:

| Path | Build-Time | Runtime | Resolution |
|------|-----------|---------|------------|
| `/usr` | **Mutable** (layered via rpm-ostree) | **Read-only** | Install binaries and static assets here during build. Never write here at runtime. |
| `/var` | **Ephemeral** (discarded after build) | **Mutable** | State and runtime data. If a build-time script needs to place something here, redirect to `/usr/lib/` and generate `tmpfiles.d` rules to provision it at boot. |
| `/etc` | **Provisioned** via `/usr/etc` | **Mutable** (3-way merge) | Ship defaults as `/usr/etc/`. Runtime modifications in `/etc/` survive rebases. |
| `/home` | **Immutable** (separate mount) | **Mutable** | User data. Never touch during build. |

**The Constraint Resolution Engine:**

When a manifest contains a command that writes to `/var` during build time, the parser must:
1. Redirect the binary/asset path to `/usr/lib/` or `/usr/bin/`.
2. Generate a `/usr/lib/tmpfiles.d/<module>.conf` entry with the correct mode, owner, and path.
3. Emit a systemd oneshot service that applies the runtime state on first boot, not during build.

---

## 4. SPDM SCRIPT MORPHOLOGY: THE 6 RULES

All `.sh` manifests in the repository root must follow this anatomy exactly. No exceptions.

### Rule 1: Build Intercept

Immediately after the shebang and header comments, the script must intercept the `bluebuild` argument:

```bash
if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi
```

This is the **switch** that separates human reading from machine execution. If a human runs the script without arguments, they see the manifest. If BlueBuild invokes it with `bluebuild`, the AST engine takes over.

### Rule 2: Declarative Human Layer

All commands intended for the human (or the AST parser) live between these exact markers:

```bash
# <MANIFEST_START>

# Install the package
rpm-ostree install -y usbguard

# Enable the first-boot service
systemctl enable usbguard-first-boot.service

# <MANIFEST_END>
```

**Syntax Purity:** Within the human layer, there are **NO** bash variables, **NO** `if`/`for`/`while`, **NO** dynamic flags, **NO** command substitution, **NO** redirection to variables. Only explicit CLI commands with hardcoded paths and flags. Each command must be separated by a blank line. Each command must have a comment explaining its purpose.

### Rule 3: Explicit Terminator

Immediately below `# <MANIFEST_END>`, the script must exit:

```bash
exit 0
```

No trailing logic after the terminator. The human layer ends here. The machine layer begins below.

### Rule 4: AST Engine (AWK)

The `goto_script_logic()` function must parse `$0` (the script itself) via an AWK state machine. It must:

1. Toggle parsing on `# <MANIFEST_START>` and `# <MANIFEST_END>`.
2. Strip comment lines (starting with `#`).
3. Strip blank lines.
4. Buffer line continuations (`\` at end of line) into a single command.
5. Emit a sanitized, single-line command stream.

### Rule 5: Dynamic Routing (Per-Module, Not Monolithic)

The AWK engine categorizes each command into **Build Phase** or **Runtime Phase**:

**Build Phase (execute immediately in build container):**
- `rpm-ostree install ...` → execute immediately
- `systemctl enable ...` → execute immediately
- `mkdir -p /usr/...` → execute immediately

**Runtime Phase (must NOT execute in build container):**
- `usbguard generate-policy` → **hardware-specific, must run on target**
- `systemctl restart ...` → **runtime service management**
- Any command that touches hardware, user accounts, or dynamic state

**Resolution:** Runtime commands are **NOT** appended to a monolithic `/usr/libexec/first-boot-setup.sh`. Instead, each module generates its own **dedicated systemd oneshot service**:

```bash
/usr/lib/systemd/system/<module>-first-boot.service
```

This is **modular**, **debuggable**, and **idempotent**. A single monolithic first-boot script is a debugging nightmare and violates the principle of separation of concerns.

### Rule 6: Infallible First-Boot (Per-Module Systemd)

Each module that requires runtime initialization must ship:

**A. The first-boot script:**

```bash
/usr/bin/<module>-first-boot.sh
```

This script must:
- Check `ConditionPathExists=!/var/lib/<module>-first-boot.done` before doing work.
- Be idempotent (running twice should be safe).
- Use `run0` for any privileged operations, never `sudo`.

**B. The systemd oneshot service:**

```ini
[Unit]
Description=<Module> First-Boot Setup
After=network-online.target systemd-tmpfiles-setup.service
Before=display-manager.service sddm.service
ConditionPathExists=!/var/lib/<module>-first-boot.done

[Service]
Type=oneshot
ExecStart=/usr/bin/<module>-first-boot.sh
ExecStartPost=/bin/touch /var/lib/<module>-first-boot.done
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**C. Network Resilience (Standard):**

For modules that require network, the first-boot script should include a wait loop. The service must declare `After=network-online.target`, but this is best-effort. For critical network dependencies, add a retry loop inside the script itself.

**D. Enabling:**

The service is enabled during **build time** via the human layer:

```bash
systemctl enable <module>-first-boot.service
```

This creates the symlink in `multi-user.target.wants` automatically. Do not manually create symlinks.

---

## 5. REPOSITORY TOPOLOGY: THE 3 REALMS

After the SPDM refactor, the repository is divided into three distinct realms. Know where things live.

### Realm 1: The Root (Authority)

```
REPO ROOT/
├── *.sh                    ← SPDM MANIFESTS (human-readable, machine-parseable)
├── cosign.pub              ← Public signing key
├── README.md               ← Project overview + SECURITY AUDIT
└── .gitignore
```

The root is **declarative authority**. Every `.sh` file here is a contract. A human can `ls` the root and know every subsystem in the project by name. No clutter. No `node_modules`. No `dist/`. Just contracts.

### Realm 2: `.backend/` (The Forge)

```
.backend/
├── modules/                ← BlueBuild module declarations (*.yml)
├── files/<module>/usr/     ← System file drops (maps to /usr/ in OCI image)
├── recipes/                ← BlueBuild recipe files (recipe.yml, recipe-intel-g16.yml, etc.)
├── scripts/legacy/         ← Old scripts (read-only, reference only)
├── Justfile               ← Build automation
├── paint_recipe.py        ← Recipe generation
└── swarm_ledger.json      ← Agent state tracking
```

The backend is the **forge**. It contains the machinery that produces the OCI image. It is not human-readable at a glance. It is machine-readable. The root manifests reference it, but humans do not navigate here unless they are debugging a build.

### Realm 3: `.assets/docs/` (The Library)

```
.assets/docs/
├── README.md               ← Index of all guides
├── CONTRIBUTING_Coding_Agent.md  ← Baseline prompt for all coding agents
├── SPDM_CONSTITUTION.md    ← This document
├── <Module>_Fleet_Provisioning.md  ← Per-module documentation
├── DEPLOYMENT.md           ← Deployment overview
├── BROWSER_POLICY.md       ← Browser isolation policies
└── research/               ← Archived research, cryptomining docs, etc.
```

The library is **documentation**. Every module must have a corresponding `.md` file explaining the Human Logic and Script Logic. The library is for humans who need to understand, audit, or modify the system.

---

## 6. OPENCLAW / AGENT EXECUTION PROTOCOL

### The Non-Negotiable Rules

1. **STOP if unclear.** If an agent does not know where a file should go, what a command does, or whether a command is build-time or runtime, it must **stop working** and ask BuildBlue Pulse. Guessing is a bug. Stopping is correct.

2. **Never execute without audit.** No agent commits to `main` directly. All work happens on `feat/<descriptive>` branches. BuildBlue Pulse audits every branch before merge.

3. **Never use `sudo`.** SecureBlue strips `sudo`. Use `run0` for all privileged operations.

4. **Never commit secrets.** No API keys, no tokens, no PATs, no passwords. Use `env-init.sh` interactive prompting or systemd credentials for runtime secrets.

5. **Document or it didn't happen.** Every module must have a root manifest `.sh`, a backend module `.yml`, file drops in `.backend/files/`, and documentation in `.assets/docs/`. Missing any piece is incomplete.

### The Workflow

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Human Idea    │────▶│  Coding Agent    │────▶│  BuildBlue Pulse  │
│  (new feature)  │     │  (implements)    │     │  (audits + steers)│
└─────────────────┘     └──────────────────┘     └──────────────────┘
                              │                           │
                              ▼                           ▼
                        feat/usbguard-provision      Approved → Merge
                        (branch pushed to origin)    Rejected → Steer
                                                        │
                                                        ▼
                                                   Deep Research
                                                   (if needed)
```

### The Audit Gate

BuildBlue Pulse audits for:

- [ ] SPDM 6-Rule compliance (intercept, markers, purity, terminator, AST, per-module systemd)
- [ ] Path correctness (`.backend/` prefix, not root `files/` or `modules/`)
- [ ] Naming convention (`<module>-<action>.sh`, not `script.sh` or `installations.sh`)
- [ ] Build-time vs runtime separation (no hardware detection in build scripts)
- [ ] No `sudo` usage (only `run0`)
- [ ] No secrets in committed files
- [ ] Security scan for `curl | bash` patterns, pre-compiled binaries, obfuscated code

If any check fails, the branch is rejected with a specific steer for correction.

---

## 7. SECURITY AUDIT MANDATE

Every major refactor or module addition must include a security audit section. The audit must explicitly answer:

1. **Are there any `curl | bash` patterns?** If yes, document them, justify them, and describe the mitigation (e.g., fallback wrapper, checksum verification).
2. **Are there any pre-compiled binaries?** If yes, document the source, checksum, and verification method (e.g., Cosign signature, GPG key).
3. **Are there any secrets?** If no, state "No secrets committed." If yes, **reject the PR immediately.**
4. **Are there any obfuscated or minified scripts?** If yes, **reject the PR immediately.** All code must be auditable plain text.
5. **What is the supply chain path?** Trace every external dependency from source to binary in the final image.

The audit summary is appended to the top of `README.md` under the `# SECURITY AUDIT` header.

---

## 8. VERSIONING & AMENDMENT

This document is a **living document**. It changes as the project evolves.

- **Version format:** `MAJOR.MINOR` (e.g., `1.0`, `1.1`, `2.0`)
- **Major changes:** Breaking changes to the 6 Rules, topology, or agent protocol. Require human approval.
- **Minor changes:** Clarifications, additions, corrections. Can be approved by BuildBlue Pulse after a 24-hour review window.
- **Amendment process:** Submit a PR with `docs(constitution): amend [section]`. The PR must include a diff and a rationale.
- **Last Updated:** The date at the top of this file is updated on every amendment.

---

## 9. SIGNATURE

> This Constitution is the shared memory of the BuildBlue project. It is the reason we can hand work between agents, humans, and time itself without losing context. If you are reading this, you are bound by it.

**Current Canonical Branch:** `arch/spdm-refactor`  
**Next Scheduled Review:** 2026-08-18  
**Keeper of Record:** BuildBlue Pulse (Cloud Verifier / DevOps Auditor)

---

## APPENDIX A: Quick Reference Card

### Creating a New Module

1. `git checkout -b feat/<module-name> origin/arch/spdm-refactor`
2. Create `.backend/files/<module>/usr/...` file drops
3. Create `.backend/modules/<module>/module.yml` declaration
4. Add module to `.backend/recipes/recipe.yml` (and fleet variants)
5. Create root manifest: `<module>-<action>.sh` with SPDM 6-Rule format
6. Create `.assets/docs/<Module>_Fleet_Provisioning.md` documentation
7. Commit, push, request BuildBlue Pulse audit

### Build-Time vs Runtime Cheat Sheet

| Task | Phase | Implementation |
|------|-------|----------------|
| `rpm-ostree install` | Build | Human layer in root `.sh` |
| `systemctl enable` | Build | Human layer in root `.sh` |
| File drop to `/usr/etc/` | Build | `.backend/files/<module>/usr/etc/` |
| Hardware detection | Runtime | Systemd oneshot first-boot service |
| User configuration | Runtime | Systemd oneshot first-boot service |
| Network-dependent setup | Runtime | Systemd oneshot with `After=network-online.target` |
| State persistence | Runtime | `tmpfiles.d` + systemd oneshot |

### The Forbidden List

| Forbidden | Replacement | Why |
|-----------|-------------|-----|
| `sudo` | `run0` | SecureBlue strips sudo |
| `files/` at root | `.backend/files/` | Post-refactor topology |
| `modules/` at root | `.backend/modules/` | Post-refactor topology |
| `installations.sh` | `usbguard-provision.sh` | Descriptive naming |
| Script module for runtime | Systemd oneshot | Build vs runtime separation |
| `curl | bash` in human layer | `rpm-ostree install` or documented fallback | Security audit |
| Secrets in any file | `env-init.sh` or systemd credentials | Security audit |
| Direct push to `main` | `feat/` branch + audit | Quality gate |

---

*End of Constitution. If you reached this line, you have read the entire document. You are now authorized to contribute.*
