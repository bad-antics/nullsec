#!/usr/bin/env python3
"""
NULLSEC DESKTOP v2.0 - WINDOWS EDITION
═══════════════════════════════════════════════════════════════════════════════
Windows Desktop GUI for NULLSEC Framework

Features:
- Native Windows GUI (tkinter/PyQt5)
- Module browser with categories
- Search functionality
- PowerShell integration
- Dark theme interface

Author: bad-antics development
GitHub: github.com/bad-antics
License: For authorized security testing only
"""

import os
import sys
import subprocess
import threading
import json
from pathlib import Path
import platform

IS_WINDOWS = platform.system() == 'Windows'

# Try to use PyQt5 first, fallback to tkinter
try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                  QHBoxLayout, QListWidget, QListWidgetItem, QPushButton,
                                  QLineEdit, QLabel, QTextEdit, QComboBox, QSplitter,
                                  QFrame, QMessageBox, QTabWidget)
    from PyQt5.QtCore import Qt, QThread, pyqtSignal
    from PyQt5.QtGui import QFont, QPalette, QColor
    USE_PYQT = True
except ImportError:
    USE_PYQT = False
    import tkinter as tk
    from tkinter import ttk, scrolledtext, messagebox

SCRIPT_DIR = Path(__file__).parent.absolute()
MODULES_DIR = SCRIPT_DIR.parent / "powershell-modules"
CONFIG_FILE = SCRIPT_DIR / "config.json"


def auto_discover_modules():
    """Auto-discover Windows attack modules"""
    discovered = []
    module_id = 1
    
    category_patterns = {
        'Windows': ['uac-', 'windows-', 'powershell-', 'wmi-', 'psexec-', 'smb-'],
        'Active Directory': ['ad-', 'ldap-', 'kerberoast', 'golden-ticket', 'bloodhound'],
        'Credentials': ['pass', 'hash', 'cred', 'mimikatz', 'dump'],
        'Network': ['port-', 'network-', 'dns-', 'mitm-', 'scan'],
        'Evasion': ['bypass', 'amsi-', 'edr-', 'av-', 'defender-'],
        'Persistence': ['persistence', 'backdoor', 'registry-', 'scheduled-'],
        'Exploitation': ['exploit', 'kernel-', 'shellcode-'],
    }
    
    # Built-in Windows tools
    builtin_tools = [
        {'name': 'System Enumeration', 'category': 'Windows', 'cmd': 'systeminfo && whoami /all'},
        {'name': 'Network Info', 'category': 'Network', 'cmd': 'ipconfig /all && netstat -ano'},
        {'name': 'User Enumeration', 'category': 'Windows', 'cmd': 'net user && net localgroup administrators'},
        {'name': 'Service Enumeration', 'category': 'Windows', 'cmd': 'wmic service list brief'},
        {'name': 'Token Privileges', 'category': 'Credentials', 'cmd': 'whoami /priv'},
        {'name': 'Scheduled Tasks', 'category': 'Persistence', 'cmd': 'schtasks /query /fo LIST /v'},
        {'name': 'Registry Run Keys', 'category': 'Persistence', 'cmd': 'reg query HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run'},
        {'name': 'PowerShell Bypass', 'category': 'Evasion', 'cmd': 'powershell -ep bypass'},
        {'name': 'Port Scan (PowerShell)', 'category': 'Network', 'cmd': 'Test-NetConnection -ComputerName TARGET -Port 445'},
        {'name': 'SMB Shares', 'category': 'Network', 'cmd': 'net view \\\\TARGET'},
        {'name': 'Domain Info', 'category': 'Active Directory', 'cmd': 'nltest /dclist:'},
        {'name': 'Domain Users', 'category': 'Active Directory', 'cmd': 'net user /domain'},
        {'name': 'Process List', 'category': 'Windows', 'cmd': 'tasklist /v'},
        {'name': 'Installed Software', 'category': 'Windows', 'cmd': 'wmic product get name,version'},
        {'name': 'SAM Backup', 'category': 'Credentials', 'cmd': 'reg save HKLM\\SAM sam.hive'},
    ]
    
    for tool in builtin_tools:
        discovered.append({
            'id': module_id,
            'name': tool['name'],
            'category': tool['category'],
            'script': tool['cmd'],
            'type': 'builtin'
        })
        module_id += 1
    
    # Discover PowerShell scripts
    if MODULES_DIR.exists():
        for script in sorted(MODULES_DIR.glob('*.ps1')):
            category = 'Windows'
            for cat, patterns in category_patterns.items():
                if any(pattern in script.name.lower() for pattern in patterns):
                    category = cat
                    break
            
            discovered.append({
                'id': module_id,
                'name': script.stem.replace('-', ' ').replace('_', ' ').title(),
                'category': category,
                'script': str(script),
                'type': 'powershell'
            })
            module_id += 1
    
    return discovered


