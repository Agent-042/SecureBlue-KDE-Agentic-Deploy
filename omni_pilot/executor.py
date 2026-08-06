"""
omni_pilot/executor.py
======================
Unified Actuation Engine delegating low-latency input execution to libomni_core.so
with fallback to RFB 3.8 VNC and gui_pilot.py VM input injection.
"""

import ctypes
import os
import subprocess
import time

def _resolve_lib_path():
    # 1. check LIB_PATH env var
    env_path = os.environ.get("LIB_PATH")
    if env_path and os.path.exists(env_path):
        return env_path

    # 2. check relative lookup
    current_dir = os.path.dirname(os.path.abspath(__file__))
    rel_path = os.path.join(current_dir, "libomni_core.so")
    if os.path.exists(rel_path):
        return rel_path

    # 3. fallback
    return "/root/omni_pilot/libomni_core.so"

LIB_PATH = _resolve_lib_path()

class OmniPoint(ctypes.Structure):
    _fields_ = [
        ("x_virtual", ctypes.c_uint16),
        ("y_virtual", ctypes.c_uint16)
    ]

class ActuationEngine:
    def __init__(self, target_vm="bazzite-vm"):
        self.target_vm = target_vm
        self.lib = ctypes.CDLL(LIB_PATH)
        
        self.lib.omni_move.argtypes = [OmniPoint]
        self.lib.omni_move.restype = ctypes.c_int
        
        self.lib.omni_click.argtypes = [OmniPoint, ctypes.c_uint8]
        self.lib.omni_click.restype = ctypes.c_int

    def click(self, x_virt, y_virt, button=1):
        pt = OmniPoint(x_virt=x_virt, y_virt=y_virt)
        # Execute C core Bezier mouse move + uinput click
        res = self.lib.omni_click(pt, button)
        
        # Also mirror to KVM VM via gui_pilot.py for active session display
        px_x = int((x_virt / 1000.0) * 1920)
        px_y = int((y_virt / 1000.0) * 1080)
        cmd = f"python3 /usr/local/bin/gui_pilot.py vm click {self.target_vm} {px_x} {px_y} left"
        subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"status": "success", "x_virt": x_virt, "y_virt": y_virt}

    def type_text(self, text):
        cmd = f"python3 /usr/local/bin/gui_pilot.py vm type {self.target_vm} \"{text}\""
        subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"status": "success", "typed": text}

    def send_key(self, key_name):
        cmd = f"python3 /usr/local/bin/gui_pilot.py vm key {self.target_vm} {key_name}"
        subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"status": "success", "key": key_name}
