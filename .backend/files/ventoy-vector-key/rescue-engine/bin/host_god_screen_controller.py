#!/usr/bin/env python3
"""
Host OS "God Mode" Screen & Input Controller
Provides pure-Python direct /dev/uinput Linux kernel virtual input device creation.
Enables agentic direct mouse movement, mouse clicks, and keystroke injection on Wayland / SecureBlue host.
"""

import os, sys, struct, fcntl, time, argparse

# Kernel uinput ioctl constants
UI_SET_EVBIT = 0x400455C7
UI_SET_KEYBIT = 0x400455C8
UI_SET_RELBIT = 0x400455C9

EV_SYN = 0
EV_KEY = 1
EV_REL = 2

REL_X = 0
REL_Y = 1

BTN_LEFT = 0x110
BTN_RIGHT = 0x111

KEY_CODES = {
    'a': 30, 'b': 48, 'c': 46, 'd': 32, 'e': 18, 'f': 33, 'g': 34, 'h': 35,
    'i': 23, 'j': 36, 'k': 37, 'l': 38, 'm': 50, 'n': 49, 'o': 24, 'p': 25,
    'q': 16, 'r': 19, 's': 31, 't': 20, 'u': 22, 'v': 47, 'w': 17, 'x': 45,
    'y': 21, 'z': 44, 'enter': 28, 'space': 57, 'backspace': 14, 'tab': 15
}

# struct uinput_user_dev layout: name (80 bytes), id (vendor, product, version, bustype - 8 bytes), absmax/absmin (64 bytes)
UINPUT_USER_DEV_FMT = '80sHHHHi32i32i'

class HostUinputDevice:
    def __init__(self):
        self.fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
        
        # Enable key & relative mouse events
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_KEY)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_REL)
        fcntl.ioctl(self.fd, UI_SET_RELBIT, REL_X)
        fcntl.ioctl(self.fd, UI_SET_RELBIT, REL_Y)
        fcntl.ioctl(self.fd, UI_SET_KEYBIT, BTN_LEFT)
        fcntl.ioctl(self.fd, UI_SET_KEYBIT, BTN_RIGHT)

        for code in KEY_CODES.values():
            fcntl.ioctl(self.fd, UI_SET_KEYBIT, code)

        # Setup device name
        dev_name = b"SecureBlue Agentic God Controller"
        dev_name = dev_name.ljust(80, b'\x00')
        user_dev = struct.pack(UINPUT_USER_DEV_FMT, dev_name, 0x03, 0x1234, 0x5678, 1, 0, *([0]*64))
        os.write(self.fd, user_dev)
        
        # UI_DEV_CREATE = 0x5501
        fcntl.ioctl(self.fd, 0x5501)
        time.sleep(0.2)
        print("[+] Created /dev/uinput virtual mouse and keyboard device!")

    def emit_event(self, ev_type, code, value):
        # struct input_event: timeval (tv_sec, tv_usec), type, code, value
        now = time.time()
        tv_sec = int(now)
        tv_usec = int((now - tv_sec) * 1000000)
        event = struct.pack('llHHi', tv_sec, tv_usec, ev_type, code, value)
        os.write(self.fd, event)

    def syn(self):
        self.emit_event(EV_SYN, 0, 0)

    def move_mouse(self, dx, dy):
        print(f"[*] Moving host mouse by ({dx}, {dy})...")
        self.emit_event(EV_REL, REL_X, dx)
        self.emit_event(EV_REL, REL_Y, dy)
        self.syn()

    def click_mouse(self, button=BTN_LEFT):
        print(f"[*] Sending host mouse click...")
        self.emit_event(EV_KEY, button, 1)
        self.syn()
        time.sleep(0.05)
        self.emit_event(EV_KEY, button, 0)
        self.syn()

    def send_key(self, key_name):
        code = KEY_CODES.get(key_name.lower())
        if code:
            print(f"[*] Sending key '{key_name}' (code {code})...")
            self.emit_event(EV_KEY, code, 1)
            self.syn()
            time.sleep(0.05)
            self.emit_event(EV_KEY, code, 0)
            self.syn()

    def type_text(self, text):
        print(f"[*] Typing text payload on host: '{text}'...")
        for char in text:
            if char == ' ':
                self.send_key('space')
            elif char in KEY_CODES:
                self.send_key(char)
            time.sleep(0.02)

    def close(self):
        # UI_DEV_DESTROY = 0x5502
        fcntl.ioctl(self.fd, 0x5502)
        os.close(self.fd)

def main():
    parser = argparse.ArgumentParser(description="Host OS God Mode Screen Controller")
    parser.add_argument("--move", nargs=2, type=int, metavar=('DX', 'DY'), help="Move mouse by relative X and Y")
    parser.add_argument("--click", action="store_true", help="Perform left mouse click")
    parser.add_argument("--key", help="Send keystroke (e.g. enter, space, a, b)")
    parser.add_argument("--type", help="Type text string")
    args = parser.parse_args()

    dev = HostUinputDevice()
    try:
        if args.move:
            dev.move_mouse(args.move[0], args.move[1])
        if args.click:
            dev.click_mouse()
        if args.key:
            dev.send_key(args.key)
        if args.type:
            dev.type_text(args.type)
    finally:
        dev.close()

if __name__ == "__main__":
    main()
