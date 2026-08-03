# Research Phase 3: Agentic Automation & Secure dom0 Access

This document outlines the secure architecture for achieving agent-driven automation of a Qubes OS system, fulfilling the "Agentic DevOps" requirement.

## 1. The Core Principle: No Direct `dom0` Shell Access

The initial request for direct `ssh` access from an `AgentVM` to `dom0` is a critical security anti-pattern that would dismantle the isolation guarantees of Qubes OS. **This approach will not be used.**

Instead, we will implement a secure, Qubes-native architecture using a combination of the **`qrexec` framework** and the **`SaltStack` configuration management engine**.

**The Proposed Architecture:**

1.  **The AgentVM (Conductor):** A dedicated `AgentVM` running the `agentic-agy` CLI will serve as the high-level orchestrator. It will make decisions (e.g., "create a new VM") but will not contain the low-level implementation details.
2.  **The `qrexec` API (Baton):** We will create a limited set of single-purpose `qrexec` services in `dom0`. These services act as a secure API, allowing the `AgentVM` to trigger specific, predefined actions without gaining arbitrary code execution.
3.  **The Salt States (Orchestra):** The `qrexec` services will, in turn, execute `SaltStack` states. These Salt files contain the declarative, "Infrastructure as Code" definitions for the entire Qubes system (all VMs, properties, software, etc.).

This model provides immense power while adhering to the principle of least privilege.

## 2. Step 1: `SaltStack` - Defining the System as Code

`SaltStack` is the engine that will build our system. We will define all components declaratively in `.sls` files stored in `dom0`.

### Example: A Declarative Gaming VM

1.  **Pillar Data (The variables):** We create a Pillar file in `dom0` at `/srv/user_pillar/gaming_vm.sls` to define our gaming VM's properties. This separates data from logic.

    ```yaml
    # /srv/user_pillar/gaming_vm.sls
    gaming_vm_config:
      name: bazzite-gaming
      label: red
      template: fedora-39
      maxmem: 16384
      vcpus: 8
      netvm: sys-firewall
      gpu_id: "01:00.0"
      gpu_audio_id: "01:00.1"
    ```

2.  **State File (The logic):** We create a Salt state file in `dom0` at `/srv/user_salt/gaming_vm.sls` that uses the Pillar data to configure the VM.

    ```yaml
    # /srv/user_salt/gaming_vm.sls
    {% set vm = salt['pillar.get']('gaming_vm_config') %}

    ensure_gaming_vm_is_present:
      qvm.present:
        - name: {{ vm.name }}
        - template: {{ vm.template }}
        - label: {{ vm.label }}
        - class: StandaloneVM

    configure_gaming_vm_prefs:
      qvm.prefs:
        - name: {{ vm.name }}
        - virt_mode: hvm
        - kernel: ""
        - maxmem: {{ vm.maxmem }}
        - memory: {{ vm.maxmem }}
        - vcpus: {{ vm.vcpus }}
        - netvm: {{ vm.netvm }}

    attach_gaming_vm_gpu:
      qvm.pci:
        - name: {{ vm.name }}
        - action: attach
        - persistent: True
        - devices:
            - dom0:{{ vm.gpu_id | replace(':','_') | replace('.','_') }}
            - dom0:{{ vm.gpu_audio_id | replace(':','_') | replace('.','_') }}
    ```

3.  **Top Files:** We create `top.sls` files in `/srv/user_pillar/` and `/srv/user_salt/` to map this configuration to `dom0`.

With these files in place, running `sudo qubesctl state.highstate` in `dom0` would automatically create, configure, and attach the GPU to the `bazzite-gaming` VM based entirely on our declarative files.

## 3. Step 2: `qrexec` - The Secure API for the Agent

Now, we create the secure `qrexec` service that allows the `AgentVM` to trigger this Salt run.

1.  **Create the `qrexec` Service Script:** In `dom0`, create the executable file `/etc/qubes-rpc/agent.ApplySaltState`.

    ```bash
    #!/bin/bash
    set -e

    # Read the name of the salt state to apply from stdin
    read -r SALT_STATE

    # Validate the input to only allow specific, safe state names
    case "$SALT_STATE" in
      "gaming_vm")
        # Execute the salt state
        echo "Applying Salt state: gaming_vm..."
        /usr/bin/qubesctl state.apply gaming_vm saltenv=user pillarenv=user
        ;;
      "dev_vm")
        echo "Applying Salt state: dev_vm..."
        /usr/bin/qubesctl state.apply dev_vm saltenv=user pillarenv=user
        ;;
      *)
        echo "ERROR: Unknown or disallowed Salt state '$SALT_STATE'." >&2
        exit 1
        ;;
    esac

    echo "State '$SALT_STATE' applied successfully."
    ```
    *This script is the security gatekeeper. It only allows known, safe Salt states to be triggered.*

2.  **Create the `qrexec` Policy:** In `dom0`, create the policy file `/etc/qubes/policy.d/90-agentvm-policy.policy`.

    ```
    # Allow 'agent-vm' to call the agent.ApplySaltState service on dom0
    agent.ApplySaltState    *   agent-vm   dom0   allow
    ```

## 4. Step 3: `AgentVM` - Triggering the Automation

Now, from the `agent-vm`, the `agentic-agy` tool can build the entire gaming VM with a single, secure command, without ever having shell access to `dom0`.

```bash
# In 'agent-vm' terminal
echo "gaming_vm" | qrexec-client-vm dom0 agent.ApplySaltState
```

**This architecture is the correct, secure, and powerful foundation for building an agent-driven Qubes OS system.** It is fully aligned with the Qubes security model while enabling the desired "autobuild" and "Agentic DevOps" capabilities.
