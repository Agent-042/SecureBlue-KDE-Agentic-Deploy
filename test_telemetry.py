import time
import os
import shutil
from omni_pilot.telemetry import TelemetryEngine, DB_PATH, LOG_JSONL

def clean():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    if os.path.exists(LOG_JSONL):
        os.remove(LOG_JSONL)

def test_telemetry():
    clean()
    engine = TelemetryEngine()

    state = {
        "timestamp_ns": 123456789,
        "rois": [
            {"id": "btn_settings", "role": "button", "label": "Settings", "bbox_virt": [850, 20, 950, 80], "confidence": 0.98},
            {"id": "btn_start", "role": "button", "label": "Start Menu", "bbox_virt": [20, 920, 80, 980], "confidence": 0.99},
        ],
        "accessibility_nodes_count": 2,
        "perception_latency_ms": 3.42
    }
    action = {"chosen_action": "click", "target_roi": {"id": "btn_settings"}, "mcts_score": 0.98, "decision_latency_ms": 1.2}

    start = time.time()
    iterations = 50
    for i in range(iterations):
        engine.log_event(f"Task Goal {i}", state, action, 12.34, True)
    end = time.time()
    elapsed = end - start
    print(f"Total time for {iterations} iterations: {elapsed:.4f}s")
    print(f"Average time per log_event: {(elapsed / iterations) * 1000:.2f}ms")

if __name__ == "__main__":
    test_telemetry()
