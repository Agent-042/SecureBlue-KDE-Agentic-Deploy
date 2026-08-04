import os
import json
import sqlite3
import pytest
from omni_pilot.telemetry import TelemetryEngine, DB_PATH, LOG_JSONL

def test_telemetry_logging():
    # Clean up files before test to ensure consistency
    for filepath in [DB_PATH, LOG_JSONL]:
        if os.path.exists(filepath):
            try:
                os.remove(filepath)
            except Exception:
                pass

    # Instantiate TelemetryEngine
    engine = TelemetryEngine()

    task_goal = "Deploy nested virtualization"
    state_snapshot = {"rois": [{"id": "btn_vm", "label": "Start VM"}]}
    action_taken = {"action": "click", "target": "btn_vm"}
    latency_ms = 45.2
    success = True

    # Log an event
    engine.log_event(
        task_goal=task_goal,
        state_snapshot=state_snapshot,
        action_taken=action_taken,
        latency_ms=latency_ms,
        success=success
    )

    # 1. Verify JSONL file content
    assert os.path.exists(LOG_JSONL)
    with open(LOG_JSONL, "r", encoding="utf-8") as f:
        lines = f.readlines()

    assert len(lines) == 1
    logged_event = json.loads(lines[0])
    assert logged_event["task_goal"] == task_goal
    assert logged_event["state_snapshot"] == state_snapshot
    assert logged_event["action_taken"] == action_taken
    assert logged_event["execution_time_ms"] == latency_ms
    assert logged_event["success"] is True

    # 2. Verify SQLite replay buffer content
    assert os.path.exists(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, task_goal, state_snapshot, action_taken, latency_ms, success FROM replay_buffer")
    rows = cursor.fetchall()
    conn.close()

    assert len(rows) == 1
    row = rows[0]
    assert row[1] == task_goal
    assert json.loads(row[2]) == state_snapshot
    assert json.loads(row[3]) == action_taken
    assert row[4] == latency_ms
    assert row[5] == 1

    # Cleanup instance to close handlers
    del engine
