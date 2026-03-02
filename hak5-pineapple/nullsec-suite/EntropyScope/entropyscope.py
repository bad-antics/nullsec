#!/usr/bin/env python3
"""
NullSec EntropyScope - Network Traffic Entropy Analyzer
Detects encrypted C2 channels, data exfiltration, and covert tunnels by
analyzing entropy patterns in network traffic flows.

Features:
- Per-flow entropy calculation (Shannon entropy)
- Beaconing detection (periodic callback patterns)
- DNS tunneling detection (high-entropy domain names)
- Protocol anomaly scoring
- Baseline learning mode
- Real-time alerts + JSON/Markdown reports

Author: bad-antics / NullSec
License: MIT
"""

import socket
import struct
import math
import time
import json
import os
import sys
import signal
import threading
import re
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path

# ─── Entropy Calculation ───────────────────────────────────────────────────

def shannon_entropy(data):
    """Calculate Shannon entropy of a byte sequence (0-8 bits)."""
    if not data:
        return 0.0
    counts = Counter(data)
    length = len(data)
    entropy = 0.0
    for count in counts.values():
        p = count / length
        if p > 0:
            entropy -= p * math.log2(p)
    return entropy


def domain_entropy(domain):
    """Calculate character-level entropy of a domain name."""
    if not domain:
        return 0.0
    domain = domain.lower().replace('.', '')
    counts = Counter(domain)
    length = len(domain)
    entropy = 0.0
    for count in counts.values():
        p = count / length
        if p > 0:
            entropy -= p * math.log2(p)
    return entropy


def chi_squared(data):
    """Chi-squared test for randomness."""
    if not data or len(data) < 10:
        return 0.0
    expected = len(data) / 256.0
    counts = Counter(data)
    chi2 = sum((counts.get(i, 0) - expected) ** 2 / expected for i in range(256))
    return chi2


# ─── Flow Tracker ──────────────────────────────────────────────────────────

class FlowTracker:
    """Track and analyze individual network flows."""
    
    def __init__(self):
        self.flows = defaultdict(lambda: {
            'packets': 0,
            'bytes': 0,
            'timestamps': [],
            'payload_sizes': [],
            'entropies': [],
            'first_seen': None,
            'last_seen': None,
            'protocol': '',
            'flags': Counter()
        })
    
    def add_packet(self, flow_key, payload, timestamp, protocol='', flags=None):
        """Add a packet to a flow."""
        flow = self.flows[flow_key]
        flow['packets'] += 1
        flow['bytes'] += len(payload)
        flow['timestamps'].append(timestamp)
        flow['payload_sizes'].append(len(payload))
        
        if payload:
            flow['entropies'].append(shannon_entropy(payload))
        
        if flow['first_seen'] is None:
            flow['first_seen'] = timestamp
        flow['last_seen'] = timestamp
        flow['protocol'] = protocol
        
        if flags:
            flow['flags'][flags] += 1
    
    def detect_beaconing(self, flow_key, threshold=0.15):
        """Detect periodic beaconing behavior in a flow."""
        flow = self.flows.get(flow_key)
        if not flow or len(flow['timestamps']) < 5:
            return None
        
        # Calculate inter-arrival times
        times = sorted(flow['timestamps'])
        intervals = [times[i+1] - times[i] for i in range(len(times)-1)]
        
        if not intervals:
            return None
        
        mean_interval = sum(intervals) / len(intervals)
        if mean_interval == 0:
            return None
        
        # Calculate coefficient of variation (low = regular intervals = beaconing)
        variance = sum((i - mean_interval) ** 2 for i in intervals) / len(intervals)
        std_dev = math.sqrt(variance)
        cv = std_dev / mean_interval
        
        if cv < threshold:
            return {
                'mean_interval': round(mean_interval, 3),
                'std_dev': round(std_dev, 3),
                'coefficient_variation': round(cv, 4),
                'sample_count': len(intervals),
                'confidence': round(max(0, (1 - cv) * 100), 1)
            }
        return None
    
    def get_flow_stats(self, flow_key):
        """Get comprehensive stats for a flow."""
        flow = self.flows.get(flow_key)
        if not flow:
            return None
        
        stats = {
            'flow': flow_key,
            'packets': flow['packets'],
            'bytes': flow['bytes'],
            'duration': (flow['last_seen'] - flow['first_seen']) if flow['first_seen'] else 0,
            'protocol': flow['protocol']
        }
        
        if flow['entropies']:
            stats['avg_entropy'] = round(sum(flow['entropies']) / len(flow['entropies']), 4)
            stats['max_entropy'] = round(max(flow['entropies']), 4)
            stats['min_entropy'] = round(min(flow['entropies']), 4)
        else:
            stats['avg_entropy'] = 0
            stats['max_entropy'] = 0
            stats['min_entropy'] = 0
        
        if flow['payload_sizes']:
            stats['avg_payload_size'] = round(sum(flow['payload_sizes']) / len(flow['payload_sizes']), 1)
        
        return stats


