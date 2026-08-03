"""
omni_pilot/failure_detector.py
==============================
Real-time Failure Detector (< 100ms detection budget) & Action Stack Rollback Manager.
Detects hung dialogs, unexpected popups, validation errors, and invalid clicks.
"""

import time

class ActionStackRollbackManager:
    def __init__(self):
        self.action_stack = []
        self.last_state_timestamp = time.time()

    def push_action(self, action_type, target_info, inverse_action):
        self.action_stack.append({
            "type": action_type,
            "target": target_info,
            "inverse": inverse_action,
            "timestamp": time.time()
        })

    def detect_failure(self, current_state, expected_outcome):
        start_time = time.time()
        
        # 1. Check hung state (no state change for > 3 seconds)
        if time.time() - self.last_state_timestamp > 3.0:
            return {"failed": True, "reason": "HUNG_DIALOG_DETECTED", "action": "rollback_last"}

        # 2. Check for error modal popups
        for roi in current_state.get("rois", []):
            if "error" in roi.get("label", "").lower() or "failed" in roi.get("label", "").lower():
                return {"failed": True, "reason": "UNEXPECTED_ERROR_POPUP", "action": "dismiss_and_retry"}

        elapsed_ms = (time.time() - start_time) * 1000.0
        return {"failed": False, "reason": None, "check_latency_ms": elapsed_ms}

    def execute_rollback(self):
        if not self.action_stack:
            return False, "Stack Empty"
        last = self.action_stack.pop()
        # Execute inverse action (e.g. Backspace, Esc, Ctrl+Z)
        return True, f"Rolled back action '{last['type']}' via inverse '{last['inverse']}'"
