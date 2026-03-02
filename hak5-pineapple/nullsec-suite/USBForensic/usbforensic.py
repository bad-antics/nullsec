#!/usr/bin/env python3
"""
NullSec USBForensic - USB Device Forensics & History Analyzer
Reconstructs complete USB device history from system artifacts:
- /var/log/syslog & journal entries
- udev rules and persistent naming
- /sys/bus/usb/devices enumeration
- USB event timeline reconstruction
- Device fingerprinting (VID:PID, serial, class)
- Mass storage mount history
- Badusb/rubber ducky detection heuristics

Author: bad-antics / NullSec
License: MIT
"""

import os
import re
import sys
import json
import glob
import time
import subprocess
import hashlib
from collections import defaultdict
from datetime import datetime
from pathlib import Path


class USBDevice:
    """Represents a USB device with forensic metadata."""
    
    # Known BadUSB vendor/product IDs
    BADUSB_INDICATORS = {
        ('1fc9', '0083'): 'LPC USB VirtualCom (HID attack tool)',
        ('1b4f', '9205'): 'SparkFun Pro Micro (common rubber ducky clone)',
        ('1b4f', '9206'): 'SparkFun Pro Micro bootloader',
        ('2341', '8036'): 'Arduino Leonardo (HID injection capable)',
        ('2341', '8037'): 'Arduino Micro (HID injection capable)',
        ('16c0', '0486'): 'Teensy (HID attack tool)',
        ('16c0', '0487'): 'Teensy MIDI (potential HID)',
        ('04d8', '003f'): 'USB Rubber Ducky (Hak5)',
        ('2b4d', '1557'): 'USB Armory',
        ('1d50', '60fc'): 'USBNinja cable',
        ('feed', '1337'): 'O.MG Cable',
    }
    
    # USB class codes
    CLASS_NAMES = {
        0x00: 'Composite', 0x01: 'Audio', 0x02: 'CDC/Modem',
        0x03: 'HID', 0x05: 'Physical', 0x06: 'Image',
        0x07: 'Printer', 0x08: 'Mass Storage', 0x09: 'Hub',
        0x0a: 'CDC-Data', 0x0b: 'Smart Card', 0x0d: 'Content Security',
        0x0e: 'Video', 0x0f: 'Healthcare', 0x10: 'Audio/Video',
        0xdc: 'Diagnostic', 0xe0: 'Wireless', 0xef: 'Misc',
        0xfe: 'Application Specific', 0xff: 'Vendor Specific'
    }
    
    def __init__(self, vid=None, pid=None, serial=None):
        self.vid = vid or ''
        self.pid = pid or ''
        self.serial = serial or ''
        self.manufacturer = ''
        self.product = ''
        self.device_class = 0
        self.speed = ''
        self.bus = ''
        self.port = ''
        self.first_seen = None
        self.last_seen = None
        self.events = []
        self.mount_points = []
        self.is_suspicious = False
        self.risk_score = 0
        self.risk_reasons = []
    
    @property
    def device_id(self):
        return f"{self.vid}:{self.pid}"
    
    @property
    def fingerprint(self):
        data = f"{self.vid}:{self.pid}:{self.serial}:{self.manufacturer}:{self.product}"
        return hashlib.md5(data.encode()).hexdigest()[:12]
    
    def analyze_risk(self):
        """Assess security risk of this device."""
        self.risk_score = 0
        self.risk_reasons = []
        
        # Check against known BadUSB devices
        key = (self.vid.lower(), self.pid.lower())
        if key in self.BADUSB_INDICATORS:
            self.risk_score += 80
            self.risk_reasons.append(f"Known attack tool: {self.BADUSB_INDICATORS[key]}")
            self.is_suspicious = True
        
        # HID + Mass Storage combo (potential BadUSB)
        has_hid = False
        has_storage = False
        for event in self.events:
            if 'HID' in event.get('detail', ''):
                has_hid = True
            if 'Mass Storage' in event.get('detail', '') or 'sd' in event.get('detail', ''):
                has_storage = True
        
        if has_hid and has_storage:
            self.risk_score += 40
            self.risk_reasons.append("Device exposes both HID and Mass Storage (BadUSB pattern)")
        
        # Pure HID devices with no recognized manufacturer
        if self.device_class == 0x03 and not self.manufacturer:
            self.risk_score += 20
            self.risk_reasons.append("HID device with no manufacturer string")
        
        # Very rapid connect/disconnect (potential injection)
        if len(self.events) >= 2:
            timestamps = [e.get('timestamp') for e in self.events if e.get('timestamp')]
            if len(timestamps) >= 2:
                duration = (timestamps[-1] - timestamps[0]).total_seconds()
                if 0 < duration < 5 and len(self.events) > 4:
                    self.risk_score += 30
                    self.risk_reasons.append(f"Rapid connect/disconnect ({len(self.events)} events in {duration:.1f}s)")
        
        # No serial number (common in clone devices)
        if not self.serial:
            self.risk_score += 5
            self.risk_reasons.append("No serial number")
        
        self.is_suspicious = self.risk_score >= 30
        return self.risk_score
    
    def to_dict(self):
        return {
            'device_id': self.device_id,
            'fingerprint': self.fingerprint,
            'vid': self.vid,
            'pid': self.pid,
            'serial': self.serial,
            'manufacturer': self.manufacturer,
            'product': self.product,
            'class': self.CLASS_NAMES.get(self.device_class, f'0x{self.device_class:02x}'),
            'speed': self.speed,
            'bus_port': f"{self.bus}:{self.port}",
            'first_seen': self.first_seen.isoformat() if self.first_seen else None,
            'last_seen': self.last_seen.isoformat() if self.last_seen else None,
            'event_count': len(self.events),
            'mount_points': self.mount_points,
            'risk_score': self.risk_score,
            'risk_reasons': self.risk_reasons,
            'is_suspicious': self.is_suspicious
        }


