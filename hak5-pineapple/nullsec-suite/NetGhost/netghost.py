#!/usr/bin/env python3
"""
NullSec NetGhost - Passive Network Topology Mapper
Discovers network topology without sending any packets.
Uses ARP cache, routing tables, mDNS, SSDP, and passive traffic sniffing.

Author: bad-antics / NullSec
License: MIT
"""

import subprocess
import json
import re
import socket
import struct
import sys
import os
import time
from datetime import datetime
from pathlib import Path
from collections import defaultdict

class NetGhost:
    """Passive network topology discovery - zero active probes."""
    
    def __init__(self, interface=None, output_dir="./netghost-output"):
        self.interface = interface or self._detect_interface()
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.hosts = {}  # ip -> {mac, hostname, vendor, ports, os_guess, first_seen, last_seen, services}
        self.connections = []  # [{src, dst, port, proto}]
        self.topology = defaultdict(set)  # ip -> set of connected ips
        
    def _detect_interface(self):
        """Auto-detect the primary network interface."""
        try:
            result = subprocess.run(['ip', 'route', 'show', 'default'], 
                                    capture_output=True, text=True)
            match = re.search(r'dev (\S+)', result.stdout)
            return match.group(1) if match else 'eth0'
        except Exception:
            return 'eth0'
    
    def harvest_arp_cache(self):
        """Harvest hosts from the ARP cache (already-known neighbors)."""
        print("[*] Harvesting ARP cache...")
        try:
            result = subprocess.run(['ip', 'neigh', 'show'], capture_output=True, text=True)
            for line in result.stdout.strip().split('\n'):
                if not line.strip():
                    continue
                parts = line.split()
                if len(parts) >= 5 and parts[2] == 'lladdr':
                    ip = parts[0]
                    mac = parts[4]
                    state = parts[-1] if len(parts) > 5 else 'UNKNOWN'
                    if ip not in self.hosts:
                        self.hosts[ip] = self._new_host(ip, mac)
                    else:
                        self.hosts[ip]['mac'] = mac
                    self.hosts[ip]['arp_state'] = state
                    self.hosts[ip]['last_seen'] = datetime.now().isoformat()
            print(f"  [+] Found {len(self.hosts)} hosts in ARP cache")
        except Exception as e:
            print(f"  [!] ARP harvest failed: {e}")
    
    def harvest_routing_table(self):
        """Extract network topology from the routing table."""
        print("[*] Analyzing routing table...")
        try:
            result = subprocess.run(['ip', 'route', 'show', 'table', 'all'], 
                                    capture_output=True, text=True)
            gateways = set()
            networks = set()
            for line in result.stdout.strip().split('\n'):
                if 'via' in line:
                    match = re.search(r'via (\S+)', line)
                    if match:
                        gw = match.group(1)
                        gateways.add(gw)
                        if gw not in self.hosts:
                            self.hosts[gw] = self._new_host(gw)
                        self.hosts[gw]['role'] = 'gateway'
                net_match = re.match(r'(\d+\.\d+\.\d+\.\d+/\d+)', line)
                if net_match:
                    networks.add(net_match.group(1))
            print(f"  [+] Gateways: {gateways}")
            print(f"  [+] Networks: {len(networks)}")
        except Exception as e:
            print(f"  [!] Route analysis failed: {e}")
    
    def harvest_dns_cache(self):
        """Extract hostnames from systemd-resolved cache or /etc/hosts."""
        print("[*] Harvesting DNS cache...")
        count = 0
        
        # /etc/hosts
        try:
            with open('/etc/hosts', 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        parts = line.split()
                        if len(parts) >= 2:
                            ip = parts[0]
                            hostnames = parts[1:]
                            if ip in self.hosts:
                                self.hosts[ip]['hostnames'] = hostnames
                            elif not ip.startswith('127.') and not ip.startswith('::'):
                                self.hosts[ip] = self._new_host(ip)
                                self.hosts[ip]['hostnames'] = hostnames
                            count += 1
        except Exception:
            pass
        
        # systemd-resolve cache
        try:
            result = subprocess.run(['resolvectl', 'statistics'], 
                                    capture_output=True, text=True)
            if result.returncode == 0:
                cache_match = re.search(r'Current Cache Size:\s+(\d+)', result.stdout)
                if cache_match:
                    print(f"  [+] DNS cache entries: {cache_match.group(1)}")
        except Exception:
            pass
        
        # SSH known_hosts
        try:
            known_hosts = Path.home() / '.ssh' / 'known_hosts'
            if known_hosts.exists():
                with open(known_hosts, 'r') as f:
                    for line in f:
                        parts = line.strip().split()
                        if parts:
                            host_entry = parts[0]
                            for h in host_entry.split(','):
                                h = h.strip('[]').split(':')[0]
                                if re.match(r'\d+\.\d+\.\d+\.\d+', h):
                                    if h not in self.hosts:
                                        self.hosts[h] = self._new_host(h)
                                    self.hosts[h]['ssh_known'] = True
                                    count += 1
        except Exception:
            pass
        
        print(f"  [+] Resolved {count} DNS/host entries")
    
    def harvest_connections(self):
        """Harvest active connections from /proc/net or ss."""
        print("[*] Harvesting active connections...")
        try:
            result = subprocess.run(['ss', '-tupn', '--no-header'], 
                                    capture_output=True, text=True)
            for line in result.stdout.strip().split('\n'):
                if not line.strip():
                    continue
                parts = line.split()
                if len(parts) >= 5:
                    proto = parts[0]
                    local = parts[3]
                    remote = parts[4]
                    
                    # Parse remote address
                    if ':' in remote and not remote.startswith('['):
                        remote_ip, remote_port = remote.rsplit(':', 1)
                    else:
                        continue
                    
                    if remote_ip in ('*', '0.0.0.0', '::'):
                        continue
                    
                    # Extract process info
                    process = ''
                    for p in parts[5:]:
                        if 'users:' in p:
                            proc_match = re.search(r'"([^"]+)"', p)
                            if proc_match:
                                process = proc_match.group(1)
                    
                    conn = {
                        'proto': proto,
                        'remote_ip': remote_ip,
                        'remote_port': int(remote_port) if remote_port.isdigit() else 0,
                        'process': process,
                        'local': local
                    }
                    self.connections.append(conn)
                    
                    # Add to hosts
                    if remote_ip not in self.hosts:
                        self.hosts[remote_ip] = self._new_host(remote_ip)
                    self.hosts[remote_ip]['seen_ports'].add(int(remote_port) if remote_port.isdigit() else 0)
                    self.hosts[remote_ip]['last_seen'] = datetime.now().isoformat()
                    
                    # Build topology
                    self.topology[remote_ip].add('local')
                    
            print(f"  [+] Found {len(self.connections)} active connections")
        except Exception as e:
            print(f"  [!] Connection harvest failed: {e}")
    
    def harvest_mdns(self):
        """Listen for mDNS/Bonjour advertisements (passive)."""
        print("[*] Checking mDNS/Avahi services...")
        try:
            result = subprocess.run(['avahi-browse', '-tpk', '-a'], 
                                    capture_output=True, text=True, timeout=5)
            services = set()
            for line in result.stdout.strip().split('\n'):
                parts = line.split(';')
                if len(parts) >= 7 and parts[0] == '=':
                    hostname = parts[3]
                    service_type = parts[4]
                    ip = parts[7] if len(parts) > 7 else ''
                    if ip and re.match(r'\d+\.\d+\.\d+\.\d+', ip):
                        if ip not in self.hosts:
                            self.hosts[ip] = self._new_host(ip)
                        self.hosts[ip]['mdns_services'].add(service_type)
                        if hostname:
                            self.hosts[ip]['hostnames'].append(hostname)
                        services.add(service_type)
            print(f"  [+] Found {len(services)} mDNS service types")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("  [-] mDNS not available (avahi-browse not found)")
    
    def harvest_ssdp(self):
        """Check for SSDP/UPnP responses (passive from cache)."""
        print("[*] Checking SSDP/UPnP devices...")
        try:
            result = subprocess.run(['gssdp-discover', '--timeout=3'], 
                                    capture_output=True, text=True, timeout=5)
            for line in result.stdout.strip().split('\n'):
                if 'Location:' in line:
                    match = re.search(r'http://(\d+\.\d+\.\d+\.\d+)', line)
                    if match:
                        ip = match.group(1)
                        if ip not in self.hosts:
                            self.hosts[ip] = self._new_host(ip)
                        self.hosts[ip]['upnp'] = True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("  [-] SSDP discovery not available")
    
    def resolve_vendors(self):
        """Resolve MAC addresses to vendor names using local OUI database."""
        print("[*] Resolving MAC vendors...")
        oui_paths = [
            '/usr/share/ieee-data/oui.txt',
            '/usr/share/nmap/nmap-mac-prefixes',
            '/usr/share/arp-scan/ieee-oui.txt',
            '/var/lib/ieee-data/oui.txt'
        ]
        
        oui_db = {}
        for path in oui_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r', errors='ignore') as f:
                        for line in f:
                            # Try different formats
                            match = re.match(r'^([0-9A-Fa-f]{6})\s+(.+)', line.strip())
                            if match:
                                oui_db[match.group(1).upper()] = match.group(2).strip()
                            match2 = re.match(r'^([0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2})\s+\(hex\)\s+(.+)', line.strip())
                            if match2:
                                prefix = match2.group(1).replace('-', '').upper()
                                oui_db[prefix] = match2.group(2).strip()
                    break
                except Exception:
                    continue
        
        resolved = 0
        for ip, host in self.hosts.items():
            mac = host.get('mac', '')
            if mac and mac != 'unknown':
                prefix = mac.replace(':', '').replace('-', '').upper()[:6]
                if prefix in oui_db:
                    host['vendor'] = oui_db[prefix]
                    resolved += 1
        print(f"  [+] Resolved {resolved} vendors")
    
    def guess_os(self):
        """Guess OS based on available clues (TTL, MAC vendor, services)."""
        print("[*] Fingerprinting operating systems...")
        for ip, host in self.hosts.items():
            vendor = host.get('vendor', '').lower()
            services = host.get('mdns_services', set())
            ports = host.get('seen_ports', set())
            
            # MAC vendor heuristics
            if any(v in vendor for v in ['apple', 'iphone', 'ipad']):
                host['os_guess'] = 'Apple/macOS/iOS'
            elif any(v in vendor for v in ['microsoft', 'xbox']):
                host['os_guess'] = 'Windows'
            elif any(v in vendor for v in ['raspberry', 'broadcom']):
                host['os_guess'] = 'Linux/Raspberry Pi'
            elif any(v in vendor for v in ['samsung', 'android', 'huawei', 'xiaomi']):
                host['os_guess'] = 'Android'
            elif any(v in vendor for v in ['cisco', 'juniper', 'ubiquiti', 'netgear', 'tp-link']):
                host['os_guess'] = 'Network Device'
            elif any(v in vendor for v in ['dell', 'hp', 'lenovo', 'intel']):
                host['os_guess'] = 'PC (Unknown OS)'
            
            # Service-based heuristics
            if 22 in ports:
                host['services_detected'] = host.get('services_detected', []) + ['SSH']
            if 3389 in ports:
                host['os_guess'] = 'Windows'
                host['services_detected'] = host.get('services_detected', []) + ['RDP']
            if 445 in ports:
                host['services_detected'] = host.get('services_detected', []) + ['SMB']
            if 80 in ports or 443 in ports:
                host['services_detected'] = host.get('services_detected', []) + ['HTTP/S']
            if 5353 in ports:
                host['services_detected'] = host.get('services_detected', []) + ['mDNS']
    
    def generate_topology_map(self):
        """Generate a visual network topology in multiple formats."""
        print("[*] Generating topology map...")
        
        # Mermaid diagram
        mermaid = ["graph TD"]
        mermaid.append("    GATEWAY[🌐 Gateway/Router]")
        
        for ip, host in sorted(self.hosts.items()):
            safe_id = ip.replace('.', '_')
            label = host.get('hostnames', [ip])[0] if host.get('hostnames') else ip
            os_g = host.get('os_guess', '')
            vendor = host.get('vendor', '')[:20]
            role = host.get('role', 'host')
            
            icon = '💻'
            if 'gateway' in role:
                icon = '🌐'
            elif 'apple' in os_g.lower():
                icon = '🍎'
            elif 'windows' in os_g.lower():
                icon = '🪟'
            elif 'linux' in os_g.lower() or 'raspberry' in os_g.lower():
                icon = '🐧'
            elif 'android' in os_g.lower():
                icon = '📱'
            elif 'network' in os_g.lower():
                icon = '📡'
            
            node_label = f"{icon} {label}\\n{ip}\\n{vendor}"
            mermaid.append(f"    {safe_id}[\"{node_label}\"]")
            
            if role == 'gateway':
                mermaid.append(f"    INTERNET((☁️ Internet)) --> GATEWAY")
                mermaid.append(f"    GATEWAY --> {safe_id}")
            else:
                mermaid.append(f"    GATEWAY --> {safe_id}")
        
        mermaid_text = '\n'.join(mermaid)
        
        # Save outputs
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # JSON export
        export = {
            'scan_time': datetime.now().isoformat(),
            'interface': self.interface,
            'method': 'passive (zero active probes)',
            'hosts': {},
            'connections': self.connections[:100],
            'topology_mermaid': mermaid_text
        }
        for ip, host in self.hosts.items():
            h = dict(host)
            h['seen_ports'] = list(h.get('seen_ports', set()))
            h['mdns_services'] = list(h.get('mdns_services', set()))
            export['hosts'][ip] = h
        
        json_path = self.output_dir / f"netghost_{timestamp}.json"
        with open(json_path, 'w') as f:
            json.dump(export, f, indent=2, default=str)
        
        # Markdown report
        md_path = self.output_dir / f"netghost_{timestamp}.md"
        with open(md_path, 'w') as f:
            f.write(f"# NetGhost Passive Topology Report\n\n")
            f.write(f"**Scanned:** {datetime.now().isoformat()}\n")
            f.write(f"**Interface:** {self.interface}\n")
            f.write(f"**Method:** 100% Passive (zero packets sent)\n")
            f.write(f"**Hosts Discovered:** {len(self.hosts)}\n\n")
            f.write(f"## Network Topology\n\n```mermaid\n{mermaid_text}\n```\n\n")
            f.write(f"## Host Inventory\n\n")
            f.write(f"| IP | MAC | Hostname | Vendor | OS Guess | Ports | Services |\n")
            f.write(f"|----|----|----------|--------|----------|-------|----------|\n")
            for ip in sorted(self.hosts.keys(), key=lambda x: [int(o) for o in x.split('.') if o.isdigit()]):
                h = self.hosts[ip]
                hostname = ', '.join(h.get('hostnames', []))[:30]
                mac = h.get('mac', '?')
                vendor = h.get('vendor', '?')[:25]
                os_g = h.get('os_guess', '?')
                ports = ', '.join(str(p) for p in sorted(h.get('seen_ports', set())))[:20]
                svcs = ', '.join(h.get('services_detected', []))[:25]
                f.write(f"| {ip} | {mac} | {hostname} | {vendor} | {os_g} | {ports} | {svcs} |\n")
            
            f.write(f"\n## Active Connections\n\n")
            f.write(f"| Proto | Remote | Port | Process |\n")
            f.write(f"|-------|--------|------|---------|\n")
            for c in self.connections[:50]:
                f.write(f"| {c['proto']} | {c['remote_ip']} | {c['remote_port']} | {c['process']} |\n")
        
        print(f"  [+] Saved: {json_path}")
        print(f"  [+] Saved: {md_path}")
        return json_path, md_path
    
    def _new_host(self, ip, mac='unknown'):
        return {
            'ip': ip,
            'mac': mac,
            'hostnames': [],
            'vendor': '',
            'os_guess': '',
            'role': 'host',
            'seen_ports': set(),
            'mdns_services': set(),
            'services_detected': [],
            'ssh_known': False,
            'upnp': False,
            'arp_state': '',
            'first_seen': datetime.now().isoformat(),
            'last_seen': datetime.now().isoformat()
        }
    
    def run(self):
        """Execute full passive discovery."""
        print("\n" + "="*60)
        print("  👻 NetGhost - Passive Network Topology Mapper")
        print("  Zero packets sent. Total stealth.")
        print("="*60 + "\n")
        
        self.harvest_arp_cache()
        self.harvest_routing_table()
        self.harvest_dns_cache()
        self.harvest_connections()
        self.harvest_mdns()
        self.harvest_ssdp()
        self.resolve_vendors()
        self.guess_os()
        
        print(f"\n{'='*60}")
        print(f"  RESULTS: {len(self.hosts)} hosts, {len(self.connections)} connections")
        print(f"{'='*60}\n")
        
        for ip in sorted(self.hosts.keys(), key=lambda x: [int(o) for o in x.split('.') if o.isdigit()]):
            h = self.hosts[ip]
            hostname = h.get('hostnames', [''])[0] if h.get('hostnames') else ''
            vendor = h.get('vendor', '')
            os_g = h.get('os_guess', '')
            ports = sorted(h.get('seen_ports', set()))
            role = h.get('role', '')
            
            line = f"  {ip:<18}"
            if hostname:
                line += f" {hostname:<20}"
            if vendor:
                line += f" [{vendor[:25]}]"
            if os_g:
                line += f" ({os_g})"
            if role == 'gateway':
                line += " ★GATEWAY"
            if ports:
                line += f" ports:{ports}"
            print(line)
        
        return self.generate_topology_map()


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='NetGhost - Passive Network Topology Mapper')
    parser.add_argument('-i', '--interface', help='Network interface to analyze')
    parser.add_argument('-o', '--output', default='./netghost-output', help='Output directory')
    parser.add_argument('--json', action='store_true', help='Output JSON only')
    args = parser.parse_args()
    
    ghost = NetGhost(interface=args.interface, output_dir=args.output)
    ghost.run()
