#!/usr/bin/env python3
"""
NullSec Firmware Updater for WiFi Pineapple Pager
A desktop application for easy firmware installation

Credits: Built for Hak5 WiFi Pineapple devices - https://hak5.org
"""

import sys
import os
import subprocess
import threading
import json
import hashlib
import tarfile
import tempfile
import shutil
from pathlib import Path
from datetime import datetime

try:
    import tkinter as tk
    from tkinter import ttk, filedialog, messagebox, scrolledtext
    HAS_TK = True
except ImportError:
    HAS_TK = False

try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                  QHBoxLayout, QPushButton, QLabel, QTextEdit,
                                  QProgressBar, QFileDialog, QMessageBox, QGroupBox,
                                  QLineEdit, QComboBox, QTabWidget, QFrame)
    from PyQt5.QtCore import Qt, QThread, pyqtSignal
    from PyQt5.QtGui import QFont, QPalette, QColor
    HAS_QT = True
except ImportError:
    HAS_QT = False

# Application metadata
APP_NAME = "NullSec Firmware Updater"
APP_VERSION = "1.0.0"
HAK5_CREDIT = "Built for Hak5 WiFi Pineapple - https://hak5.org"

# Default connection settings
DEFAULT_PAGER_IP = "172.16.52.1"
DEFAULT_PAGER_USER = "root"
DEFAULT_PAGER_PASS = ""

class PagerConnection:
    """Handle SSH/SCP connections to Pineapple Pager"""
    
    def __init__(self, ip=DEFAULT_PAGER_IP, user=DEFAULT_PAGER_USER, password=""):
        self.ip = ip
        self.user = user
        self.password = password
        self.connected = False
    
    def test_connection(self):
        """Test if device is reachable"""
        try:
            result = subprocess.run(
                ["ping", "-c", "1", "-W", "2", self.ip],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except:
            return False
    
    def ssh_command(self, command):
        """Execute command on device via SSH"""
        ssh_cmd = ["sshpass", "-p", self.password, "ssh",
                   "-o", "StrictHostKeyChecking=no",
                   "-o", "UserKnownHostsFile=/dev/null",
                   f"{self.user}@{self.ip}", command]
        try:
            result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=30)
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Connection timed out"
        except Exception as e:
            return False, "", str(e)
    
    def scp_upload(self, local_path, remote_path):
        """Upload file to device via SCP"""
        scp_cmd = ["sshpass", "-p", self.password, "scp",
                   "-o", "StrictHostKeyChecking=no",
                   "-o", "UserKnownHostsFile=/dev/null",
                   "-r", local_path, f"{self.user}@{self.ip}:{remote_path}"]
        try:
            result = subprocess.run(scp_cmd, capture_output=True, text=True, timeout=120)
            return result.returncode == 0
        except:
            return False
    
    def get_device_info(self):
        """Get device information"""
        success, output, _ = self.ssh_command(
            "echo -n 'Hostname: ' && cat /etc/hostname && "
            "echo -n 'Kernel: ' && uname -r && "
            "echo -n 'Uptime: ' && uptime && "
            "echo -n 'Storage: ' && df -h /mmc | tail -1"
        )
        if success:
            return output
        return "Unable to get device info"
    
    def is_pineapple_pager(self):
        """Check if connected device is a Pineapple Pager"""
        success, output, _ = self.ssh_command("ls /pineapple/pineapple 2>/dev/null && echo 'PAGER_FOUND'")
        return success and "PAGER_FOUND" in output


