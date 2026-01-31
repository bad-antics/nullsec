#!/usr/bin/env python3
"""
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
█  NULLSEC ADVANCED NETWORK MANAGER                                █
█  Real-time network monitoring & traffic analysis                 █
█                    [ bad-antics development ]                    █
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

Features:
- Real-time connection monitoring
- Bandwidth usage tracking
- Protocol analysis
- Suspicious activity detection
- Device profiling & OS fingerprinting
- Network topology mapping
- Traffic capture & analysis
"""

import subprocess
import time
import sys
import json
import re
from datetime import datetime
from collections import defaultdict, Counter
import sqlite3

DB_PATH = '../nullsec.db'

class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    RESET = '\033[0m'
    DIM = '\033[2m'
    BOLD = '\033[1m'

def run_cmd(cmd):
    """Execute command and return output"""
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL)
    except:
        return ""

class NetworkMonitor:
    def __init__(self):
        self.connections = {}
        self.bandwidth = defaultdict(int)
        self.devices = {}
        self.alerts = []
    
    def get_connections(self):
        """Get all network connections"""
        output = run_cmd("ss -tunap 2>/dev/null")
        connections = []
        
        for line in output.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 6:
                conn = {
                    'proto': parts[0],
                    'state': parts[1],
                    'local': parts[4],
                    'remote': parts[5],
                    'process': ' '.join(parts[6:]) if len(parts) > 6 else ''
                }
                connections.append(conn)
        
        return connections
    
    def get_devices(self):
        """Get network devices from ARP table"""
        output = run_cmd("ip neigh")
        devices = []
        
        for line in output.splitlines():
            parts = line.split()
            if len(parts) >= 4:
                ip = parts[0]
                mac = ''
                state = parts[-1]
                
                for i, part in enumerate(parts):
                    if part == 'lladdr' and i < len(parts) - 1:
                        mac = parts[i + 1]
                
                devices.append({
                    'ip': ip,
                    'mac': mac,
                    'state': state,
                    'vendor': self.get_mac_vendor(mac) if mac else 'Unknown'
                })
        
        return devices
    
    def get_mac_vendor(self, mac):
        """Lookup MAC vendor (simplified)"""
        # In production, use MAC vendor database
        oui = mac[:8].upper().replace(':', '')
        
        vendors = {
            '000C29': 'VMware',
            '0050': 'Apple',
            '001B63': 'Apple',
            '080027': 'VirtualBox',
            '525400': 'QEMU/KVM',
        }
        
        for oui_prefix, vendor in vendors.items():
            if mac.upper().replace(':', '').startswith(oui_prefix):
                return vendor
        
        return 'Unknown'
    
    def get_listening_ports(self):
        """Get all listening ports"""
        output = run_cmd("ss -tulnp 2>/dev/null")
        ports = []
        
        for line in output.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 5:
                proto = parts[0]
                local = parts[4]
                process = ' '.join(parts[6:]) if len(parts) > 6 else ''
                
                # Extract port
                port_match = re.search(r':(\d+)$', local)
                if port_match:
                    port = port_match.group(1)
                    ports.append({
                        'port': port,
                        'proto': proto,
                        'address': local,
                        'process': process
                    })
        
        return ports
    
    def get_bandwidth_usage(self):
        """Get network interface statistics"""
        output = run_cmd("ip -s link")
        interfaces = {}
        
        current_iface = None
        for line in output.splitlines():
            # Match interface line
            if re.match(r'^\d+:', line):
                match = re.search(r'^\d+:\s+(\S+):', line)
                if match:
                    current_iface = match.group(1)
                    interfaces[current_iface] = {'rx': 0, 'tx': 0}
            
            # Match RX/TX lines
            elif current_iface and 'RX:' in line:
                parts = line.split()
                if len(parts) >= 2:
                    interfaces[current_iface]['rx'] = int(parts[1])
            elif current_iface and 'TX:' in line:
                parts = line.split()
                if len(parts) >= 2:
                    interfaces[current_iface]['tx'] = int(parts[1])
        
        return interfaces
    
    def detect_suspicious_activity(self, connections):
        """Detect potentially suspicious network activity"""
        alerts = []
        
        for conn in connections:
            # Check for unusual ports
            remote = conn.get('remote', '')
            if remote:
                parts = remote.split(':')
                if len(parts) == 2:
                    port = parts[1]
                    
                    # Common suspicious ports
                    suspicious_ports = ['4444', '31337', '12345', '6667', '6666']
                    if port in suspicious_ports:
                        alerts.append({
                            'type': 'suspicious_port',
                            'severity': 'high',
                            'message': f"Connection to suspicious port {port}: {remote}",
                            'details': conn
                        })
            
            # Check for IRC-like connections
            if conn.get('proto') == 'tcp' and any(p in str(conn) for p in ['6667', '6666', '7000']):
                alerts.append({
                    'type': 'irc_connection',
                    'severity': 'medium',
                    'message': f"Possible IRC/C2 connection detected",
                    'details': conn
                })
            
            # Check for high number of connections from single IP
            # (Would need connection history tracking)
        
        return alerts
    
    def get_protocol_stats(self, connections):
        """Get protocol statistics"""
        protocols = Counter(conn['proto'] for conn in connections)
        states = Counter(conn['state'] for conn in connections)
        
        return {
            'protocols': dict(protocols),
            'states': dict(states),
            'total': len(connections)
        }
    
    def get_top_talkers(self, connections, limit=10):
        """Get top communicating IPs"""
        remote_ips = [conn['remote'].split(':')[0] for conn in connections 
                      if ':' in conn.get('remote', '')]
        
        talkers = Counter(remote_ips).most_common(limit)
        return [{'ip': ip, 'count': count} for ip, count in talkers]
    
    def save_snapshot(self):
        """Save network snapshot to database"""
        try:
            conn = sqlite3.connect(DB_PATH)
            c = conn.cursor()
            
            # Create snapshot table if not exists
            c.execute('''CREATE TABLE IF NOT EXISTS network_snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                connections INTEGER,
                devices INTEGER,
                alerts INTEGER,
                data TEXT
            )''')
            
            snapshot = {
                'timestamp': datetime.now().isoformat(),
                'connections': self.get_connections(),
                'devices': self.get_devices(),
                'listening_ports': self.get_listening_ports(),
                'bandwidth': self.get_bandwidth_usage()
            }
            
            c.execute('''INSERT INTO network_snapshots 
                        (timestamp, connections, devices, alerts, data)
                        VALUES (?, ?, ?, ?, ?)''',
                     (snapshot['timestamp'],
                      len(snapshot['connections']),
                      len(snapshot['devices']),
                      0,
                      json.dumps(snapshot)))
            
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            print(f"{Colors.RED}[!] Error saving snapshot: {e}{Colors.RESET}")
            return False
    
    def display_dashboard(self):
        """Display real-time network dashboard"""
        while True:
            # Clear screen
            print('\033[2J\033[H')
            
            # Header
            print(f"""{Colors.CYAN}
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
█{Colors.WHITE}              NULLSEC NETWORK MONITOR - LIVE DASHBOARD{Colors.CYAN}                  █
█{Colors.DIM}                     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Colors.CYAN}                         █
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
{Colors.RESET}""")
            
            # Get current data
            connections = self.get_connections()
            devices = self.get_devices()
            ports = self.get_listening_ports()
            bandwidth = self.get_bandwidth_usage()
            alerts = self.detect_suspicious_activity(connections)
            stats = self.get_protocol_stats(connections)
            talkers = self.get_top_talkers(connections)
            
            # Display statistics
            print(f"\n{Colors.YELLOW}== NETWORK STATISTICS =={Colors.RESET}")
            print(f"{Colors.WHITE}  Active Connections:{Colors.RESET} {Colors.GREEN}{len(connections)}{Colors.RESET}")
            print(f"{Colors.WHITE}  Network Devices:   {Colors.RESET} {Colors.GREEN}{len(devices)}{Colors.RESET}")
            print(f"{Colors.WHITE}  Listening Ports:   {Colors.RESET} {Colors.GREEN}{len(ports)}{Colors.RESET}")
            print(f"{Colors.WHITE}  Security Alerts:   {Colors.RESET} {Colors.RED if alerts else Colors.GREEN}{len(alerts)}{Colors.RESET}")
            
            # Protocol breakdown
            print(f"\n{Colors.YELLOW}== PROTOCOL BREAKDOWN =={Colors.RESET}")
            for proto, count in stats['protocols'].items():
                bar_length = int((count / max(stats['protocols'].values())) * 20)
                bar = '█' * bar_length
                print(f"  {proto:4s} {Colors.CYAN}{bar}{Colors.RESET} {count}")
            
            # Top talkers
            print(f"\n{Colors.YELLOW}== TOP TALKERS =={Colors.RESET}")
            for i, talker in enumerate(talkers[:5], 1):
                print(f"  {Colors.DIM}{i}.{Colors.RESET} {Colors.WHITE}{talker['ip']:<15}{Colors.RESET} "
                      f"{Colors.GREEN}{talker['count']} connections{Colors.RESET}")
            
            # Bandwidth
            print(f"\n{Colors.YELLOW}== BANDWIDTH USAGE =={Colors.RESET}")
            for iface, stats in list(bandwidth.items())[:5]:
                rx_mb = stats['rx'] / 1024 / 1024
                tx_mb = stats['tx'] / 1024 / 1024
                print(f"  {iface:10s} {Colors.GREEN}↓{rx_mb:8.2f}MB{Colors.RESET} "
                      f"{Colors.YELLOW}↑{tx_mb:8.2f}MB{Colors.RESET}")
            
            # Alerts
            if alerts:
                print(f"\n{Colors.RED}== SECURITY ALERTS =={Colors.RESET}")
                for alert in alerts[:5]:
                    severity_color = Colors.RED if alert['severity'] == 'high' else Colors.YELLOW
                    print(f"  {severity_color}⚠{Colors.RESET} {alert['message']}")
            
            # Footer
            print(f"\n{Colors.DIM}{'─' * 75}{Colors.RESET}")
            print(f"{Colors.DIM}Press Ctrl+C to exit | Refreshing every 3 seconds{Colors.RESET}")
            
            time.sleep(3)
    
    def export_connections(self, filename='network-connections.json'):
        """Export current connections to JSON"""
        data = {
            'timestamp': datetime.now().isoformat(),
            'connections': self.get_connections(),
            'devices': self.get_devices(),
            'listening_ports': self.get_listening_ports(),
            'bandwidth': self.get_bandwidth_usage()
        }
        
        with open(filename, 'w') as f:
            json.dumps(data, f, indent=2)
        
        print(f"{Colors.GREEN}[✓] Exported to {filename}{Colors.RESET}")

