🛑 ════════════════════════════════════════════════════════════
  BUILDBLUE PULSE — CODING AGENT INSTRUCTIONS (COPY-PASTE IN FULL)
  ════════════════════════════════════════════════════════════ 🛑

  ⚠️  READ THIS ENTIRE BLOCK BEFORE DOING ANY WORK.
  ⚠️  DO NOT SKIP SECTIONS. DO NOT ASSUME PATHS.
  ⚠️  IF ANYTHING IS UNCLEAR, STOP AND ASK BUILDBLUE PULSE.

  ────────────────────────────────────────────────────────────────
  📍 REPOSITORY STRUCTURE (POST-SPDM REFACTOR — USE THESE PATHS)
  ────────────────────────────────────────────────────────────────

  REPO ROOT
  ├── *.sh                    ← SPDM MANIFESTS (root-level, human-readable)
  │                              Naming: <module>-<action>.sh
  │                              GOOD:  usbguard-provision.sh
  │                              BAD:   installations.sh, script.sh, run.sh
  │
  ├── .backend/               ← BlueBuild BUILD-TIME ASSETS
  │   ├── modules/            ← Module declarations (*.yml)
  │   │   └── usbguard/
  │   │       └── module.yml
  │   ├── files/<module>/usr/ ← System file drops (maps to /usr/ in image)
  │   │   └── usbguard/
  │   │       └── usr/
  │   │           ├── bin/
  │   │           ├── etc/
  │   │           └── lib/systemd/system/
  │   ├── recipes/            ← BlueBuild recipes
  │   │   ├── recipe.yml
  │   │   ├── recipe-intel-g16.yml
  │   │   └── recipe-amd-workstation.yml
  │   └── scripts/legacy/     ← OLD SCRIPTS (read-only, do not modify)
  │
  ├── .assets/docs/           ← ALL DOCUMENTATION AND GUIDES
  │   └── USBGuard_Fleet_Provisioning.md
  │
  └── .github/workflows/      ← CI/CD (do not touch)

  ────────────────────────────────────────────────────────────────
  🚫 NEVER DO THESE THINGS
  ────────────────────────────────────────────────────────────────

  [ ] NEVER push directly to main. Always create feature branch.
    Branch naming: feat/<descriptive-name>
    Example: feat/usbguard-provision

  [ ] NEVER use files/, modules/, recipes/ at root.
    They are now in .backend/. Pushing to old paths = REJECTED.

  [ ] NEVER use generic filenames like installations.sh, script.sh, run.sh.
    Every root manifest must be descriptively named.

  [ ] NEVER use BlueBuild "script" module for RUNTIME logic.
    Script modules run in BUILD CONTAINER, not target hardware.
    If it needs to run on the actual laptop/workstation:
    → Use systemd oneshot service + .backend/files/ drop.

  [ ] NEVER use sudo. SecureBlue strips it. Use run0 instead.

  [ ] NEVER put API keys, tokens, or secrets in any committed file.
    Use env-init.sh prompt pattern or systemd credentials.

  ────────────────────────────────────────────────────────────────
  ✅ ALWAYS DO THESE THINGS
  ────────────────────────────────────────────────────────────────

  [ ] ALWAYS check out the latest branch before starting:
        git fetch origin
        git checkout -b feat/<name> origin/arch/spdm-refactor

  [ ] ALWAYS use .backend/ prefix for all build assets:
        .backend/files/<module>/  ← NOT files/
        .backend/modules/<module>/  ← NOT modules/
        .backend/recipes/  ← NOT recipes/

  [ ] ALWAYS create a root SPDM manifest for human reference:
        <module>-<action>.sh at repo root
        Use exact SPDM format with # <MANIFEST_START> / # <MANIFEST_END>
        Include comments explaining each command's purpose

  [ ] ALWAYS separate BUILD-TIME vs RUNTIME logic:
        BUILD-TIME (runs in BlueBuild container):
          - rpm-ostree install <package>
          - systemctl enable <service>
          - File drops to /usr/

        RUNTIME (runs on target hardware after first boot):
          - usbguard generate-policy
          - Hardware detection
          - User-specific configuration
          → Must be implemented as systemd oneshot service

  [ ] ALWAYS create documentation in .assets/docs/:
        File naming: <Module>_Fleet_Provisioning.md
        Include: Human Logic, Script Logic, Troubleshooting

  [ ] ALWAYS commit with descriptive message:
        feat(<module>): <what changed>
        Example: feat(usbguard): add daemon config and first-boot policy generator

  ────────────────────────────────────────────────────────────────
  📋 SPDM MANIFEST TEMPLATE (Copy-Paste for Root *.sh)
  ────────────────────────────────────────────────────────────────

  #!/usr/bin/env bash
  # <module>-<action>.sh
  # <one-line description of what this does>
  # SPDM Manifest: Self-Parsing Deployment Manifest format.

  if [[ "$1" == "bluebuild" ]]; then goto_script_logic "$0"; exit 0; fi

  # <MANIFEST_START>
  # Pure commands only. No variables. No conditionals. No loops.
  # One command per line. Blank line between commands.
  # Every command MUST have a comment explaining its purpose.

  # Install the usbguard package into the image
  rpm-ostree install -y usbguard

  # Enable the first-boot policy generation service
  systemctl enable usbguard-first-boot.service

  # <MANIFEST_END>

  exit 0

  # --- SPDM AST Construction Engine ---
  # (Include standard goto_script_logic() function here)
  # DO NOT MODIFY THIS FUNCTION. Copy it from any existing root manifest.

  ────────────────────────────────────────────────────────────────
  🔄 SYSTEMD ONESHOT TEMPLATE (For Runtime Logic)
  ────────────────────────────────────────────────────────────────

  [Unit]
  Description=<Module> First-Boot Setup
  After=network-online.target systemd-tmpfiles-setup.service
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

  ────────────────────────────────────────────────────────────────
  🆘 WHEN YOU ARE STUCK OR UNSURE
  ────────────────────────────────────────────────────────────────

  STOP WORKING. Do not guess. Do not "figure it out."

  Ask BuildBlue Pulse (the Cloud Verifier / Auditor) using EXACTLY this format:

    [STUCK] Module: <name>
    Question: <precise question about structure or integration>
    Context: <what you tried and what failed>

  BuildBlue Pulse will either:
  - Give you the exact path and structure
  - Escalate to a deep research agent for technical details
  - Reject the approach and suggest an alternative

  ────────────────────────────────────────────────────────────────
  📝 END OF BUILDBLUE PULSE CODING AGENT INSTRUCTIONS
  ══════════════════════════════════════════════════════════════
