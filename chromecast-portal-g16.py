#!/usr/bin/env python3
"""
Chromecast Hardware PiKVM & Wi-Fi Hotspot Master Portal (G16)
Provides real-time Wi-Fi AP Hotspot status, reverse Internet routing,
Hardware USB KVM Keyboard & Mouse injection, and HDMI Virtual Monitor stream portal.
"""

import subprocess
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk

class ChromecastPortalWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Chromecast Hardware PiKVM & Wi-Fi Hotspot Portal (G16)")
        self.set_default_size(1150, 750)

        # Apply dark sleek styling
        provider = Gtk.CssProvider()
        css = """
        window {
            background-color: #0b0e14;
            color: #d1d5db;
            font-family: 'Inter', 'Ubuntu', sans-serif;
        }
        .header-bar {
            background: linear-gradient(135deg, #1f2937 0%, #111827 100%);
            padding: 14px;
            border-bottom: 2px solid #10b981;
        }
        .node-title {
            font-size: 18px;
            font-weight: bold;
            color: #38bdf8;
        }
        .status-pill {
            background-color: #059669;
            color: #ffffff;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: bold;
        }
        .card-box {
            background-color: #111827;
            border: 1px solid #1f2937;
            border-radius: 8px;
            padding: 16px;
            margin: 8px;
        }
        .card-title {
            font-size: 14px;
            font-weight: bold;
            color: #9ca3af;
            margin-bottom: 8px;
        }
        .action-btn {
            background-color: #1f2937;
            color: #f3f4f6;
            border: 1px solid #374151;
            border-radius: 6px;
            padding: 8px 16px;
            font-weight: 600;
        }
        .action-btn:hover {
            background-color: #374151;
            color: #38bdf8;
        }
        """
        provider.load_from_data(css.encode('utf-8'))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_child(main_box)

        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header.add_css_class("header-bar")

        title = Gtk.Label(label="⚡ HARDWARE PiKVM & WI-FI HOTSPOT PORTAL (G16)")
        title.add_css_class("node-title")
        header.append(title)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        header.append(spacer)

        badge = Gtk.Label(label="SSID: chromecast-node | PiKVM Active")
        badge.add_css_class("status-pill")
        header.append(badge)

        main_box.append(header)

        # Content Grid
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        content.set_margin_top(10)
        content.set_margin_bottom(10)
        content.set_margin_start(10)
        content.set_margin_end(10)
        content.set_vexpand(True)
        main_box.append(content)

        # Left Column
        left_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        left_col.set_size_request(380, -1)
        content.append(left_col)

        # Card 1: Wi-Fi Hotspot & Reverse Internet NAT
        wifi_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        wifi_card.add_css_class("card-box")
        
        t1 = Gtk.Label(label="📡 WI-FI HOTSPOT & INTERNET ROUTING")
        t1.add_css_class("card-title")
        t1.set_halign(Gtk.Align.START)
        wifi_card.append(t1)

        self.wifi_status_label = Gtk.Label()
        self.wifi_status_label.set_markup("Hotspot SSID: <b>chromecast-node</b>\nWPA2 Password: <b>tag82358235</b>\nHotspot Gateway: <b>192.168.12.1 (wlan0)</b>\nUSB Gateway: <b>192.168.7.1 (usb0)</b>\nReverse NAT: <b>G16 Primary Net (wlo1)</b>")
        self.wifi_status_label.set_halign(Gtk.Align.START)
        wifi_card.append(self.wifi_status_label)

        left_col.append(wifi_card)

        # Card 2: Portals
        portal_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        portal_card.add_css_class("card-box")

        t2 = Gtk.Label(label="🖥️ PORTALS & INTERFACES")
        t2.add_css_class("card-title")
        t2.set_halign(Gtk.Align.START)
        portal_card.append(t2)

        btn_term = Gtk.Button(label="Open Web Terminal (http://192.168.7.1:7681)")
        btn_term.add_css_class("action-btn")
        btn_term.connect("clicked", self.on_open_terminal)
        portal_card.append(btn_term)

        btn_vnc = Gtk.Button(label="Open WayVNC GUI (vnc://192.168.7.1:5900)")
        btn_vnc.add_css_class("action-btn")
        btn_vnc.connect("clicked", self.on_open_vnc)
        portal_card.append(btn_vnc)

        btn_ssh = Gtk.Button(label="Open SSH Root Terminal")
        btn_ssh.add_css_class("action-btn")
        btn_ssh.connect("clicked", self.on_open_ssh)
        portal_card.append(btn_ssh)

        left_col.append(portal_card)

        # Right Column: Hardware USB KVM Controls
        right_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        right_col.set_hexpand(True)
        content.append(right_col)

        kvm_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        kvm_card.add_css_class("card-box")
        kvm_card.set_vexpand(True)

        t3 = Gtk.Label(label="⌨️🖱️ HARDWARE USB KVM (KEYBOARD + MOUSE)")
        t3.add_css_class("card-title")
        t3.set_halign(Gtk.Align.START)
        kvm_card.append(t3)

        desc = Gtk.Label(label="Control workstation hardware directly over USB Composite Gadget:\n • Keyboard: /dev/hidg0\n • Mouse: /dev/hidg1\n • Monitor: HDMI Virtual Display Sink (1080p@60Hz)")
        desc.set_wrap(True)
        desc.set_halign(Gtk.Align.START)
        kvm_card.append(desc)

        btn_grub = Gtk.Button(label="Inject GRUB Recovery Macro (/dev/hidg0)")
        btn_grub.add_css_class("action-btn")
        btn_grub.connect("clicked", self.on_inject_grub)
        kvm_card.append(btn_grub)

        btn_click = Gtk.Button(label="Send Hardware Left Click (/dev/hidg1)")
        btn_click.add_css_class("action-btn")
        btn_click.connect("clicked", self.on_click_mouse)
        kvm_card.append(btn_click)

        btn_move = Gtk.Button(label="Move Mouse Cursor Delta (+50, +50)")
        btn_move.add_css_class("action-btn")
        btn_move.connect("clicked", self.on_move_mouse)
        kvm_card.append(btn_move)

        right_col.append(kvm_card)

    def on_open_terminal(self, btn):
        subprocess.Popen(["xdg-open", "http://192.168.7.1:7681"])

    def on_open_vnc(self, btn):
        subprocess.Popen(["remote-viewer", "vnc://192.168.7.1:5900"])

    def on_open_ssh(self, btn):
        subprocess.Popen(["ptyxis", "--", "ssh", "root@192.168.7.1"])

    def on_inject_grub(self, btn):
        subprocess.Popen(["python3", "/root/agentic-qubes-staging/scripts/usb-hid-paste.py", "--grub-loadout", "recovery-root"])

    def on_click_mouse(self, btn):
        subprocess.Popen(["python3", "/root/agentic-qubes-staging/scripts/usb-hid-kvm-mouse.py", "--click", "left"])

    def on_move_mouse(self, btn):
        subprocess.Popen(["python3", "/root/agentic-qubes-staging/scripts/usb-hid-kvm-mouse.py", "--move", "50", "50"])

def main():
    app = Gtk.Application(application_id="org.agentic.chromecastpikvm")
    def on_activate(app):
        win = ChromecastPortalWindow(app)
        win.present()
    app.connect("activate", on_activate)
    app.run(None)

if __name__ == "__main__":
    main()