MODULES = auto_discover_modules()


if USE_PYQT:
    # PyQt5 Version
    
    class CommandRunner(QThread):
        """Thread for running commands"""
        output_signal = pyqtSignal(str)
        finished_signal = pyqtSignal()
        
        def __init__(self, command, is_powershell=False):
            super().__init__()
            self.command = command
            self.is_powershell = is_powershell
        
        def run(self):
            try:
                if self.is_powershell:
                    result = subprocess.run(
                        ['powershell', '-ExecutionPolicy', 'Bypass', '-Command', self.command],
                        capture_output=True,
                        text=True,
                        timeout=120
                    )
                else:
                    result = subprocess.run(
                        self.command,
                        shell=True,
                        capture_output=True,
                        text=True,
                        timeout=120
                    )
                
                if result.stdout:
                    self.output_signal.emit(result.stdout)
                if result.stderr:
                    self.output_signal.emit(f"[STDERR] {result.stderr}")
            except Exception as e:
                self.output_signal.emit(f"[ERROR] {str(e)}")
            
            self.finished_signal.emit()
    
    
    class NullsecDesktop(QMainWindow):
        """Main NULLSEC Desktop Window"""
        
        def __init__(self):
            super().__init__()
            self.setWindowTitle("NULLSEC Framework v2.0 - Windows Edition")
            self.setGeometry(100, 100, 1200, 800)
            self.setStyleSheet(self._dark_theme())
            
            self.command_runner = None
            self.setup_ui()
        
        def _dark_theme(self):
            return """
                QMainWindow { background-color: #1a1a2e; }
                QWidget { background-color: #1a1a2e; color: #eee; }
                QListWidget { 
                    background-color: #16213e; 
                    border: 1px solid #0f3460;
                    border-radius: 5px;
                    padding: 5px;
                }
                QListWidget::item { 
                    padding: 8px; 
                    margin: 2px;
                    border-radius: 3px;
                }
                QListWidget::item:selected { 
                    background-color: #e94560; 
                    color: white;
                }
                QListWidget::item:hover { 
                    background-color: #0f3460; 
                }
                QPushButton { 
                    background-color: #e94560; 
                    color: white; 
                    border: none;
                    padding: 10px 20px;
                    border-radius: 5px;
                    font-weight: bold;
                }
                QPushButton:hover { background-color: #ff6b6b; }
                QPushButton:pressed { background-color: #c73e54; }
                QPushButton:disabled { background-color: #555; }
                QLineEdit { 
                    background-color: #16213e; 
                    border: 1px solid #0f3460;
                    padding: 8px;
                    border-radius: 5px;
                    color: #eee;
                }
                QTextEdit { 
                    background-color: #0a0a14; 
                    border: 1px solid #0f3460;
                    padding: 10px;
                    border-radius: 5px;
                    font-family: 'Consolas', 'Courier New', monospace;
                    color: #00ff00;
                }
                QComboBox { 
                    background-color: #16213e; 
                    border: 1px solid #0f3460;
                    padding: 8px;
                    border-radius: 5px;
                }
                QLabel { color: #eee; font-weight: bold; }
                QTabWidget::pane { border: 1px solid #0f3460; }
                QTabBar::tab { 
                    background-color: #16213e; 
                    padding: 10px 20px;
                    margin-right: 2px;
                }
                QTabBar::tab:selected { background-color: #e94560; }
            """
        
        def setup_ui(self):
            central = QWidget()
            self.setCentralWidget(central)
            layout = QVBoxLayout(central)
            
            # Header
            header = QLabel("☠ NULLSEC FRAMEWORK v2.0 - Windows Edition ☠")
            header.setAlignment(Qt.AlignCenter)
            header.setStyleSheet("font-size: 24px; color: #e94560; padding: 15px;")
            layout.addWidget(header)
            
            # Main content with splitter
            splitter = QSplitter(Qt.Horizontal)
            
            # Left panel - Module list
            left_panel = QWidget()
            left_layout = QVBoxLayout(left_panel)
            
            # Search
            self.search_box = QLineEdit()
            self.search_box.setPlaceholderText("🔍 Search modules...")
            self.search_box.textChanged.connect(self.filter_modules)
            left_layout.addWidget(self.search_box)
            
            # Category filter
            self.category_combo = QComboBox()
            categories = ["All Categories"] + sorted(list(set(m['category'] for m in MODULES)))
            self.category_combo.addItems(categories)
            self.category_combo.currentTextChanged.connect(self.filter_modules)
            left_layout.addWidget(self.category_combo)
            
            # Module list
            self.module_list = QListWidget()
            self.module_list.itemDoubleClicked.connect(self.run_selected_module)
            self.populate_modules()
            left_layout.addWidget(self.module_list)
            
            # Run button
            self.run_btn = QPushButton("▶ RUN MODULE")
            self.run_btn.clicked.connect(self.run_selected_module)
            left_layout.addWidget(self.run_btn)
            
            splitter.addWidget(left_panel)
            
            # Right panel - Output
            right_panel = QWidget()
            right_layout = QVBoxLayout(right_panel)
            
            output_label = QLabel("📟 Output Console")
            right_layout.addWidget(output_label)
            
            self.output_area = QTextEdit()
            self.output_area.setReadOnly(True)
            self.output_area.setPlaceholderText("Module output will appear here...")
            right_layout.addWidget(self.output_area)
            
            # Command input
            cmd_layout = QHBoxLayout()
            self.cmd_input = QLineEdit()
            self.cmd_input.setPlaceholderText("Enter custom command...")
            self.cmd_input.returnPressed.connect(self.run_custom_command)
            cmd_layout.addWidget(self.cmd_input)
            
            exec_btn = QPushButton("Execute")
            exec_btn.clicked.connect(self.run_custom_command)
            cmd_layout.addWidget(exec_btn)
            
            right_layout.addLayout(cmd_layout)
            
            # Action buttons
            btn_layout = QHBoxLayout()
            
            clear_btn = QPushButton("🗑 Clear")
            clear_btn.clicked.connect(self.output_area.clear)
            btn_layout.addWidget(clear_btn)
            
            ps_btn = QPushButton("⚡ PowerShell")
            ps_btn.clicked.connect(self.launch_powershell)
            btn_layout.addWidget(ps_btn)
            
            ai_btn = QPushButton("🤖 AI Console")
            ai_btn.clicked.connect(self.launch_ai)
            btn_layout.addWidget(ai_btn)
            
            right_layout.addLayout(btn_layout)
            
            splitter.addWidget(right_panel)
            splitter.setSizes([400, 800])
            
            layout.addWidget(splitter)
            
            # Status bar
            self.statusBar().showMessage(f"Ready | {len(MODULES)} modules loaded")
        
        def populate_modules(self, modules=None):
            """Populate the module list"""
            self.module_list.clear()
            modules = modules or MODULES
            
            for mod in modules:
                item = QListWidgetItem(f"[{mod['category']}] {mod['name']}")
                item.setData(Qt.UserRole, mod)
                self.module_list.addItem(item)
        
        def filter_modules(self):
            """Filter modules by search and category"""
            search_text = self.search_box.text().lower()
            category = self.category_combo.currentText()
            
            filtered = [m for m in MODULES 
                       if (search_text in m['name'].lower() or search_text in m['category'].lower())
                       and (category == "All Categories" or m['category'] == category)]
            
            self.populate_modules(filtered)
        
        def run_selected_module(self):
            """Run the selected module"""
            current = self.module_list.currentItem()
            if not current:
                return
            
            mod = current.data(Qt.UserRole)
            self.run_module(mod)
        
        def run_module(self, mod):
            """Execute a module"""
            self.output_area.append(f"\n{'='*60}")
            self.output_area.append(f"[*] Running: {mod['name']}")
            self.output_area.append(f"[*] Category: {mod['category']}")
            self.output_area.append(f"[*] Command: {mod['script']}")
            self.output_area.append(f"{'='*60}\n")
            
            self.run_btn.setEnabled(False)
            self.statusBar().showMessage(f"Running: {mod['name']}...")
            
            is_powershell = mod['type'] == 'powershell'
            self.command_runner = CommandRunner(mod['script'], is_powershell)
            self.command_runner.output_signal.connect(self.append_output)
            self.command_runner.finished_signal.connect(self.on_command_finished)
            self.command_runner.start()
        
        def run_custom_command(self):
            """Run custom command"""
            cmd = self.cmd_input.text().strip()
            if not cmd:
                return
            
            self.output_area.append(f"\n[>] {cmd}\n")
            self.command_runner = CommandRunner(cmd, True)
            self.command_runner.output_signal.connect(self.append_output)
            self.command_runner.finished_signal.connect(self.on_command_finished)
            self.command_runner.start()
            self.cmd_input.clear()
        
        def append_output(self, text):
            """Append text to output"""
            self.output_area.append(text)
        
        def on_command_finished(self):
            """Handle command completion"""
            self.run_btn.setEnabled(True)
            self.statusBar().showMessage(f"Ready | {len(MODULES)} modules loaded")
            self.output_area.append("\n[✓] Command completed\n")
        
        def launch_powershell(self):
            """Launch PowerShell with bypass"""
            subprocess.Popen(['powershell', '-ExecutionPolicy', 'Bypass', '-NoProfile', '-NoExit'])
        
        def launch_ai(self):
            """Launch AI console"""
            ai_script = SCRIPT_DIR / 'nullsec-ai-windows.py'
            if ai_script.exists():
                subprocess.Popen(['python', str(ai_script)])
            else:
                QMessageBox.warning(self, "AI Not Found", "NULLSEC AI module not found.")
    
    
    def main_pyqt():
        app = QApplication(sys.argv)
        app.setStyle('Fusion')
        window = NullsecDesktop()
        window.show()
        sys.exit(app.exec_())

