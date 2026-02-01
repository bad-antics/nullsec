#!/usr/bin/env python3
"""
NULLSEC DESKTOP v2.0 - Armitage-Style Attack Framework GUI
===========================================================
Professional penetration testing and red team operations GUI

Features:
- Network topology visualization
- Host discovery and management  
- 185+ Attack modules with auto-discovery
- Shodan integration
- Session management
- Target database
- Real-time terminal output

Author: bad-antics development
GitHub: github.com/bad-antics
"""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Vte', '2.91')
from gi.repository import Gtk, Gdk, GLib, Pango, GdkPixbuf, Vte
import os
import sys
import json
import subprocess
import threading
import socket
import ipaddress
import shlex
import pty
import signal
from datetime import datetime
from pathlib import Path
from queue import Queue, Empty

# NULLSEC Color Scheme
COLORS = {
    'bg_dark': '#0a0a0a',
    'bg_panel': '#141414',
    'bg_header': '#1a0000',
    'red': '#cc0000',
    'red_bright': '#ff3333',
    'green': '#00cc00',
    'yellow': '#cccc00',
    'cyan': '#00cccc',
    'white': '#ffffff',
    'gray': '#666666',
    'text': '#e0e0e0'
}

# Framework paths
NULLSEC_DIR = Path(__file__).parent.parent
MODULES_DIR = NULLSEC_DIR / 'nullsecurity'
SHODAN_TARGET = NULLSEC_DIR / '.shodan_target'
LOGS_DIR = NULLSEC_DIR / 'logs'


class Target:
    """Represents a network target"""
    def __init__(self, ip, hostname=None, os_type=None, ports=None, status='unknown'):
        self.ip = ip
        self.hostname = hostname or ip
        self.os_type = os_type or 'Unknown'
        self.ports = ports or []
        self.status = status  # unknown, alive, compromised
        self.sessions = []
        self.notes = ""
        self.discovered = datetime.now()
    
    def to_dict(self):
        return {
            'ip': self.ip,
            'hostname': self.hostname,
            'os_type': self.os_type,
            'ports': self.ports,
            'status': self.status,
            'notes': self.notes
        }


class ModuleCategory:
    """Attack module category"""
    def __init__(self, name, icon, modules):
        self.name = name
        self.icon = icon
        self.modules = modules


