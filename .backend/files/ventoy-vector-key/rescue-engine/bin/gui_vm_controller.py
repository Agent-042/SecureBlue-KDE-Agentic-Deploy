#!/usr/bin/env python3
"""
Direct GUI VM Controller (Keyboard & Mouse Input Controller for QEMU/KVM VMs)
Enables agentic direct control over Qubes OS and Bazzite VMs from the host using virsh send-key and QEMU monitor input events.
"""

import sys, os, subprocess, time, argparse

def send_keystroke(domain, key_sequence):
    print(f"[*] Sending keystroke sequence '{key_sequence}' to VM domain '{domain}'...")
    # Send keys via virsh send-key
    keys = key_sequence.split()
    cmd = ["virsh", "send-key", domain] + keys
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"[+] Keystroke '{key_sequence}' successfully injected into '{domain}'.")
    else:
        print(f"[!] Keystroke injection error: {res.stderr.strip()}")

def send_text_payload(domain, text):
    print(f"[*] Typing text payload into VM domain '{domain}'...")
    # Translate characters into Linux keycodes for virsh send-key
    char_to_keycode = {
        'a': 'KEY_A', 'b': 'KEY_B', 'c': 'KEY_C', 'd': 'KEY_D', 'e': 'KEY_E',
        'f': 'KEY_F', 'g': 'KEY_G', 'h': 'KEY_H', 'i': 'KEY_I', 'j': 'KEY_J',
        'k': 'KEY_K', 'l': 'KEY_L', 'm': 'KEY_M', 'n': 'KEY_N', 'o': 'KEY_O',
        'p': 'KEY_P', 'q': 'KEY_Q', 'r': 'KEY_R', 's': 'KEY_S', 't': 'KEY_T',
        'u': 'KEY_U', 'v': 'KEY_V', 'w': 'KEY_W', 'x': 'KEY_X', 'y': 'KEY_Y',
        'z': 'KEY_Z', ' ': 'KEY_SPACE', '\n': 'KEY_ENTER', '-': 'KEY_MINUS',
        '=': 'KEY_EQUAL', '.': 'KEY_DOT', '/': 'KEY_SLASH', '1': 'KEY_1',
        '2': 'KEY_2', '3': 'KEY_3', '4': 'KEY_4', '5': 'KEY_5', '6': 'KEY_6',
        '7': 'KEY_7', '8': 'KEY_8', '9': 'KEY_9', '0': 'KEY_0'
    }
    
    for char in text.lower():
        if char in char_to_keycode:
            send_keystroke(domain, char_to_keycode[char])
            time.sleep(0.05)

def capture_vm_screenshot(domain, output_path):
    print(f"[*] Capturing live framebuffer screenshot for VM domain '{domain}' -> {output_path}...")
    ppm_temp = f"/tmp/{domain}_screen.ppm"
    res = subprocess.run(["virsh", "screenshot", domain, ppm_temp], capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(ppm_temp):
        shutil_cmd = ["cp", ppm_temp, output_path]
        subprocess.run(shutil_cmd)
        print(f"[+] Screenshot captured successfully: {output_path}")
    else:
        print(f"[!] Screenshot error: {res.stderr.strip()}")

def send_mouse_click(domain, x, y):
    print(f"[*] Injecting mouse movement ({x}, {y}) and click into VM domain '{domain}'...")
    # Send QMP monitor mouse event via virsh qemu-monitor-command
    qmp_cmd = f'{{"execute": "input-send-event", "arguments": {{"events": [{{"type": "rel", "data": {{"axis": "x", "value": {x}}}}}, {{"type": "rel", "data": {{"axis": "y", "value": {y}}}}}]}}}}'
    res = subprocess.run(["virsh", "qemu-monitor-command", domain, qmp_cmd], capture_output=True, text=True)
    print(f"[+] Mouse event result: {res.stdout.strip()}")

def main():
    parser = argparse.ArgumentParser(description="Direct GUI VM Controller for QEMU/KVM VMs")
    parser.add_argument("--domain", default="qubes-vm", help="Target VM domain name (default: qubes-vm)")
    parser.add_argument("--send-keys", help="Key sequence to send (e.g. 'KEY_LEFTALT KEY_F2')")
    parser.add_argument("--type-text", help="Text payload to type into VM")
    parser.add_argument("--screenshot", help="Capture screenshot to specified output image file")
    parser.add_argument("--mouse-click", nargs=2, type=int, metavar=('X', 'Y'), help="Inject mouse movement (X, Y)")
    args = parser.parse_args()

    if args.send_keys:
        send_keystroke(args.domain, args.send_keys)
    if args.type_text:
        send_text_payload(args.domain, args.type_text)
    if args.mouse_click:
        send_mouse_click(args.domain, args.mouse_click[0], args.mouse_click[1])
    if args.screenshot:
        capture_vm_screenshot(args.domain, args.screenshot)

if __name__ == "__main__":
    main()
