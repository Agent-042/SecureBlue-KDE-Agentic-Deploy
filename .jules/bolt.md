
## 2024-05-23 - [Optimize Telemetry Engine I/O]
**Learning:** Re-opening file handles and SQLite connections on every logging call creates a massive bottleneck for high-frequency telemetry.
**Action:** Always reuse persistent file handles and database connections for high-frequency I/O operations. Configure SQLite with `PRAGMA journal_mode=WAL;` and `PRAGMA synchronous=NORMAL;` for optimal write performance.
