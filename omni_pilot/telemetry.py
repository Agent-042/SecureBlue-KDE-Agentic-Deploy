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
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA synchronous=NORMAL")
        self._file = open(LOG_JSONL, "a")
        self.init_sqlite()

    def init_sqlite(self):
        cursor = self._conn.cursor()
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
        self._conn.commit()

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
        
        event_str = json.dumps(event) + "\n"
        state_str = json.dumps(state_snapshot)
        action_str = json.dumps(action_taken)
        success_int = 1 if success else 0

        with self._lock:
            # 1. Write to JSONL
            self._file.write(event_str)
            self._file.flush()

            # 2. Store in SQLite Replay Buffer
            self._conn.execute("""
                INSERT INTO replay_buffer (timestamp_iso, task_goal, state_snapshot, action_taken, latency_ms, success)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (timestamp, task_goal, state_str, action_str, latency_ms, success_int))
            self._conn.commit()

    def close(self):
        with self._lock:
            if self._file and not self._file.closed:
                self._file.close()
            if self._conn:
                self._conn.close()

    def __del__(self):
        try:
            self.close()
        except:
            pass
