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
import atexit

DB_PATH = "/tmp/omni_replay_buffer.db"
LOG_JSONL = "/tmp/omni_telemetry.jsonl"

class TelemetryEngine:
    def __init__(self):
        # Thread lock for concurrent writes
        self.lock = threading.Lock()

        # Persistent JSONL file handle
        self.jsonl_file = open(LOG_JSONL, "a")

        # Persistent SQLite connection
        self.conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        self.init_sqlite()

        # Guarantee deterministic cleanup
        atexit.register(self.close)

    def init_sqlite(self):
        cursor = self.conn.cursor()

        # Optimize SQLite for write performance
        cursor.execute("PRAGMA journal_mode=WAL;")
        cursor.execute("PRAGMA synchronous=NORMAL;")

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
        
        with self.lock:
            # 1. Write to JSONL using persistent handle
            self.jsonl_file.write(json.dumps(event) + "\n")
            self.jsonl_file.flush()

            # 2. Store in SQLite Replay Buffer using persistent connection
            cursor = self.conn.cursor()
            cursor.execute("""
                INSERT INTO replay_buffer (timestamp_iso, task_goal, state_snapshot, action_taken, latency_ms, success)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (timestamp, task_goal, json.dumps(state_snapshot), json.dumps(action_taken), latency_ms, 1 if success else 0))
            self.conn.commit()

    def close(self):
        if hasattr(self, 'jsonl_file'):
            self.jsonl_file.close()
        if hasattr(self, 'conn'):
            self.conn.close()

    def __del__(self):
        self.close()
