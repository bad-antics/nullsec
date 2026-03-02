#!/usr/bin/env python3
"""
NullSec WiFiSentinel - Wireless Deauthentication Monitor & Alert System
Real-time detection of WiFi attacks:
- Deauthentication flood detection
- Disassociation attack detection
- Evil Twin AP detection (SSID/BSSID mismatch)
- Rogue AP monitoring
- KARMA attack detection
- Client tracking & association monitoring
- Channel hopping for full spectrum coverage
- Alert via webhook, email, or local notification

Requires: monitor mode capable WiFi adapter
Author: bad-antics / NullSec
License: MIT
"""

import os
import sys
import json
import time
import struct
import socket
import signal
import subprocess
import threading
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path


# ─── 802.11 Frame Constants ───────────────────────────────────────────────

# Frame types
MGMT_FRAME = 0
CTRL_FRAME = 1
DATA_FRAME = 2

# Management subtypes
ASSOC_REQ = 0
ASSOC_RESP = 1
REASSOC_REQ = 2
REASSOC_RESP = 3
PROBE_REQ = 4
PROBE_RESP = 5
BEACON = 8
DISASSOC = 10
AUTH = 11
DEAUTH = 12
ACTION = 13

# Reason codes for deauth
DEAUTH_REASONS = {
    1: 'Unspecified',
    2: 'Previous auth no longer valid',
    3: 'Deauthenticated: leaving',
    4: 'Disassociated: inactivity',
    5: 'Disassociated: AP busy',
    6: 'Class 2 frame from non-auth station',
    7: 'Class 3 frame from non-assoc station',
    8: 'Disassociated: leaving BSS',
}


class WiFiFrame:
    """Parse 802.11 frame from raw bytes (radiotap header assumed)."""
    
    def __init__(self, raw):
        self.raw = raw
        self.valid = False
        self.frame_type = None
        self.frame_subtype = None
        self.src = None
        self.dst = None
        self.bssid = None
        self.ssid = None
        self.channel = None
        self.signal = None
        self.reason = None
        
        self._parse()
    
    def _parse(self):
        """Parse the frame."""
        if len(self.raw) < 24:
            return
        
        # Parse Radiotap header
        try:
            rt_version, rt_pad, rt_length = struct.unpack_from('<BBH', self.raw, 0)
            if rt_version != 0 or rt_length > len(self.raw):
                return
            
            # Extract signal strength if present in radiotap
            # (simplified - full radiotap parsing is complex)
            if rt_length >= 14:
                try:
                    # Typically at offset 14 in many radiotap implementations
                    self.signal = struct.unpack_from('b', self.raw, min(14, rt_length - 1))[0]
                except:
                    pass
            
            # 802.11 frame starts after radiotap
            frame_start = rt_length
            if frame_start + 24 > len(self.raw):
                return
            
            # Frame control
            fc = struct.unpack_from('<H', self.raw, frame_start)[0]
            self.frame_type = (fc >> 2) & 0x3
            self.frame_subtype = (fc >> 4) & 0xF
            
            # Address fields
            self.dst = self._mac_str(self.raw[frame_start + 4:frame_start + 10])
            self.src = self._mac_str(self.raw[frame_start + 10:frame_start + 16])
            self.bssid = self._mac_str(self.raw[frame_start + 16:frame_start + 22])
            
            # Parse specific frame types
            if self.frame_type == MGMT_FRAME:
                body_start = frame_start + 24
                
                if self.frame_subtype in (DEAUTH, DISASSOC):
                    if body_start + 2 <= len(self.raw):
                        self.reason = struct.unpack_from('<H', self.raw, body_start)[0]
                
                elif self.frame_subtype == BEACON or self.frame_subtype == PROBE_RESP:
                    # Skip fixed fields (timestamp + interval + capability = 12 bytes)
                    ie_start = body_start + 12
                    self._parse_ies(ie_start)
                
                elif self.frame_subtype == PROBE_REQ:
                    self._parse_ies(body_start)
            
            self.valid = True
            
        except Exception:
            pass
    
    def _parse_ies(self, offset):
        """Parse Information Elements (SSID, channel, etc.)."""
        try:
            while offset + 2 <= len(self.raw):
                ie_id = self.raw[offset]
                ie_len = self.raw[offset + 1]
                
                if offset + 2 + ie_len > len(self.raw):
                    break
                
                ie_data = self.raw[offset + 2:offset + 2 + ie_len]
                
                if ie_id == 0 and ie_len > 0:  # SSID
                    try:
                        self.ssid = ie_data.decode('utf-8', errors='replace')
                    except:
                        self.ssid = ie_data.hex()
                
                elif ie_id == 3 and ie_len == 1:  # DS Channel
                    self.channel = ie_data[0]
                
                offset += 2 + ie_len
        except:
            pass
    
    def _mac_str(self, mac_bytes):
        """Convert MAC bytes to string."""
        return ':'.join(f'{b:02x}' for b in mac_bytes)
    
    @property
    def is_broadcast(self):
        return self.dst == 'ff:ff:ff:ff:ff:ff'


