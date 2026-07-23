#!/usr/bin/env python3
"""
Airgapped HID Keystroke Injector & YubiKey OTP Simulator
Simulates USB HID Keyboard (/dev/hidg0) or Kernel uinput device to inject keystrokes into airgapped machines.
"""

import sys, os, time, argparse

# USB HID Keyboard Scancode Map (Standard US QWERTY)
KEY_MAP = {
    'a': (0, 0x04), 'b': (0, 0x05), 'c': (0, 0x06), 'd': (0, 0x07), 'e': (0, 0x08),
    'f': (0, 0x09), 'g': (0, 0x0a), 'h': (0, 0x0b), 'i': (0, 0x0c), 'j': (0, 0x0d),
    'k': (0, 0x0e), 'l': (0, 0x0f), 'm': (0, 0x10), 'n': (0, 0x11), 'o': (0, 0x12),
    'p': (0, 0x13), 'q': (0, 0x14), 'r': (0, 0x15), 's': (0, 0x16), 't': (0, 0x17),
    'u': (0, 0x18), 'v': (0, 0x19), 'w': (0, 0x1a), 'x': (0, 0x1b), 'y': (0, 0x1c),
    'z': (0, 0x1d),
    'A': (2, 0x04), 'B': (2, 0x05), 'C': (2, 0x06), 'D': (2, 0x07), 'E': (2, 0x08),
    'F': (2, 0x09), 'G': (2, 0x0a), 'H': (2, 0x0b), 'I': (2, 0x0c), 'J': (2, 0x0d),
    'K': (2, 0x0e), 'L': (2, 0x0f), 'M': (2, 0x10), 'N': (2, 0x11), 'O': (2, 0x12),
    'P': (2, 0x13), 'Q': (2, 0x14), 'R': (2, 0x15), 'S': (2, 0x16), 'T': (2, 0x17),
    'U': (2, 0x18), 'V': (2, 0x19), 'W': (2, 0x1a), 'X': (2, 0x1b), 'Y': (2, 0x1c),
    'Z': (2, 0x1d),
    '1': (0, 0x1e), '2': (0, 0x1f), '3': (0, 0x20), '4': (0, 0x21), '5': (0, 0x22),
    '6': (0, 0x23), '7': (0, 0x24), '8': (0, 0x25), '9': (0, 0x26), '0': (0, 0x27),
    '!': (2, 0x1e), '@': (2, 0x1f), '#': (2, 0x20), '$': (2, 0x21), '%': (2, 0x22),
    '^': (2, 0x23), '&': (2, 0x24), '*': (2, 0x25), '(': (2, 0x26), ')': (2, 0x27),
    '\n': (0, 0x28), '\t': (0, 0x2b), ' ': (0, 0x2c), '-': (0, 0x2d), '=': (0, 0x2e),
    '_': (2, 0x2d), '+': (2, 0x2e), '[': (0, 0x2f), ']': (0, 0x30), '\\': (0, 0x31),
    '{': (2, 0x2f), '}': (2, 0x30), '|': (2, 0x31), ';': (0, 0x33), '\'': (0, 0x34),
    ':': (2, 0x33), '"': (2, 0x34), '`': (0, 0x35), '~': (2, 0x35), ',': (0, 0x36),
    '.': (0, 0x37), '/': (0, 0x38), '<': (2, 0x36), '>': (2, 0x37), '?': (2, 0x38)
}

def send_hid_report(hid_dev, modifier, scancodes):
    # Standard 8-byte USB HID report format: [modifier, reserved, key1, key2, key3, key4, key5, key6]
    report = bytearray(8)
    report[0] = modifier
    for i, sc in enumerate(scancodes[:6]):
        report[2 + i] = sc
        
    try:
        with open(hid_dev, 'wb') as fd:
            fd.write(report)
            fd.flush()
            time.sleep(0.01)
            # Release key report
            fd.write(bytearray(8))
            fd.flush()
    except Exception as e:
        print(f"[!] HID Write Error on {hid_dev}: {e}")

def type_string(text, hid_dev, delay_ms):
    print(f"[*] Injecting {len(text)} characters into {hid_dev}...")
    for char in text:
        if char in KEY_MAP:
            mod, key = KEY_MAP[char]
            send_hid_report(hid_dev, mod, [key])
        else:
            print(f"[?] Character '{char}' not in KEY_MAP, skipping.")
        time.sleep(delay_ms / 1000.0)

def main():
    parser = argparse.ArgumentParser(description="Airgapped HID Keystroke Injector")
    parser.add_argument("--text", help="Text string to type")
    parser.add_argument("--file", help="Path to text file containing commands to type")
    parser.add_argument("--device", default="/dev/hidg0", help="HID device path (default: /dev/hidg0)")
    parser.add_argument("--wpm", type=int, default=120, help="Typing speed in words per minute")
    parser.add_argument("--yubikey-otp", action="store_true", help="Simulate YubiKey OTP typing prefix")
    args = parser.parse_args()

    content = ""
    if args.text:
        content = args.text
    elif args.file and os.path.exists(args.file):
        with open(args.file, 'r') as f:
            content = f.read()
    else:
        print("Usage: --text 'command' or --file /path/to/script.sh")
        sys.exit(1)

    if args.yubikey-otp:
        # Prepend YubiKey OTP prefix simulation
        content = "cccccc" + content + "\n"

    # WPM to character delay calculation (Average 5 chars per word)
    chars_per_sec = (args.wpm * 5) / 60.0
    delay_ms = max(5, int(1000.0 / chars_per_sec))

    if not os.path.exists(args.device):
        print(f"[!] Warning: {args.device} does not exist. Running in simulation stdout mode.")
        print("--- SIMULATED HID KEYSTROKE OUTPUT ---")
        for line in content.splitlines():
            print(f"[TYPE]: {line}")
            time.sleep(0.05)
        print("--- END SIMULATION ---")
    else:
        type_string(content, args.device, delay_ms)

if __name__ == "__main__":
    main()