else:
    # Tkinter fallback version
    
    class NullsecDesktopTk:
        """Tkinter version of NULLSEC Desktop"""
        
        def __init__(self):
            self.root = tk.Tk()
            self.root.title("NULLSEC Framework v2.0 - Windows Edition")
            self.root.geometry("1200x800")
            self.root.configure(bg='#1a1a2e')
            
            self.setup_styles()
            self.setup_ui()
        
        def setup_styles(self):
            style = ttk.Style()
            style.theme_use('clam')
            
            style.configure('TFrame', background='#1a1a2e')
            style.configure('TLabel', background='#1a1a2e', foreground='#eee', font=('Arial', 10))
            style.configure('Header.TLabel', font=('Arial', 20, 'bold'), foreground='#e94560')
            style.configure('TButton', background='#e94560', foreground='white', font=('Arial', 10, 'bold'))
            style.configure('TEntry', fieldbackground='#16213e', foreground='#eee')
            style.configure('TCombobox', fieldbackground='#16213e', foreground='#eee')
        
        def setup_ui(self):
            # Header
            header = ttk.Label(self.root, text="☠ NULLSEC FRAMEWORK v2.0 - Windows Edition ☠", 
                              style='Header.TLabel')
            header.pack(pady=15)
            
            # Main container
            main_frame = ttk.Frame(self.root)
            main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
            
            # Left panel
            left_frame = ttk.Frame(main_frame)
            left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=5)
            
            # Search
            self.search_var = tk.StringVar()
            self.search_var.trace('w', lambda *args: self.filter_modules())
            search_entry = ttk.Entry(left_frame, textvariable=self.search_var, width=30)
            search_entry.pack(pady=5)
            search_entry.insert(0, "Search modules...")
            
            # Category filter
            self.category_var = tk.StringVar(value="All Categories")
            categories = ["All Categories"] + sorted(list(set(m['category'] for m in MODULES)))
            category_combo = ttk.Combobox(left_frame, textvariable=self.category_var, values=categories)
            category_combo.pack(pady=5)
            category_combo.bind('<<ComboboxSelected>>', lambda e: self.filter_modules())
            
            # Module listbox
            self.module_listbox = tk.Listbox(left_frame, width=40, height=25, 
                                             bg='#16213e', fg='#eee',
                                             selectbackground='#e94560')
            self.module_listbox.pack(pady=5, fill=tk.Y, expand=True)
            self.module_listbox.bind('<Double-1>', lambda e: self.run_selected_module())
            self.populate_modules()
            
            # Run button
            run_btn = tk.Button(left_frame, text="▶ RUN MODULE", bg='#e94560', fg='white',
                               font=('Arial', 10, 'bold'), command=self.run_selected_module)
            run_btn.pack(pady=10, fill=tk.X)
            
            # Right panel
            right_frame = ttk.Frame(main_frame)
            right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=5)
            
            ttk.Label(right_frame, text="📟 Output Console").pack(anchor=tk.W)
            
            self.output_text = scrolledtext.ScrolledText(right_frame, width=80, height=30,
                                                          bg='#0a0a14', fg='#00ff00',
                                                          font=('Consolas', 10))
            self.output_text.pack(fill=tk.BOTH, expand=True, pady=5)
            
            # Command input
            cmd_frame = ttk.Frame(right_frame)
            cmd_frame.pack(fill=tk.X, pady=5)
            
            self.cmd_entry = ttk.Entry(cmd_frame)
            self.cmd_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)
            self.cmd_entry.bind('<Return>', lambda e: self.run_custom_command())
            
            exec_btn = tk.Button(cmd_frame, text="Execute", bg='#e94560', fg='white',
                                command=self.run_custom_command)
            exec_btn.pack(side=tk.RIGHT, padx=5)
            
            # Action buttons
            btn_frame = ttk.Frame(right_frame)
            btn_frame.pack(fill=tk.X, pady=5)
            
            tk.Button(btn_frame, text="🗑 Clear", bg='#0f3460', fg='white',
                     command=lambda: self.output_text.delete(1.0, tk.END)).pack(side=tk.LEFT, padx=5)
            tk.Button(btn_frame, text="⚡ PowerShell", bg='#0f3460', fg='white',
                     command=self.launch_powershell).pack(side=tk.LEFT, padx=5)
            tk.Button(btn_frame, text="🤖 AI Console", bg='#0f3460', fg='white',
                     command=self.launch_ai).pack(side=tk.LEFT, padx=5)
            
            # Status bar
            self.status_var = tk.StringVar(value=f"Ready | {len(MODULES)} modules loaded")
            status = ttk.Label(self.root, textvariable=self.status_var)
            status.pack(side=tk.BOTTOM, fill=tk.X, pady=5)
        
        def populate_modules(self, modules=None):
            self.module_listbox.delete(0, tk.END)
            modules = modules or MODULES
            for mod in modules:
                self.module_listbox.insert(tk.END, f"[{mod['category']}] {mod['name']}")
        
        def filter_modules(self):
            search_text = self.search_var.get().lower()
            if search_text == "search modules...":
                search_text = ""
            category = self.category_var.get()
            
            filtered = [m for m in MODULES 
                       if (search_text in m['name'].lower() or search_text in m['category'].lower())
                       and (category == "All Categories" or m['category'] == category)]
            
            self.populate_modules(filtered)
        
        def run_selected_module(self):
            selection = self.module_listbox.curselection()
            if not selection:
                return
            
            idx = selection[0]
            filtered_modules = [m for m in MODULES 
                               if (self.search_var.get().lower() in m['name'].lower() or 
                                   self.search_var.get().lower() in m['category'].lower())
                               and (self.category_var.get() == "All Categories" or 
                                    m['category'] == self.category_var.get())]
            
            if idx < len(filtered_modules):
                self.run_module(filtered_modules[idx])
        
        def run_module(self, mod):
            self.output_text.insert(tk.END, f"\n{'='*60}\n")
            self.output_text.insert(tk.END, f"[*] Running: {mod['name']}\n")
            self.output_text.insert(tk.END, f"[*] Command: {mod['script']}\n")
            self.output_text.insert(tk.END, f"{'='*60}\n\n")
            
            def run():
                try:
                    result = subprocess.run(mod['script'], shell=True, 
                                          capture_output=True, text=True, timeout=60)
                    if result.stdout:
                        self.output_text.insert(tk.END, result.stdout)
                    if result.stderr:
                        self.output_text.insert(tk.END, f"[STDERR] {result.stderr}")
                except Exception as e:
                    self.output_text.insert(tk.END, f"[ERROR] {str(e)}\n")
                
                self.output_text.insert(tk.END, "\n[✓] Command completed\n")
                self.output_text.see(tk.END)
            
            threading.Thread(target=run, daemon=True).start()
        
        def run_custom_command(self):
            cmd = self.cmd_entry.get().strip()
            if not cmd:
                return
            
            self.output_text.insert(tk.END, f"\n[>] {cmd}\n")
            self.cmd_entry.delete(0, tk.END)
            
            def run():
                try:
                    result = subprocess.run(['powershell', '-Command', cmd],
                                          capture_output=True, text=True, timeout=60)
                    if result.stdout:
                        self.output_text.insert(tk.END, result.stdout)
                    if result.stderr:
                        self.output_text.insert(tk.END, f"[STDERR] {result.stderr}")
                except Exception as e:
                    self.output_text.insert(tk.END, f"[ERROR] {str(e)}\n")
                
                self.output_text.see(tk.END)
            
            threading.Thread(target=run, daemon=True).start()
        
        def launch_powershell(self):
            subprocess.Popen(['powershell', '-ExecutionPolicy', 'Bypass', '-NoProfile', '-NoExit'])
        
        def launch_ai(self):
            ai_script = SCRIPT_DIR / 'nullsec-ai-windows.py'
            if ai_script.exists():
                subprocess.Popen(['python', str(ai_script)])
            else:
                messagebox.showwarning("AI Not Found", "NULLSEC AI module not found.")
        
        def run(self):
            self.root.mainloop()
    
    
    def main_tkinter():
        app = NullsecDesktopTk()
        app.run()


def main():
    """Main entry point"""
    if USE_PYQT:
        main_pyqt()
    else:
        main_tkinter()


if __name__ == "__main__":
    main()
