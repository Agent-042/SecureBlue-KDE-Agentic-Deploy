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
import threading

DB_PATH = "/tmp/omni_replay_buffer.db"
LOG_JSONL = "/tmp/omni_telemetry.jsonl"

class TelemetryEngine:
    def __init__(self):
        self.lock = threading.Lock()
        self.init_sqlite()
        # Open persistent JSONL append handle
        self.jsonl_file = open(LOG_JSONL, "a", encoding="utf-8", buffering=1)

    def init_sqlite(self):
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
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
        conn.commit()
        conn.close()

        # Open persistent SQLite connection with WAL mode and relaxed synchronous writes for performance
        self.conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        self.conn.execute("PRAGMA journal_mode=WAL;")
        self.conn.execute("PRAGMA synchronous=NORMAL;")

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
        
        with self.lock:
            # 1. Write to persistent JSONL append handle
            if self.jsonl_file and not self.jsonl_file.closed:
                self.jsonl_file.write(json.dumps(event) + "\n")

            # 2. Store in persistent SQLite Replay Buffer
            if self.conn:
                cursor = self.conn.cursor()
                cursor.execute("""
                    INSERT INTO replay_buffer (timestamp_iso, task_goal, state_snapshot, action_taken, latency_ms, success)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (timestamp, task_goal, json.dumps(state_snapshot), json.dumps(action_taken), latency_ms, 1 if success else 0))
                self.conn.commit()

    def close(self):
        """Idempotent cleanup of persistent file and database connections."""
        with self.lock:
            if hasattr(self, "jsonl_file") and self.jsonl_file:
                if not self.jsonl_file.closed:
                    self.jsonl_file.close()
                self.jsonl_file = None

            if hasattr(self, "conn") and self.conn:
                self.conn.close()
                self.conn = None

    def __del__(self):
        try:
            self.close()
        except Exception:
            pass
