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
        
        # 1. Write to JSONL
        with open(LOG_JSONL, "a") as f:
            f.write(json.dumps(event) + "\n")

        # 2. Store in SQLite Replay Buffer
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO replay_buffer (timestamp_iso, task_goal, state_snapshot, action_taken, latency_ms, success)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (timestamp, task_goal, json.dumps(state_snapshot), json.dumps(action_taken), latency_ms, 1 if success else 0))
        conn.commit()
        conn.close()
