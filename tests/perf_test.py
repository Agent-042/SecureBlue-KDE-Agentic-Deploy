import time
import json
from omni_pilot.telemetry import TelemetryEngine
import os

if os.path.exists("/tmp/omni_replay_buffer.db"):
    os.remove("/tmp/omni_replay_buffer.db")
if os.path.exists("/tmp/omni_telemetry.jsonl"):
    os.remove("/tmp/omni_telemetry.jsonl")

telemetry = TelemetryEngine()
start = time.time()
n_iter = 1000

for i in range(n_iter):
    telemetry.log_event("task", {"state": i}, {"action": i}, 1.0, success=True)

end = time.time()
print(f"Time for {n_iter} logs: {end - start:.4f} seconds")
print(f"Throughput: {n_iter / (end - start):.2f} ops/sec")