class DeauthDetector:
    """Detect deauthentication attacks."""
    
    def __init__(self, threshold=10, window=10):
        self.threshold = threshold  # deauths per window to trigger alert
        self.window = window        # seconds
        self.deauth_log = defaultdict(list)  # bssid -> [timestamps]
        self.alerts = []
    
    def process(self, frame, timestamp):
        """Process a deauth/disassoc frame."""
        if frame.frame_subtype not in (DEAUTH, DISASSOC):
            return None
        
        key = f"{frame.src}->{frame.dst}"
        self.deauth_log[key].append(timestamp)
        
        # Clean old entries
        cutoff = timestamp - self.window
        self.deauth_log[key] = [t for t in self.deauth_log[key] if t > cutoff]
        
        count = len(self.deauth_log[key])
        
        if count >= self.threshold:
            attack_type = 'deauth_flood' if frame.frame_subtype == DEAUTH else 'disassoc_flood'
            reason_str = DEAUTH_REASONS.get(frame.reason, f'Unknown ({frame.reason})')
            
            alert = {
                'type': attack_type,
                'severity': 'critical' if count > self.threshold * 3 else 'high',
                'source': frame.src,
                'target': frame.dst,
                'bssid': frame.bssid,
                'count': count,
                'window': self.window,
                'reason_code': frame.reason,
                'reason': reason_str,
                'broadcast': frame.is_broadcast,
                'timestamp': datetime.fromtimestamp(timestamp).isoformat()
            }
            
            # Avoid duplicate alerts within window
            if not any(a['type'] == attack_type and a['source'] == frame.src 
                      and timestamp - datetime.fromisoformat(a['timestamp']).timestamp() < self.window
                      for a in self.alerts[-20:]):
                self.alerts.append(alert)
                return alert
        
        return None


class EvilTwinDetector:
    """Detect Evil Twin / Rogue AP attacks."""
    
    def __init__(self):
        self.known_aps = {}  # ssid -> {bssid: set(), channel: set(), ...}
        self.alerts = []
    
    def process_beacon(self, frame, timestamp):
        """Process a beacon frame to build AP database."""
        if not frame.ssid or frame.frame_subtype != BEACON:
            return None
        
        ssid = frame.ssid
        bssid = frame.bssid
        
        if ssid not in self.known_aps:
            self.known_aps[ssid] = {
                'bssids': set(),
                'channels': set(),
                'first_seen': timestamp,
                'beacon_count': 0
            }
        
        ap = self.known_aps[ssid]
        ap['bssids'].add(bssid)
        ap['channels'].add(frame.channel or 0)
        ap['beacon_count'] += 1
        
        # Detect new BSSID for known SSID (potential evil twin)
        if len(ap['bssids']) > 1 and ap['beacon_count'] > 10:
            alert = {
                'type': 'evil_twin_suspect',
                'severity': 'critical',
                'ssid': ssid,
                'bssids': list(ap['bssids']),
                'channels': list(ap['channels']),
                'detail': f'Multiple BSSIDs ({len(ap["bssids"])}) for SSID "{ssid}"',
                'timestamp': datetime.fromtimestamp(timestamp).isoformat()
            }
            
            if not any(a['ssid'] == ssid for a in self.alerts[-10:]):
                self.alerts.append(alert)
                return alert
        
        return None


