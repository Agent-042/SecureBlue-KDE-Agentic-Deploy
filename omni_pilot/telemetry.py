"""
omni_pilot/telemetry.py
=======================
Telemetry Logger & Continuous Replay Buffer (JSONL + SQLite).
Records high-FPS session telemetry and distills successful execution paths.
"""

import json
import sqlite3
import time
import os

DB_PATH = "/tmp/omni_replay_buffer.db"
LOG_JSONL = "/tmp/omni_telemetry.jsonl"

class TelemetryEngine:
    def __init__(self):
        self.init_sqlite()
        # Initialize persistent JSONL file handle to avoid repeated open/close system calls
        self.jsonl_file = open(LOG_JSONL, "a", encoding="utf-8")

    def init_sqlite(self):
        # Initialize persistent connection with check_same_thread=False
        # to prevent thread-safety regressions across threads/modules.
        self.conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        cursor = self.conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS replay_buffer (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp_iso TEXT,
                task_goal TEXT,
                state_snapshot TEXT,
                action_taken TEXT,
                latency_ms REAL,
                success INTEGER
            )
        """)
        # Optimize performance using Write-Ahead Logging (WAL) and synchronous normal configuration.
        # This provides low latency write operations without blockages.
        cursor.execute("PRAGMA journal_mode=WAL;")
        cursor.execute("PRAGMA synchronous=NORMAL;")
        self.conn.commit()

    def log_event(self, task_goal, state_snapshot, action_taken, latency_ms, success=True):
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ")
        event = {
            "timestamp_iso8601": timestamp,
            "task_goal": task_goal,
            "state_snapshot": state_snapshot,
            "action_taken": action_taken,
            "execution_time_ms": latency_ms,
            "success": success
        }
        
        # 1. Write to JSONL (using persistent file handle)
        self.jsonl_file.write(json.dumps(event) + "\n")
        self.jsonl_file.flush()

        # 2. Store in SQLite Replay Buffer (using persistent connection)
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO replay_buffer (timestamp_iso, task_goal, state_snapshot, action_taken, latency_ms, success)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (timestamp, task_goal, json.dumps(state_snapshot), json.dumps(action_taken), latency_ms, 1 if success else 0))
        self.conn.commit()

    def __del__(self):
        try:
            if hasattr(self, "jsonl_file") and self.jsonl_file:
                self.jsonl_file.close()
        except Exception:
            pass
        try:
            if hasattr(self, "conn") and self.conn:
                self.conn.close()
        except Exception:
            pass
