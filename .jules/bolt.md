## 2025-08-02 - Python fcntl Lock Release on Garbage Collection
**Learning:** When using Python's `fcntl.flock` to establish exclusive process locking, the lock is bound to the file descriptor (FD). If the helper function that acquires the lock returns the FD but the caller discards it, CPython's reference counting immediately drops to 0, garbage-collecting the FD. This closes the file and releases the lock instantly, creating concurrent execution race conditions.
**Action:** Always assign the returned lock file descriptor to a local variable in the active long-running function (e.g., `_lock_fd = acquire_lock()`) to prevent garbage collection and keep the lock active.

## 2025-08-02 - Cached-First Rclone Credential Re-use
**Learning:** Generating fresh 2FA/TOTP credentials and rebuilding rclone configs on every loop pass or invocation introduces significant overhead, network latency, and risks account blockages/rate-limiting on the authentication server.
**Action:** Implement cached-credential loading first, verify the session validity with a quick status check, and only trigger full re-authentication and 2FA configuration rebuilds on demand (when missing, unreadable, or when a network request returns a 401 Unauthorized status).