# ─── DNS Analyzer ──────────────────────────────────────────────────────────

class DNSAnalyzer:
    """Detect DNS tunneling and suspicious domain patterns."""
    
    # Known DNS tunnel indicators
    TUNNEL_PATTERNS = [
        r'^[a-z0-9]{30,}\.', # Very long subdomain
        r'^[a-f0-9]{16,}\.',  # Hex-encoded subdomain
        r'\.dnscat\.',         # dnscat tool
        r'\.dns2tcp\.',        # dns2tcp tool
    ]
    
    HIGH_ENTROPY_THRESHOLD = 3.8  # Bits per character
    LONG_SUBDOMAIN_THRESHOLD = 50
    
    def __init__(self):
        self.queries = defaultdict(list)  # domain -> [timestamps]
        self.alerts = []
    
    def analyze_query(self, domain, src_ip, timestamp):
        """Analyze a DNS query for tunneling indicators."""
        score = 0
        reasons = []
        
        # Check subdomain entropy
        parts = domain.split('.')
        if len(parts) > 2:
            subdomain = '.'.join(parts[:-2])
            ent = domain_entropy(subdomain)
            
            if ent > self.HIGH_ENTROPY_THRESHOLD:
                score += 3
                reasons.append(f"high_entropy_subdomain({ent:.2f})")
        
        # Check total domain length
        if len(domain) > self.LONG_SUBDOMAIN_THRESHOLD:
            score += 2
            reasons.append(f"long_domain({len(domain)}chars)")
        
        # Check for known tunnel patterns
        for pattern in self.TUNNEL_PATTERNS:
            if re.search(pattern, domain, re.IGNORECASE):
                score += 5
                reasons.append(f"tunnel_pattern_match")
                break
        
        # Check query frequency for this domain's base
        base_domain = '.'.join(parts[-2:]) if len(parts) >= 2 else domain
        self.queries[base_domain].append(timestamp)
        
        # High frequency DNS queries (> 10/min to same base domain)
        recent = [t for t in self.queries[base_domain] if timestamp - t < 60]
        if len(recent) > 10:
            score += 2
            reasons.append(f"high_freq({len(recent)}/min)")
        
        # Check for unusual TXT/NULL record types (would need deeper parsing)
        # Encoded data in subdomains (base64-like patterns)
        if re.match(r'^[A-Za-z0-9+/=]{20,}', parts[0] if parts else ''):
            score += 3
            reasons.append("base64_subdomain")
        
        if score >= 3:
            alert = {
                'type': 'dns_tunnel_suspect',
                'domain': domain,
                'src_ip': src_ip,
                'score': score,
                'reasons': reasons,
                'timestamp': datetime.fromtimestamp(timestamp).isoformat()
            }
            self.alerts.append(alert)
            return alert
        
        return None


# ─── PCAP Reader (lightweight) ─────────────────────────────────────────────

def read_pcap(filepath):
    """Read packets from a PCAP file (basic parser, no scapy needed)."""
    packets = []
    with open(filepath, 'rb') as f:
        # Read global header
        magic = struct.unpack('<I', f.read(4))[0]
        if magic == 0xa1b2c3d4:
            endian = '<'
        elif magic == 0xd4c3b2a1:
            endian = '>'
        else:
            raise ValueError("Not a valid PCAP file")
        
        # Skip rest of global header
        f.read(20)
        
        # Read packets
        while True:
            header = f.read(16)
            if len(header) < 16:
                break
            
            ts_sec, ts_usec, incl_len, orig_len = struct.unpack(f'{endian}IIII', header)
            data = f.read(incl_len)
            if len(data) < incl_len:
                break
            
            timestamp = ts_sec + ts_usec / 1000000.0
            packets.append((timestamp, data))
    
    return packets