class USBForensic:
    """Main forensics engine for USB device analysis."""
    
    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/usbforensic')
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        self.devices = {}  # fingerprint -> USBDevice
        self.timeline = []
    
    def scan_current_devices(self):
        """Enumerate currently connected USB devices."""
        print("🔌 Scanning current USB devices...")
        
        usb_path = '/sys/bus/usb/devices'
        if not os.path.exists(usb_path):
            print("   ⚠️  /sys/bus/usb/devices not available")
            return
        
        for entry in os.listdir(usb_path):
            dev_path = os.path.join(usb_path, entry)
            
            # Skip interfaces (contain ':')
            if ':' in entry:
                continue
            
            vid = self._read_sysfs(dev_path, 'idVendor')
            pid = self._read_sysfs(dev_path, 'idProduct')
            
            if not vid or not pid:
                continue
            
            device = USBDevice(vid, pid)
            device.serial = self._read_sysfs(dev_path, 'serial') or ''
            device.manufacturer = self._read_sysfs(dev_path, 'manufacturer') or ''
            device.product = self._read_sysfs(dev_path, 'product') or ''
            device.speed = self._read_sysfs(dev_path, 'speed') or ''
            device.bus = self._read_sysfs(dev_path, 'busnum') or ''
            device.port = self._read_sysfs(dev_path, 'devnum') or ''
            
            # Get device class
            bclass = self._read_sysfs(dev_path, 'bDeviceClass')
            if bclass:
                try:
                    device.device_class = int(bclass, 16)
                except:
                    pass
            
            device.first_seen = datetime.now()
            device.last_seen = datetime.now()
            device.events.append({
                'type': 'current_enumeration',
                'timestamp': datetime.now(),
                'detail': f'Currently connected on bus {device.bus}'
            })
            
            fp = device.fingerprint
            self.devices[fp] = device
        
        print(f"   Found {len(self.devices)} USB devices")
    
    def scan_syslog(self):
        """Parse syslog for USB history."""
        print("📜 Scanning syslog for USB history...")
        
        log_files = []
        for pattern in ['/var/log/syslog*', '/var/log/messages*', '/var/log/kern.log*']:
            log_files.extend(sorted(glob.glob(pattern)))
        
        if not log_files:
            # Try journalctl
            self._scan_journal()
            return
        
        usb_pattern = re.compile(
            r'(\w+\s+\d+\s+[\d:]+)\s+\S+\s+kernel.*?usb\s+(\S+):\s+(.*)',
            re.IGNORECASE
        )
        
        vid_pid_pattern = re.compile(r'idVendor=(\w+),\s*idProduct=(\w+)')
        serial_pattern = re.compile(r'SerialNumber:\s*(\S+)')
        product_pattern = re.compile(r'Product:\s*(.+)')
        manufacturer_pattern = re.compile(r'Manufacturer:\s*(.+)')
        disconnect_pattern = re.compile(r'USB disconnect')
        
        event_count = 0
        
        for log_file in log_files:
            try:
                opener = open
                if log_file.endswith('.gz'):
                    import gzip
                    opener = gzip.open
                
                with opener(log_file, 'rt', errors='replace') as f:
                    for line in f:
                        match = usb_pattern.search(line)
                        if not match:
                            continue
                        
                        timestamp_str = match.group(1)
                        usb_bus = match.group(2)
                        detail = match.group(3)
                        
                        try:
                            # Parse timestamp (add current year)
                            timestamp = datetime.strptime(
                                f"{datetime.now().year} {timestamp_str}",
                                "%Y %b %d %H:%M:%S"
                            )
                        except:
                            timestamp = datetime.now()
                        
                        event = {
                            'timestamp': timestamp,
                            'bus': usb_bus,
                            'detail': detail.strip(),
                            'source': os.path.basename(log_file)
                        }
                        
                        # Extract device identifiers
                        vid_match = vid_pid_pattern.search(detail)
                        if vid_match:
                            event['vid'] = vid_match.group(1)
                            event['pid'] = vid_match.group(2)
                        
                        serial_match = serial_pattern.search(detail)
                        if serial_match:
                            event['serial'] = serial_match.group(1)
                        
                        if disconnect_pattern.search(detail):
                            event['type'] = 'disconnect'
                        else:
                            event['type'] = 'connect'
                        
                        self.timeline.append(event)
                        event_count += 1
                        
            except Exception as e:
                print(f"   ⚠️  Error reading {log_file}: {e}")
        
        print(f"   Found {event_count} USB events in logs")
        self._correlate_events()
    
    def _scan_journal(self):
        """Use journalctl for USB history."""
        print("📜 Scanning journal for USB history...")
        
        try:
            result = subprocess.run(
                ['journalctl', '-k', '--no-pager', '-o', 'short-iso', '--grep=usb'],
                capture_output=True, text=True, timeout=30
            )
            
            if result.returncode != 0:
                print("   ⚠️  journalctl access failed")
                return
            
            event_count = 0
            for line in result.stdout.split('\n'):
                if not line.strip():
                    continue
                
                # Parse journal timestamp
                parts = line.split(' ', 3)
                if len(parts) < 4:
                    continue
                
                try:
                    timestamp = datetime.fromisoformat(parts[0])
                except:
                    continue
                
                detail = parts[3] if len(parts) > 3 else ''
                
                if 'usb' in detail.lower():
                    event = {
                        'timestamp': timestamp,
                        'detail': detail.strip(),
                        'type': 'disconnect' if 'disconnect' in detail.lower() else 'connect',
                        'source': 'journal'
                    }
                    
                    # Extract VID:PID
                    vid_match = re.search(r'idVendor=(\w+)', detail)
                    pid_match = re.search(r'idProduct=(\w+)', detail)
                    if vid_match:
                        event['vid'] = vid_match.group(1)
                    if pid_match:
                        event['pid'] = pid_match.group(1)
                    
                    self.timeline.append(event)
                    event_count += 1
            
            print(f"   Found {event_count} USB events in journal")
            self._correlate_events()
            
        except Exception as e:
            print(f"   ⚠️  Journal scan error: {e}")
    
    def _correlate_events(self):
        """Correlate timeline events with device records."""
        for event in self.timeline:
            vid = event.get('vid', '')
            pid = event.get('pid', '')
            serial = event.get('serial', '')
            
            if vid and pid:
                device = USBDevice(vid, pid, serial)
                fp = device.fingerprint
                
                if fp not in self.devices:
                    self.devices[fp] = device
                
                dev = self.devices[fp]
                dev.events.append(event)
                
                ts = event.get('timestamp')
                if ts:
                    if dev.first_seen is None or ts < dev.first_seen:
                        dev.first_seen = ts
                    if dev.last_seen is None or ts > dev.last_seen:
                        dev.last_seen = ts
    
    def scan_mount_history(self):
        """Check for USB mass storage mount history."""
        print("💾 Scanning mount history...")
        
        # Check fstab for USB entries
        fstab_usb = []
        try:
            with open('/etc/fstab') as f:
                for line in f:
                    if 'usb' in line.lower() or 'media' in line.lower():
                        fstab_usb.append(line.strip())
        except:
            pass
        
        # Check /media and /mnt for USB mount remnants
        mount_points = []
        for base in ['/media', '/mnt']:
            if os.path.exists(base):
                for entry in os.listdir(base):
                    full_path = os.path.join(base, entry)
                    if os.path.isdir(full_path):
                        mount_points.append(full_path)
        
        # Check current mounts
        try:
            with open('/proc/mounts') as f:
                for line in f:
                    if '/dev/sd' in line or 'usb' in line.lower():
                        parts = line.split()
                        if len(parts) >= 2:
                            mount_points.append(parts[1])
        except:
            pass
        
        print(f"   Found {len(mount_points)} USB-related mount points")
        return mount_points
    
    def _read_sysfs(self, base_path, attr):
        """Read a sysfs attribute."""
        try:
            with open(os.path.join(base_path, attr)) as f:
                return f.read().strip()
        except:
            return None
    
    def analyze_all(self):
        """Run full forensic analysis."""
        print("\n🔬 USBForensic - Full Analysis")
        print("=" * 50)
        
        self.scan_current_devices()
        self.scan_syslog()
        mount_points = self.scan_mount_history()
        
        # Risk assessment
        print("\n🎯 Risk Assessment...")
        suspicious = []
        for fp, device in self.devices.items():
            device.analyze_risk()
            if device.is_suspicious:
                suspicious.append(device)
                print(f"   ⚠️  {device.device_id} ({device.product or 'Unknown'}) - Risk: {device.risk_score}")
                for reason in device.risk_reasons:
                    print(f"      └─ {reason}")
        
        if not suspicious:
            print("   ✅ No suspicious devices detected")
        
        return self._generate_report(mount_points)
    
    def _generate_report(self, mount_points=None):
        """Generate forensic report."""
        # Sort devices by risk
        sorted_devices = sorted(
            self.devices.values(),
            key=lambda d: d.risk_score,
            reverse=True
        )
        
        report = {
            'scan_time': datetime.now().isoformat(),
            'total_devices': len(self.devices),
            'suspicious_devices': sum(1 for d in self.devices.values() if d.is_suspicious),
            'timeline_events': len(self.timeline),
            'devices': [d.to_dict() for d in sorted_devices],
            'mount_points': mount_points or [],
            'timeline': [
                {
                    'timestamp': e['timestamp'].isoformat() if isinstance(e.get('timestamp'), datetime) else str(e.get('timestamp', '')),
                    'type': e.get('type', ''),
                    'detail': e.get('detail', '')[:100]
                }
                for e in sorted(self.timeline, key=lambda x: x.get('timestamp', datetime.min))
            ][-100:]  # Last 100 events
        }
        
        # Save JSON
        json_path = os.path.join(self.output_dir, f"usb-forensic-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Generate Markdown
        md_path = os.path.join(self.output_dir, f"usb-forensic-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 🔌 USBForensic Analysis Report\n\n")
            f.write(f"**Scan Time:** {report['scan_time']}\n\n")
            f.write("## Summary\n\n")
            f.write(f"| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Total Devices | {report['total_devices']} |\n")
            f.write(f"| Suspicious | {report['suspicious_devices']} |\n")
            f.write(f"| Timeline Events | {report['timeline_events']} |\n\n")
            
            # Device inventory
            f.write("## Device Inventory\n\n")
            f.write("| VID:PID | Product | Manufacturer | Class | Risk | Suspicious |\n")
            f.write("|---------|---------|-------------|-------|------|------------|\n")
            for d in sorted_devices:
                sus = '⚠️ YES' if d.is_suspicious else '✅ No'
                f.write(f"| {d.device_id} | {d.product or 'N/A'} | {d.manufacturer or 'N/A'} | ")
                f.write(f"{d.CLASS_NAMES.get(d.device_class, '?')} | {d.risk_score} | {sus} |\n")
            f.write("\n")
            
            # Suspicious devices detail
            suspicious = [d for d in sorted_devices if d.is_suspicious]
            if suspicious:
                f.write("## ⚠️ Suspicious Devices\n\n")
                for d in suspicious:
                    f.write(f"### {d.device_id} - {d.product or 'Unknown Device'}\n\n")
                    f.write(f"- **Risk Score:** {d.risk_score}/100\n")
                    f.write(f"- **Serial:** {d.serial or 'None'}\n")
                    f.write(f"- **First Seen:** {d.first_seen}\n")
                    f.write(f"- **Last Seen:** {d.last_seen}\n")
                    f.write(f"- **Events:** {len(d.events)}\n\n")
                    f.write("**Risk Reasons:**\n")
                    for reason in d.risk_reasons:
                        f.write(f"- 🔴 {reason}\n")
                    f.write("\n")
            
            # Timeline
            f.write("## 📅 Recent Timeline\n\n")
            f.write("| Time | Type | Detail |\n")
            f.write("|------|------|--------|\n")
            for event in report['timeline'][-30:]:
                f.write(f"| {event['timestamp']} | {event['type']} | {event['detail']} |\n")
            
            f.write("\n---\n*Generated by NullSec USBForensic*\n")
        
        print(f"\n📄 Reports saved:")
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  🔌 USBForensic v1.0                  ║
    ║  USB Device Forensics & History       ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='USBForensic - USB Device History & Risk Analysis')
    parser.add_argument('-f', '--full', action='store_true', help='Full forensic analysis')
    parser.add_argument('-c', '--current', action='store_true', help='Show current devices only')
    parser.add_argument('-t', '--timeline', action='store_true', help='Show event timeline')
    parser.add_argument('-o', '--output', help='Output directory')
    parser.add_argument('--json', action='store_true', help='JSON output to stdout')
    
    args = parser.parse_args()
    
    forensic = USBForensic(args.output)
    
    if args.current:
        forensic.scan_current_devices()
        for fp, dev in forensic.devices.items():
            dev.analyze_risk()
            sus = '⚠️' if dev.is_suspicious else '✅'
            print(f"  {sus} {dev.device_id} | {dev.product or 'N/A':30s} | {dev.manufacturer or 'N/A':20s} | Risk: {dev.risk_score}")
    elif args.timeline:
        forensic.scan_syslog()
        for event in forensic.timeline[-50:]:
            ts = event.get('timestamp', '')
            if isinstance(ts, datetime):
                ts = ts.strftime('%Y-%m-%d %H:%M:%S')
            print(f"  [{ts}] {event.get('type', ''):12s} {event.get('detail', '')[:80]}")
    elif args.full:
        report = forensic.analyze_all()
        if args.json:
            print(json.dumps(report, indent=2, default=str))
    else:
        # Default: full analysis
        forensic.analyze_all()
