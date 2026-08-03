#!/usr/bin/env python3
"""
omni_runner.py
==============
Main Entry Point & Systemd Service Controller for Agi-OmniPilot-V Engine.
"""

import sys
import os

# Ensure /root/omni_pilot is in PYTHONPATH
sys.path.insert(0, "/root")

from omni_pilot.benchmark import run_agionmipilot_benchmark

def main():
    print("[*] Starting Agi-OmniPilot-V Vision & Actuation Service...")
    results = run_agionmipilot_benchmark()
    print("\n[+] Agi-OmniPilot-V Execution & Verification Complete.")

if __name__ == "__main__":
    main()
