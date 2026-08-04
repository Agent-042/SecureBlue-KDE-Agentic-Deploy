# Bolt's Performance Journal

## 2025-02-15 - Persistent Telemetry Stream & SQLite WAL Optimization
**Learning:** Re-connecting to SQLite and re-opening JSONL files on every logging event creates a severe disk I/O bottleneck (averaging 2.37ms per call in our environment). By maintaining persistent file handles and SQLite connections, enabling SQLite Write-Ahead Logging (WAL) mode, and adjusting synchronicity to `NORMAL` (`PRAGMA synchronous=NORMAL;`), we reduced the latency down to 0.07ms per call. This represents a >30x performance improvement.
**Action:** Always reuse connections and file descriptors for any logging, telemetry, or continuous data streaming modules. Utilize WAL mode for SQLite when dealing with high-frequency writes.
