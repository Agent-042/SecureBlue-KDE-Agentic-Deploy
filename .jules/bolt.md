# Bolt's Journal - Critical Performance Learnings

## 2025-08-03 - [rclone N+1 Directory Listing Query Bottleneck]
**Learning:** In rclone migration and backup workflows, omitting the `--fast-list` flag causes rclone to traverse directory structures recursively using sequential individual API calls. For deep and heavily-nested directories, this produces an N+1 API query problem on cloud providers like Proton Drive and Google Drive, triggering aggressive rate limits and severely bottlenecking overall transfer speeds.
**Action:** Always include the `--fast-list` flag when invoking `rclone copy` or `rclone sync` on cloud storage remotes to batch directory listings in memory, minimizing API requests and eliminating sequential roundtrip latencies.