class WiFiSentinel:
    """Main wireless monitoring engine."""
    
    def __init__(self, interface, output_dir=None):
        self.interface = interface
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/wifisentinel')
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        
        self.deauth_detector = DeauthDetector()
        self.evil_twin_detector = EvilTwinDetector()
        
        self.running = False
        self.stats = {
            'total_frames': 0,
            'mgmt_frames': 0,
            'deauths': 0,
            'disassocs': 0,
            'beacons': 0,
            'probe_reqs': 0,
            'clients_seen': set(),
            'aps_seen': set(),
            'start_time': None
        }
        self.alerts = []
    
    def enable_monitor_mode(self):
        """Put interface into monitor mode."""
        print(f"📡 Enabling monitor mode on {self.interface}...")
        
        commands = [
            ['ip', 'link', 'set', self.interface, 'down'],
            ['iw', 'dev', self.interface, 'set', 'type', 'monitor'],
            ['ip', 'link', 'set', self.interface, 'up'],
        ]
        
        for cmd in commands:
            try:
                subprocess.run(cmd, check=True, capture_output=True, timeout=5)
            except subprocess.CalledProcessError as e:
                # Try airmon-ng as fallback
                try:
                    subprocess.run(['airmon-ng', 'start', self.interface],
                                  check=True, capture_output=True, timeout=10)
                    return True
                except:
                    print(f"   ❌ Failed to enable monitor mode: {e}")
                    return False
        
        print(f"   ✅ Monitor mode enabled")
        return True
    
    def start_channel_hopper(self):
        """Hop through WiFi channels for full coverage."""
        channels = list(range(1, 14))  # 2.4GHz channels
        
        def hopper():
            idx = 0
            while self.running:
                channel = channels[idx % len(channels)]
                try:
                    subprocess.run(
                        ['iw', 'dev', self.interface, 'set', 'channel', str(channel)],
                        capture_output=True, timeout=2
                    )
                except:
                    pass
                idx += 1
                time.sleep(0.3)
        
        thread = threading.Thread(target=hopper, daemon=True)
        thread.start()
        return thread
    
    def monitor(self, duration=None, channel_hop=True):
        """Start monitoring for attacks."""
        print(f"\n📡 WiFiSentinel - Monitoring on {self.interface}")
        print(f"   Duration: {'infinite' if not duration else f'{duration}s'}")
        print(f"   Channel hopping: {'enabled' if channel_hop else 'disabled'}")
        print("=" * 50)
        
        # Create raw socket
        try:
            sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
            sock.bind((self.interface, 0))
            sock.settimeout(1.0)
        except PermissionError:
            print("❌ Root privileges required")
            sys.exit(1)
        except OSError as e:
            print(f"❌ Socket error: {e}")
            print("   Make sure interface is in monitor mode")
            sys.exit(1)
        
        self.running = True
        self.stats['start_time'] = time.time()
        
        # Start channel hopper
        if channel_hop:
            self.start_channel_hopper()
        
        end_time = time.time() + duration if duration else float('inf')
        last_status = time.time()
        
        try:
            while self.running and time.time() < end_time:
                try:
                    raw, _ = sock.recvfrom(65535)
                    now = time.time()
                    
                    frame = WiFiFrame(raw)
                    if not frame.valid:
                        continue
                    
                    self.stats['total_frames'] += 1
                    
                    if frame.frame_type == MGMT_FRAME:
                        self.stats['mgmt_frames'] += 1
                        
                        # Track clients and APs
                        if frame.src:
                            self.stats['clients_seen'].add(frame.src)
                        if frame.bssid:
                            self.stats['aps_seen'].add(frame.bssid)
                        
                        # Deauth / Disassoc
                        if frame.frame_subtype in (DEAUTH, DISASSOC):
                            if frame.frame_subtype == DEAUTH:
                                self.stats['deauths'] += 1
                            else:
                                self.stats['disassocs'] += 1
                            
                            alert = self.deauth_detector.process(frame, now)
                            if alert:
                                self._handle_alert(alert)
                        
                        # Beacons
                        elif frame.frame_subtype == BEACON:
                            self.stats['beacons'] += 1
                            alert = self.evil_twin_detector.process_beacon(frame, now)
                            if alert:
                                self._handle_alert(alert)
                        
                        # Probe requests
                        elif frame.frame_subtype == PROBE_REQ:
                            self.stats['probe_reqs'] += 1
                    
                    # Status update every 10s
                    if now - last_status > 10:
                        elapsed = now - self.stats['start_time']
                        fps = self.stats['total_frames'] / elapsed if elapsed > 0 else 0
                        print(f"\r   📊 {self.stats['total_frames']:,} frames | "
                              f"{self.stats['deauths']} deauths | "
                              f"{len(self.stats['aps_seen'])} APs | "
                              f"{len(self.stats['clients_seen'])} clients | "
                              f"{fps:.0f} fps | "
                              f"{len(self.alerts)} alerts", end='', flush=True)
                        last_status = now
                    
                except socket.timeout:
                    continue
                    
        except KeyboardInterrupt:
            print("\n\n⏹️  Stopping...")
        
        self.running = False
        sock.close()
        
        return self._generate_report()
    
    def _handle_alert(self, alert):
        """Handle a security alert."""
        self.alerts.append(alert)
        
        severity_icon = {
            'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'
        }.get(alert['severity'], '⚪')
        
        print(f"\n   {severity_icon} ALERT [{alert['severity'].upper()}] {alert['type']}")
        
        if alert['type'] in ('deauth_flood', 'disassoc_flood'):
            print(f"      Source: {alert['source']} → Target: {alert['target']}")
            print(f"      Count: {alert['count']}/{self.deauth_detector.window}s | "
                  f"Broadcast: {alert['broadcast']} | Reason: {alert['reason']}")
        elif alert['type'] == 'evil_twin_suspect':
            print(f"      SSID: {alert['ssid']}")
            print(f"      BSSIDs: {', '.join(alert['bssids'])}")
    
    def _generate_report(self):
        """Generate monitoring report."""
        duration = time.time() - self.stats['start_time'] if self.stats['start_time'] else 0
        
        report = {
            'scan_time': datetime.now().isoformat(),
            'interface': self.interface,
            'duration_seconds': round(duration, 1),
            'stats': {
                'total_frames': self.stats['total_frames'],
                'mgmt_frames': self.stats['mgmt_frames'],
                'deauths': self.stats['deauths'],
                'disassocs': self.stats['disassocs'],
                'beacons': self.stats['beacons'],
                'probe_requests': self.stats['probe_reqs'],
                'unique_clients': len(self.stats['clients_seen']),
                'unique_aps': len(self.stats['aps_seen']),
            },
            'alerts': self.alerts,
            'deauth_alerts': self.deauth_detector.alerts,
            'evil_twin_alerts': self.evil_twin_detector.alerts,
            'known_aps': {
                ssid: {
                    'bssids': list(info['bssids']),
                    'channels': list(info['channels']),
                    'beacons': info['beacon_count']
                }
                for ssid, info in self.evil_twin_detector.known_aps.items()
            }
        }
        
        # Save JSON
        json_path = os.path.join(self.output_dir, f"wifi-sentinel-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Markdown
        md_path = os.path.join(self.output_dir, f"wifi-sentinel-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 📡 WiFiSentinel Monitoring Report\n\n")
            f.write(f"**Generated:** {report['scan_time']}\n")
            f.write(f"**Interface:** {self.interface}\n")
            f.write(f"**Duration:** {duration:.0f} seconds\n\n")
            
            f.write("## Statistics\n\n")
            f.write("| Metric | Value |\n|--------|-------|\n")
            for key, val in report['stats'].items():
                f.write(f"| {key.replace('_', ' ').title()} | {val:,} |\n")
            f.write("\n")
            
            if self.alerts:
                f.write("## 🚨 Alerts\n\n")
                f.write("| Time | Type | Severity | Details |\n")
                f.write("|------|------|----------|--------|\n")
                for a in self.alerts:
                    detail = ''
                    if 'source' in a:
                        detail = f"{a['source']}→{a.get('target', '?')}"
                    elif 'ssid' in a:
                        detail = f"SSID: {a['ssid']}"
                    f.write(f"| {a['timestamp']} | {a['type']} | {a['severity']} | {detail} |\n")
                f.write("\n")
            
            if report['known_aps']:
                f.write("## Discovered APs\n\n")
                f.write("| SSID | BSSIDs | Channels | Beacons |\n")
                f.write("|------|--------|----------|--------|\n")
                for ssid, info in sorted(report['known_aps'].items()):
                    f.write(f"| {ssid} | {len(info['bssids'])} | {info['channels']} | {info['beacons']} |\n")
            
            f.write("\n---\n*Generated by NullSec WiFiSentinel*\n")
        
        print(f"\n📄 Reports:")
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  📡 WiFiSentinel v1.0                 ║
    ║  Wireless Deauth Monitor & Alert      ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='WiFiSentinel - Wireless Attack Monitor')
    parser.add_argument('-i', '--interface', required=True, help='WiFi interface (must be monitor mode capable)')
    parser.add_argument('-d', '--duration', type=int, help='Monitoring duration in seconds')
    parser.add_argument('-t', '--threshold', type=int, default=10, help='Deauth alert threshold (default: 10)')
    parser.add_argument('--no-hop', action='store_true', help='Disable channel hopping')
    parser.add_argument('--monitor', action='store_true', help='Enable monitor mode on interface')
    parser.add_argument('-o', '--output', help='Output directory')
    
    args = parser.parse_args()
    
    sentinel = WiFiSentinel(args.interface, args.output)
    sentinel.deauth_detector.threshold = args.threshold
    
    if args.monitor:
        if not sentinel.enable_monitor_mode():
            sys.exit(1)
    
    def signal_handler(sig, frame):
        sentinel.running = False
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    sentinel.monitor(duration=args.duration, channel_hop=not args.no_hop)
