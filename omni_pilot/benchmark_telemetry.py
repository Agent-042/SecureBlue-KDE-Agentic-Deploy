"""
omni_pilot/benchmark_telemetry.py
=================================
Measures logging latency and throughput for the TelemetryEngine.
"""

from omni_pilot.telemetry import TelemetryEngine

telemetry = TelemetryEngine()

def log_single_telemetry():
    # Simulate state snapshot and action taken
    state_snapshot = {
        "rois": [
            {"id": "btn_settings", "role": "button", "label": "Settings", "bbox_virt": [850, 20, 950, 80], "confidence": 0.98}
        ],
        "perception_latency_ms": 3.42
    }
    action_taken = {
        "status": "success",
        "x_virt": 900,
        "y_virt": 50
    }
    telemetry.log_event("Install browser", state_snapshot, action_taken, 54.22, success=True)

if __name__ == "__main__":
    import time
    print("[*] Running micro-benchmark directly...")
    t0 = time.perf_counter()
    for _ in range(100):
        log_single_telemetry()
    t1 = time.perf_counter()
    dur = t1 - t0
    print(f"Logged 100 events in {dur:.4f} seconds ({100/dur:.2f} ops/sec)")