def parse_ethernet(data):
    """Parse an Ethernet frame."""
    if len(data) < 14:
        return None
    
    dst_mac = data[:6]
    src_mac = data[6:12]
    eth_type = struct.unpack('!H', data[12:14])[0]
    payload = data[14:]
    
    return {'dst_mac': dst_mac, 'src_mac': src_mac, 'type': eth_type, 'payload': payload}


def parse_ip(data):
    """Parse an IP packet."""
    if len(data) < 20:
        return None
    
    header = struct.unpack('!BBHHHBBH4s4s', data[:20])
    ihl = (header[0] & 0x0F) * 4
    protocol = header[6]
    src_ip = socket.inet_ntoa(header[8])
    dst_ip = socket.inet_ntoa(header[9])
    payload = data[ihl:]
    
    return {'src': src_ip, 'dst': dst_ip, 'proto': protocol, 'payload': payload}


def parse_tcp(data):
    """Parse TCP segment."""
    if len(data) < 20:
        return None
    
    header = struct.unpack('!HHLLBBHHH', data[:20])
    src_port = header[0]
    dst_port = header[1]
    data_offset = ((header[4] >> 4) & 0xF) * 4
    flags = header[5]
    payload = data[data_offset:]
    
    return {'src_port': src_port, 'dst_port': dst_port, 'flags': flags, 'payload': payload}


def parse_udp(data):
    """Parse UDP datagram."""
    if len(data) < 8:
        return None
    
    header = struct.unpack('!HHHH', data[:8])
    return {'src_port': header[0], 'dst_port': header[1], 'length': header[2], 'payload': data[8:]}


# ─── Main Analyzer ─────────────────────────────────────────────────────────