class FirmwareInstaller:
    """Handle firmware installation process"""
    
    def __init__(self, connection, callback=None):
        self.connection = connection
        self.callback = callback or print
    
    def log(self, message):
        """Log message to callback"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.callback(f"[{timestamp}] {message}")
    
    def verify_package(self, package_path):
        """Verify firmware package integrity"""
        self.log("Verifying firmware package...")
        
        if not os.path.exists(package_path):
            return False, "Package file not found"
        
        # Check if it's a valid tarball
        if not tarfile.is_tarfile(package_path):
            return False, "Invalid package format (not a tar archive)"
        
        # Check for required files
        with tarfile.open(package_path, 'r:gz') as tar:
            members = tar.getnames()
            required = ['install.sh', 'VERSION']
            for req in required:
                if req not in members:
                    return False, f"Missing required file: {req}"
        
        self.log("Package verification passed")
        return True, "OK"
    
    def extract_package(self, package_path, extract_dir):
        """Extract firmware package"""
        self.log(f"Extracting package to {extract_dir}...")
        
        try:
            with tarfile.open(package_path, 'r:gz') as tar:
                tar.extractall(extract_dir)
            return True
        except Exception as e:
            self.log(f"Extraction failed: {e}")
            return False
    
    def install(self, package_path):
        """Full installation process"""
        self.log("Starting NullSec Firmware installation...")
        self.log(f"Package: {package_path}")
        
        # Verify package
        valid, msg = self.verify_package(package_path)
        if not valid:
            self.log(f"ERROR: {msg}")
            return False
        
        # Test connection
        self.log("Testing connection to Pineapple Pager...")
        if not self.connection.test_connection():
            self.log("ERROR: Cannot reach device. Check connection.")
            return False
        
        # Verify it's a Pineapple Pager
        self.log("Verifying device type...")
        if not self.connection.is_pineapple_pager():
            self.log("ERROR: Device doesn't appear to be a Pineapple Pager")
            return False
        
        self.log("Device verified as WiFi Pineapple Pager")
        
        # Create temp directory and extract
        with tempfile.TemporaryDirectory() as tmpdir:
            if not self.extract_package(package_path, tmpdir):
                return False
            
            # Upload files
            self.log("Uploading firmware files...")
            remote_tmp = "/tmp/nullsec-install"
            
            success, _, _ = self.connection.ssh_command(f"mkdir -p {remote_tmp}")
            if not success:
                self.log("ERROR: Failed to create temp directory on device")
                return False
            
            if not self.connection.scp_upload(tmpdir + "/.", remote_tmp):
                self.log("ERROR: Failed to upload files")
                return False
            
            self.log("Files uploaded successfully")
            
            # Run installer
            self.log("Running installer on device...")
            success, output, stderr = self.connection.ssh_command(
                f"cd {remote_tmp} && chmod +x install.sh && ./install.sh"
            )
            
            if output:
                for line in output.split('\n'):
                    if line.strip():
                        self.log(f"  {line}")
            
            # Cleanup
            self.log("Cleaning up...")
            self.connection.ssh_command(f"rm -rf {remote_tmp}")
        
        if success:
            self.log("")
            self.log("═" * 50)
            self.log("  INSTALLATION COMPLETE!")
            self.log("═" * 50)
            self.log("")
            self.log("Please reboot your Pineapple Pager to apply changes.")
            return True
        else:
            self.log("ERROR: Installation failed")
            if stderr:
                self.log(f"Error details: {stderr}")
            return False


# ═══════════════════════════════════════════════════════════════════════════════
# PyQt5 GUI (Preferred)
# ═══════════════════════════════════════════════════════════════════════════════

if HAS_QT:
    
    class InstallWorker(QThread):
        """Background worker for installation"""
        log_signal = pyqtSignal(str)
        finished_signal = pyqtSignal(bool)
        
        def __init__(self, installer, package_path):
            super().__init__()
            self.installer = installer
            self.package_path = package_path
        
        def run(self):
            self.installer.callback = self.log_signal.emit
            result = self.installer.install(self.package_path)
            self.finished_signal.emit(result)
    
    
    class NullSecUpdaterQt(QMainWindow):
        """Main application window (PyQt5)"""
        
        def __init__(self):
            super().__init__()
            self.connection = PagerConnection()
            self.package_path = None
            self.init_ui()
        
        def init_ui(self):
            """Initialize the user interface"""
            self.setWindowTitle(f"{APP_NAME} v{APP_VERSION}")
            self.setMinimumSize(700, 600)
            
            # Set dark theme
            self.set_dark_theme()
            
            # Central widget
            central = QWidget()
            self.setCentralWidget(central)
            layout = QVBoxLayout(central)
            layout.setSpacing(10)
            
            # Header
            header = QLabel("""
    ╔═══════════════════════════════════════════════════════════════╗
    ║         NULLSEC FIRMWARE UPDATER                              ║
    ║         For WiFi Pineapple Pager                              ║
    ╚═══════════════════════════════════════════════════════════════╝
            """)
            header.setFont(QFont("Monospace", 9))
            header.setStyleSheet("color: #ff3333; background: #1a1a1a; padding: 10px;")
            layout.addWidget(header)
            
            # Tabs
            tabs = QTabWidget()
            layout.addWidget(tabs)
            
            # Install tab
            install_tab = QWidget()
            install_layout = QVBoxLayout(install_tab)
            tabs.addTab(install_tab, "Install Firmware")
            
            # Connection group
            conn_group = QGroupBox("Device Connection")
            conn_layout = QHBoxLayout(conn_group)
            
            conn_layout.addWidget(QLabel("IP:"))
            self.ip_input = QLineEdit(DEFAULT_PAGER_IP)
            self.ip_input.setMaximumWidth(150)
            conn_layout.addWidget(self.ip_input)
            
            conn_layout.addWidget(QLabel("Password:"))
            self.pass_input = QLineEdit()
            self.pass_input.setEchoMode(QLineEdit.Password)
            self.pass_input.setMaximumWidth(150)
            conn_layout.addWidget(self.pass_input)
            
            self.connect_btn = QPushButton("Test Connection")
            self.connect_btn.clicked.connect(self.test_connection)
            conn_layout.addWidget(self.connect_btn)
            
            self.status_label = QLabel("Not connected")
            self.status_label.setStyleSheet("color: #888;")
            conn_layout.addWidget(self.status_label)
            conn_layout.addStretch()
            
            install_layout.addWidget(conn_group)
            
            # Firmware group
            fw_group = QGroupBox("Firmware Package")
            fw_layout = QHBoxLayout(fw_group)
            
            self.package_label = QLineEdit("No package selected")
            self.package_label.setReadOnly(True)
            fw_layout.addWidget(self.package_label)
            
            browse_btn = QPushButton("Browse...")
            browse_btn.clicked.connect(self.browse_package)
            fw_layout.addWidget(browse_btn)
            
            install_layout.addWidget(fw_group)
            
            # Progress
            self.progress = QProgressBar()
            self.progress.setRange(0, 0)  # Indeterminate
            self.progress.setVisible(False)
            install_layout.addWidget(self.progress)
            
            # Log output
            log_group = QGroupBox("Installation Log")
            log_layout = QVBoxLayout(log_group)
            
            self.log_output = QTextEdit()
            self.log_output.setReadOnly(True)
            self.log_output.setFont(QFont("Monospace", 9))
            self.log_output.setStyleSheet(
                "background: #0a0a0a; color: #33ff33; border: 1px solid #333;"
            )
            log_layout.addWidget(self.log_output)
            
            install_layout.addWidget(log_group)
            
            # Buttons
            btn_layout = QHBoxLayout()
            
            self.install_btn = QPushButton("Install NullSec Firmware")
            self.install_btn.setStyleSheet(
                "background: #cc0000; color: white; font-weight: bold; "
                "padding: 10px 20px; font-size: 14px;"
            )
            self.install_btn.clicked.connect(self.start_install)
            btn_layout.addWidget(self.install_btn)
            
            btn_layout.addStretch()
            
            reboot_btn = QPushButton("Reboot Device")
            reboot_btn.clicked.connect(self.reboot_device)
            btn_layout.addWidget(reboot_btn)
            
            install_layout.addLayout(btn_layout)
            
            # Device Info tab
            info_tab = QWidget()
            info_layout = QVBoxLayout(info_tab)
            tabs.addTab(info_tab, "Device Info")
            
            self.info_text = QTextEdit()
            self.info_text.setReadOnly(True)
            self.info_text.setFont(QFont("Monospace", 10))
            info_layout.addWidget(self.info_text)
            
            refresh_btn = QPushButton("Refresh Device Info")
            refresh_btn.clicked.connect(self.refresh_device_info)
            info_layout.addWidget(refresh_btn)
            
            # About tab
            about_tab = QWidget()
            about_layout = QVBoxLayout(about_tab)
            tabs.addTab(about_tab, "About")
            
            about_text = QLabel(f"""
            <h2 style="color: #ff3333;">{APP_NAME}</h2>
            <p>Version {APP_VERSION}</p>
            <br>
            <p><b>Credits:</b></p>
            <p>{HAK5_CREDIT}</p>
            <br>
            <p>This tool is designed to install NullSec custom firmware
            on Hak5 WiFi Pineapple Pager devices.</p>
            <br>
            <p><b>Disclaimer:</b></p>
            <p>This tool is provided for authorized security testing only.
            Users are responsible for ensuring compliance with all applicable
            laws and regulations.</p>
            <br>
            <p>WiFi Pineapple® is a registered trademark of Hak5 LLC.</p>
            """)
            about_text.setWordWrap(True)
            about_text.setAlignment(Qt.AlignCenter)
            about_layout.addWidget(about_text)
            about_layout.addStretch()
            
            # Footer
            footer = QLabel(HAK5_CREDIT)
            footer.setAlignment(Qt.AlignCenter)
            footer.setStyleSheet("color: #666; padding: 5px;")
            layout.addWidget(footer)
        
        def set_dark_theme(self):
            """Apply dark theme"""
            palette = QPalette()
            palette.setColor(QPalette.Window, QColor(26, 26, 26))
            palette.setColor(QPalette.WindowText, QColor(200, 200, 200))
            palette.setColor(QPalette.Base, QColor(15, 15, 15))
            palette.setColor(QPalette.AlternateBase, QColor(26, 26, 26))
            palette.setColor(QPalette.ToolTipBase, QColor(200, 200, 200))
            palette.setColor(QPalette.ToolTipText, QColor(200, 200, 200))
            palette.setColor(QPalette.Text, QColor(200, 200, 200))
            palette.setColor(QPalette.Button, QColor(40, 40, 40))
            palette.setColor(QPalette.ButtonText, QColor(200, 200, 200))
            palette.setColor(QPalette.BrightText, QColor(255, 0, 0))
            palette.setColor(QPalette.Highlight, QColor(200, 0, 0))
            palette.setColor(QPalette.HighlightedText, QColor(255, 255, 255))
            self.setPalette(palette)
        
        def log(self, message):
            """Add message to log"""
            self.log_output.append(message)
            self.log_output.verticalScrollBar().setValue(
                self.log_output.verticalScrollBar().maximum()
            )
        
        def test_connection(self):
            """Test connection to device"""
            self.connection.ip = self.ip_input.text()
            self.connection.password = self.pass_input.text()
            
            self.status_label.setText("Testing...")
            self.status_label.setStyleSheet("color: #ffaa00;")
            QApplication.processEvents()
            
            if self.connection.test_connection():
                if self.connection.is_pineapple_pager():
                    self.status_label.setText("Connected to Pineapple Pager!")
                    self.status_label.setStyleSheet("color: #33ff33;")
                    self.log("Connected to WiFi Pineapple Pager")
                else:
                    self.status_label.setText("Connected (not a Pager?)")
                    self.status_label.setStyleSheet("color: #ffaa00;")
            else:
                self.status_label.setText("Connection failed")
                self.status_label.setStyleSheet("color: #ff3333;")
                self.log("Connection failed - check IP and ensure device is on")
        
        def browse_package(self):
            """Browse for firmware package"""
            path, _ = QFileDialog.getOpenFileName(
                self,
                "Select NullSec Firmware Package",
                "",
                "Firmware Package (*.tar.gz);;All Files (*)"
            )
            if path:
                self.package_path = path
                self.package_label.setText(path)
                self.log(f"Selected package: {path}")
        
        def start_install(self):
            """Start installation process"""
            if not self.package_path:
                QMessageBox.warning(self, "Error", "Please select a firmware package first")
                return
            
            if not self.connection.test_connection():
                QMessageBox.warning(self, "Error", "Cannot connect to device")
                return
            
            # Confirm
            reply = QMessageBox.question(
                self,
                "Confirm Installation",
                "This will install NullSec firmware on your Pineapple Pager.\n\n"
                "Make sure you have a backup of any important data.\n\n"
                "Continue with installation?",
                QMessageBox.Yes | QMessageBox.No
            )
            
            if reply != QMessageBox.Yes:
                return
            
            # Disable UI
            self.install_btn.setEnabled(False)
            self.progress.setVisible(True)
            self.log_output.clear()
            
            # Start worker
            self.connection.ip = self.ip_input.text()
            self.connection.password = self.pass_input.text()
            
            installer = FirmwareInstaller(self.connection)
            self.worker = InstallWorker(installer, self.package_path)
            self.worker.log_signal.connect(self.log)
            self.worker.finished_signal.connect(self.install_finished)
            self.worker.start()
        
        def install_finished(self, success):
            """Called when installation completes"""
            self.install_btn.setEnabled(True)
            self.progress.setVisible(False)
            
            if success:
                QMessageBox.information(
                    self,
                    "Installation Complete",
                    "NullSec firmware has been installed successfully!\n\n"
                    "Please reboot your Pineapple Pager to apply changes."
                )
            else:
                QMessageBox.warning(
                    self,
                    "Installation Failed",
                    "Installation failed. Check the log for details."
                )
        
        def refresh_device_info(self):
            """Refresh device information"""
            self.connection.ip = self.ip_input.text()
            self.connection.password = self.pass_input.text()
            
            if not self.connection.test_connection():
                self.info_text.setText("Cannot connect to device")
                return
            
            info = self.connection.get_device_info()
            self.info_text.setText(info)
        
        def reboot_device(self):
            """Reboot the connected device"""
            reply = QMessageBox.question(
                self,
                "Confirm Reboot",
                "Are you sure you want to reboot the Pineapple Pager?",
                QMessageBox.Yes | QMessageBox.No
            )
            
            if reply == QMessageBox.Yes:
                self.connection.ip = self.ip_input.text()
                self.connection.password = self.pass_input.text()
                success, _, _ = self.connection.ssh_command("reboot")
                if success:
                    self.log("Reboot command sent")
                else:
                    self.log("Failed to send reboot command")


# ═══════════════════════════════════════════════════════════════════════════════
# Tkinter GUI (Fallback)
# ═══════════════════════════════════════════════════════════════════════════════

if HAS_TK and not HAS_QT:
    
    class NullSecUpdaterTk:
        """Main application window (Tkinter fallback)"""
        
        def __init__(self):
            self.root = tk.Tk()
            self.root.title(f"{APP_NAME} v{APP_VERSION}")
            self.root.geometry("700x600")
            self.root.configure(bg='#1a1a1a')
            
            self.connection = PagerConnection()
            self.package_path = None
            
            self.init_ui()
        
        def init_ui(self):
            """Initialize the user interface"""
            # Header
            header = tk.Label(
                self.root,
                text="NULLSEC FIRMWARE UPDATER\nFor WiFi Pineapple Pager",
                font=("Courier", 14, "bold"),
                fg="#ff3333",
                bg="#1a1a1a"
            )
            header.pack(pady=10)
            
            # Connection frame
            conn_frame = tk.LabelFrame(
                self.root,
                text="Device Connection",
                fg="white",
                bg="#1a1a1a"
            )
            conn_frame.pack(fill="x", padx=10, pady=5)
            
            tk.Label(conn_frame, text="IP:", fg="white", bg="#1a1a1a").pack(side="left", padx=5)
            self.ip_entry = tk.Entry(conn_frame, width=15)
            self.ip_entry.insert(0, DEFAULT_PAGER_IP)
            self.ip_entry.pack(side="left", padx=5)
            
            tk.Label(conn_frame, text="Password:", fg="white", bg="#1a1a1a").pack(side="left", padx=5)
            self.pass_entry = tk.Entry(conn_frame, width=15, show="*")
            self.pass_entry.pack(side="left", padx=5)
            
            tk.Button(
                conn_frame,
                text="Test Connection",
                command=self.test_connection
            ).pack(side="left", padx=10)
            
            self.status_label = tk.Label(
                conn_frame,
                text="Not connected",
                fg="#888888",
                bg="#1a1a1a"
            )
            self.status_label.pack(side="left", padx=10)
            
            # Package frame
            pkg_frame = tk.LabelFrame(
                self.root,
                text="Firmware Package",
                fg="white",
                bg="#1a1a1a"
            )
            pkg_frame.pack(fill="x", padx=10, pady=5)
            
            self.pkg_label = tk.Label(
                pkg_frame,
                text="No package selected",
                fg="#888888",
                bg="#1a1a1a"
            )
            self.pkg_label.pack(side="left", padx=10)
            
            tk.Button(
                pkg_frame,
                text="Browse...",
                command=self.browse_package
            ).pack(side="right", padx=10)
            
            # Log frame
            log_frame = tk.LabelFrame(
                self.root,
                text="Installation Log",
                fg="white",
                bg="#1a1a1a"
            )
            log_frame.pack(fill="both", expand=True, padx=10, pady=5)
            
            self.log_text = scrolledtext.ScrolledText(
                log_frame,
                height=15,
                bg="#0a0a0a",
                fg="#33ff33",
                font=("Courier", 9)
            )
            self.log_text.pack(fill="both", expand=True, padx=5, pady=5)
            
            # Buttons
            btn_frame = tk.Frame(self.root, bg="#1a1a1a")
            btn_frame.pack(fill="x", padx=10, pady=10)
            
            tk.Button(
                btn_frame,
                text="Install NullSec Firmware",
                command=self.start_install,
                bg="#cc0000",
                fg="white",
                font=("Arial", 12, "bold"),
                padx=20,
                pady=10
            ).pack(side="left")
            
            tk.Button(
                btn_frame,
                text="Reboot Device",
                command=self.reboot_device
            ).pack(side="right")
            
            # Footer
            footer = tk.Label(
                self.root,
                text=HAK5_CREDIT,
                fg="#666666",
                bg="#1a1a1a"
            )
            footer.pack(pady=5)
        
        def log(self, message):
            """Add message to log"""
            self.log_text.insert(tk.END, message + "\n")
            self.log_text.see(tk.END)
        
        def test_connection(self):
            """Test connection to device"""
            self.connection.ip = self.ip_entry.get()
            self.connection.password = self.pass_entry.get()
            
            self.status_label.config(text="Testing...", fg="#ffaa00")
            self.root.update()
            
            if self.connection.test_connection():
                self.status_label.config(text="Connected!", fg="#33ff33")
                self.log("Connected to device")
            else:
                self.status_label.config(text="Connection failed", fg="#ff3333")
                self.log("Connection failed")
        
        def browse_package(self):
            """Browse for firmware package"""
            path = filedialog.askopenfilename(
                title="Select NullSec Firmware Package",
                filetypes=[("Firmware Package", "*.tar.gz"), ("All Files", "*")]
            )
            if path:
                self.package_path = path
                self.pkg_label.config(text=path, fg="#33ff33")
                self.log(f"Selected: {path}")
        
        def start_install(self):
            """Start installation"""
            if not self.package_path:
                messagebox.showwarning("Error", "Please select a firmware package first")
                return
            
            if messagebox.askyesno("Confirm", "Install NullSec firmware?"):
                self.connection.ip = self.ip_entry.get()
                self.connection.password = self.pass_entry.get()
                
                installer = FirmwareInstaller(self.connection, self.log)
                
                def install_thread():
                    result = installer.install(self.package_path)
                    if result:
                        messagebox.showinfo("Complete", "Installation successful!")
                    else:
                        messagebox.showwarning("Failed", "Installation failed")
                
                threading.Thread(target=install_thread, daemon=True).start()
        
        def reboot_device(self):
            """Reboot device"""
            if messagebox.askyesno("Confirm", "Reboot the device?"):
                self.connection.ip = self.ip_entry.get()
                self.connection.password = self.pass_entry.get()
                self.connection.ssh_command("reboot")
                self.log("Reboot command sent")
        
        def run(self):
            """Run the application"""
            self.root.mainloop()


# ═══════════════════════════════════════════════════════════════════════════════
# Command Line Interface
# ═══════════════════════════════════════════════════════════════════════════════

def cli_mode(args):
    """Command line interface mode"""
    print(f"""
    ╔═══════════════════════════════════════════════════════════════╗
    ║         NULLSEC FIRMWARE UPDATER - CLI MODE                   ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    {HAK5_CREDIT}
    """)
    
    import argparse
    parser = argparse.ArgumentParser(description="NullSec Firmware Updater CLI")
    parser.add_argument("package", help="Path to firmware package")
    parser.add_argument("-i", "--ip", default=DEFAULT_PAGER_IP, help="Device IP address")
    parser.add_argument("-p", "--password", default="", help="Device password")
    parser.add_argument("-t", "--test", action="store_true", help="Test connection only")
    
    parsed = parser.parse_args(args)
    
    connection = PagerConnection(parsed.ip, DEFAULT_PAGER_USER, parsed.password)
    
    if parsed.test:
        print("Testing connection...")
        if connection.test_connection():
            print("Connection successful!")
            if connection.is_pineapple_pager():
                print("Device verified as Pineapple Pager")
            else:
                print("Warning: Device may not be a Pineapple Pager")
        else:
            print("Connection failed")
        return
    
    installer = FirmwareInstaller(connection, print)
    result = installer.install(parsed.package)
    sys.exit(0 if result else 1)


# ═══════════════════════════════════════════════════════════════════════════════
# Main Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    """Main entry point"""
    # Check for CLI mode
    if len(sys.argv) > 1 and sys.argv[1] not in ['--gui', '-g']:
        cli_mode(sys.argv[1:])
        return
    
    # Launch GUI
    if HAS_QT:
        app = QApplication(sys.argv)
        app.setStyle('Fusion')
        window = NullSecUpdaterQt()
        window.show()
        sys.exit(app.exec_())
    elif HAS_TK:
        app = NullSecUpdaterTk()
        app.run()
    else:
        print("ERROR: No GUI toolkit available")
        print("Please install PyQt5 or tkinter:")
        print("  pip install PyQt5")
        print("")
        print("Or use CLI mode:")
        print(f"  {sys.argv[0]} --help")
        sys.exit(1)


if __name__ == "__main__":
    main()
