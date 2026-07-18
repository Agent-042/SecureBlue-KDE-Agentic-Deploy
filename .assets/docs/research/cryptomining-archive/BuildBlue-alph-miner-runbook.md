# BuildBlue ALPH Miner — Rootless RTX 4080 MoneroOcean Profit-Switching Runbook

> **Version:** 1.0  
> **Date:** 2026-07-12  
> **Target:** SecureBlue Kinoite (Fedora KDE, hardened immutable)  
> **Goal:** Operate a rootless Podman GPU miner that profit-switches between `autolykos2` and `etchash` on MoneroOcean via Multi-Miner v5.0 and Rigel 1.23.2. `kawpow` is benchmarked but disabled because Multi-Miner v5.0 misreads Rigel's kawpow hashrate.

---

## Table of Contents

1. [One-Line Purpose](#one-line-purpose)
2. [System Architecture](#system-architecture)
3. [File Inventory](#file-inventory)
4. [Operational Commands](#operational-commands)
5. [Script Logic](#script-logic)
6. [Benchmark Results](#benchmark-results)
7. [Troubleshooting Playbooks](#troubleshooting-playbooks)
8. [Security Notes](#security-notes)

---

## 1. One-Line Purpose

A hardened, rootless, systemd-managed RTX 4080 miner stack that automatically selects the most profitable MoneroOcean algorithm while self-healing from stuck GPUs, duplicate miners, and stale containers.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Host: SecureBlue Kinoite / Fedora KDE (RTX 4080)                       │
│  ─────────────────────────────────────────────────────                  │
│  systemd user units                                                     │
│    ├── alph-miner.service        (Podman Quadlet .container)            │
│    ├── gpu-watchdog.service      (triggered by gpu-watchdog.timer)      │
│    └── gpu-watchdog.timer        (every 30 s)                           │
│                                                                         │
│  Podman (rootless)                                                      │
│    └── alph-miner container                                             │
│        ├── CDI GPU passthrough: nvidia.com/gpu=all                      │
│        ├── mm.json mounted from host                                    │
│        ├── Multi-Miner v5.0  (/miner/mm)                                │
│        └── Rigel 1.23.2      (/miner/rigel)                             │
│                                                                         │
│  Pool: gulf.moneroocean.stream:ssl20128 (SSL stratum)                   │
└─────────────────────────────────────────────────────────────────────────┘
```

Flow:
1. `gpu-watchdog.timer` fires every 30 seconds.
2. `gpu-watchdog.service` runs `gpu_watchdog.sh`.
3. The watchdog checks `alph-miner` status, duplicate Rigel processes, and GPU utilization.
4. If a fault is detected, the watchdog restarts `alph-miner`.
5. `alph-miner.service` runs an `ExecStartPre` (`alph-miner-cleanup.sh`) that kills any stale Rigel processes before the container starts.
6. The container starts `mm`, which spawns Rigel for the currently selected algorithm and proxies work to MoneroOcean.

---

## 3. File Inventory

| File | Path | Purpose |
|------|------|---------|
| Quadlet container unit | `~/.config/containers/systemd/alph-miner.container` | Defines the rootless Podman container: image, CDI GPU device, volume mount, capabilities, restart policy. |
| Container image recipe | `~/mo-gpu-miner.Containerfile` | Builds `localhost/mo-gpu-miner:latest` from `nvidia/cuda:12.5.1-base-ubuntu24.04`, installing Multi-Miner v5.0 and Rigel 1.23.2. |
| Multi-Miner config | `~/.config/mo-gpu-miner/mm.json` | Profit-switching configuration: pool, algorithms, Rigel CLI templates, `algo_perf` benchmarks, watchdog timers. |
| GPU watchdog script | `~/gpu_watchdog.sh` | Detects 0% GPU utilization and duplicate Rigel processes; restarts `alph-miner` with cooldown and strike logic. |
| Pre-start cleanup script | `~/alph-miner-cleanup.sh` | Kills stale Rigel processes before a new container starts. |
| Watchdog service | `~/.config/systemd/user/gpu-watchdog.service` | systemd oneshot service that executes `gpu_watchdog.sh`. |
| Watchdog timer | `~/.config/systemd/user/gpu-watchdog.timer` | Fires `gpu-watchdog.service` every 30 seconds. |
| Service override | `~/.config/systemd/user/alph-miner.service.d/prestart-cleanup.conf` | Injects `ExecStartPre=-/home/agent-42/alph-miner-cleanup.sh` into the Quadlet-generated `alph-miner.service`. |

---

## 4. Operational Commands

### Start the miner
```bash
systemctl --user start alph-miner
```

### Stop the miner
```bash
systemctl --user stop alph-miner
```

### Restart the miner
```bash
systemctl --user restart alph-miner
```

### View miner logs
```bash
journalctl --user -u alph-miner -f
```

### View Multi-Miner / Rigel logs inside the container
```bash
podman logs -f alph-miner
```

### View watchdog log
```bash
tail -f ~/gpu_watchdog.log
```

### Check watchdog timer status
```bash
systemctl --user status gpu-watchdog.timer
systemctl --user list-timers gpu-watchdog.timer
```

### Check all related units
```bash
systemctl --user status alph-miner gpu-watchdog.service gpu-watchdog.timer
```

### Rebuild the image (after modifying `mo-gpu-miner.Containerfile`)
```bash
cd ~
podman build -t localhost/mo-gpu-miner:latest -f mo-gpu-miner.Containerfile .
```

### Reload systemd user daemon (after changing `.container`, `.service`, `.timer`, or override files)
```bash
systemctl --user daemon-reload
```

### Enable units to start on login
```bash
systemctl --user enable alph-miner gpu-watchdog.timer
```

---

## 5. Script Logic

### `gpu_watchdog.sh`

Runs every 30 seconds via `gpu-watchdog.timer`.

1. **Early exit.** If `alph-miner` is not active, reset the zero-utilization counter and exit.
2. **Duplicate Rigel detection.** Counts real (non-defunct) `rigel-1.23.2-linux/rigel` processes owned by the user. The `/miner/rigel` wrapper is ignored. If the count is greater than 1, the watchdog kills duplicates and restarts `alph-miner`.
3. **GPU utilization sampling.** Reads `nvidia-smi --query-gpu=utilization.gpu`. If the value is missing or non-numeric, the sample is ignored.
4. **Strike logic.** If utilization is `0%`, increment a counter (`STRIKES=3`). After 3 consecutive zero samples, restart `alph-miner`.
5. **Cooldown.** Restarts are throttled to one per `COOLDOWN_SEC=300` seconds.
6. **Diagnostics.** On restart, captures `nvidia-smi` output and the last 30 lines of `podman logs alph-miner` to `~/gpu_watchdog.log`.

### `alph-miner-cleanup.sh`

Executed as `ExecStartPre` before the container starts.

1. Identifies user-owned processes whose exact command name is `rigel` or `rigel-1.23.2-linux` and whose state is not zombie.
2. Excludes the cleanup script itself (`comm` is `bash`).
3. Sends `SIGKILL` to each stale PID.
4. Always exits 0 so a missing PID cannot fail the service start.

### `mm.json` profit switching

Multi-Miner selects the algorithm with the highest expected profit:

```
profit_estimate = algo_perf[algo] * pool_value_for_algo
```

Where:
- `algo_perf` is the measured hashrate in hashes per second.
- Pool value is MoneroOcean's live price for that algorithm.

Key fields:

| Field | Value | Meaning |
|-------|-------|---------|
| `pools` | `gulf.moneroocean.stream:ssl20128` | SSL MoneroOcean pool endpoint. |
| `algos` | Rigel CLI per algorithm | Rigel connects to the local `mm` proxy at `127.0.0.1:3333`. `kawpow` is not present because it is disabled. |
| `algo_perf` | `autolykos2: 155400000`, `etchash: 33280000` | Benchmarked hashrates (H/s). |
| `algo_min_time` | `600` | Minimum seconds on an algorithm before switching. |
| `watchdog` | `600` | Multi-Miner internal watchdog interval (seconds). |
| `hashrate_watchdog` | `50` | Threshold percentage of expected hashrate before Multi-Miner restarts the miner. |

---

## 6. Benchmark Results

| Algorithm | Hashrate | `algo_perf` (H/s) | Notes |
|-----------|----------|-------------------|-------|
| autolykos2 | 155.4 MH/s | `155400000` | Currently the primary, stable algorithm. |
| etchash | 33.28 MH/s | `33280000` | Stable fallback. |
| kawpow | 41.45 MH/s | `41450000` (measured, not active) | **Disabled:** Multi-Miner v5.0 misreads Rigel's kawpow hashrate as ~0.0097, tripping `hashrate_watchdog`. Value preserved for future reference. |

### kawpow hashrate-watchdog caveat

When `kawpow` is enabled, Multi-Miner v5.0 sees roughly `0.0097` instead of the measured `41.45 MH/s`. This trips `hashrate_watchdog` and causes repeated restarts.

**Decision:** Remove `kawpow` from the `algos` dictionary in `mm.json` so Multi-Miner cannot select it. The measured `41.45 MH/s` value is preserved in this runbook for future reference. To re-enable kawpow later, a different miner or a `hashrate_watchdog` workaround would be required.

---

## 7. Troubleshooting Playbooks

### 0% GPU utilization

1. Check that `alph-miner` is active:
   ```bash
   systemctl --user status alph-miner
   ```
2. Inspect miner logs:
   ```bash
   journalctl --user -u alph-miner -n 100
   podman logs --tail 50 alph-miner
   ```
3. Check `nvidia-smi` from the host:
   ```bash
   nvidia-smi
   ```
4. Verify the watchdog is running and has not hit cooldown:
   ```bash
   tail -f ~/gpu_watchdog.log
   ```
5. If utilization remains 0% for more than ~90 seconds, the watchdog will restart the miner after 3 strikes.

### Duplicate Rigel

Symptom: multiple `rigel-1.23.2-linux/rigel` processes, high CPU from orphaned miners, watchdog restarts.

1. List processes:
   ```bash
   ps -eo user,pid,stat,comm,args | grep rigel
   ```
2. The watchdog auto-kills duplicates. To force cleanup:
   ```bash
   ~/alph-miner-cleanup.sh
   systemctl --user restart alph-miner
   ```
3. Verify only one real Rigel process remains:
   ```bash
   ps -eo user,pid,comm,args | grep '/rigel-1\.23\.2-linux/rigel'
   ```

### Connection errors

1. Confirm host networking and DNS:
   ```bash
   ping -c 3 gulf.moneroocean.stream
   ```
2. Check the pool endpoint in `~/.config/mo-gpu-miner/mm.json`:
   - Expected: `gulf.moneroocean.stream:ssl20128`
3. Verify SSL is allowed; Rigel is invoked with `--no-strict-ssl` for the local `mm` proxy.
4. Review `podman logs alph-miner` for stratum or certificate errors.

### Profit-switching not switching

1. Verify `algo_perf` values are populated in `~/.config/mo-gpu-miner/mm.json`.
2. Confirm `algo_min_time` is not set too high (default: 600 seconds).
3. Watch the Multi-Miner logs for `Switching` messages:
   ```bash
   podman logs -f alph-miner
   ```
4. Ensure MoneroOcean is returning pool price data for all configured algorithms.

### kawpow watchdog restarts

1. Confirm the symptom in `podman logs alph-miner`:
   - Rigel reports ~41 MH/s.
   - Multi-Miner reports ~0.0097 and triggers `hashrate_watchdog`.
2. Current fix: `kawpow` is removed from `mm.json` `algos`, so the miner stays on `autolykos2` or `etchash` and restarts stop.
3. To re-test kawpow later, re-add the `kawpow` entry to `algos` and `algo_perf` (`41450000`), then address the `hashrate_watchdog` mismatch (e.g., a different miner binary or a higher global threshold).

---

## 8. Security Notes

| Control | Implementation |
|---------|----------------|
| Rootless Podman | The container runs under the user's systemd, not as root. |
| Capability drop | `DropCapability=ALL` in `alph-miner.container`. |
| No new privileges | `NoNewPrivileges=true` in `alph-miner.container`. |
| CDI GPU passthrough | `AddDevice=nvidia.com/gpu=all` uses the NVIDIA Container Toolkit CDI spec; no raw `/dev/nvidia*` manipulation is required. |
| Minimal container image | Based on `nvidia/cuda:12.5.1-base-ubuntu24.04`; only `ca-certificates`, `curl`, `wget`, `tar`, and `ocl-icd-libopencl1` are added. |
| Local proxy only | Rigel connects to `127.0.0.1:3333` inside the container; the wallet/user string is sent to MoneroOcean only via Multi-Miner. |
| Self-cleaning | `alph-miner-cleanup.sh` and `gpu_watchdog.sh` prevent orphaned GPU miner processes from persisting. |

---

## Quick Reference

```bash
# Status
systemctl --user status alph-miner gpu-watchdog.timer gpu-watchdog.service

# Logs
journalctl --user -u alph-miner -f
podman logs -f alph-miner
tail -f ~/gpu_watchdog.log

# Restart / reload
systemctl --user restart alph-miner
systemctl --user daemon-reload

# Rebuild image
podman build -t localhost/mo-gpu-miner:latest -f ~/mo-gpu-miner.Containerfile ~
```
