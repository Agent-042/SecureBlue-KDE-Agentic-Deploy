# QUBES OS AI & AGENTIC DEVOPS WORKSTATION ARCHITECTURE

> **Target Platform**: Qubes OS 4.2 / 4.3 Architecture  
> **Security Strategy**: Strict Dom0 Isolation + Qrexec RPC Policy Control + `qubes-builderv2` Disposable Cages  
> **GCP Context**: Project `gen-lang-client-0385466726` | Region `us-west1`  
> **GitHub Repository**: [`Agent-042/SecureBlue-KDE-Agentic-Deploy`](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy)  

---

```
                               ┌─────────────────────────────────────────┐
                               │   OFFLINE DOM0 (Minimal Qubes Admin)    │
                               │ - No Network Interfaces / No SSH Server │
                               │ - Qrexec Policy Engine                  │
                               │ - Xen Hypervisor (PVH / HVM Domains)    │
                               └────────────────────┬────────────────────┘
                                                    │
         ┌──────────────────────────────────────────┼──────────────────────────────────────────┐
         │ (Qrexec RPC Policy)                      │ (PCI GPU Passthrough)                    │ (qubes.ConnectTCP VNC)
         ▼                                          ▼                                          ▼
┌──────────────────────────┐             ┌──────────────────────────┐               ┌──────────────────────────┐
│   Agent-Builder-VM       │             │   Bazzite Gaming / AI    │               │  Presentation / Dashboard│
│ - qubes-builderv2 Cage  │             │   GPU HVM (RTX 5080)     │               │  AppVM (VNC Viewer)      │
│ - Builds Bazzite/Secure- │             │ - VirtualGL / Looking    │               │ - Receives Streamed      │
│   Blue/Kicksecure Templates│           │   Glass IVSHMEM Output   │               │   Agent Metrics          │
└──────────────────────────┘             └──────────────────────────┘               └──────────────────────────┘
```

---

## 1. Core Principles & Dom0 Security Boundaries

1. **Zero Dom0 Network Reachability**: Dom0 remains 100% offline. No SSH daemons or networked shells are permitted in Dom0.
2. **Qrexec RPC Admin API**: All VM creation, template provisioning, and device assignment are performed via Qubes Admin API (`qrexec-client-vm dom0 qubes.AdminAPI...`) triggered from authorized management VMs.
3. **Isolated Build Pipelines (`qubes-builderv2`)**: Kernel builds, ISO generation, and custom template compilation (Bazzite, SecureBlue, Kicksecure) take place in disposable cages (`qubes-builder-dvm`) with strict stage isolation.
4. **Hardware GPU Passthrough**: High-performance AI model inference and gaming run in dedicated HVM qubes with secondary GPU passthrough via `pciback` and Looking Glass IVSHMEM channels.

---

## 2. `qubes-builderv2` Deployment Configuration (`builder.yml`)

The following `builder.yml` encapsulates the automated build pipeline for Bazzite, SecureBlue, Kicksecure, and GPU-enabled templates:

```yaml
# /builder/builder.yml - Qubes OS Agentic Workstation Builder Pipeline
schema-version: "2.0"

artifacts-dir: "/builder/artifacts"

executor:
  type: qubes
  options:
    dispvm: "qubes-builder-dvm"

components:
  - name: qubes-linux-kernel
    url: "https://github.com/QubesOS/qubes-linux-kernel"
    branch: "stable-6.6"
  - name: bazzite-template-builder
    url: "https://github.com/Agent-042/bazzite-qubes-template"
    branch: "main"
  - name: kicksecure-template-builder
    url: "https://github.com/Kicksecure/qubes-template-kicksecure"
    branch: "master"
  - name: gpu-template-builder
    url: "https://git.sr.ht/~yukikoo/gpu_template"
    branch: "main"

distributions:
  - name: fc39
    package-set: vm
  - name: bookworm
    package-set: vm

templates:
  - name: bazzite-gaming-atomic
    dist: fc39
    builder-component: bazzite-template-builder
  - name: kicksecure-hardened-agent
    dist: bookworm
    builder-component: kicksecure-template-builder
  - name: fedora-gpu-passthrough
    dist: fc39
    builder-component: gpu-template-builder

pipelines:
  template:
    - fetch
    - prep
    - build
    - publish
```

