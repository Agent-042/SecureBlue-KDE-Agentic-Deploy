# Bolt's Journal - Critical Learnings Only

This journal tracks critical learnings on performance optimization in this codebase.

## 2025-08-03 - Persistent File and DB Connections in High-Frequency Telemetry
**Learning:** Instantiating new SQLite connections and opening/closing JSONL log files synchronously inside hot path loops causes substantial disk/OS I/O latency bottlenecks (~2.07ms per entry). Keeping connections and file descriptors persistent, and utilizing optimized SQLite PRAGMAs like `journal_mode=WAL` and `synchronous=NORMAL` completely bypasses this overhead, dropping latency to ~0.13ms.
**Action:** Keep database connections and log file descriptors open in persistent state objects/engines instead of recreating them on every single log/write event.
