# G16 Bazzite VM Deployment: Orientation & Architecture Handbook

> **Project Boss Target:** Google AI Studio  
> **SPDM Constitution:** [SPDM_CONSTITUTION.md](SPDM_CONSTITUTION.md)  
> **Coding Guidelines:** [CONTRIBUTING_Coding_Agent.md](CONTRIBUTING_Coding_Agent.md)  
> **GITHUB_PAT:** `${GITHUB_PAT}` (Transient environment reference)

---

## 1. Executive Context

This handbook acts as the architecture onboarding reference for Google AI Studio during the Bazzite gaming VM implementation on the ASUS ROG Zephyrus G16 laptop. It describes the physical-to-virtual boundaries, security verification guidelines, and IaC repository topology.

The repository is authenticated using the provided `GITHUB_PAT` and conforms strictly to the **SPDM Constitution (v1.0)**.

---

## 2. The Core Dual-VM Architecture

The G16 deployment implements a **Dual-VM system** designed to run Windows Enterprise (productivity/isolated work) and Bazzite (gaming/performance) concurrently or sequentially on top of a hardened SecureBlue host.

```text
       ┌──────────────────────────────────────────────┐
       │             ASUS ROG Zephyrus G16            │
       │           (Hardened SecureBlue Host)         │
       └──────────────────────┬───────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
  ┌───────────────────────┐       ┌───────────────────────┐
  │  Windows Enterprise   │       │  Bazzite Gaming VM    │
  │     (Productivity)    │       │   (Steam / Lutris)    │
  │                       │       │                       │
  │ - Q35 / UEFI / Host   │       │ - Q35 / UEFI / Host   │
  │ - RTX 5080 Passthrough│       │ - RTX 5080 Passthrough│
  │ - Looking Glass Client│       │ - Looking Glass Client│
  │ - evdev input toggle  │       │ - evdev input toggle  │
  └───────────────────────┘       └───────────────────────┘
```

### High-Performance Passthrough Mechanics:
1. **Discrete GPU Passthrough:** The system isolates the NVIDIA RTX 4070/5080 Laptop dGPU at boot using `vfio-pci` binding. The VM has exclusive raw hardware access for maximum FPS and DLSS support.
2. **KVMFR (Looking Glass Framebuffer):** Rather than standard `/dev/shm` virtual files, the system uses the `kvmfr` kernel module. This allocates a dedicated, page-aligned raw memory frame buffer directly in kernel space, allowing zero-copy frames to be pulled by the Looking Glass client on the host.
3. **Evdev Low-Latency Inputs:** Mice and keyboards are passed directly using QEMU's `input-linux` command-line switches, routing hardware device inputs directly without emulating USB latency. Toggle occurs via the `Left-Ctrl + Right-Ctrl` hotkey.
4. **USB Hotplugging (YubiKey):** A custom transient `ujust` macro is provided to safely hotplug the host's physical YubiKey into whichever VM is actively focused.

---

## 3. Compliance & Structural Standards

All code generated for this project is bound by the **SPDM Constitution**. Any changes must be verified against the following checks before committing:

1. **Dual-State Separation:**
   - Build-time commands (e.g., `rpm-ostree install`) live in the declarative SPDM human layer between `# <MANIFEST_START>` and `# <MANIFEST_END>` in root manifests.
   - Runtime configuration (e.g., loading modules, modifying `/var/` or user space) must be encapsulated into dedicated systemd oneshot services and `/usr/bin/` scripts to protect the immutable OSTree filesystem.
2. **Strict Command Terminals:**
   - Root manifests must have `exit 0` directly below the `# <MANIFEST_END>` tag to prevent the shell from executing lower machine-state code blocks when read or run directly by operators.
3. **Privilege Escalation:**
   - Absolutely no `sudo` commands. SecureBlue strips sudo access. All host-level administrative operations must use `run0`.
4. **Secret Sanitation:**
   - No API keys, personal access tokens, or credentials may be written to disk. The `GITHUB_PAT` is treated as a transient environment variable `${GITHUB_PAT}` injected via systemd or terminal state at runtime.

---

## 4. Repository Topology Map

When writing backend integrations, ensure code is dropped into the correct folders:

```text
ROOT/
├── bazzite-deploy.sh         <-- SPDM VM Provisioning Manifest
├── *.sh                       <-- Other SPDM manifests (e.g. rebase.sh)
├── .backend/
│   ├── modules/               <-- BlueBuild YAML declarations
│   ├── files/                 <-- OS Overlay directory drops (maps to /usr/)
│   │   └── bazzite-launcher.desktop
│   └── recipes/               <-- Image recipe templates
└── .assets/docs/
    ├── SPDM_CONSTITUTION.md   <-- Project Architecture Core
    ├── CONTRIBUTING_Coding_Agent.md
    └── BAZZITE_ORIENTATION_HANDBOOK.md  <-- This document
```

---

## 5. Deployment Roadmap & Execution Strategy

1. **Image Compile Phase:** The GitHub Actions workflow builds the target image via BlueBuild, installing virtualization libraries and generating the `bazzite-launcher.desktop` shortcut.
2. **Reconnaissance Mapping:** The operator runs IOMMU queries to locate the exact bus, slot, and function numbers for the GPU.
3. **Deployment Script Run:** The operator executes:
   ```bash
   run0 bash bazzite-deploy.sh
   ```
   This creates the isolated bridge network interface, creates the 100GB sparse `qcow2` virtual disk, sets up `tmpfiles.d` for the framebuffer, and registers the XML template with `virsh`.
4. **Validation Check:** Verify the signature using `cosign.pub` and perform a dry-run check of the VM properties.