class EntropyScope:
    """Main traffic analysis engine."""
    
    ALERT_THRESHOLDS = {
        'high_entropy': 7.2,       # Near-random = likely encrypted
        'beaconing_cv': 0.15,      # Coefficient of variation for beaconing
        'dns_tunnel_score': 3,      # Minimum score for DNS tunnel alert
        'data_exfil_bytes': 1048576, # 1MB outbound to single dest
        'covert_channel_ratio': 0.8  # Payload entropy ratio for covert channels
    }
    
    def __init__(self, output_dir=None):
        self.flow_tracker = FlowTracker()
        self.dns_analyzer = DNSAnalyzer()
        self.alerts = []
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/entropyscope')
        self.packet_count = 0
        self.start_time = time.time()
        
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
    
    def analyze_pcap(self, pcap_path):
        """Analyze a PCAP file for suspicious patterns."""
        print(f"📊 EntropyScope - Analyzing {pcap_path}")
        
        packets = read_pcap(pcap_path)
        print(f"   Loaded {len(packets)} packets")
        
        for timestamp, raw in packets:
            self._process_packet(timestamp, raw)
        
        return self._generate_report()
    
    def live_capture(self, interface='eth0', duration=60):
        """Live capture and analyze traffic (requires root)."""
        print(f"📡 EntropyScope - Live capture on {interface} for {duration}s")
        
        try:
            sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(3))
            sock.bind((interface, 0))
            sock.settimeout(1.0)
        except PermissionError:
            print("❌ Root privileges required for live capture")
            sys.exit(1)
        
        end_time = time.time() + duration
        
        while time.time() < end_time:
            try:
                raw, _ = sock.recvfrom(65535)
                self._process_packet(time.time(), raw)
            except socket.timeout:
                continue
            except KeyboardInterrupt:
                break
        
        sock.close()
        return self._generate_report()
    
    def _process_packet(self, timestamp, raw):
        """Process a single packet."""
        self.packet_count += 1
        
        # Parse Ethernet
        eth = parse_ethernet(raw)
        if not eth or eth['type'] != 0x0800:  # IPv4 only
            return
        
        # Parse IP
        ip = parse_ip(eth['payload'])
        if not ip:
            return
        
        proto_name = {6: 'TCP', 17: 'UDP', 1: 'ICMP'}.get(ip['proto'], str(ip['proto']))
        
        if ip['proto'] == 6:  # TCP
            tcp = parse_tcp(ip['payload'])
            if tcp:
                flow_key = f"{ip['src']}:{tcp['src_port']}->{ip['dst']}:{tcp['dst_port']}"
                self.flow_tracker.add_packet(flow_key, tcp['payload'], timestamp, 
                                            proto_name, tcp['flags'])
                
                # Check payload entropy
                if tcp['payload'] and len(tcp['payload']) > 20:
                    ent = shannon_entropy(tcp['payload'])
                    if ent > self.ALERT_THRESHOLDS['high_entropy']:
                        self._raise_alert('high_entropy_flow', {
                            'flow': flow_key,
                            'entropy': round(ent, 4),
                            'payload_size': len(tcp['payload']),
                            'timestamp': datetime.fromtimestamp(timestamp).isoformat()
                        })
        
        elif ip['proto'] == 17:  # UDP
            udp = parse_udp(ip['payload'])
            if udp:
                flow_key = f"{ip['src']}:{udp['src_port']}->{ip['dst']}:{udp['dst_port']}"
                self.flow_tracker.add_packet(flow_key, udp['payload'], timestamp, proto_name)
                
                # DNS analysis (port 53)
                if udp['dst_port'] == 53 or udp['src_port'] == 53:
                    self._analyze_dns_packet(udp['payload'], ip['src'], timestamp)
    
    def _analyze_dns_packet(self, payload, src_ip, timestamp):
        """Extract and analyze DNS queries from a packet."""
        try:
            if len(payload) < 12:
                return
            
            # Skip DNS header
            offset = 12
            domain_parts = []
            
            while offset < len(payload):
                length = payload[offset]
                if length == 0:
                    break
                if length >= 0xC0:  # Pointer
                    break
                offset += 1
                if offset + length > len(payload):
                    break
                domain_parts.append(payload[offset:offset+length].decode('ascii', errors='ignore'))
                offset += length
            
            if domain_parts:
                domain = '.'.join(domain_parts)
                alert = self.dns_analyzer.analyze_query(domain, src_ip, timestamp)
                if alert:
                    self._raise_alert('dns_tunnel_suspect', alert)
        except Exception:
            pass
    
    def _raise_alert(self, alert_type, details):
        """Raise a security alert."""
        alert = {
            'id': len(self.alerts) + 1,
            'type': alert_type,
            'severity': self._severity(alert_type, details),
            'details': details,
            'timestamp': datetime.now().isoformat()
        }
        self.alerts.append(alert)
        
        severity_icon = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}
        icon = severity_icon.get(alert['severity'], '⚪')
        print(f"   {icon} [{alert['severity'].upper()}] {alert_type}: {json.dumps(details, default=str)[:120]}")
    
    def _severity(self, alert_type, details):
        """Determine alert severity."""
        if alert_type == 'dns_tunnel_suspect':
            score = details.get('score', 0)
            if score >= 8: return 'critical'
            if score >= 5: return 'high'
            return 'medium'
        elif alert_type == 'high_entropy_flow':
            ent = details.get('entropy', 0)
            if ent > 7.8: return 'critical'
            if ent > 7.5: return 'high'
            return 'medium'
        elif alert_type == 'beaconing':
            conf = details.get('confidence', 0)
            if conf > 90: return 'critical'
            if conf > 70: return 'high'
            return 'medium'
        return 'low'
    
    def _check_beaconing(self):
        """Check all flows for beaconing behavior."""
        for flow_key in self.flow_tracker.flows:
            result = self.flow_tracker.detect_beaconing(flow_key)
            if result:
                self._raise_alert('beaconing', {
                    'flow': flow_key,
                    **result
                })
    
    def _generate_report(self):
        """Generate comprehensive analysis report."""
        self._check_beaconing()
        
        # Gather flow statistics
        flow_stats = []
        for flow_key in self.flow_tracker.flows:
            stats = self.flow_tracker.get_flow_stats(flow_key)
            if stats:
                flow_stats.append(stats)
        
        # Sort by entropy (highest first)
        flow_stats.sort(key=lambda x: x.get('avg_entropy', 0), reverse=True)
        
        report = {
            'scan_time': datetime.now().isoformat(),
            'duration': round(time.time() - self.start_time, 2),
            'total_packets': self.packet_count,
            'total_flows': len(flow_stats),
            'alerts': self.alerts,
            'alert_summary': Counter(a['type'] for a in self.alerts),
            'top_entropy_flows': flow_stats[:20],
            'dns_alerts': self.dns_analyzer.alerts
        }
        
        # Save JSON
        json_path = os.path.join(self.output_dir, f"entropy-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Generate Markdown
        md_path = os.path.join(self.output_dir, f"entropy-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 📊 EntropyScope Analysis Report\n\n")
            f.write(f"**Generated:** {report['scan_time']}\n\n")
            f.write(f"| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Total Packets | {report['total_packets']:,} |\n")
            f.write(f"| Total Flows | {report['total_flows']:,} |\n")
            f.write(f"| Duration | {report['duration']}s |\n")
            f.write(f"| Alerts | {len(report['alerts'])} |\n\n")
            
            if report['alerts']:
                f.write("## 🚨 Alerts\n\n")
                f.write("| # | Severity | Type | Details |\n")
                f.write("|---|----------|------|--------|\n")
                for a in report['alerts'][:50]:
                    detail_str = json.dumps(a['details'], default=str)[:80]
                    f.write(f"| {a['id']} | {a['severity']} | {a['type']} | {detail_str} |\n")
                f.write("\n")
            
            if report['top_entropy_flows']:
                f.write("## 🔥 Top Entropy Flows\n\n")
                f.write("| Flow | Packets | Bytes | Avg Entropy | Max Entropy |\n")
                f.write("|------|---------|-------|-------------|-------------|\n")
                for fs in report['top_entropy_flows'][:15]:
                    f.write(f"| {fs['flow']} | {fs['packets']} | {fs['bytes']:,} | {fs['avg_entropy']} | {fs['max_entropy']} |\n")
                f.write("\n")
            
            f.write("---\n*Generated by NullSec EntropyScope*\n")
        
        print(f"\n✅ Analysis complete")
        print(f"   Packets: {report['total_packets']:,} | Flows: {report['total_flows']} | Alerts: {len(report['alerts'])}")
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


# ─── CLI ───────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  📊 EntropyScope v1.0                 ║
    ║  Network Traffic Entropy Analyzer     ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='EntropyScope - Network Traffic Entropy Analyzer')
    sub = parser.add_subparsers(dest='mode')
    
    # PCAP analysis
    pcap_p = sub.add_parser('pcap', help='Analyze a PCAP file')
    pcap_p.add_argument('file', help='Path to PCAP file')
    pcap_p.add_argument('-o', '--output', help='Output directory')
    
    # Live capture
    live_p = sub.add_parser('live', help='Live traffic capture')
    live_p.add_argument('-i', '--interface', default='eth0', help='Network interface')
    live_p.add_argument('-d', '--duration', type=int, default=60, help='Capture duration (seconds)')
    live_p.add_argument('-o', '--output', help='Output directory')
    
    # Entropy calculator
    calc_p = sub.add_parser('calc', help='Calculate entropy of a file')
    calc_p.add_argument('file', help='File to analyze')
    
    args = parser.parse_args()
    
    if args.mode == 'pcap':
        scope = EntropyScope(args.output)
        scope.analyze_pcap(args.file)
    
    elif args.mode == 'live':
        scope = EntropyScope(args.output)
        scope.live_capture(args.interface, args.duration)
    
    elif args.mode == 'calc':
        with open(args.file, 'rb') as f:
            data = f.read()
        ent = shannon_entropy(data)
        chi = chi_squared(data)
        print(f"File: {args.file}")
        print(f"Size: {len(data):,} bytes")
        print(f"Shannon Entropy: {ent:.6f} / 8.0 bits")
        print(f"Chi-Squared: {chi:.2f}")
        print(f"Randomness: {'HIGH' if ent > 7.5 else 'MEDIUM' if ent > 6.0 else 'LOW'}")
        print(f"Assessment: {'Likely encrypted/compressed' if ent > 7.0 else 'Structured data' if ent > 4.0 else 'Low entropy (text/sparse)'}")
    
    else:
        parser.print_help()
