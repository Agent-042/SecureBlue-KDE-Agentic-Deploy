import os
import json
import sqlite3
import threading
import pytest
from omni_pilot.telemetry import TelemetryEngine, DB_PATH, LOG_JSONL

@pytest.fixture(autouse=True)
def setup_cleanup_paths():
    # Clean up files before and after each test
    for path in [DB_PATH, LOG_JSONL]:
        if os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass
    yield
    for path in [DB_PATH, LOG_JSONL]:
        if os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass

def test_logging_insertion():
    engine = TelemetryEngine()

    goal = "Test Single Task Goal"
    state = {"nodes": 42}
    action = {"type": "click"}
    latency = 4.56

    engine.log_event(goal, state, action, latency, success=True)
    engine.close()

    # 1. Verify JSONL exists and has correct event data
    assert os.path.exists(LOG_JSONL)
    with open(LOG_JSONL, "r", encoding="utf-8") as f:
        lines = f.readlines()
    assert len(lines) == 1
    event = json.loads(lines[0])
    assert event["task_goal"] == goal
    assert event["state_snapshot"] == state
    assert event["action_taken"] == action
    assert event["execution_time_ms"] == latency
    assert event["success"] is True

    # 2. Verify SQLite DB exists and has correct entries
    assert os.path.exists(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT task_goal, state_snapshot, action_taken, latency_ms, success FROM replay_buffer")
    rows = cursor.fetchall()
    conn.close()

    assert len(rows) == 1
    row = rows[0]
    assert row[0] == goal
    assert json.loads(row[1]) == state
    assert json.loads(row[2]) == action
    assert row[3] == latency
    assert row[4] == 1

def test_concurrent_logging():
    engine = TelemetryEngine()

    num_threads = 10
    events_per_thread = 20

    def worker(worker_id):
        for i in range(events_per_thread):
            goal = f"Thread {worker_id} Event {i}"
            state = {"i": i, "worker_id": worker_id}
            action = {"success": True}
            engine.log_event(goal, state, action, 1.0, success=True)

    threads = []
    for t_id in range(num_threads):
        t = threading.Thread(target=worker, args=(t_id,))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    engine.close()

    # Verify total JSONL count
    with open(LOG_JSONL, "r", encoding="utf-8") as f:
        lines = f.readlines()
    assert len(lines) == num_threads * events_per_thread

    # Verify total DB count
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM replay_buffer")
    count = cursor.fetchone()[0]
    conn.close()

    assert count == num_threads * events_per_thread

def test_cleanup_close():
    engine = TelemetryEngine()
    engine.log_event("Close goal", {}, {}, 0.0)

    assert engine.conn is not None
    assert engine.jsonl_file is not None

    engine.close()

    assert engine.conn is None
    assert engine.jsonl_file is None