class NullsecDesktop(Gtk.Window):
    """Main NULLSEC Desktop Application Window"""
    
    def __init__(self):
        super().__init__(title="NULLSEC Desktop v2.0")
        self.set_default_size(1400, 900)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        # Initialize data structures
        self.targets = {}  # ip -> Target
        self.sessions = []
        self.modules = self.load_modules()
        self.current_target = None
        self.running_processes = {}  # pid -> process info
        self.output_queue = Queue()
        self._last_log_message = None  # Prevent duplicate log entries
        self._last_log_time = 0
        
        # Apply dark theme
        self.apply_css()
        
        # Build UI
        self.build_ui()
        
        # Connect window close
        self.connect("destroy", self.on_destroy)
        
        # Load Shodan target if exists
        self.load_shodan_target()
        
        # Start output monitor
        GLib.timeout_add(100, self.process_output_queue)
    
    def on_destroy(self, widget):
        """Clean up on window close"""
        # Kill any running background processes
        for pid, info in self.running_processes.items():
            try:
                os.kill(pid, signal.SIGTERM)
            except:
                pass
        Gtk.main_quit()
    
    def apply_css(self):
        """Apply custom dark theme CSS"""
        css = b"""
        window {
            background-color: #0a0a0a;
        }
        .header-bar {
            background: linear-gradient(to bottom, #2a0000, #1a0000);
            border-bottom: 2px solid #cc0000;
        }
        .panel {
            background-color: #141414;
            border: 1px solid #333333;
        }
        .red-text {
            color: #cc0000;
        }
        .green-text {
            color: #00cc00;
        }
        .module-button {
            background-color: #1a1a1a;
            border: 1px solid #333333;
            color: #ffffff;
            padding: 8px;
        }
        .module-button:hover {
            background-color: #2a0000;
            border-color: #cc0000;
        }
        .target-alive {
            background-color: #001a00;
        }
        .target-compromised {
            background-color: #1a0000;
        }
        treeview {
            background-color: #141414;
            color: #e0e0e0;
        }
        treeview:selected {
            background-color: #2a0000;
        }
        entry {
            background-color: #1a1a1a;
            color: #ffffff;
            border: 1px solid #333333;
        }
        button {
            background-color: #1a1a1a;
            color: #ffffff;
            border: 1px solid #333333;
        }
        button:hover {
            background-color: #2a0000;
            border-color: #cc0000;
        }
        notebook tab {
            background-color: #1a1a1a;
            color: #888888;
            padding: 8px 16px;
        }
        notebook tab:checked {
            background-color: #2a0000;
            color: #ffffff;
        }
        textview {
            background-color: #0a0a0a;
            color: #00cc00;
            font-family: monospace;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def load_modules(self):
        """Load attack modules from nullsecurity directory using auto-discovery"""
        # Category detection from filename patterns (same as CLI launcher)
        category_patterns = {
            'Network': ['port-', 'network-', 'dns-', 'mitm-', 'arp-', 'wifi-', 'bluetooth-', 'sniffer', 'scan'],
            'Web': ['web-', 'xss-', 'sqli-', 'sql-', 'lfi-', 'rfi-', 'ssrf-', 'csrf-', 'jwt-', 'oauth-', 'ssti-', 'xxe-', 'cors-', 'csp-'],
            'Credentials': ['pass', 'hash', 'cred', 'brute', 'kerberos', 'ntlm', 'token-'],
            'Malware': ['payload', 'trojan', 'ransomware', 'rootkit', 'backdoor', 'rat-', 'c2-', 'cryptominer'],
            'Cloud': ['cloud-', 'aws-', 'azure-', 'gcp-', 's3-', 'kubernetes-', 'docker-', 'container-'],
            'Active Directory': ['ad-', 'ldap-', 'kerberoast', 'golden-ticket', 'dcsync'],
            'Database': ['database-', 'mysql-', 'postgres-', 'mssql-', 'oracle-', 'mongodb-', 'redis-', 'kafka-', 'neo4j-', 'couchdb-'],
            'Mobile': ['mobile-', 'android-', 'ios-', 'apk-'],
            'IoT': ['iot-', 'modbus-', 'zigbee-', 'mqtt-', 'upnp-', 'smart-', 'scada-'],
            'Exploitation': ['exploit', 'kernel-', 'rop-', 'shellcode-', 'heap-', 'buffer-'],
            'Evasion': ['bypass', 'amsi-', 'edr-', 'av-', 'sandbox-', 'anti-'],
            'Persistence': ['persistence', 'backdoor', 'startup'],
            'Exfiltration': ['exfil', 'tunnel'],
            'Recon': ['recon', 'enum', 'shodan', 'osint', 'whois'],
            'Physical': ['badusb', 'camera-', 'alarm-', 'atm-', 'rfid-'],
            'OPSEC': ['darkweb', 'crypto-', 'identity-', 'evidence-', 'stego'],
            'DDoS': ['ddos', 'slowloris', 'amplify', 'flood'],
            'ICS': ['scada', 'plc-', 'power-', 'water-', 'industrial'],
            'Protocols': ['http', 'grpc-', 'websocket-', 'quic-', 'protobuf-', 'thrift-'],
            'Enterprise': ['jenkins-', 'gitlab-', 'confluence-', 'jira-', 'sharepoint-'],
            'Hardware': ['fortinet-', 'palo-alto-', 'cisco-', 'mikrotik-', 'router-'],
        }
        
        # Icon mapping
        category_icons = {
            'Network': '🌐', 'Web': '🕸️', 'Credentials': '🔑', 'Malware': '🦠',
            'Cloud': '☁️', 'Active Directory': '🏢', 'Database': '🗄️', 'Mobile': '📱',
            'IoT': '🔌', 'Exploitation': '💣', 'Evasion': '🥷', 'Persistence': '🔒',
            'Exfiltration': '📤', 'Recon': '🔍', 'Physical': '💾', 'OPSEC': '🧅',
            'DDoS': '💥', 'ICS': '🏭', 'Protocols': '📡', 'Enterprise': '🏢', 'Hardware': '🔧',
        }
        
        modules = {}
        
        if MODULES_DIR.exists():
            for script in sorted(MODULES_DIR.glob('*.sh')):
                if script.name in ['nullsec-common.sh', 'enhance-all-modules.sh', 
                                   'batch-enhance.sh', 'check-enhancements.sh', 'dep-check.sh',
                                   'batch-create-modules.sh']:
                    continue
                
                name = script.stem.replace('-', ' ').title()
                
                # Determine category
                category = 'Advanced'
                for cat, patterns in category_patterns.items():
                    if any(pattern in script.name.lower() for pattern in patterns):
                        category = cat
                        break
                
                # Get icon
                icon = category_icons.get(category, '⚡')
                
                # Add to category
                if category not in modules:
                    modules[category] = []
                
                modules[category].append({
                    'name': name,
                    'script': str(script),
                    'icon': icon
                })
        
        return modules
    
    def build_ui(self):
        """Build the main UI"""
        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(main_box)
        
        # Header bar
        header = self.create_header()
        main_box.pack_start(header, False, False, 0)
        
        # Main paned container (3 panels)
        main_paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        main_box.pack_start(main_paned, True, True, 0)
        
        # Left panel - Module tree
        left_panel = self.create_module_panel()
        left_panel.set_size_request(280, -1)
        main_paned.pack1(left_panel, False, False)
        
        # Right paned (center + right)
        right_paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        main_paned.pack2(right_paned, True, False)
        
        # Center panel - Network view
        center_panel = self.create_network_panel()
        right_paned.pack1(center_panel, True, False)
        
        # Right panel - Details/Console
        right_panel = self.create_details_panel()
        right_panel.set_size_request(350, -1)
        right_paned.pack2(right_panel, False, False)
        
        # Status bar
        statusbar = self.create_statusbar()
        main_box.pack_start(statusbar, False, False, 0)
    
    def create_header(self):
        """Create the header bar with logo and toolbar"""
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        header_box.get_style_context().add_class('header-bar')
        header_box.set_margin_top(5)
        header_box.set_margin_bottom(5)
        header_box.set_margin_start(10)
        header_box.set_margin_end(10)
        
        # Compact logo/title
        logo = Gtk.Label()
        logo.set_markup(
            '<span font_family="monospace" foreground="#cc0000" weight="bold" size="large">'
            '▓█ </span>'
            '<span font_family="monospace" foreground="#ffffff" weight="bold" size="large">'
            'NULLSEC DESKTOP</span>'
            '<span font_family="monospace" foreground="#cc0000" weight="bold" size="large">'
            ' █▓</span>'
            '<span font_family="monospace" foreground="#666666" size="small">'
            '  v1.0</span>'
        )
        header_box.pack_start(logo, False, False, 0)
        
        # Target input
        target_label = Gtk.Label(label="Target:")
        target_label.set_margin_start(20)
        target_label.set_margin_end(5)
        header_box.pack_start(target_label, False, False, 0)
        
        self.target_entry = Gtk.Entry()
        self.target_entry.set_placeholder_text("IP / Range / Domain")
        self.target_entry.set_width_chars(20)
        self.target_entry.connect('activate', self.on_add_target)
        header_box.pack_start(self.target_entry, False, False, 0)
        
        add_btn = Gtk.Button(label="+ Add")
        add_btn.connect('clicked', self.on_add_target)
        header_box.pack_start(add_btn, False, False, 5)
        
        # Spacer
        header_box.pack_start(Gtk.Box(), True, True, 0)
        
        # Quick actions on the right
        actions = [
            ('Scan', self.on_quick_scan),
            ('Shodan', self.on_shodan_search),
            ('AI', self.on_ai_console),
            ('Pentester', self.on_ai_pentester),
            ('Flipper', self.on_flipper_zero),
            ('Pineapple', self.on_pineapple),
            ('Import', self.on_import_targets),
            ('Export', self.on_export_targets),
            ('Settings', self.on_settings),
        ]
        
        for label, callback in actions:
            btn = Gtk.Button(label=label)
            btn.connect('clicked', callback)
            header_box.pack_start(btn, False, False, 2)
        
        return header_box
    def create_module_panel(self):
        """Create the left panel with attack modules tree"""
        frame = Gtk.Frame(label=" 💀 Attack Modules ")
        frame.get_style_context().add_class('panel')
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        frame.add(scroll)
        
        # Tree store: icon, name, script_path
        self.module_store = Gtk.TreeStore(str, str, str)
        
        for category, modules in self.modules.items():
            if not modules:
                continue
            # Add category
            cat_iter = self.module_store.append(None, ['📁', category, ''])
            # Add modules
            for module in modules:
                self.module_store.append(cat_iter, [
                    module['icon'],
                    module['name'],
                    module['script']
                ])
        
        tree = Gtk.TreeView(model=self.module_store)
        tree.set_headers_visible(False)
        tree.connect('row-activated', self.on_module_activated)
        
        # Columns
        renderer_icon = Gtk.CellRendererText()
        col_icon = Gtk.TreeViewColumn("", renderer_icon, text=0)
        col_icon.set_fixed_width(30)
        tree.append_column(col_icon)
        
        renderer_name = Gtk.CellRendererText()
        col_name = Gtk.TreeViewColumn("Module", renderer_name, text=1)
        tree.append_column(col_name)
        
        scroll.add(tree)
        return frame
    
    def create_network_panel(self):
        """Create the center panel with network visualization"""
        frame = Gtk.Frame(label=" 🌐 Network Topology ")
        frame.get_style_context().add_class('panel')
        
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        frame.add(vbox)
        
        # Drawing area for network map
        self.network_canvas = Gtk.DrawingArea()
        self.network_canvas.set_size_request(400, 300)
        self.network_canvas.connect('draw', self.on_draw_network)
        self.network_canvas.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.network_canvas.connect('button-press-event', self.on_network_click)
        vbox.pack_start(self.network_canvas, True, True, 0)
        
        # Target list below
        scroll = Gtk.ScrolledWindow()
        scroll.set_size_request(-1, 200)
        vbox.pack_start(scroll, False, False, 0)
        
        # Target list store: icon, IP, hostname, OS, ports, status
        self.target_store = Gtk.ListStore(str, str, str, str, str, str)
        
        tree = Gtk.TreeView(model=self.target_store)
        tree.connect('row-activated', self.on_target_selected)
        self.target_tree = tree
        
        columns = [
            ('', 0, 30),
            ('IP', 1, 120),
            ('Hostname', 2, 150),
            ('OS', 3, 100),
            ('Ports', 4, 150),
            ('Status', 5, 80)
        ]
        
        for title, idx, width in columns:
            renderer = Gtk.CellRendererText()
            col = Gtk.TreeViewColumn(title, renderer, text=idx)
            col.set_fixed_width(width)
            col.set_resizable(True)
            tree.append_column(col)
        
        scroll.add(tree)
        return frame
    
    def create_details_panel(self):
        """Create the right panel with details and console"""
        notebook = Gtk.Notebook()
        
        # Console tab
        console_scroll = Gtk.ScrolledWindow()
        self.console = Gtk.TextView()
        self.console.set_editable(False)
        self.console.set_monospace(True)
        self.console_buffer = self.console.get_buffer()
        
        # Create text tags for coloring
        self.console_buffer.create_tag('red', foreground='#cc0000')
        self.console_buffer.create_tag('green', foreground='#00cc00')
        self.console_buffer.create_tag('yellow', foreground='#cccc00')
        self.console_buffer.create_tag('cyan', foreground='#00cccc')
        self.console_buffer.create_tag('white', foreground='#ffffff')
        
        console_scroll.add(self.console)
        notebook.append_page(console_scroll, Gtk.Label(label="🖥️ Console"))
        
        # Target details tab
        details_scroll = Gtk.ScrolledWindow()
        self.details_text = Gtk.TextView()
        self.details_text.set_editable(False)
        self.details_text.set_monospace(True)
        details_scroll.add(self.details_text)
        notebook.append_page(details_scroll, Gtk.Label(label="📋 Details"))
        
        # Sessions tab
        sessions_scroll = Gtk.ScrolledWindow()
        self.sessions_store = Gtk.ListStore(str, str, str, str, str)  # type, target, user, time, pid
        sessions_tree = Gtk.TreeView(model=self.sessions_store)
        sessions_tree.connect('row-activated', self.on_session_activated)
        self.sessions_tree = sessions_tree
        
        for i, title in enumerate(['Type', 'Target', 'User', 'Time']):
            col = Gtk.TreeViewColumn(title, Gtk.CellRendererText(), text=i)
            sessions_tree.append_column(col)
        
        sessions_scroll.add(sessions_tree)
        notebook.append_page(sessions_scroll, Gtk.Label(label="🔗 Sessions"))
        
        # Terminal tab with embedded VTE terminal
        terminal_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        
        # Create VTE terminal
        try:
            self.terminal = Vte.Terminal()
            self.terminal.set_color_background(Gdk.RGBA(0.04, 0.04, 0.04, 1.0))
            self.terminal.set_color_foreground(Gdk.RGBA(0.0, 0.8, 0.0, 1.0))
            self.terminal.set_font(Pango.FontDescription("monospace 10"))
            self.terminal.set_scrollback_lines(10000)
            
            # Connect child-exited signal to handle terminal closing
            self.terminal.connect("child-exited", self.on_terminal_child_exited)
            
            # Spawn shell - use login shell for proper SSH handling
            # Don't use --rcfile to avoid double-sourcing profile scripts
            self.terminal.spawn_sync(
                Vte.PtyFlags.DEFAULT,
                str(NULLSEC_DIR),
                ["/bin/bash", "-l"],  # Login shell - loads profile once
                ["TERM=xterm-256color", "NULLSEC_TERMINAL=1"],  # Mark as nullsec terminal
                GLib.SpawnFlags.DEFAULT,
                None, None
            )
            
            terminal_scroll = Gtk.ScrolledWindow()
            terminal_scroll.add(self.terminal)
            terminal_box.pack_start(terminal_scroll, True, True, 0)
            
            # Command input for quick commands
            cmd_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            cmd_label = Gtk.Label(label="nullsec> ")
            cmd_label.set_margin_start(5)
            cmd_box.pack_start(cmd_label, False, False, 0)
            
            self.cmd_entry = Gtk.Entry()
            self.cmd_entry.set_placeholder_text("Enter command...")
            self.cmd_entry.connect('activate', self.on_cmd_enter)
            cmd_box.pack_start(self.cmd_entry, True, True, 5)
            
            terminal_box.pack_start(cmd_box, False, False, 5)
            
        except Exception as e:
            # Fallback if VTE not available
            self.terminal = None
            fallback_label = Gtk.Label(label=f"VTE Terminal not available: {e}\nInstall with: sudo apt install gir1.2-vte-2.91")
            terminal_box.pack_start(fallback_label, True, True, 0)
        
        notebook.append_page(terminal_box, Gtk.Label(label="💻 Terminal"))
        
        return notebook
    
    def on_terminal_child_exited(self, terminal, status):
        """Handle terminal shell exit - respawn for next use"""
        # Only respawn if window is still open
        if hasattr(self, 'terminal') and self.terminal:
            try:
                self.terminal.spawn_sync(
                    Vte.PtyFlags.DEFAULT,
                    str(NULLSEC_DIR),
                    ["/bin/bash", "-l"],
                    ["TERM=xterm-256color", "NULLSEC_TERMINAL=1"],
                    GLib.SpawnFlags.DEFAULT,
                    None, None
                )
            except:
                pass
    
    def on_terminal_spawn(self, terminal, pid, error, user_data):
        """Called when terminal shell spawns"""
        if error:
            self.log(f"Terminal error: {error}", 'red')
        else:
            self.log("Terminal ready", 'green')
    
    def on_cmd_enter(self, widget):
        """Handle command entry"""
        cmd = widget.get_text().strip()
        if cmd and self.terminal:
            # Send command to terminal
            self.terminal.feed_child((cmd + "\n").encode())
            widget.set_text("")
    
    def on_session_activated(self, tree, path, column):
        """Handle double-click on session"""
        model = tree.get_model()
        iter = model.get_iter(path)
        session_type = model.get_value(iter, 0)
        target = model.get_value(iter, 1)
        self.log(f"Interacting with {session_type} session on {target}", 'cyan')
    
    def create_statusbar(self):
        """Create status bar"""
        statusbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        statusbar.set_margin_start(10)
        statusbar.set_margin_end(10)
        statusbar.set_margin_top(5)
        statusbar.set_margin_bottom(5)
        
        self.status_label = Gtk.Label(label="Ready")
        statusbar.pack_start(self.status_label, False, False, 0)
        
        statusbar.pack_start(Gtk.Box(), True, True, 0)
        
        self.targets_label = Gtk.Label(label="Targets: 0")
        statusbar.pack_start(self.targets_label, False, False, 0)
        
        self.sessions_label = Gtk.Label(label="Sessions: 0")
        statusbar.pack_start(self.sessions_label, False, False, 0)
        
        self.modules_label = Gtk.Label(label=f"Modules: {sum(len(m) for m in self.modules.values())}")
        statusbar.pack_start(self.modules_label, False, False, 0)
        
        return statusbar
    
    def on_draw_network(self, widget, cr):
        """Draw network topology visualization"""
        width = widget.get_allocated_width()
        height = widget.get_allocated_height()
        
        # Background
        cr.set_source_rgb(0.04, 0.04, 0.04)
        cr.paint()
        
        # Grid lines
        cr.set_source_rgba(0.2, 0.2, 0.2, 0.3)
        cr.set_line_width(1)
        for x in range(0, width, 50):
            cr.move_to(x, 0)
            cr.line_to(x, height)
        for y in range(0, height, 50):
            cr.move_to(0, y)
            cr.line_to(width, y)
        cr.stroke()
        
        # Draw attacker (center left)
        attacker_x, attacker_y = 80, height // 2
        cr.set_source_rgb(0.8, 0, 0)
        cr.arc(attacker_x, attacker_y, 25, 0, 2 * 3.14159)
        cr.fill()
        cr.set_source_rgb(1, 1, 1)
        cr.select_font_face("monospace", 0, 1)
        cr.set_font_size(10)
        cr.move_to(attacker_x - 18, attacker_y + 4)
        cr.show_text("ATTACKER")
        
        # Draw targets in a grid
        if self.targets:
            targets = list(self.targets.values())
            cols = 3
            start_x = 200
            spacing_x = 120
            spacing_y = 100
            
            for i, target in enumerate(targets):
                col = i % cols
                row = i // cols
                x = start_x + col * spacing_x
                y = 80 + row * spacing_y
                
                # Store position for click detection
                target.x = x
                target.y = y
                
                # Line to target
                cr.set_source_rgba(0.5, 0, 0, 0.5)
                cr.set_line_width(2)
                cr.move_to(attacker_x + 25, attacker_y)
                cr.line_to(x, y)
                cr.stroke()
                
                # Target node color based on status
                if target.status == 'compromised':
                    cr.set_source_rgb(0.8, 0, 0)
                elif target.status == 'alive':
                    cr.set_source_rgb(0, 0.6, 0)
                else:
                    cr.set_source_rgb(0.4, 0.4, 0.4)
                
                cr.arc(x, y, 20, 0, 2 * 3.14159)
                cr.fill()
                
                # Target label
                cr.set_source_rgb(1, 1, 1)
                cr.set_font_size(9)
                cr.move_to(x - 25, y + 35)
                cr.show_text(target.ip[:15])
        
        return True
    
    def on_network_click(self, widget, event):
        """Handle clicks on network canvas"""
        for target in self.targets.values():
            if hasattr(target, 'x') and hasattr(target, 'y'):
                dist = ((event.x - target.x) ** 2 + (event.y - target.y) ** 2) ** 0.5
                if dist < 25:
                    self.current_target = target
                    self.show_target_details(target)
                    self.show_target_menu(target, event)
                    break
    
    def show_target_menu(self, target, event):
        """Show context menu for target"""
        menu = Gtk.Menu()
        
        items = [
            ('🔍 Scan Ports', lambda w: self.run_module_on_target('port-scanner', target)),
            ('💉 Exploit', lambda w: self.show_exploit_menu(target)),
            ('🔑 Credential Attack', lambda w: self.show_cred_menu(target)),
            ('📡 Shodan Lookup', lambda w: self.shodan_lookup(target)),
            ('✏️ Edit Notes', lambda w: self.edit_target_notes(target)),
            ('🗑️ Remove', lambda w: self.remove_target(target)),
        ]
        
        for label, callback in items:
            item = Gtk.MenuItem(label=label)
            item.connect('activate', callback)
            menu.append(item)
        
        menu.show_all()
        menu.popup_at_pointer(None)
    
    def show_exploit_menu(self, target):
        """Show exploit submenu"""
        menu = Gtk.Menu()
        
        exploit_modules = [
            ('web-exploit', '🌐 Web Exploit'),
            ('xss-attack', '💉 XSS Attack'),
            ('zero-day', '🔥 Zero-Day'),
            ('container-exploit', '🐳 Container Exploit'),
            ('api-exploit', '🔌 API Exploit'),
        ]
        
        for module, label in exploit_modules:
            item = Gtk.MenuItem(label=label)
            item.connect('activate', lambda w, m=module: self.run_module_on_target(m, target))
            menu.append(item)
        
        menu.show_all()
        menu.popup_at_pointer(None)
    
    def show_cred_menu(self, target):
        """Show credential attack submenu"""
        menu = Gtk.Menu()
        
        cred_modules = [
            ('password-crack', '🔓 Password Crack'),
            ('pass-hash', '🔑 Pass-the-Hash'),
            ('kerberoast', '🎫 Kerberoast'),
            ('golden-ticket', '🏆 Golden Ticket'),
            ('cred-stuff', '📋 Credential Stuffing'),
        ]
        
        for module, label in cred_modules:
            item = Gtk.MenuItem(label=label)
            item.connect('activate', lambda w, m=module: self.run_module_on_target(m, target))
            menu.append(item)
        
        menu.show_all()
        menu.popup_at_pointer(None)
    
    def shodan_lookup(self, target):
        """Lookup target in Shodan"""
        self.log(f"Looking up {target.ip} in Shodan...", 'cyan')
        self.run_background_command(f"shodan host {target.ip}", f"Shodan lookup: {target.ip}")
    
    def edit_target_notes(self, target):
        """Edit notes for target"""
        dialog = Gtk.Dialog(
            title=f"Notes: {target.ip}",
            parent=self,
            flags=0
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE, Gtk.ResponseType.OK
        )
        dialog.set_default_size(400, 300)
        
        content = dialog.get_content_area()
        
        scroll = Gtk.ScrolledWindow()
        textview = Gtk.TextView()
        textview.set_monospace(True)
        buffer = textview.get_buffer()
        buffer.set_text(target.notes or "")
        scroll.add(textview)
        content.pack_start(scroll, True, True, 10)
        
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            start, end = buffer.get_bounds()
            target.notes = buffer.get_text(start, end, True)
            self.log(f"Updated notes for {target.ip}", 'green')
            self.show_target_details(target)
        
        dialog.destroy()
    
    def remove_target(self, target):
        """Remove target from list"""
        if target.ip in self.targets:
            del self.targets[target.ip]
            self.refresh_target_list()
            self.network_canvas.queue_draw()
            self.log(f"Removed target: {target.ip}", 'yellow')
    
    def on_module_activated(self, tree, path, column):
        """Handle double-click on module - show launch options"""
        model = tree.get_model()
        iter = model.get_iter(path)
        script = model.get_value(iter, 2)
        
        if script:  # Not a category
            name = model.get_value(iter, 1)
            
            # Show launch options dialog
            dialog = Gtk.Dialog(
                title=f"Launch: {name}",
                parent=self,
                flags=0
            )
            dialog.set_default_size(350, 150)
            
            content = dialog.get_content_area()
            content.set_margin_start(20)
            content.set_margin_end(20)
            content.set_margin_top(20)
            content.set_margin_bottom(10)
            
            label = Gtk.Label()
            label.set_markup(f"<b>Select execution mode for:</b>\n{name}")
            content.pack_start(label, False, False, 10)
            
            # Button box
            btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            btn_box.set_halign(Gtk.Align.CENTER)
            
            standard_btn = Gtk.Button(label="🚀 Standard")
            standard_btn.connect('clicked', lambda w: self._launch_module_response(dialog, 'standard', script, name))
            btn_box.pack_start(standard_btn, False, False, 0)
            
            ai_btn = Gtk.Button(label="🤖 AI Execute")
            ai_btn.connect('clicked', lambda w: self._launch_module_response(dialog, 'ai', script, name))
            btn_box.pack_start(ai_btn, False, False, 0)
            
            cancel_btn = Gtk.Button(label="Cancel")
            cancel_btn.connect('clicked', lambda w: dialog.response(Gtk.ResponseType.CANCEL))
            btn_box.pack_start(cancel_btn, False, False, 0)
            
            content.pack_start(btn_box, False, False, 10)
            
            dialog.show_all()
            dialog.run()
            dialog.destroy()
    
    def _launch_module_response(self, dialog, mode, script, name):
        """Handle module launch mode selection"""
        dialog.response(Gtk.ResponseType.OK)
        
        if mode == 'standard':
            self.run_module(script, name)
        elif mode == 'ai':
            # Get target if available
            target = None
            if self.targets:
                target = list(self.targets.keys())[0]
            
            # Find module category from self.modules dict
            category = "general"
            for cat_name, cat_modules in self.modules.items():
                for mod in cat_modules:
                    if mod.get('script') == script:
                        category = cat_name.lower()
                        break
            
            self.ai_execute_module(name, category, target)
    
    def run_module(self, script, name, in_terminal=False):
        """Run an attack module with enhanced interactive framework"""
        self.log(f"Launching module: {name}", 'cyan')
        self.log(f"Script: {script}", 'white')
        
        # Check if module has enhanced config
        config_path = script.replace('.sh', '.json')
        framework_script = os.path.join(NULLSEC_DIR, 'module-framework.py')
        
        if os.path.exists(config_path) and os.path.exists(framework_script):
            # Use enhanced interactive framework
            self.log("Using enhanced interactive mode", 'yellow')
            cmd = f'cd {NULLSEC_DIR} && python3 module-framework.py "{script}" "{config_path}"; echo; read -p "Press Enter to close..."'
        else:
            # Standard execution
            cmd = f'cd {NULLSEC_DIR} && bash "{script}"; echo; read -p "Press Enter to close..."'
        
        # Always run in external terminal for interactive scripts
        try:
            # Try mate-terminal first (for MATE desktop)
            result = subprocess.Popen([
                'mate-terminal', '--title', f'NULLSEC: {name}',
                '-e', f"bash -c '{cmd}'"
            ])
            self.log(f"Module started (PID: {result.pid})", 'green')
        except FileNotFoundError:
            try:
                # Fallback to x-terminal-emulator
                result = subprocess.Popen([
                    'x-terminal-emulator', '-e', f"bash -c '{cmd}'"
                ])
                self.log(f"Module started (PID: {result.pid})", 'green')
            except FileNotFoundError:
                try:
                    # Fallback to gnome-terminal
                    result = subprocess.Popen([
                        'gnome-terminal', '--', 'bash', '-c', cmd
                    ])
                    self.log(f"Module started (PID: {result.pid})", 'green')
                except Exception as e:
                    self.log(f"Error: No terminal emulator found: {e}", 'red')
    
    def run_background_command(self, cmd, description="Background task"):
        """Run a command in background and capture output"""
        self.log(f"Starting: {description}", 'cyan')
        
        def run_cmd():
            try:
                process = subprocess.Popen(
                    cmd,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=str(NULLSEC_DIR)
                )
                
                pid = process.pid
                self.running_processes[pid] = {'desc': description, 'process': process}
                
                # Add to sessions
                GLib.idle_add(self.add_session, 'CMD', description, os.getenv('USER', 'antics'), str(pid))
                
                for line in process.stdout:
                    self.output_queue.put(('output', line.strip()))
                
                process.wait()
                self.output_queue.put(('complete', f"{description} completed (exit: {process.returncode})"))
                
                if pid in self.running_processes:
                    del self.running_processes[pid]
                
            except Exception as e:
                self.output_queue.put(('error', f"Error: {e}"))
        
        thread = threading.Thread(target=run_cmd, daemon=True)
        thread.start()
    
    def process_output_queue(self):
        """Process output from background commands"""
        try:
            while True:
                msg_type, msg = self.output_queue.get_nowait()
                if msg_type == 'output':
                    self.log(msg, 'white')
                elif msg_type == 'complete':
                    self.log(msg, 'green')
                elif msg_type == 'error':
                    self.log(msg, 'red')
        except Empty:
            pass
        return True  # Keep timer running
    
    def add_session(self, session_type, target, user, pid):
        """Add a session to the sessions list - prevents duplicates"""
        # Check if session with same PID already exists
        for row in self.sessions_store:
            if row[4] == pid:  # PID is column 4
                return  # Skip duplicate
        
        time_str = datetime.now().strftime('%H:%M:%S')
        self.sessions_store.append([session_type, target, user, time_str, pid])
        self.sessions_label.set_text(f"Sessions: {len(self.sessions_store)}")
    
    def run_module_on_target(self, module_name, target):
        """Run a module with target pre-filled"""
        script = MODULES_DIR / f"{module_name}.sh"
        if script.exists():
            # Save target for module to read
            with open(SHODAN_TARGET, 'w') as f:
                f.write(f"TARGET={target.ip}\n")
            
            self.run_module(str(script), module_name)
    
    def on_target_selected(self, tree, path, column):
        """Handle target selection"""
        model = tree.get_model()
        iter = model.get_iter(path)
        ip = model.get_value(iter, 1)
        
        if ip in self.targets:
            target = self.targets[ip]
            self.current_target = target
            self.show_target_details(target)
    
    def show_target_details(self, target):
        """Show target details in details panel"""
        details = f"""
╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
  TARGET DETAILS
╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸

IP Address: {target.ip}
Hostname:   {target.hostname}
OS Type:    {target.os_type}
Status:     {target.status}
Discovered: {target.discovered.strftime('%Y-%m-%d %H:%M')}

Open Ports:
{', '.join(map(str, target.ports)) if target.ports else 'Not scanned'}

Sessions:   {len(target.sessions)}

Notes:
{target.notes or 'No notes'}
"""
        buffer = self.details_text.get_buffer()
        buffer.set_text(details)
    
    def on_add_target(self, widget):
        """Add target from entry"""
        text = self.target_entry.get_text().strip()
        if not text:
            return
        
        # Check if it's a range
        if '/' in text:
            try:
                network = ipaddress.ip_network(text, strict=False)
                for ip in list(network.hosts())[:256]:  # Limit to 256
                    self.add_target(str(ip))
            except ValueError:
                self.log(f"Invalid network range: {text}", 'red')
        else:
            self.add_target(text)
        
        self.target_entry.set_text("")
    
    def add_target(self, ip):
        """Add a single target"""
        if ip not in self.targets:
            target = Target(ip)
            self.targets[ip] = target
            self.refresh_target_list()
            self.log(f"Added target: {ip}", 'green')
            self.network_canvas.queue_draw()
    
    def refresh_target_list(self):
        """Refresh the target list view"""
        self.target_store.clear()
        
        for ip, target in self.targets.items():
            status_icon = {
                'unknown': '❓',
                'alive': '🟢',
                'compromised': '💀'
            }.get(target.status, '❓')
            
            ports = ', '.join(map(str, target.ports[:5]))
            if len(target.ports) > 5:
                ports += '...'
            
            self.target_store.append([
                status_icon,
                target.ip,
                target.hostname,
                target.os_type,
                ports,
                target.status.upper()
            ])
        
        self.targets_label.set_text(f"Targets: {len(self.targets)}")
    
    def load_shodan_target(self):
        """Load target from Shodan search"""
        if SHODAN_TARGET.exists():
            try:
                with open(SHODAN_TARGET) as f:
                    for line in f:
                        if line.startswith('TARGET='):
                            ip = line.split('=')[1].strip()
                            if ip:
                                self.add_target(ip)
                                self.log(f"Loaded Shodan target: {ip}", 'cyan')
            except Exception as e:
                self.log(f"Error loading Shodan target: {e}", 'red')
    
    def log(self, message, color='white'):
        """Add message to console - prevents rapid duplicate messages"""
        import time
        current_time = time.time()
        
        # Prevent duplicate messages within 0.5 seconds
        if (message == self._last_log_message and 
            current_time - self._last_log_time < 0.5):
            return
        
        self._last_log_message = message
        self._last_log_time = current_time
        
        end_iter = self.console_buffer.get_end_iter()
        timestamp = datetime.now().strftime('%H:%M:%S')
        
        self.console_buffer.insert_with_tags_by_name(
            end_iter,
            f"[{timestamp}] ",
            'white'
        )
        
        end_iter = self.console_buffer.get_end_iter()
        self.console_buffer.insert_with_tags_by_name(
            end_iter,
            f"{message}\n",
            color
        )
        
        # Auto-scroll
        mark = self.console_buffer.get_insert()
        self.console.scroll_to_mark(mark, 0, False, 0, 0)
    
    # Toolbar callbacks
    def on_quick_scan(self, widget):
        """Quick network scan on all targets"""
        if self.targets:
            # Scan all targets with nmap in background
            targets_str = ' '.join(self.targets.keys())
            self.run_background_command(
                f"nmap -sV -sC --top-ports 100 {targets_str}",
                f"Quick scan: {len(self.targets)} targets"
            )
        else:
            self.log("No targets to scan. Add targets first.", 'yellow')
    
    def on_shodan_search(self, widget):
        """Open Shodan search dialog"""
        dialog = Gtk.Dialog(
            title="Shodan Search",
            parent=self,
            flags=0
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            "🔍 Search", Gtk.ResponseType.OK
        )
        dialog.set_default_size(400, 150)
        
        content = dialog.get_content_area()
        content.set_margin_start(10)
        content.set_margin_end(10)
        
        # Search query
        query_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        query_label = Gtk.Label(label="Query:")
        query_entry = Gtk.Entry()
        query_entry.set_placeholder_text("e.g., apache port:80 country:US")
        query_entry.set_width_chars(40)
        query_box.pack_start(query_label, False, False, 0)
        query_box.pack_start(query_entry, True, True, 0)
        content.pack_start(query_box, False, False, 10)
        
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            query = query_entry.get_text().strip()
            if query:
                self.run_background_command(
                    f"shodan search --fields ip_str,port,org '{query}' --limit 20",
                    f"Shodan: {query}"
                )
        
        dialog.destroy()
    
    def on_import_targets(self, widget):
        """Import targets from file"""
        dialog = Gtk.FileChooserDialog(
            title="Import Targets",
            parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            filename = dialog.get_filename()
            try:
                with open(filename) as f:
                    for line in f:
                        ip = line.strip()
                        if ip and not ip.startswith('#'):
                            self.add_target(ip)
                self.log(f"Imported targets from {filename}", 'green')
            except Exception as e:
                self.log(f"Import error: {e}", 'red')
        
        dialog.destroy()
    
    def on_export_targets(self, widget):
        """Export targets to file"""
        dialog = Gtk.FileChooserDialog(
            title="Export Targets",
            parent=self,
            action=Gtk.FileChooserAction.SAVE
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE, Gtk.ResponseType.OK
        )
        dialog.set_current_name("targets.json")
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            filename = dialog.get_filename()
            try:
                data = [t.to_dict() for t in self.targets.values()]
                with open(filename, 'w') as f:
                    json.dump(data, f, indent=2, default=str)
                self.log(f"Exported {len(data)} targets to {filename}", 'green')
            except Exception as e:
                self.log(f"Export error: {e}", 'red')
        
        dialog.destroy()
    
    def on_ai_console(self, widget):
        """Open NULLSEC AI Console dialog"""
        dialog = Gtk.Dialog(
            title="☠ NULLSEC Framework CLI - AI Console",
            parent=self,
            flags=0
        )
        dialog.add_buttons(
            "Close", Gtk.ResponseType.CLOSE
        )
        dialog.set_default_size(900, 700)
        
        content = dialog.get_content_area()
        
        # Create VTE terminal for AI console
        vte_terminal = Vte.Terminal()
        vte_terminal.set_color_background(Gdk.RGBA(0.04, 0.04, 0.04, 1.0))
        vte_terminal.set_color_foreground(Gdk.RGBA(0.9, 0.9, 0.9, 1.0))
        vte_terminal.set_font(Pango.FontDescription("monospace 11"))
        vte_terminal.set_scrollback_lines(10000)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.add(vte_terminal)
        content.pack_start(scroll, True, True, 0)
        
        # Get target if selected
        target_arg = ""
        if self.targets:
            # Get first target or selected target
            target_arg = f"target {list(self.targets.keys())[0]}"
        
        # Launch AI console in terminal
        ai_script = str(NULLSEC_DIR / 'nullsec-ai.py')
        if os.path.exists(ai_script):
            vte_terminal.spawn_sync(
                Vte.PtyFlags.DEFAULT,
                str(NULLSEC_DIR),
                [sys.executable, ai_script],
                [],
                GLib.SpawnFlags.DEFAULT,
                None, None
            )
        else:
            self.log("AI console not found", 'red')
            dialog.destroy()
            return
        
        dialog.show_all()
        dialog.run()
        dialog.destroy()
    
    def ai_execute_module(self, module_name, module_category, target=None):
        """Execute a module with AI assistance"""
        self.log(f"[AI] Executing {module_name} with AI assistance...", 'cyan')
        
        # Run AI-powered execution in background
        def run_ai():
            try:
                ai_script = str(NULLSEC_DIR / 'nullsec-ai.py')
                target_arg = f"--target {target}" if target else ""
                cmd = f"{sys.executable} {ai_script} attack '{module_name}' {target_arg}"
                
                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=120,
                    cwd=str(NULLSEC_DIR)
                )
                
                GLib.idle_add(self.log, f"[AI] {module_name} completed", 'green')
                if result.stdout:
                    for line in result.stdout.split('\n')[:20]:
                        if line.strip():
                            GLib.idle_add(self.log, f"  {line}", 'white')
                            
            except subprocess.TimeoutExpired:
                GLib.idle_add(self.log, f"[AI] {module_name} timed out", 'yellow')
            except Exception as e:
                GLib.idle_add(self.log, f"[AI] Error: {e}", 'red')
        
        thread = threading.Thread(target=run_ai, daemon=True)
        thread.start()

    def on_ai_pentester(self, widget):
        """Open NULLSEC AI Pentester dialog"""
        dialog = Gtk.Dialog(
            title="☠ NULLSEC AI Pentester",
            parent=self,
            flags=0
        )
        dialog.add_buttons(
            "Cancel", Gtk.ResponseType.CANCEL,
            "☠ Start Pentest", Gtk.ResponseType.OK
        )
        dialog.set_default_size(600, 400)
        
        content = dialog.get_content_area()
        content.set_margin_start(15)
        content.set_margin_end(15)
        content.set_margin_top(10)
        
        # Title
        title_label = Gtk.Label()
        title_label.set_markup(
            '<span size="large" weight="bold" foreground="#cc0000">☠ NULLSEC AI Pentester ☠</span>\n'
            '<span foreground="#888888">Fully Autonomous Offensive Security AI</span>'
        )
        title_label.set_justify(Gtk.Justification.CENTER)
        content.pack_start(title_label, False, False, 10)
        
        # Form grid
        grid = Gtk.Grid()
        grid.set_row_spacing(10)
        grid.set_column_spacing(10)
        content.pack_start(grid, True, True, 10)
        
        # Target URL
        url_label = Gtk.Label(label="Target URL:")
        url_label.set_halign(Gtk.Align.END)
        grid.attach(url_label, 0, 0, 1, 1)
        
        url_entry = Gtk.Entry()
        url_entry.set_placeholder_text("https://target.com")
        url_entry.set_hexpand(True)
        # Pre-fill with first target if available
        if self.targets:
            first_ip = list(self.targets.keys())[0]
            url_entry.set_text(f"http://{first_ip}")
        grid.attach(url_entry, 1, 0, 1, 1)
        
        # Repository path
        repo_label = Gtk.Label(label="Repository Path:")
        repo_label.set_halign(Gtk.Align.END)
        grid.attach(repo_label, 0, 1, 1, 1)
        
        repo_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        repo_entry = Gtk.Entry()
        repo_entry.set_placeholder_text("/path/to/target/repo")
        repo_entry.set_hexpand(True)
        repo_box.pack_start(repo_entry, True, True, 0)
        
        browse_btn = Gtk.Button(label="Browse")
        def on_browse(btn):
            fc = Gtk.FileChooserDialog(
                title="Select Repository",
                parent=dialog,
                action=Gtk.FileChooserAction.SELECT_FOLDER
            )
            fc.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
            if fc.run() == Gtk.ResponseType.OK:
                repo_entry.set_text(fc.get_filename())
            fc.destroy()
        browse_btn.connect('clicked', on_browse)
        repo_box.pack_start(browse_btn, False, False, 0)
        grid.attach(repo_box, 1, 1, 1, 1)
        
        # Vulnerability type
        vuln_label = Gtk.Label(label="Vulnerability Focus:")
        vuln_label.set_halign(Gtk.Align.END)
        grid.attach(vuln_label, 0, 2, 1, 1)
        
        vuln_combo = Gtk.ComboBoxText()
        vuln_combo.append('all', 'All Vulnerabilities')
        vuln_combo.append('injection', 'Injection (SQL, Command, Code)')
        vuln_combo.append('xss', 'Cross-Site Scripting (XSS)')
        vuln_combo.append('auth', 'Authentication Bypass')
        vuln_combo.append('ssrf', 'Server-Side Request Forgery')
        vuln_combo.append('authz', 'Authorization Flaws')
        vuln_combo.set_active(0)
        grid.attach(vuln_combo, 1, 2, 1, 1)
        
        # Warning
        warning_label = Gtk.Label()
        warning_label.set_markup(
            '<span foreground="#ff6600">⚠️ WARNING: This tool actively exploits vulnerabilities!</span>\n'
            '<span foreground="#888888">Only test systems you own or have permission to test.</span>'
        )
        warning_label.set_justify(Gtk.Justification.CENTER)
        content.pack_start(warning_label, False, False, 10)
        
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            target_url = url_entry.get_text().strip()
            repo_path = repo_entry.get_text().strip()
            vuln_type = vuln_combo.get_active_id()
            
            if target_url and repo_path:
                dialog.destroy()
                self.launch_ai_pentester(target_url, repo_path, vuln_type)
            else:
                self.log("Error: Both URL and repository path are required", 'red')
                dialog.destroy()
        else:
            dialog.destroy()
    
    def launch_ai_pentester(self, target_url, repo_path, vuln_type='all'):
        """Launch the AI pentester in a terminal dialog"""
        self.log(f"[☠] Launching AI Pentester on {target_url}...", 'cyan')
        
        dialog = Gtk.Dialog(
            title="☠ NULLSEC AI Pentester - Running",
            parent=self,
            flags=0
        )
        dialog.add_buttons("Close", Gtk.ResponseType.CLOSE)
        dialog.set_default_size(1000, 700)
        
        content = dialog.get_content_area()
        
        # Create VTE terminal
        vte_terminal = Vte.Terminal()
        vte_terminal.set_color_background(Gdk.RGBA(0.04, 0.04, 0.04, 1.0))
        vte_terminal.set_color_foreground(Gdk.RGBA(0.9, 0.1, 0.1, 1.0))
        vte_terminal.set_font(Pango.FontDescription("monospace 10"))
        vte_terminal.set_scrollback_lines(10000)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.add(vte_terminal)
        content.pack_start(scroll, True, True, 0)
        
        # Build command
        pentester_script = str(NULLSEC_DIR / 'nullsec-pentester' / 'nullsec-pentester.sh')
        vuln_arg = f"--vuln {vuln_type}" if vuln_type != 'all' else ""
        
        # Spawn pentester in terminal
        vte_terminal.spawn_sync(
            Vte.PtyFlags.DEFAULT,
            str(NULLSEC_DIR),
            ["/bin/bash", pentester_script, target_url, repo_path] + (["--vuln", vuln_type] if vuln_type != 'all' else []),
            [],
            GLib.SpawnFlags.DEFAULT,
            None, None
        )
        
        dialog.show_all()
        dialog.run()
        dialog.destroy()
        
        self.log("[☠] AI Pentester session closed", 'green')

    def on_flipper_zero(self, widget):
        """Open Flipper Zero control panel"""
        self.log("[🐬] Opening Flipper Zero Control Panel...", 'cyan')
        
        dialog = Gtk.Dialog(
            title="🐬 NULLSEC Flipper Zero Control",
            parent=self,
            flags=0
        )
        dialog.add_buttons("Close", Gtk.ResponseType.CLOSE)
        dialog.set_default_size(1100, 750)
        
        content = dialog.get_content_area()
        
        # Create VTE terminal for Flipper CLI
        vte_terminal = Vte.Terminal()
        vte_terminal.set_color_background(Gdk.RGBA(0.04, 0.04, 0.06, 1.0))
        vte_terminal.set_color_foreground(Gdk.RGBA(0.0, 0.9, 0.9, 1.0))
        vte_terminal.set_font(Pango.FontDescription("monospace 10"))
        vte_terminal.set_scrollback_lines(10000)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.add(vte_terminal)
        content.pack_start(scroll, True, True, 0)
        
        # Launch Flipper CLI
        flipper_script = str(NULLSEC_DIR / 'nullsec-flipper' / 'flipper_zero.py')
        
        vte_terminal.spawn_sync(
            Vte.PtyFlags.DEFAULT,
            str(NULLSEC_DIR),
            ["/usr/bin/python3", flipper_script],
            [],
            GLib.SpawnFlags.DEFAULT,
            None, None
        )
        
        dialog.show_all()
        dialog.run()
        dialog.destroy()
        
        self.log("[🐬] Flipper Zero panel closed", 'green')

    def on_pineapple(self, widget):
        """Open WiFi Pineapple control panel"""
        self.log("[🍍] Opening WiFi Pineapple Control Panel...", 'cyan')
        
        dialog = Gtk.Dialog(
            title="🍍 NULLSEC WiFi Pineapple Control",
            parent=self,
            flags=0
        )
        dialog.add_buttons("Close", Gtk.ResponseType.CLOSE)
        dialog.set_default_size(1100, 750)
        
        content = dialog.get_content_area()
        
        # Create VTE terminal for Pineapple CLI
        vte_terminal = Vte.Terminal()
        vte_terminal.set_color_background(Gdk.RGBA(0.02, 0.06, 0.02, 1.0))
        vte_terminal.set_color_foreground(Gdk.RGBA(0.0, 0.9, 0.3, 1.0))
        vte_terminal.set_font(Pango.FontDescription("monospace 10"))
        vte_terminal.set_scrollback_lines(10000)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.add(vte_terminal)
        content.pack_start(scroll, True, True, 0)
        
        # Launch Pineapple CLI
        pineapple_script = str(NULLSEC_DIR / 'nullsec-pineapple' / 'pineapple_control.py')
        
        vte_terminal.spawn_sync(
            Vte.PtyFlags.DEFAULT,
            str(NULLSEC_DIR),
            ["/usr/bin/python3", pineapple_script],
            [],
            GLib.SpawnFlags.DEFAULT,
            None, None
        )
        
        dialog.show_all()
        dialog.run()
        dialog.destroy()
        
        self.log("[🍍] Pineapple panel closed", 'green')

    def on_settings(self, widget):
        """Open settings dialog"""
        dialog = Gtk.Dialog(
            title="NULLSEC Settings",
            parent=self,
            flags=0
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE, Gtk.ResponseType.OK
        )
        dialog.set_default_size(500, 400)
        
        content = dialog.get_content_area()
        content.set_margin_start(15)
        content.set_margin_end(15)
        content.set_margin_top(10)
        
        # Settings notebook
        notebook = Gtk.Notebook()
        
        # General settings
        general_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        general_box.set_margin_top(10)
        
        # Terminal setting
        term_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        term_label = Gtk.Label(label="External Terminal:")
        term_entry = Gtk.Entry()
        term_entry.set_text("x-terminal-emulator")
        term_box.pack_start(term_label, False, False, 0)
        term_box.pack_start(term_entry, True, True, 0)
        general_box.pack_start(term_box, False, False, 0)
        
        # Auto-scan setting
        auto_scan = Gtk.CheckButton(label="Auto-scan targets on add")
        general_box.pack_start(auto_scan, False, False, 0)
        
        notebook.append_page(general_box, Gtk.Label(label="General"))
        
        # Shodan settings
        shodan_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        shodan_box.set_margin_top(10)
        
        api_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        api_label = Gtk.Label(label="Shodan API Key:")
        api_entry = Gtk.Entry()
        api_entry.set_placeholder_text("Enter your Shodan API key")
        api_entry.set_visibility(False)
        api_box.pack_start(api_label, False, False, 0)
        api_box.pack_start(api_entry, True, True, 0)
        shodan_box.pack_start(api_box, False, False, 0)
        
        notebook.append_page(shodan_box, Gtk.Label(label="Shodan"))
        
        # About
        about_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        about_box.set_margin_top(20)
        about_label = Gtk.Label()
        about_label.set_markup(
            '<span size="large" weight="bold">NULLSEC Desktop v1.0</span>\n\n'
            '<span>Armitage-style Attack Framework GUI</span>\n\n'
            '<span foreground="#cc0000">[ bad-antics development ]</span>\n\n'
            f'<span>Modules: {sum(len(m) for m in self.modules.values())}</span>\n'
            f'<span>Targets: {len(self.targets)}</span>'
        )
        about_label.set_justify(Gtk.Justification.CENTER)
        about_box.pack_start(about_label, True, True, 0)
        notebook.append_page(about_box, Gtk.Label(label="About"))
        
        content.pack_start(notebook, True, True, 0)
        
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            self.log("Settings saved", 'green')
        
        dialog.destroy()


def main():
    """Main entry point"""
    # Set app icon
    try:
        icon_path = NULLSEC_DIR / 'static' / 'skull.png'
        if icon_path.exists():
            Gtk.Window.set_default_icon_from_file(str(icon_path))
    except:
        pass
    
    # Create and run app
    win = NullsecDesktop()
    win.show_all()
    
    # Print startup message
    win.log("╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸", 'red')
    win.log("  NULLSEC Desktop v1.0 - bad-antics development", 'white')
    win.log("╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸", 'red')
    win.log("Ready. Add targets and launch attacks.", 'green')
    win.log(f"Loaded {sum(len(m) for m in win.modules.values())} attack modules", 'cyan')
    win.log("Type 'help' in Terminal tab for CLI commands.", 'cyan')
    
    Gtk.main()


if __name__ == '__main__':
    main()
