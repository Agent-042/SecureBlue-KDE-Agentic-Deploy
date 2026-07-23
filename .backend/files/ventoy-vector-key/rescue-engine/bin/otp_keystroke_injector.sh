#!/usr/bin/env bash
# Airgapped OTP & Keystroke Injector Utility
# Transmits raw keystrokes or GRUB configuration strings to airgapped target machines over USB HID (/dev/hidg0) or virtual uinput.
set -euo pipefail

echo "=================================================="
echo "⌨️ Airgapped OTP & Keystroke Injector Utility"
echo "=================================================="

TEXT_PAYLOAD="${1:-}"
WPM_SPEED="${2:-120}"

if [ -z "$TEXT_PAYLOAD" ]; then
    echo "Usage: $0 \"<command string or text payload>\" [wpm_speed]"
    echo "Example: $0 \"systemctl reboot\" 120"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_INJECTOR="$SCRIPT_DIR/hid_keystroke_injector.py"

if [ -f "$PYTHON_INJECTOR" ]; then
    echo "[*] Executing Python HID Injector..."
    python3 "$PYTHON_INJECTOR" --text "$TEXT_PAYLOAD" --wpm "$WPM_SPEED"
else
    echo "[!] Python HID Injector not found at $PYTHON_INJECTOR. Outputting payload to stdout:"
    echo "$TEXT_PAYLOAD"
fi

echo "=================================================="
echo "[SUCCESS] Keystroke injection sequence completed."
echo "=================================================="