---

## 3. Qrexec RPC Security Policies (`50-agentic-workstation.policy`)

Deploy the following policy manifest to `/etc/qubes-rpc/policy/50-agentic-workstation.policy` in Dom0:

```text
# /etc/qubes-rpc/policy/50-agentic-workstation.policy

# Allow Agent-Builder-VM to trigger qubes-builder-dvm disposables
qubes.BuilderCreate  *  Agent-Builder-VM  @default  allow  target=qubes-builder-dvm

# Optional Dom0 Authentication Prompt for VM Sudo (qubes.VMAuth)
qubes.VMAuth        *  @anyvm            dom0      ask    default_target=dom0

# Screen / Dashboard TCP Stream Policy between Content Qube and Presentation Qube
qubes.ConnectTCP+5901  *  Presentation-VM  Content-VM  allow

# Restricted Admin API Access for Authorized Management Qube
qubes.AdminAPI+VMCreate  *  Agent-Manager-VM  @adminvm  allow
qubes.AdminAPI+VMPart    *  Agent-Manager-VM  @adminvm  allow
```

---

## 4. GPU Passthrough & Looking Glass Setup (`gpu_template`)

### Dom0 PCI Hiding (`/etc/default/grub`):
Find GPU PCI bus ID via `lspci | grep -i nvidia`:
```bash
# Add to GRUB_CMDLINE_LINUX in Dom0
rd.qubes.hide_pci=01:00.0,01:00.1
```
Regenerate grub and reboot:
```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
```

### Guest Attachment & VirtualGL Environment:
```bash
# Attach GPU to Bazzite Gaming HVM persistently
qvm-pci attach bazzite-gaming dom0:01_00.0 --persistent -o permissive=True -o no-strict-reset=True

# Enable VirtualGL & PRIME Render Offload inside Guest
export VGL_DISPLAY=egl
export __NV_PRIME_RENDER_OFFLOAD=1
export __VK_LAYER_NV_optimus=NVIDIA_only
export __GLX_VENDOR_LIBRARY_NAME=nvidia
```

---

## 5. RAG Knowledge Base Ingestion Script

The python helper below ingests all Qubes RPC policies, `qubes-builderv2` workflows, and GPU passthrough procedures directly into `/var/lib/agy/knowledge.db`:

```python
#!/usr/bin/env python3
import sqlite3
import os

DB_PATH = "/var/lib/agy/knowledge.db"

QUBES_KNOWLEDGE = [
    ("qubes-rpc", "qubes.VMAuth", "Triggers Dom0 prompt on VM sudo escalation via qrexec-client-vm", 
     "echo '/usr/bin/echo 1' > /etc/qubes-rpc/qubes.VMAuth"),
    ("qubes-builder", "qubes-builderv2 ./qb package all", "Builds Qubes packages inside disposable cages", 
     "./qb --executor qubes --dispvm qubes-builder-dvm package all"),
    ("qubes-pci", "qvm-pci attach <vm> dom0:<pci_id> --persistent", "Attaches host PCI GPU to target HVM with permissive mode", 
     "qvm-pci attach bazzite-gaming dom0:01_00.0 --persistent -o permissive=True -o no-strict-reset=True"),
    ("qubes-vnc", "qvm-connect-tcp ::5901", "Binds VNC TCP port between Presentation and Content qubes", 
     "qvm-connect-tcp ::5901 && vncviewer 127.0.0.1:5901")
]

def main():
    if not os.path.exists(DB_PATH):
        print(f"[!] Database path {DB_PATH} not found.")
        return
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    for sub, cmd, summ, ex in QUBES_KNOWLEDGE:
        cursor.execute(
            "INSERT OR REPLACE INTO commands (subsystem, command, summary, example) VALUES (?, ?, ?, ?)",
            (sub, cmd, summ, ex)
        )
    conn.commit()
    conn.close()
    print("[+] Successfully ingested Qubes OS Agentic Architecture into MCP RAG database.")

if __name__ == "__main__":
    main()
```
