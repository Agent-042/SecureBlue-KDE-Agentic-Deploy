# AGENTIC POWERHOUSE & GEMINI CLI HANDOVER MANIFEST

> **Target Platform**: SecureBlue Atomic Fedora (`ASUS` ROG G16)  
> **GCP Project ID**: `gen-lang-client-0385466726` | **Region**: `us-west1`  
> **GitHub Repository**: [`Agent-042/SecureBlue-KDE-Agentic-Deploy`](https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy)  
> **OpenWrt Router**: `Singularity` (`192.168.1.1`)  

---

## 1. Co-Execution & Integration Architecture

Antigravity CLI (`agy`) and Gemini CLI (`gemini`) run together on the same host using a shared environment and configuration state:

```
                          ┌──────────────────────────────────────┐
                          │   ASUS ROG G16 Workstation Host      │
                          └──────────────────┬───────────────────┘
                                             │
             ┌───────────────────────────────┴───────────────────────────────┐
             ▼                                                               ▼
┌─────────────────────────┐                                     ┌─────────────────────────┐
│   Antigravity CLI (agy) │                                     │     Gemini CLI (gemini) │
│ (Local Shell & Control) │                                     │ (MCP & IDE Extensions)  │
└────────────┬────────────┘                                     └────────────┬────────────┘
             │                                                               │
             └───────────────────────────────┬───────────────────────────────┘
                                             │
                                             ▼
                      ┌─────────────────────────────────────────────┐
                      │    Shared ~/.gemini/ Config & State         │
                      │  - mcp_config.json (18 MCP Servers)         │
                      │  - settings.json (Gemma Router Enabled)    │
                      │  - Data Agent Kit Starter Pack (25 Skills)  │
                      └──────────────────────┬──────────────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       ▼                                           ▼
         ┌───────────────────────────┐               ┌───────────────────────────┐
         │  Local Gemma Model Router │               │ Vertex AI Cloud RAG Engine│
         │ (Zero-Cost, Fast Speed)   │               │ (Spanner Vector Corpus)   │
         └───────────────────────────┘               └───────────────────────────┘
```

---

## 2. Model Usage & Efficiency Comparison

| Dimension | **Local Gemma Model (Gemma Model Router)** | **Cloud Gemini 2.5 / Vertex RAG** |
| :--- | :--- | :--- |
| **Primary Use Case** | Routine code completions, CLI lookups, local script edits, syntax checks | Large-scale codebase refactoring, multi-file architectural planning, cloud data apps |
| **Token Cost & Quota** | **0 Cost / Unlimited** (Runs 100% locally on RTX 5080) | Consumes API Quota / GCP billing |
| **Inference Speed** | **Ultra-Fast (~80-120 tok/sec)** | Dependent on cloud latency & network bandwidth |
| **Network Dependency**| **100% Offline Compatible** | Requires active internet connection |
| **Context Capacity** | Optimal for 8K-32K context tasks | 1M-2M ultra-long context window |

> [!TIP]
> **Recommended Strategy**: Use **Local Gemma** as the default engine for rapid local shell tasks, script editing, and command dispatch to minimize API consumption. Use **Cloud Gemini** when building complex Data Agent Kit pipelines, executing bigquery/dataproc transforms, or querying the Vertex AI RAG Corpus.

---

## 3. Configured MCP Servers & Extension Matrix

Shared across `/root/.gemini/antigravity-cli/mcp_config.json` and `/var/home/backstage/.gemini/antigravity-cli/mcp_config.json`:

- **Local MCP Toolboxes (`npx -y @toolbox-sdk/server`)**:
  - `notebook` (`--mode=notebook`)
  - `visualization` (`--mode=visualization`)
  - `bigquery`, `spanner`, `alloydb-postgres-admin`, `alloydb-postgres`
  - `cloud-sql-postgresql-admin`, `cloud-sql-postgresql`, `knowledge_catalog`
  - `dataproc`, `serverless-spark`, `bigtable`

- **Remote HTTP MCP Endpoints (`https://*.googleapis.com/mcp`)**:
  - `datacloud_knowledge_catalog_remote`, `datacloud_bigquery_remote`, `datacloud_spanner_remote`
  - `datacloud_dataproc_remote`, `datacloud_alloydb_remote`, `datacloud_cloud-sql_remote`

---

## 4. 5-VM Hypervisor & Passthrough Matrix

| Virtual Machine | Architecture | Looking Glass SHM | Passthrough / Features |
| :--- | :--- | :--- | :--- |
| **`qubes-agentic-powerhouse`** | Qubes OS | `/dev/shm/looking-glass-qubes-ph` | **SecureBoot Confirmed** |
| **`qubes-vm`** | Qubes OS | `/dev/shm/looking-glass-qubes` | **SecureBoot Confirmed** |
| **`bazzite-vm`** | Bazzite Linux | `/dev/shm/looking-glass-bazzite` | VirtIO 3D (`pci.0,addr=0x10`) |
| **`win11-gpu-agentic`** | Windows 11 | `/dev/shm/looking-glass-win11` | **NVIDIA RTX 5080 Passthrough** |
| **`bazzite-gaming`** | Bazzite Linux | `/dev/shm/looking-glass-bazzite-gaming` | **NVIDIA RTX 5080 Passthrough** |

---

## 5. Network & OpenWrt 25.12 Architecture

- **OpenWrt Router (`Singularity` `192.168.1.1`)**:
  - **`mwan3` Dual-WAN**: `wan` (modem `eth0`, metric 10) + `wwan` (`honeypot` repeater, metric 20).
  - **Mullvad WireGuard Tunnel**: Hardened with `fw4` kill-switch (`lan` forwards exclusively to `vpn` zone).
  - **DNS Interception**: All port 53 traffic DNATed to Mullvad DNS `10.64.0.1`.
- **Host NetworkManager (ASUS ROG G16)**:
  - Ethernet `enp0s13f0u4u3u4`: `route-metric 100`, `dns 192.168.1.1`, `ignore-auto-dns yes`, `autoconnect-priority 100`.
  - Wi-Fi `honeypot`: `route-metric 600`, `autoconnect-priority 50`.
