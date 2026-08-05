# Bolt's Journal - Critical Learnings Only

## 2026-08-05 - [High-Frequency Database Logging Bottleneck]
**Learning:** Opening and closing SQLite connections, committing, and opening/closing JSONL files on every high-frequency logging call degrades throughput dramatically (e.g. up to 10-20x slower) because of repeated I/O and connection setup/teardown overhead. Using a persistent connection with `check_same_thread=False` combined with `journal_mode=WAL` and `synchronous=NORMAL` completely bypasses these bottlenecks.
**Action:** Always prefer persistent database and file handles with WAL mode for low-latency telemetry logging modules.
