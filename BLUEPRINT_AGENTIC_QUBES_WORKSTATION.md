# Blueprint: An Agent-Driven, High-Performance Qubes OS Workstation

This document synthesizes the research from all phases into a single, cohesive blueprint for building the desired Qubes OS system. It serves as the master plan for the "Agentic DevOps" construction process.

## 1. Vision Overview

The goal is to construct a highly customized Qubes OS workstation with three primary components:
1.  **A Customized `dom0`:** A stable, user-friendly `dom0` running the KDE Plasma desktop.
2.  **A High-Performance Gaming VM:** A `Bazzite` standalone HVM with a dedicated NVIDIA RTX 4080 GPU passed through for near bare-metal gaming performance.
3.  **An Agentic DevOps Framework:** A dedicated `AgentVM` that can securely and automatically build, configure, and manage the entire Qubes OS environment using a combination of `qrexec` and `SaltStack`.

## 2. Component Blueprints

### 2.1. `dom0` and Host System

-   **Desktop Environment:** KDE Plasma will be installed in `dom0` using the officially supported `kde-settings-qubes` package group.
-   **Immutability:** A true `rpm-ostree` based `dom0` is not feasible. Instead, immutability of configuration will be achieved declaratively via **SaltStack**. All `dom0` customizations will be defined in Salt state files.
-   **Hardware Configuration (AM5/7800X3D):**
    -   **UEFI/BIOS:** SVM, IOMMU, and Above 4G Decoding will be **Enabled**. Resizable BAR and XHCI Hand-off will be **Disabled**. The primary display will be set to the **iGPU**.
    -   **GRUB/Xen:** The `x2apic=false` kernel parameter is mandatory. The RTX 4080's PCI IDs will be hidden from `dom0` using `rd.qubes.hide_pci`.

**Reference:** `RESEARCH_DOM0_CUSTOMIZATION.md`

### 2.2. The Gaming VM (`bazzite-gaming`)

-   **VM Type:** Standalone HVM.
-   **OS:** Bazzite (NVIDIA ISO), installed from an ISO into the StandaloneVM's private volume.
-   **Hardware Assignment:**
    -   The NVIDIA RTX 4080 (VGA and Audio devices) will be attached via PCI passthrough.
    -   A dedicated secondary USB controller will be passed through for low-latency peripherals.
    -   Memory will be a static 16GB+ with memory balancing disabled.
    -   The kernel will be set to `(none)` to use Bazzite's native kernel.

**Reference:** `RESEARCH_GPU_PASSTHROUGH_GAMING.md`

### 2.3. The Agent VM and Automation Framework

-   **The `AgentVM`:** A dedicated AppVM, named `agent-vm`, will host the `agentic-agy` CLI.
-   **Core Principle:** The `AgentVM` will have **NO** direct shell access to `dom0`. All communication will be brokered through `qrexec`.
-   **Automation Architecture:**
    1.  **Declarative State:** The entire desired state of the system (VMs, properties, software) will be defined in **SaltStack** `.sls` state files and Pillar data files within `dom0`.
    2.  **Secure API:** A limited set of `qrexec` services (e.g., `agent.ApplySaltState`) will be created in `dom0`. These services act as a secure, high-level API. They are simple wrappers that validate input and execute `qubesctl` commands to apply Salt states.
    3.  **Orchestration:** The `AgentVM` will use `qrexec-client-vm` to call these services, passing the name of the desired state (e.g., `gaming_vm`) as an argument. This provides a secure chain of command to build and configure the entire system.

**Reference:** `RESEARCH_AGENTIC_AUTOMATION.md`

## 3. RAG Ingestion & Knowledge Base

The research documents (`RESEARCH_*.md`) created in this process serve as the source material for the RAG knowledge base.

-   **Local RAG (`agy`):** Key commands and concepts from the research will be added to the local SQLite database using `agy --learn`. This provides instant, offline access to critical commands.
    -   Example commands to learn:
        -   `sudo qubes-dom0-update @kde-desktop-qubes`
        -   `qvm-pci attach --persistent bazzite-gaming dom0:01_00.0`
        -   `echo "gaming_vm" | qrexec-client-vm dom0 agent.ApplySaltState`
-   **Cloud RAG (Vertex AI):** The full markdown documents should be uploaded to the designated GCS bucket (`gs://agentic-agy-rag-source/`) to be ingested by the Vertex AI RAG corpus. This will allow for more complex, semantic queries against the full body of research. The `agy_rag_setup.py` script can then be used to point the Gemini model to this corpus.

## 4. Next Steps: Implementation

This blueprint concludes the research phase. The next step is to begin implementation, which will be orchestrated by the `AgentVM`. The agent will now use this blueprint to:
1.  Create the necessary Salt and Pillar files in `dom0` (likely via a preliminary, manual setup or a specialized `qrexec` file-push service).
2.  Create the `qrexec` API services in `dom0`.
3.  Begin executing `qrexec` calls from the `AgentVM` to build the system as defined.
