import os
import json
import sqlite3
import pytest
from omni_pilot.telemetry import TelemetryEngine, DB_PATH, LOG_JSONL

def test_telemetry_engine_logging():
    # 1. Clean files before test
    for path in (DB_PATH, LOG_JSONL, DB_PATH + "-wal", DB_PATH + "-shm"):
        if os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass

    # 2. Instantiate and run logging
    engine = TelemetryEngine()

    state = {"fake_state": True}
    action = {"click": True}

    engine.log_event("Test Task", state, action, 12.34, success=True)
    engine.log_event("Test Task 2", state, action, 56.78, success=False)

    # Close handles so files are flushed and unlocked
    engine.close()

    # 3. Verify JSONL exists and has correct content
    assert os.path.exists(LOG_JSONL)
    with open(LOG_JSONL, "r", encoding="utf-8") as f:
        lines = f.readlines()
        assert len(lines) == 2

        event1 = json.loads(lines[0])
        assert event1["task_goal"] == "Test Task"
        assert event1["state_snapshot"] == state
        assert event1["action_taken"] == action
        assert event1["execution_time_ms"] == 12.34
        assert event1["success"] is True

        event2 = json.loads(lines[1])
        assert event2["task_goal"] == "Test Task 2"
        assert event2["success"] is False

    # 4. Verify SQLite DB exists and has correct rows
    assert os.path.exists(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, timestamp_iso, task_goal, state_snapshot, action_taken, latency_ms, success FROM replay_buffer")
    rows = cursor.fetchall()
    conn.close()

    assert len(rows) == 2
    assert rows[0][2] == "Test Task"
    assert json.loads(rows[0][3]) == state
    assert json.loads(rows[0][4]) == action
    assert rows[0][5] == 12.34
    assert rows[0][6] == 1

    assert rows[1][2] == "Test Task 2"
    assert rows[1][6] == 0

    # 5. Clean up files after test
    for path in (DB_PATH, LOG_JSONL, DB_PATH + "-wal", DB_PATH + "-shm"):
        if os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass
