#!/usr/bin/env python3
import subprocess
import time
import os
import sys
import json

VM_NAME = "qubes-agentic-powerhouse"

class QubesPilot:
    def __init__(self, vm_name=VM_NAME):
        self.vm_name = vm_name

    def run_cmd(self, cmd):
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return res.returncode, res.stdout, res.stderr

    def get_vm_state(self):
        code, out, _ = self.run_cmd(f"virsh -c qemu:///system domstate {self.vm_name}")
        return out.strip() if code == 0 else "unknown"

    def start_vm(self):
        print(f"Starting {self.vm_name}...")
        return self.run_cmd(f"virsh -c qemu:///system start {self.vm_name}")

    def shutdown_vm(self, force=True):
        cmd = "destroy" if force else "shutdown"
        print(f"Stopping {self.vm_name} ({cmd})...")
        return self.run_cmd(f"virsh -c qemu:///system {cmd} {self.vm_name}")

    def take_snapshot(self, output_path):
        tmp_ppm = "/tmp/pilot_snap.ppm"
        code, _, err = self.run_cmd(f"virsh -c qemu:///system screenshot {self.vm_name} {tmp_ppm}")
        if code == 0 and os.path.exists(tmp_ppm):
            self.run_cmd(f"ffmpeg -y -i {tmp_ppm} {output_path} >/dev/null 2>&1 || cp {tmp_ppm} {output_path}")
            return True, output_path
        return False, err

    def record_screen(self, duration_sec, output_mp4, fps=5):
        print(f"Recording {self.vm_name} screen for {duration_sec}s at {fps} FPS...")
        frames_dir = f"/tmp/pilot_frames_{int(time.time())}"
        os.makedirs(frames_dir, exist_ok=True)
        start_time = time.time()
        count = 0
        interval = 1.0 / fps

        while (time.time() - start_time) < duration_sec:
            frame_ppm = os.path.join(frames_dir, f"frame_{count:04d}.ppm")
            self.run_cmd(f"virsh -c qemu:///system screenshot {self.vm_name} {frame_ppm}")
            count += 1
            time.sleep(interval)

        # Compile frames into MP4 video using ffmpeg
        ffmpeg_cmd = f"ffmpeg -y -framerate {fps} -i {frames_dir}/frame_%04d.ppm -c:v libx264 -pix_fmt yuv420p {output_mp4}"
        code, _, err = self.run_cmd(ffmpeg_cmd)
        if code == 0 and os.path.exists(output_mp4):
            print(f"Screen recording saved successfully to {output_mp4} ({count} frames)")
            return True, output_mp4, count
        else:
            print(f"Video compilation completed with code {code}")
            return False, err, count

    def send_keys(self, keys):
        # keys can be a list like ['KEY_LEFTSHIFT', 'KEY_A'] or single string
        key_str = " ".join(keys) if isinstance(keys, list) else keys
        return self.run_cmd(f"virsh -c qemu:///system send-key {self.vm_name} {key_str}")

    def send_mouse_click(self, button=1):
        # Send mouse press and release via QMP
        press_qmp = json.dumps({"execute": "input-send-event", "arguments": {"events": [{"type": "btn", "data": {"down": True, "button": "left" if button==1 else "right"}}]}})
        release_qmp = json.dumps({"execute": "input-send-event", "arguments": {"events": [{"type": "btn", "data": {"down": False, "button": "left" if button==1 else "right"}}]}})
        self.run_cmd(f"virsh -c qemu:///system qemu-monitor-command {self.vm_name} '{press_qmp}'")
        time.sleep(0.05)
        self.run_cmd(f"virsh -c qemu:///system qemu-monitor-command {self.vm_name} '{release_qmp}'")

if __name__ == "__main__":
    pilot = QubesPilot()
    print(f"Pilot initialized. VM State: {pilot.get_vm_state()}")
