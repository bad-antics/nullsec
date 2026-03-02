#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    NullSec Mesh Monitor v1.0                                ║
║           Real-time Cluster & Mesh Network Dashboard                        ║
║                     Author: bad-antics                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

Desktop application for monitoring the NullSec mesh cluster.
Shows real-time stats for all nodes: CPU, RAM, disk, GPU, network, services.
"""

import tkinter as tk
from tkinter import ttk, font as tkfont
import subprocess
import threading
import time
import os
import json
import socket
import re
from datetime import datetime, timedelta
from collections import deque

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

NODES_CONF = os.path.expanduser("~/.nullsec/cluster/nodes.conf")
REFRESH_INTERVAL = 5000  # ms between full refreshes
SSH_TIMEOUT = 4  # seconds

# Color scheme - dark hacker theme
COLORS = {
    "bg_dark": "#0a0a0f",
    "bg_panel": "#111118",
    "bg_card": "#1a1a25",
    "bg_card_hover": "#222233",
    "border": "#2a2a3a",
    "border_accent": "#00ff88",
    "text": "#c8c8d8",
    "text_dim": "#666680",
    "text_bright": "#ffffff",
    "green": "#00ff88",
    "green_dim": "#00aa55",
    "red": "#ff3355",
    "red_dim": "#aa2233",
    "yellow": "#ffaa00",
    "yellow_dim": "#aa7700",
    "cyan": "#00ccff",
    "cyan_dim": "#0088aa",
    "purple": "#aa55ff",
    "blue": "#4488ff",
    "orange": "#ff6633",
    "bar_bg": "#1a1a2a",
    "bar_good": "#00ff88",
    "bar_warn": "#ffaa00",
    "bar_crit": "#ff3355",
}

# ═══════════════════════════════════════════════════════════════════════════════
# Node Configuration Loader
# ═══════════════════════════════════════════════════════════════════════════════

def load_nodes():
    """Load cluster nodes from nodes.conf"""
    nodes = []
    
    # Always include local machine
    local = {
        "hostname": socket.gethostname(),
        "ip": "127.0.0.1",
        "user": os.environ.get("USER", "antics"),
        "port": 22,
        "os": "linux",
        "arch": "x86_64",
        "cores": os.cpu_count() or 1,
        "ram_mb": 0,
        "gpu": "none",
        "role": "controller",
        "tags": "local",
        "is_local": True,
    }
    
    if not os.path.exists(NODES_CONF):
        nodes.append(local)
        return nodes
    
    seen_ips = set()
    with open(NODES_CONF) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) < 8:
                continue
            ip = parts[1].strip()
            node = {
                "hostname": parts[0].strip(),
                "ip": ip,
                "user": parts[2].strip(),
                "port": int(parts[3].strip()) if parts[3].strip().isdigit() else 22,
                "os": parts[4].strip() if len(parts) > 4 else "unknown",
                "arch": parts[5].strip() if len(parts) > 5 else "unknown",
                "cores": int(parts[6].strip()) if len(parts) > 6 and parts[6].strip().isdigit() else 0,
                "ram_mb": int(parts[7].strip()) if len(parts) > 7 and parts[7].strip().isdigit() else 0,
                "gpu": parts[8].strip() if len(parts) > 8 else "none",
                "role": parts[9].strip() if len(parts) > 9 else "worker",
                "tags": parts[10].strip() if len(parts) > 10 else "",
                "is_local": ip in ("127.0.0.1", "localhost", "::1"),
            }
            seen_ips.add(ip)
            nodes.append(node)
    
    # Add doomsday-linux if not in conf
    if "192.168.40.141" not in seen_ips:
        nodes.append({
            "hostname": "doomsday-linux",
            "ip": "192.168.40.141",
            "user": "antx",
            "port": 22,
            "os": "linux",
            "arch": "x86_64",
            "cores": 2,
            "ram_mb": 3840,
            "gpu": "none",
            "role": "worker",
            "tags": "linux,x86_64,ssh",
            "is_local": False,
        })
    
    return nodes


# ═══════════════════════════════════════════════════════════════════════════════
# System Stats Collection
# ═══════════════════════════════════════════════════════════════════════════════

def get_local_stats():
    """Get stats for the local machine using psutil"""
    try:
        import psutil
        cpu_pct = psutil.cpu_percent(interval=0.3)
        mem = psutil.virtual_memory()
        disk = psutil.disk_usage("/")
        net = psutil.net_io_counters()
        temps = {}
        try:
            t = psutil.sensors_temperatures()
            for chip, entries in t.items():
                for e in entries:
                    if e.current > 0:
                        temps[e.label or chip] = e.current
        except Exception:
            pass
        
        load1, load5, load15 = os.getloadavg()
        uptime_s = time.time() - psutil.boot_time()
        
        return {
            "status": "online",
            "cpu_pct": cpu_pct,
            "cpu_cores": psutil.cpu_count(),
            "load_1": load1,
            "load_5": load5,
            "load_15": load15,
            "ram_total_mb": mem.total // (1024 * 1024),
            "ram_used_mb": mem.used // (1024 * 1024),
            "ram_pct": mem.percent,
            "disk_total_gb": disk.total / (1024**3),
            "disk_used_gb": disk.used / (1024**3),
            "disk_pct": disk.percent,
            "net_sent_mb": net.bytes_sent / (1024**2),
            "net_recv_mb": net.bytes_recv / (1024**2),
            "temps": temps,
            "uptime_s": uptime_s,
            "procs": len(psutil.pids()),
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def ssh_cmd(user, ip, port, cmd):
    """Run a command over SSH with timeout"""
    try:
        result = subprocess.run(
            ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3",
             "-o", "BatchMode=yes", "-p", str(port), f"{user}@{ip}", cmd],
            capture_output=True, text=True, timeout=SSH_TIMEOUT
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception:
        return None


def get_linux_stats(user, ip, port):
    """Get stats from a remote Linux machine via SSH"""
    # One compound command to minimize SSH connections
    cmd = (
        "echo CPU:$(grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; printf \"%.1f\", u/t*100}');"
        "echo CORES:$(nproc);"
        "echo LOAD:$(cat /proc/loadavg | cut -d' ' -f1-3);"
        "echo MEM:$(free -m | awk '/Mem/{printf \"%d %d %.1f\",$2,$3,$3/$2*100}');"
        "echo DISK:$(df -BG / | awk 'NR==2{gsub(/G/,\"\"); printf \"%d %d %.1f\",$2,$3,$5}');"
        "echo NET:$(cat /proc/net/dev | awk '/eth0:|ens|wlan|enp/{gsub(/:/,\"\"); printf \"%d %d\",$2,$10}' | head -1);"
        "echo UP:$(awk '{print int($1)}' /proc/uptime);"
        "echo PROCS:$(ls -d /proc/[0-9]* 2>/dev/null | wc -l);"
        "echo TEMP:$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)"
    )
    out = ssh_cmd(user, ip, port, cmd)
    if not out:
        return {"status": "offline"}
    
    stats = {"status": "online"}
    for line in out.split("\n"):
        if line.startswith("CPU:"):
            try: stats["cpu_pct"] = float(line.split(":")[1])
            except: stats["cpu_pct"] = 0
        elif line.startswith("CORES:"):
            try: stats["cpu_cores"] = int(line.split(":")[1])
            except: stats["cpu_cores"] = 0
        elif line.startswith("LOAD:"):
            parts = line.split(":")[1].split()
            try:
                stats["load_1"] = float(parts[0])
                stats["load_5"] = float(parts[1])
                stats["load_15"] = float(parts[2])
            except: pass
        elif line.startswith("MEM:"):
            parts = line.split(":")[1].split()
            try:
                stats["ram_total_mb"] = int(parts[0])
                stats["ram_used_mb"] = int(parts[1])
                stats["ram_pct"] = float(parts[2])
            except: pass
        elif line.startswith("DISK:"):
            parts = line.split(":")[1].split()
            try:
                stats["disk_total_gb"] = float(parts[0])
                stats["disk_used_gb"] = float(parts[1])
                stats["disk_pct"] = float(parts[2])
            except: pass
        elif line.startswith("NET:"):
            parts = line.split(":")[1].split()
            try:
                stats["net_recv_mb"] = int(parts[0]) / (1024**2)
                stats["net_sent_mb"] = int(parts[1]) / (1024**2)
            except: pass
        elif line.startswith("UP:"):
            try: stats["uptime_s"] = int(line.split(":")[1])
            except: pass
        elif line.startswith("PROCS:"):
            try: stats["procs"] = int(line.split(":")[1])
            except: pass
        elif line.startswith("TEMP:"):
            try:
                t = int(line.split(":")[1])
                if t > 1000: t = t / 1000
                stats["temps"] = {"CPU": t} if t > 0 else {}
            except:
                stats["temps"] = {}
    return stats


def get_windows_stats(user, ip, port):
    """Get stats from a remote Windows machine via SSH"""
    cmd = (
        'powershell -Command "'
        '$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average;'
        '$os = Get-CimInstance Win32_OperatingSystem;'
        '$tm = [math]::Round($os.TotalVisibleMemorySize/1024);'
        '$fm = [math]::Round($os.FreePhysicalMemory/1024);'
        '$disk = Get-CimInstance Win32_LogicalDisk -Filter \\\"DriveType=3\\\" | Select-Object -First 1;'
        '$dt = [math]::Round($disk.Size/1GB);'
        '$df = [math]::Round($disk.FreeSpace/1GB);'
        '$up = (Get-Date) - $os.LastBootUpTime;'
        '$procs = (Get-Process).Count;'
        'Write-Output \\\"CPU:$cpu\\\";'
        'Write-Output \\\"MEM:$tm $($tm-$fm) $([math]::Round(($tm-$fm)/$tm*100,1))\\\";'
        'Write-Output \\\"DISK:$dt $($dt-$df) $([math]::Round(($dt-$df)/$dt*100,1))\\\";'
        'Write-Output \\\"UP:$([int]$up.TotalSeconds)\\\";'
        'Write-Output \\\"PROCS:$procs\\\""'
    )
    out = ssh_cmd(user, ip, port, cmd)
    if not out:
        return {"status": "offline"}
    
    stats = {"status": "online", "temps": {}}
    for line in out.split("\n"):
        line = line.strip()
        if line.startswith("CPU:"):
            try: stats["cpu_pct"] = float(line.split(":")[1])
            except: stats["cpu_pct"] = 0
        elif line.startswith("MEM:"):
            parts = line.split(":")[1].split()
            try:
                stats["ram_total_mb"] = int(parts[0])
                stats["ram_used_mb"] = int(parts[1])
                stats["ram_pct"] = float(parts[2])
            except: pass
        elif line.startswith("DISK:"):
            parts = line.split(":")[1].split()
            try:
                stats["disk_total_gb"] = float(parts[0])
                stats["disk_used_gb"] = float(parts[1])
                stats["disk_pct"] = float(parts[2])
            except: pass
        elif line.startswith("UP:"):
            try: stats["uptime_s"] = int(line.split(":")[1])
            except: pass
        elif line.startswith("PROCS:"):
            try: stats["procs"] = int(line.split(":")[1])
            except: pass
    return stats


# ═══════════════════════════════════════════════════════════════════════════════
# GUI Application
# ═══════════════════════════════════════════════════════════════════════════════

class MeshMonitor(tk.Tk):
    def __init__(self):
        super().__init__()
        
        self.title("NullSec Mesh Monitor")
        self.configure(bg=COLORS["bg_dark"])
        self.geometry("1400x900")
        self.minsize(1000, 600)
        
        # Try to set a custom icon
        try:
            icon_path = os.path.expanduser("~/nullsec/static/nullsec-icon.png")
            if os.path.exists(icon_path):
                icon = tk.PhotoImage(file=icon_path)
                self.iconphoto(True, icon)
        except Exception:
            pass
        
        # Node data
        self.nodes = load_nodes()
        self.node_stats = {}
        self.node_history = {}  # CPU history for sparklines
        self.cluster_totals = {}
        self.is_refreshing = False
        self.last_refresh = None
        
        # Fonts
        self.title_font = tkfont.Font(family="JetBrains Mono", size=14, weight="bold")
        self.header_font = tkfont.Font(family="JetBrains Mono", size=11, weight="bold")
        self.mono_font = tkfont.Font(family="JetBrains Mono", size=10)
        self.small_font = tkfont.Font(family="JetBrains Mono", size=8)
        self.big_font = tkfont.Font(family="JetBrains Mono", size=22, weight="bold")
        
        self._build_ui()
        self._refresh_loop()
    
    def _build_ui(self):
        """Build the main UI layout"""
        # ── Top Bar ──
        top = tk.Frame(self, bg=COLORS["bg_panel"], height=60)
        top.pack(fill="x", padx=0, pady=0)
        top.pack_propagate(False)
        
        # Logo / Title
        logo_frame = tk.Frame(top, bg=COLORS["bg_panel"])
        logo_frame.pack(side="left", padx=15, pady=8)
        
        tk.Label(logo_frame, text="⬡", font=("", 24), fg=COLORS["green"],
                 bg=COLORS["bg_panel"]).pack(side="left", padx=(0, 8))
        tk.Label(logo_frame, text="NullSec Mesh Monitor", font=self.title_font,
                 fg=COLORS["text_bright"], bg=COLORS["bg_panel"]).pack(side="left")
        tk.Label(logo_frame, text="v1.0", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_panel"]).pack(side="left", padx=(8, 0))
        
        # Status indicators in top bar
        self.status_frame = tk.Frame(top, bg=COLORS["bg_panel"])
        self.status_frame.pack(side="right", padx=15, pady=8)
        
        self.lbl_time = tk.Label(self.status_frame, text="", font=self.small_font,
                                  fg=COLORS["text_dim"], bg=COLORS["bg_panel"])
        self.lbl_time.pack(side="right", padx=(10, 0))
        
        self.lbl_status = tk.Label(self.status_frame, text="● INITIALIZING",
                                    font=self.mono_font, fg=COLORS["yellow"],
                                    bg=COLORS["bg_panel"])
        self.lbl_status.pack(side="right")
        
        # Accent line
        tk.Frame(self, bg=COLORS["border_accent"], height=2).pack(fill="x")
        
        # ── Cluster Summary Bar ──
        summary = tk.Frame(self, bg=COLORS["bg_panel"], height=80)
        summary.pack(fill="x", padx=0, pady=(0, 1))
        summary.pack_propagate(False)
        
        self.summary_widgets = {}
        summary_items = [
            ("nodes", "NODES", "0/0", COLORS["cyan"]),
            ("cores", "CORES", "0", COLORS["green"]),
            ("ram", "RAM", "0 GB", COLORS["purple"]),
            ("disk", "DISK", "0 TB", COLORS["blue"]),
            ("gpu", "GPUs", "0", COLORS["orange"]),
            ("procs", "PROCS", "0", COLORS["yellow"]),
            ("net_up", "NET ↑", "0 MB", COLORS["cyan"]),
            ("net_down", "NET ↓", "0 MB", COLORS["green"]),
        ]
        
        for key, label, default, color in summary_items:
            frame = tk.Frame(summary, bg=COLORS["bg_panel"])
            frame.pack(side="left", expand=True, fill="both", padx=8, pady=8)
            
            tk.Label(frame, text=label, font=self.small_font,
                     fg=COLORS["text_dim"], bg=COLORS["bg_panel"]).pack(anchor="w")
            val_lbl = tk.Label(frame, text=default, font=self.header_font,
                               fg=color, bg=COLORS["bg_panel"])
            val_lbl.pack(anchor="w")
            self.summary_widgets[key] = val_lbl
        
        # Separator
        tk.Frame(self, bg=COLORS["border"], height=1).pack(fill="x")
        
        # ── Main Content Area ──
        main = tk.Frame(self, bg=COLORS["bg_dark"])
        main.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Scrollable node grid
        canvas = tk.Canvas(main, bg=COLORS["bg_dark"], highlightthickness=0)
        scrollbar = tk.Scrollbar(main, orient="vertical", command=canvas.yview)
        self.scroll_frame = tk.Frame(canvas, bg=COLORS["bg_dark"])
        
        self.scroll_frame.bind("<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        
        canvas.create_window((0, 0), window=self.scroll_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Bind mousewheel
        canvas.bind_all("<MouseWheel>", lambda e: canvas.yview_scroll(-1*(e.delta//120), "units"))
        canvas.bind_all("<Button-4>", lambda e: canvas.yview_scroll(-1, "units"))
        canvas.bind_all("<Button-5>", lambda e: canvas.yview_scroll(1, "units"))
        
        self.canvas = canvas
        self.node_widgets = {}
        
        self._build_node_cards()
    
    def _build_node_cards(self):
        """Create a card for each node"""
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()
        
        self.node_widgets = {}
        
        # Calculate grid columns based on window width
        cols = 3
        
        for idx, node in enumerate(self.nodes):
            row = idx // cols
            col = idx % cols
            
            card = self._create_node_card(self.scroll_frame, node)
            card.grid(row=row, column=col, padx=5, pady=5, sticky="nsew")
            self.scroll_frame.columnconfigure(col, weight=1)
        
        # Make sure all rows expand
        for r in range((len(self.nodes) + cols - 1) // cols):
            self.scroll_frame.rowconfigure(r, weight=0)
    
    def _create_node_card(self, parent, node):
        """Create a single node monitoring card"""
        hostname = node["hostname"]
        
        card = tk.Frame(parent, bg=COLORS["bg_card"], relief="flat",
                        highlightbackground=COLORS["border"], highlightthickness=1)
        
        widgets = {}
        
        # ── Card Header ──
        header = tk.Frame(card, bg=COLORS["bg_card"])
        header.pack(fill="x", padx=10, pady=(8, 4))
        
        # Status dot + hostname
        widgets["status_dot"] = tk.Label(header, text="●", font=("", 12),
                                          fg=COLORS["text_dim"], bg=COLORS["bg_card"])
        widgets["status_dot"].pack(side="left")
        
        tk.Label(header, text=hostname, font=self.header_font,
                 fg=COLORS["text_bright"], bg=COLORS["bg_card"]).pack(side="left", padx=(5, 0))
        
        # Role badge
        role_color = {
            "controller": COLORS["green"],
            "worker": COLORS["blue"],
            "gpu-worker": COLORS["orange"],
            "arm-worker": COLORS["purple"],
        }.get(node["role"], COLORS["text_dim"])
        
        tk.Label(header, text=node["role"].upper(), font=self.small_font,
                 fg=role_color, bg=COLORS["bg_card"]).pack(side="right")
        
        # IP + OS
        info_frame = tk.Frame(card, bg=COLORS["bg_card"])
        info_frame.pack(fill="x", padx=10, pady=(0, 4))
        
        tk.Label(info_frame, text=f"{node['ip']}:{node['port']}", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_card"]).pack(side="left")
        
        os_icon = {"linux": "🐧", "debian": "🐧", "windows": "🪟"}.get(node["os"], "💻")
        tk.Label(info_frame, text=f"{os_icon} {node['os']}/{node['arch']}",
                 font=self.small_font, fg=COLORS["text_dim"],
                 bg=COLORS["bg_card"]).pack(side="right")
        
        # Separator
        tk.Frame(card, bg=COLORS["border"], height=1).pack(fill="x", padx=8)
        
        # ── CPU Section ──
        cpu_frame = tk.Frame(card, bg=COLORS["bg_card"])
        cpu_frame.pack(fill="x", padx=10, pady=(6, 2))
        
        tk.Label(cpu_frame, text="CPU", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_card"]).pack(side="left")
        widgets["cpu_val"] = tk.Label(cpu_frame, text="---%", font=self.mono_font,
                                       fg=COLORS["text"], bg=COLORS["bg_card"])
        widgets["cpu_val"].pack(side="right")
        
        widgets["cpu_bar"] = self._create_bar(card)
        
        # Load avg
        load_frame = tk.Frame(card, bg=COLORS["bg_card"])
        load_frame.pack(fill="x", padx=10, pady=(2, 2))
        tk.Label(load_frame, text="LOAD", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_card"]).pack(side="left")
        widgets["load_val"] = tk.Label(load_frame, text="--- --- ---", font=self.small_font,
                                        fg=COLORS["text_dim"], bg=COLORS["bg_card"])
        widgets["load_val"].pack(side="right")
        
        # ── RAM Section ──
        ram_frame = tk.Frame(card, bg=COLORS["bg_card"])
        ram_frame.pack(fill="x", padx=10, pady=(4, 2))
        
        tk.Label(ram_frame, text="RAM", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_card"]).pack(side="left")
        widgets["ram_val"] = tk.Label(ram_frame, text="--- / --- MB", font=self.mono_font,
                                       fg=COLORS["text"], bg=COLORS["bg_card"])
        widgets["ram_val"].pack(side="right")
        
        widgets["ram_bar"] = self._create_bar(card)
        
        # ── Disk Section ──
        disk_frame = tk.Frame(card, bg=COLORS["bg_card"])
        disk_frame.pack(fill="x", padx=10, pady=(4, 2))
        
        tk.Label(disk_frame, text="DISK", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_card"]).pack(side="left")
        widgets["disk_val"] = tk.Label(disk_frame, text="--- / --- GB", font=self.mono_font,
                                        fg=COLORS["text"], bg=COLORS["bg_card"])
        widgets["disk_val"].pack(side="right")
        
        widgets["disk_bar"] = self._create_bar(card)
        
        # ── Network ──
        net_frame = tk.Frame(card, bg=COLORS["bg_card"])
        net_frame.pack(fill="x", padx=10, pady=(4, 2))
        
        tk.Label(net_frame, text="NET", font=self.small_font,
                 fg=COLORS["text_dim"], bg=COLORS["bg_card"]).pack(side="left")
        widgets["net_val"] = tk.Label(net_frame, text="↑--- ↓---", font=self.small_font,
                                       fg=COLORS["cyan_dim"], bg=COLORS["bg_card"])
        widgets["net_val"].pack(side="right")
        
        # ── GPU / Temp / Extras ──
        extra_frame = tk.Frame(card, bg=COLORS["bg_card"])
        extra_frame.pack(fill="x", padx=10, pady=(2, 2))
        
        if node["gpu"] and node["gpu"] != "none":
            gpu_short = node["gpu"][:20] + "…" if len(node["gpu"]) > 20 else node["gpu"]
            tk.Label(extra_frame, text=f"🎮 {gpu_short}", font=self.small_font,
                     fg=COLORS["orange"], bg=COLORS["bg_card"]).pack(side="left")
        
        widgets["temp_val"] = tk.Label(extra_frame, text="", font=self.small_font,
                                        fg=COLORS["yellow"], bg=COLORS["bg_card"])
        widgets["temp_val"].pack(side="right")
        
        # ── Bottom: uptime + procs ──
        bottom = tk.Frame(card, bg=COLORS["bg_card"])
        bottom.pack(fill="x", padx=10, pady=(4, 8))
        
        widgets["uptime_val"] = tk.Label(bottom, text="⏱ ---", font=self.small_font,
                                          fg=COLORS["text_dim"], bg=COLORS["bg_card"])
        widgets["uptime_val"].pack(side="left")
        
        widgets["procs_val"] = tk.Label(bottom, text="⚙ ---", font=self.small_font,
                                         fg=COLORS["text_dim"], bg=COLORS["bg_card"])
        widgets["procs_val"].pack(side="right")
        
        self.node_widgets[hostname] = {"card": card, "node": node, **widgets}
        return card
    
    def _create_bar(self, parent, width=200, height=8):
        """Create a progress bar canvas"""
        canvas = tk.Canvas(parent, width=width, height=height,
                           bg=COLORS["bar_bg"], highlightthickness=0)
        canvas.pack(fill="x", padx=10, pady=1)
        return canvas
    
    def _update_bar(self, canvas, pct, width=None):
        """Update a progress bar"""
        canvas.delete("all")
        if width is None:
            canvas.update_idletasks()
            width = canvas.winfo_width()
        if width < 10:
            width = 200
        
        h = 8
        # Background
        canvas.create_rectangle(0, 0, width, h, fill=COLORS["bar_bg"], outline="")
        
        # Determine color
        if pct < 60:
            color = COLORS["bar_good"]
        elif pct < 85:
            color = COLORS["bar_warn"]
        else:
            color = COLORS["bar_crit"]
        
        # Fill
        fill_w = max(1, int(width * min(pct, 100) / 100))
        canvas.create_rectangle(0, 0, fill_w, h, fill=color, outline="")
    
    def _format_uptime(self, seconds):
        """Format uptime seconds to human readable"""
        if not seconds or seconds < 0:
            return "---"
        d = int(seconds // 86400)
        h = int((seconds % 86400) // 3600)
        m = int((seconds % 3600) // 60)
        if d > 0:
            return f"{d}d {h}h {m}m"
        elif h > 0:
            return f"{h}h {m}m"
        else:
            return f"{m}m"
    
    def _format_bytes(self, mb):
        """Format MB to readable"""
        if mb >= 1024:
            return f"{mb/1024:.1f} GB"
        return f"{mb:.0f} MB"
    
    def _refresh_loop(self):
        """Main refresh loop - runs in background thread"""
        if not self.is_refreshing:
            self.is_refreshing = True
            self.lbl_status.config(text="● SCANNING", fg=COLORS["yellow"])
            thread = threading.Thread(target=self._collect_all_stats, daemon=True)
            thread.start()
        self.after(REFRESH_INTERVAL, self._refresh_loop)
    
    def _collect_all_stats(self):
        """Collect stats from all nodes (runs in thread)"""
        threads = []
        results = {}
        
        def collect_node(node):
            hostname = node["hostname"]
            try:
                if node["is_local"]:
                    stats = get_local_stats()
                elif node["os"] in ("linux", "debian"):
                    stats = get_linux_stats(node["user"], node["ip"], node["port"])
                elif node["os"] == "windows":
                    stats = get_windows_stats(node["user"], node["ip"], node["port"])
                else:
                    stats = get_linux_stats(node["user"], node["ip"], node["port"])
                results[hostname] = stats
            except Exception as e:
                results[hostname] = {"status": "error", "error": str(e)}
        
        for node in self.nodes:
            t = threading.Thread(target=collect_node, args=(node,), daemon=True)
            threads.append(t)
            t.start()
        
        for t in threads:
            t.join(timeout=SSH_TIMEOUT + 2)
        
        self.node_stats = results
        self.last_refresh = datetime.now()
        
        # Update UI from main thread
        self.after(0, self._update_ui)
    
    def _update_ui(self):
        """Update all UI elements with fresh data"""
        self.is_refreshing = False
        
        online_count = 0
        total_cores = 0
        total_ram_mb = 0
        total_disk_gb = 0
        total_procs = 0
        total_net_up = 0
        total_net_down = 0
        gpu_count = 0
        
        for hostname, w in self.node_widgets.items():
            node = w["node"]
            stats = self.node_stats.get(hostname, {"status": "offline"})
            
            is_online = stats.get("status") == "online"
            
            # Status dot
            if is_online:
                w["status_dot"].config(fg=COLORS["green"])
                w["card"].config(highlightbackground=COLORS["green_dim"])
                online_count += 1
            else:
                w["status_dot"].config(fg=COLORS["red"])
                w["card"].config(highlightbackground=COLORS["red_dim"])
                # Grey out the card
                w["cpu_val"].config(text="OFFLINE", fg=COLORS["red_dim"])
                w["ram_val"].config(text="---", fg=COLORS["text_dim"])
                w["disk_val"].config(text="---", fg=COLORS["text_dim"])
                w["net_val"].config(text="---", fg=COLORS["text_dim"])
                w["load_val"].config(text="---", fg=COLORS["text_dim"])
                w["uptime_val"].config(text="⏱ ---", fg=COLORS["text_dim"])
                w["procs_val"].config(text="⚙ ---", fg=COLORS["text_dim"])
                w["temp_val"].config(text="")
                self._update_bar(w["cpu_bar"], 0)
                self._update_bar(w["ram_bar"], 0)
                self._update_bar(w["disk_bar"], 0)
                continue
            
            # CPU
            cpu_pct = stats.get("cpu_pct", 0)
            cores = stats.get("cpu_cores", node.get("cores", 0))
            cpu_color = COLORS["green"] if cpu_pct < 60 else COLORS["yellow"] if cpu_pct < 85 else COLORS["red"]
            w["cpu_val"].config(text=f"{cpu_pct:.1f}% ({cores}c)", fg=cpu_color)
            self._update_bar(w["cpu_bar"], cpu_pct)
            total_cores += cores
            
            # Load
            l1 = stats.get("load_1", 0)
            l5 = stats.get("load_5", 0)
            l15 = stats.get("load_15", 0)
            load_color = COLORS["green"] if l1 < cores else COLORS["yellow"] if l1 < cores * 2 else COLORS["red"]
            w["load_val"].config(text=f"{l1:.2f} {l5:.2f} {l15:.2f}", fg=load_color)
            
            # RAM
            ram_total = stats.get("ram_total_mb", 0)
            ram_used = stats.get("ram_used_mb", 0)
            ram_pct = stats.get("ram_pct", 0)
            ram_color = COLORS["green"] if ram_pct < 70 else COLORS["yellow"] if ram_pct < 90 else COLORS["red"]
            w["ram_val"].config(
                text=f"{self._format_bytes(ram_used)} / {self._format_bytes(ram_total)}",
                fg=ram_color
            )
            self._update_bar(w["ram_bar"], ram_pct)
            total_ram_mb += ram_total
            
            # Disk
            disk_total = stats.get("disk_total_gb", 0)
            disk_used = stats.get("disk_used_gb", 0)
            disk_pct = stats.get("disk_pct", 0)
            disk_color = COLORS["green"] if disk_pct < 70 else COLORS["yellow"] if disk_pct < 90 else COLORS["red"]
            w["disk_val"].config(text=f"{disk_used:.0f} / {disk_total:.0f} GB", fg=disk_color)
            self._update_bar(w["disk_bar"], disk_pct)
            total_disk_gb += disk_total
            
            # Network
            net_up = stats.get("net_sent_mb", 0)
            net_down = stats.get("net_recv_mb", 0)
            w["net_val"].config(
                text=f"↑{self._format_bytes(net_up)} ↓{self._format_bytes(net_down)}",
                fg=COLORS["cyan"]
            )
            total_net_up += net_up
            total_net_down += net_down
            
            # Temperature
            temps = stats.get("temps", {})
            if temps:
                max_temp = max(temps.values())
                temp_color = COLORS["green"] if max_temp < 60 else COLORS["yellow"] if max_temp < 80 else COLORS["red"]
                w["temp_val"].config(text=f"🌡 {max_temp:.0f}°C", fg=temp_color)
            else:
                w["temp_val"].config(text="")
            
            # Uptime
            uptime = stats.get("uptime_s", 0)
            w["uptime_val"].config(text=f"⏱ {self._format_uptime(uptime)}", fg=COLORS["text_dim"])
            
            # Processes
            procs = stats.get("procs", 0)
            w["procs_val"].config(text=f"⚙ {procs}", fg=COLORS["text_dim"])
            total_procs += procs
            
            # GPU count
            if node.get("gpu") and node["gpu"] != "none":
                gpu_count += 1
        
        # Update summary bar
        self.summary_widgets["nodes"].config(
            text=f"{online_count}/{len(self.nodes)}",
            fg=COLORS["green"] if online_count == len(self.nodes) else COLORS["yellow"]
        )
        self.summary_widgets["cores"].config(text=f"{total_cores}")
        self.summary_widgets["ram"].config(
            text=f"{total_ram_mb/1024:.1f} GB" if total_ram_mb > 0 else "---"
        )
        self.summary_widgets["disk"].config(
            text=f"{total_disk_gb/1024:.2f} TB" if total_disk_gb > 1024 else f"{total_disk_gb:.0f} GB"
        )
        self.summary_widgets["gpu"].config(text=f"{gpu_count}")
        self.summary_widgets["procs"].config(text=f"{total_procs}")
        self.summary_widgets["net_up"].config(text=self._format_bytes(total_net_up))
        self.summary_widgets["net_down"].config(text=self._format_bytes(total_net_down))
        
        # Update status
        self.lbl_status.config(
            text=f"● LIVE ({online_count}/{len(self.nodes)} nodes)",
            fg=COLORS["green"] if online_count == len(self.nodes) else COLORS["yellow"]
        )
        
        if self.last_refresh:
            self.lbl_time.config(text=self.last_refresh.strftime("Last: %H:%M:%S"))


# ═══════════════════════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    app = MeshMonitor()
    
    # Handle graceful close
    def on_close():
        app.destroy()
    
    app.protocol("WM_DELETE_WINDOW", on_close)
    app.mainloop()


if __name__ == "__main__":
    main()
