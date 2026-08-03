# Gemini Workspace Instructions

This document provides a guide for AI agents interacting with the `SecureBlue-KDE-Agentic-Deploy` repository. Adherence to these guidelines is mandatory.

## Project Overview

This project builds a hardened, immutable, multi-fleet Fedora Atomic KDE OCI image using [BlueBuild](https://blue-build.org/). The goal is to create a high-assurance, reproducible desktop operating system tailored for agentic workflows, with a strong focus on security, isolation, and automation.

The core of the project is the **SPDM (Self-Parsing Deployment Manifest)** architecture.

## Core Architecture: SPDM (Self-Parsing Deployment Manifest)

Every `.sh` script in the root directory is an SPDM. This means it has a dual-state nature:

1.  **Human Layer:** A declarative, commented sequence of commands that a human can read and execute. This is contained between `# <MANIFEST_START>` and `# <MANIFEST_END>` markers.
2.  **Machine Layer:** A machine-parseable Abstract Syntax Tree (AST) processed by a build agent (e.g., BlueBuild). This is handled by the `goto_script_logic` function in each script.

**CRITICAL:** Within the human layer, do not use variables, loops, or conditionals. Only pure, commented, single-line commands are allowed.

## Key Agent Development Rules & Conventions

### Workflow

1.  **Branching:** ALWAYS create a feature branch from `origin/arch/spdm-refactor`. NEVER commit to `main`.
    *   `git fetch origin`
    *   `git checkout -b feat/<descriptive-name> origin/arch/spdm-refactor`
2.  **Commits:** Use descriptive, conventional commit messages.
    *   `feat(<module>): <what changed>`
    *   Example: `feat(usbguard): add first-boot policy generator`
3.  **Asking for Help:** If anything is unclear, STOP and ask for guidance. Do not guess.

### File and Directory Structure

*   **Root (`/`):** Contains only SPDM `.sh` manifests and top-level project files (`README.md`, `cosign.pub`).
*   **Build Assets (`.backend/`):** ALL build-time assets go here.
    *   `.backend/modules/`: BlueBuild module declarations (`*.yml`).
    *   `.backend/files/<module>/usr/`: Files to be injected into the OCI image.
    *   `.backend/recipes/`: BlueBuild recipe files (`recipe.yml`, etc.).
*   **Documentation (`.assets/docs/`):** All documentation and guides. Every new module requires a corresponding document here.

### Build-Time vs. Runtime Logic

The system is immutable (based on OSTree), so there's a strict separation between build-time and runtime operations.

*   **Build-Time (in BlueBuild container):**
    *   `rpm-ostree install`
    *   `systemctl enable`
    *   Dropping files into `/usr` (via `.backend/files/`)
*   **Runtime (on target machine):**
    *   Hardware-specific logic (`usbguard generate-policy`).
    *   User-specific configuration.
    *   Network-dependent setup.
    *   **Implementation:** MUST be done via a **systemd oneshot service** that runs on first boot. The service unit file and the script it runs are dropped into the image via `.backend/files/`.

### Forbidden Actions

*   **NEVER use `sudo`:** The base image strips `sudo`. Use `run0` for privileged operations.
*   **NEVER commit secrets:** No API keys, tokens, or passwords. Use `env-init.sh` for interactive prompts or `systemd` credentials for runtime secrets.
*   **NEVER use generic filenames:** Scripts must be descriptive (e.g., `usbguard-provision.sh`, not `install.sh`).
*   **NEVER use old paths:** Do not use `files/` or `modules/` at the root. They are in `.backend/`.

## Important Files for Reference

*   **Canonical Architecture:** `.assets/docs/SPDM_CONSTITUTION.md` (The single source of truth for the system architecture).
*   **Agent Instructions:** `.assets/docs/CONTRIBUTING_Coding_Agent.md` (The baseline prompt and rules for coding agents).
*   **Project README:** `README.md` (High-level overview, security audit, and rebase instructions).