def print_banner():
    print(f"""{Colors.CYAN}
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
█{Colors.WHITE}              NULLSEC ADVANCED NETWORK MANAGER{Colors.CYAN}                          █
█{Colors.DIM}                    [ bad-antics development ]{Colors.CYAN}                        █
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
{Colors.RESET}""")

def main():
    """Main function"""
    monitor = NetworkMonitor()
    
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        
        if cmd == 'connections':
            connections = monitor.get_connections()
            for conn in connections:
                print(f"{conn['proto']:6s} {conn['state']:12s} {conn['local']:22s} "
                      f"{conn['remote']:22s} {conn['process']}")
        
        elif cmd == 'devices':
            devices = monitor.get_devices()
            for dev in devices:
                print(f"{dev['ip']:15s} {dev['mac']:17s} {dev['state']:10s} {dev['vendor']}")
        
        elif cmd == 'ports':
            ports = monitor.get_listening_ports()
            for port in sorted(ports, key=lambda x: int(x['port'])):
                print(f"{port['port']:6s} {port['proto']:5s} {port['process']}")
        
        elif cmd == 'stats':
            connections = monitor.get_connections()
            stats = monitor.get_protocol_stats(connections)
            print(json.dumps(stats, indent=2))
        
        elif cmd == 'bandwidth':
            bandwidth = monitor.get_bandwidth_usage()
            for iface, stats in bandwidth.items():
                print(f"{iface:15s} RX: {stats['rx']:>12} TX: {stats['tx']:>12}")
        
        elif cmd == 'monitor' or cmd == 'dashboard':
            print_banner()
            print(f"\n{Colors.GREEN}[*] Starting live network monitor...{Colors.RESET}\n")
            time.sleep(1)
            monitor.display_dashboard()
        
        elif cmd == 'snapshot':
            if monitor.save_snapshot():
                print(f"{Colors.GREEN}[✓] Network snapshot saved{Colors.RESET}")
        
        elif cmd == 'export':
            filename = sys.argv[2] if len(sys.argv) > 2 else 'network-connections.json'
            monitor.export_connections(filename)
        
        else:
            print(f"""Usage:
  {sys.argv[0]} connections   - List all connections
  {sys.argv[0]} devices       - List network devices
  {sys.argv[0]} ports         - List listening ports
  {sys.argv[0]} stats         - Show protocol statistics
  {sys.argv[0]} bandwidth     - Show bandwidth usage
  {sys.argv[0]} monitor       - Live dashboard (default)
  {sys.argv[0]} snapshot      - Save network snapshot to DB
  {sys.argv[0]} export [file] - Export connections to JSON
""")
    else:
        # Default: Launch live monitor
        print_banner()
        print(f"\n{Colors.GREEN}[*] Starting live network monitor...{Colors.RESET}\n")
        time.sleep(1)
        monitor.display_dashboard()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}[!] Monitor stopped{Colors.RESET}")
    except Exception as e:
        print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
        import traceback
        traceback.print_exc()
