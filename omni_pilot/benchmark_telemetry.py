"""
omni_pilot/benchmark_telemetry.py
=================================
Measures the throughput and latency of TelemetryEngine.log_event.
Runs 1,000 logging iterations to baseline and verify performance.
"""

import os
import time
from omni_pilot.telemetry import TelemetryEngine, DB_PATH, LOG_JSONL

def cleanup():
    # Remove existing db and log files if they exist for a clean benchmark
    for path in (DB_PATH, LOG_JSONL, DB_PATH + "-wal", DB_PATH + "-shm"):
        if os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass

def run_benchmark():
    cleanup()

    print("Initializing TelemetryEngine...")
    engine = TelemetryEngine()

    num_iterations = 1000
    state_snapshot = {
        "timestamp_ns": 123456789,
        "rois": [
            {"id": "btn_settings", "role": "button", "label": "Settings", "bbox_virt": [850, 20, 950, 80], "confidence": 0.98},
            {"id": "btn_start", "role": "button", "label": "Start Menu", "bbox_virt": [20, 920, 80, 980], "confidence": 0.99},
        ],
        "accessibility_nodes_count": 2,
        "perception_latency_ms": 3.42
    }
    action_taken = {"status": "success", "x_virt": 500, "y_virt": 500}

    print(f"Starting benchmark of {num_iterations} log_event iterations...")

    start_time = time.time()
    for i in range(num_iterations):
        engine.log_event(
            task_goal=f"Benchmark Task Item {i}",
            state_snapshot=state_snapshot,
            action_taken=action_taken,
            latency_ms=25.4,
            success=(i % 2 == 0)
        )
    end_time = time.time()

    total_time = end_time - start_time
    avg_latency = (total_time / num_iterations) * 1000.0
    throughput = num_iterations / total_time

    print("=========================================")
    print("          BENCHMARK RESULTS              ")
    print("=========================================")
    print(f"Total Time:         {total_time:.4f} seconds")
    print(f"Average Latency:    {avg_latency:.4f} ms per log_event")
    print(f"Throughput:         {throughput:.2f} events / second")
    print("=========================================")

    # Cleanup at the end
    try:
        del engine
    except Exception:
        pass
    cleanup()

if __name__ == "__main__":
    run_benchmark()
