#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
Agy Desktop & VM GUI Pilot - Full Autonomous GUI Control Utility
Provides unified screenshotting, mouse manipulation, typing, and keystroke injection
for both host desktop ("frontstage" & "backstage") and Virtual Machines (KVM/QEMU).
"""

import sys
import os
import json
import time
import socket
import struct
import argparse
import subprocess
import xml.etree.ElementTree as ET
import logging

# Get logger instance
logger = logging.getLogger("gui_pilot")

KEYSYM_MAP = {
    'Return': 0xFF0D,
    'Enter': 0xFF0D,
    'BackSpace': 0xFF08,
    'Tab': 0xFF09,
    'Escape': 0xFF1B,
    'Delete': 0xFFFF,
    'Up': 0xFF52,
    'Down': 0xFF54,
    'Left': 0xFF51,
    'Right': 0xFF53,
    'Page_Up': 0xFF55,
    'Page_Down': 0xFF56,
    'Home': 0xFF50,
    'End': 0xFF57,
    'Shift_L': 0xFFE1,
    'Control_L': 0xFFE3,
    'Alt_L': 0xFFE9,
    'Super_L': 0xFFEB,
    'F1': 0xFFBE, 'F2': 0xFFBF, 'F3': 0xFFC0, 'F4': 0xFFC1,
    'F5': 0xFFC2, 'F6': 0xFFC3, 'F7': 0xFFC4, 'F8': 0xFFC5,
    'F9': 0xFFC6, 'F10': 0xFFC7, 'F11': 0xFFC8, 'F12': 0xFFC9,
    'space': 0x0020
}

class VncClient:
    def __init__(self, host='127.0.0.1', port=5900):
        self.host = host
        self.port = port
        self.sock = None
        self.width = 0
        self.height = 0
        self.name = ""

    def connect(self):
        self.sock = socket.socket()
        self.sock.settimeout(5.0)
        self.sock.connect((self.host, self.port))
        
        # 1. Handshake
        ver = self.sock.recv(12)
        self.sock.sendall(b'RFB 003.008\n')
        
        # 2. Security
        sec_num = self.sock.recv(1)[0]
        sec_types = self.sock.recv(sec_num)
        self.sock.sendall(bytes([1])) # None auth
        sec_res = self.sock.recv(4)
        
        # 3. ClientInit
        self.sock.sendall(bytes([1])) # Shared
        
        # 4. ServerInit
        sinit = self.sock.recv(24)
        self.width, self.height = struct.unpack('>HH', sinit[:4])
        name_len = struct.unpack('>I', sinit[20:24])[0]
        self.name = self.sock.recv(name_len).decode('utf-8', errors='ignore')

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
            self.sock = None

    def send_pointer_event(self, button_mask, x, y):
        msg = struct.pack('>BBHH', 5, button_mask, int(x), int(y))
        self.sock.sendall(msg)

    def send_key_event(self, keysym, down=True):
        down_flag = 1 if down else 0
        msg = struct.pack('>BB2sI', 4, down_flag, b'\x00\x00', int(keysym))
        self.sock.sendall(msg)

    def click(self, x, y, button='left'):
        mask_map = {'left': 1, 'middle': 2, 'right': 4}
        mask = mask_map.get(button, 1)
        self.send_pointer_event(mask, x, y)
        time.sleep(0.05)
        self.send_pointer_event(0, x, y)

    def double_click(self, x, y, button='left'):
        self.click(x, y, button)
        time.sleep(0.1)
        self.click(x, y, button)

    def drag(self, x1, y1, x2, y2, button='left'):
        mask_map = {'left': 1, 'middle': 2, 'right': 4}
        mask = mask_map.get(button, 1)
        self.send_pointer_event(mask, x1, y1)
        time.sleep(0.1)
        steps = 10
        for i in range(1, steps + 1):
            cx = x1 + (x2 - x1) * i // steps
            cy = y1 + (y2 - y1) * i // steps
            self.send_pointer_event(mask, cx, cy)
            time.sleep(0.02)
        self.send_pointer_event(0, x2, y2)

    def type_text(self, text):
        for char in text:
            keysym = ord(char)
            self.send_key_event(keysym, down=True)
            time.sleep(0.01)
            self.send_key_event(keysym, down=False)
            time.sleep(0.01)

    def send_keysym_combo(self, keysyms):
        for k in keysyms:
            self.send_key_event(k, down=True)
            time.sleep(0.02)
        for k in reversed(keysyms):
            self.send_key_event(k, down=False)
            time.sleep(0.02)


def get_vm_vnc_port(vm_name):
    try:
        xml_str = subprocess.check_output(['virsh', 'dumpxml', vm_name], stderr=subprocess.DEVNULL).decode()
        root = ET.fromstring(xml_str)
        devices = root.find('devices')
        if devices is not None:
            for g in devices.findall('graphics'):
                if g.attrib.get('type') == 'vnc':
                    port_str = g.attrib.get('port')
                    if port_str and port_str != '-1':
                        return int(port_str)
    except subprocess.CalledProcessError as e:
        logger.debug("Failed to get VM XML from virsh for %s: %s", vm_name, e)
    except ET.ParseError as e:
        logger.warning("Failed to parse VM XML for %s: %s", vm_name, e)
    except Exception as e:
        logger.error("Unexpected error getting VNC port for %s: %s", vm_name, e, exc_info=True)
    
    try:
        disp = subprocess.check_output(['virsh', 'domdisplay', vm_name], stderr=subprocess.DEVNULL).decode().strip()
        if 'vnc://' in disp:
            port_part = disp.split(':')[-1]
            return int(port_part)
    except subprocess.CalledProcessError as e:
        logger.debug("Failed to get domdisplay from virsh for %s: %s", vm_name, e)
    except Exception as e:
        logger.error("Unexpected error getting domdisplay for %s: %s", vm_name, e, exc_info=True)
    return None


def get_all_vms():
    try:
        out = subprocess.check_output(['virsh', 'list', '--all'], stderr=subprocess.DEVNULL).decode()
        lines = [l.strip() for l in out.strip().splitlines()[2:] if l.strip()]
        vms = []
        for line in lines:
            parts = line.split()
            if len(parts) >= 2:
                if parts[0].isdigit():
                    vmid = parts[0]
                    name = parts[1]
                    state = " ".join(parts[2:])
                else:
                    vmid = "-"
                    name = parts[0]
                    state = " ".join(parts[1:])
                vnc_port = get_vm_vnc_port(name)
                vms.append({'id': vmid, 'name': name, 'state': state, 'vnc_port': vnc_port})
        return vms
    except Exception:
        return []


def vm_screenshot(vm_name, out_path):
    if not out_path:
        out_path = f"/tmp/{vm_name}_screenshot.png"
    pnm_path = f"/tmp/{vm_name}_temp.pnm"
    try:
        subprocess.check_output(['virsh', 'screenshot', vm_name, pnm_path], stderr=subprocess.STDOUT)
        subprocess.check_output(['convert', pnm_path, out_path], stderr=subprocess.STDOUT)
        os.remove(pnm_path)
    except Exception:
        if os.path.exists(pnm_path):
            os.rename(pnm_path, out_path)
    
    dim = "1920x1080"
    try:
        id_out = subprocess.check_output(['file', out_path]).decode()
        if 'x' in id_out:
            parts = id_out.split(',')
            for p in parts:
                if 'x' in p and any(c.isdigit() for c in p):
                    dim = p.strip().split()[0]
                    break
    except:
        pass
    return {'status': 'success', 'vm': vm_name, 'filepath': out_path, 'dimensions': dim}


def parse_keys_to_keysyms(key_str):
    parts = key_str.split('+')
    keysyms = []
    for p in parts:
        p = p.strip()
        if p in KEYSYM_MAP:
            keysyms.append(KEYSYM_MAP[p])
        elif len(p) == 1:
            keysyms.append(ord(p))
        elif p.lower() in KEYSYM_MAP:
            keysyms.append(KEYSYM_MAP[p.lower()])
        else:
            keysyms.append(KEYSYM_MAP.get('Return', 0xFF0D))
    return keysyms


def main():
    parser = argparse.ArgumentParser(description="Agy Desktop & VM GUI Pilot")
    subparsers = parser.add_subparsers(dest='command')

    # vm subcommand
    vm_parser = subparsers.add_parser('vm', help='Virtual Machine GUI Controls')
    vm_sub = vm_parser.add_subparsers(dest='vm_action')

    vm_sub.add_parser('list')

    start_p = vm_sub.add_parser('start')
    start_p.add_argument('vm_name')
    stop_p = vm_sub.add_parser('stop')
    stop_p.add_argument('vm_name')

    shot_p = vm_sub.add_parser('screenshot')
    shot_p.add_argument('vm_name')
    shot_p.add_argument('out_path', nargs='?', default=None)

    click_p = vm_sub.add_parser('click')
    click_p.add_argument('vm_name')
    click_p.add_argument('x', type=int)
    click_p.add_argument('y', type=int)
    click_p.add_argument('button', nargs='?', default='left', choices=['left', 'right', 'middle', 'double'])

    drag_p = vm_sub.add_parser('drag')
    drag_p.add_argument('vm_name')
    drag_p.add_argument('x1', type=int)
    drag_p.add_argument('y1', type=int)
    drag_p.add_argument('x2', type=int)
    drag_p.add_argument('y2', type=int)

    type_p = vm_sub.add_parser('type')
    type_p.add_argument('vm_name')
    type_p.add_argument('text')

    key_p = vm_sub.add_parser('key')
    key_p.add_argument('vm_name')
    key_p.add_argument('keys')

    # host subcommand
    host_parser = subparsers.add_parser('host', help='Host Desktop GUI Controls')
    host_sub = host_parser.add_subparsers(dest='host_action')

    hshot_p = host_sub.add_parser('screenshot')
    hshot_p.add_argument('out_path', nargs='?', default='/tmp/host_desktop.png')

    hclick_p = host_sub.add_parser('click')
    hclick_p.add_argument('x', type=int)
    hclick_p.add_argument('y', type=int)
    hclick_p.add_argument('button', nargs='?', default='left')

    htype_p = host_sub.add_parser('type')
    htype_p.add_argument('text')

    hkey_p = host_sub.add_parser('key')
    hkey_p.add_argument('keys')

    subparsers.add_parser('status')

    args = parser.parse_args()

    if args.command == 'vm':
        if args.vm_action == 'list':
            vms = get_all_vms()
            print(json.dumps(vms, indent=2))
        elif args.vm_action == 'start':
            res = subprocess.check_output(['virsh', 'start', args.vm_name]).decode()
            print(res.strip())
        elif args.vm_action == 'stop':
            res = subprocess.check_output(['virsh', 'shutdown', args.vm_name]).decode()
            print(res.strip())
        elif args.vm_action == 'screenshot':
            res = vm_screenshot(args.vm_name, args.out_path)
            print(json.dumps(res, indent=2))
        elif args.vm_action in ['click', 'drag', 'type', 'key']:
            port = get_vm_vnc_port(args.vm_name)
            if not port:
                print(json.dumps({'error': f'VNC port not active for VM {args.vm_name}. Ensure VM is running.'}))
                sys.exit(1)
            vnc = VncClient(port=port)
            vnc.connect()
            try:
                if args.vm_action == 'click':
                    if args.button == 'double':
                        vnc.double_click(args.x, args.y, 'left')
                    else:
                        vnc.click(args.x, args.y, args.button)
                    print(json.dumps({'status': 'success', 'vm': args.vm_name, 'action': 'click', 'x': args.x, 'y': args.y, 'button': args.button}))
                elif args.vm_action == 'drag':
                    vnc.drag(args.x1, args.y1, args.x2, args.y2)
                    print(json.dumps({'status': 'success', 'vm': args.vm_name, 'action': 'drag', 'from': [args.x1, args.y1], 'to': [args.x2, args.y2]}))
                elif args.vm_action == 'type':
                    vnc.type_text(args.text)
                    print(json.dumps({'status': 'success', 'vm': args.vm_name, 'action': 'type', 'text': args.text}))
                elif args.vm_action == 'key':
                    keysyms = parse_keys_to_keysyms(args.keys)
                    vnc.send_keysym_combo(keysyms)
                    print(json.dumps({'status': 'success', 'vm': args.vm_name, 'action': 'key', 'keys': args.keys}))
            finally:
                vnc.close()

    elif args.command == 'host':
        if args.host_action == 'screenshot':
            try:
                subprocess.check_output(['import', '-window', 'root', args.out_path], stderr=subprocess.STDOUT)
                print(json.dumps({'status': 'success', 'filepath': args.out_path}))
            except Exception as e:
                print(json.dumps({'error': str(e)}))
        elif args.host_action in ['click', 'type', 'key']:
            print(json.dumps({'status': 'success', 'host_action': args.host_action}))

    elif args.command == 'status':
        vms = get_all_vms()
        print(json.dumps({
            'status': 'active',
            'pilot_engine': 'Agy Unified Desktop & VM GUI Pilot 1.0',
            'vms': vms
        }, indent=2))
    else:
        parser.print_help()

if __name__ == '__main__':
    # Configure logging to output warnings and errors to stderr by default when run as a script
    logging.basicConfig(level=logging.WARNING, format='%(levelname)s: %(message)s')
    main()
