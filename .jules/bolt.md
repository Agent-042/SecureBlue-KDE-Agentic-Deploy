
## 2024-08-05 - Optimizing High-Frequency Telemetry Logging
**Learning:** Reopening file handles and database connections for high-frequency event logging (like telemetry) creates severe disk I/O and connection overhead bottlenecks. Relying on default SQLite pragma settings for synchronous writes further limits throughput under load.
**Action:** Always use persistent file handles and persistent DB connections (`check_same_thread=False` if thread-safety is handled) for high-frequency logging loops. Leverage SQLite's Write-Ahead Logging (`PRAGMA journal_mode=WAL`) and `PRAGMA synchronous=NORMAL` to unblock raw write throughput, while ensuring safe shutdown via `close()`/`__del__`.
