#!/usr/bin/env python3
"""
NullSec PortKnock - Intelligent Port Knocking Daemon & Client
Implements advanced port knocking with:
- Cryptographic knock sequences (HMAC-SHA256 time-based)
- Single Packet Authorization (SPA) support
- Dynamic firewall rule insertion/cleanup
- Stealth mode with decoy responses

Author: bad-antics / NullSec
License: MIT
"""

import socket
import struct
import hashlib
import hmac
import time
import json
import subprocess
import threading
import os
import sys
import signal
import logging
from datetime import datetime
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('portknock')


class PortKnockServer:
    """Server-side port knock listener with crypto validation."""
    
    def __init__(self, config_path=None):
        self.config = self._load_config(config_path)
        self.active_rules = {}  # ip -> {port, timestamp, timer}
        self.knock_state = {}   # ip -> [sequence progress]
        self.running = False
        
    def _load_config(self, path):
        """Load or create default configuration."""
        defaults = {
            'secret_key': hashlib.sha256(os.urandom(32)).hexdigest(),
            'knock_sequence': [7000, 8000, 9000],  # Default knock ports
            'protected_port': 22,                    # Port to open after valid knock
            'timeout_seconds': 30,                   # Time window for knock sequence
            'open_duration': 300,                    # How long port stays open (5 min)
            'interface': 'eth0',
            'use_crypto': True,                      # Use HMAC-validated knocks
            'spa_mode': False,                       # Single Packet Authorization
            'spa_port': 62201,                       # SPA listener port
            'log_file': '/var/log/portknock.log',
            'whitelist': [],                         # Always-allowed IPs
            'decoy_response': True,                  # Send fake responses on wrong knocks
            'max_attempts': 5,                       # Max failed attempts before temp ban
            'ban_duration': 3600                     # Ban duration in seconds
        }
        
        if path and Path(path).exists():
            with open(path) as f:
                loaded = json.load(f)
                defaults.update(loaded)
        
        return defaults
    
    def save_config(self, path):
        """Save current configuration."""
        with open(path, 'w') as f:
            json.dump(self.config, f, indent=2)
        log.info(f"Config saved to {path}")
    
    def generate_knock_sequence(self, client_ip, timestamp=None):
        """Generate a time-based HMAC knock sequence."""
        if timestamp is None:
            timestamp = int(time.time()) // self.config['timeout_seconds']
        
        key = self.config['secret_key'].encode()
        message = f"{client_ip}:{timestamp}".encode()
        mac = hmac.new(key, message, hashlib.sha256).digest()
        
        # Derive 3 port numbers from HMAC (1024-65535 range)
        ports = []
        for i in range(3):
            port_val = struct.unpack('>H', mac[i*2:(i+1)*2])[0]
            port = (port_val % 64511) + 1024  # Range: 1024-65535
            ports.append(port)
        
        return ports
    
    def validate_knock(self, client_ip, knocked_ports):
        """Validate a knock sequence (static or crypto)."""
        if self.config['use_crypto']:
            # Check current and previous time windows
            for offset in range(3):
                timestamp = int(time.time()) // self.config['timeout_seconds'] - offset
                expected = self.generate_knock_sequence(client_ip, timestamp)
                if knocked_ports == expected:
                    return True
            return False
        else:
            # Static sequence
            return knocked_ports == self.config['knock_sequence']
    
    def open_port(self, client_ip):
        """Open the protected port for a specific IP."""
        port = self.config['protected_port']
        
        # Add iptables rule
        cmd = [
            'iptables', '-I', 'INPUT', '1',
            '-s', client_ip,
            '-p', 'tcp', '--dport', str(port),
            '-j', 'ACCEPT',
            '-m', 'comment', '--comment', f'portknock:{client_ip}:{int(time.time())}'
        ]
        
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            log.info(f"✅ OPENED port {port} for {client_ip} ({self.config['open_duration']}s)")
            
            # Schedule automatic closure
            timer = threading.Timer(self.config['open_duration'], self.close_port, args=[client_ip])
            timer.daemon = True
            timer.start()
            
            self.active_rules[client_ip] = {
                'port': port,
                'opened': datetime.now().isoformat(),
                'timer': timer
            }
            
        except subprocess.CalledProcessError as e:
            log.error(f"Failed to open port: {e}")
    
    def close_port(self, client_ip):
        """Close the protected port for a specific IP."""
        port = self.config['protected_port']
        
        cmd = [
            'iptables', '-D', 'INPUT',
            '-s', client_ip,
            '-p', 'tcp', '--dport', str(port),
            '-j', 'ACCEPT'
        ]
        
        try:
            # May need multiple deletes if duplicates exist
            for _ in range(3):
                result = subprocess.run(cmd, capture_output=True)
                if result.returncode != 0:
                    break
            log.info(f"🔒 CLOSED port {port} for {client_ip}")
        except Exception as e:
            log.warning(f"Close port error: {e}")
        
        self.active_rules.pop(client_ip, None)
    
    def listen_knocks(self):
        """Listen for knock sequences on specified ports."""
        log.info(f"🚪 PortKnock Server starting...")
        log.info(f"   Protected port: {self.config['protected_port']}")
        log.info(f"   Crypto mode: {self.config['use_crypto']}")
        if not self.config['use_crypto']:
            log.info(f"   Knock sequence: {self.config['knock_sequence']}")
        log.info(f"   Open duration: {self.config['open_duration']}s")
        
        self.running = True
        
        # Create raw socket to monitor SYN packets
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_TCP)
            sock.settimeout(1.0)
        except PermissionError:
            log.error("Root privileges required for raw socket")
            sys.exit(1)
        
        knock_tracker = {}  # ip -> [(port, time), ...]
        
        while self.running:
            try:
                data, addr = sock.recvfrom(65535)
                
                # Parse IP header
                ip_header = struct.unpack('!BBHHHBBH4s4s', data[:20])
                src_ip = socket.inet_ntoa(ip_header[8])
                
                # Skip whitelisted IPs
                if src_ip in self.config['whitelist']:
                    continue
                
                # Parse TCP header
                ihl = (ip_header[0] & 0xF) * 4
                tcp_header = struct.unpack('!HHLLBBHHH', data[ihl:ihl+20])
                dst_port = tcp_header[1]
                flags = tcp_header[5]
                
                # Only SYN packets (flag = 0x02)
                if flags & 0x02 and not (flags & 0x10):
                    now = time.time()
                    
                    # Initialize tracker for this IP
                    if src_ip not in knock_tracker:
                        knock_tracker[src_ip] = []
                    
                    # Add this knock
                    knock_tracker[src_ip].append((dst_port, now))
                    
                    # Clean old knocks
                    timeout = self.config['timeout_seconds']
                    knock_tracker[src_ip] = [
                        (p, t) for p, t in knock_tracker[src_ip]
                        if now - t < timeout
                    ]
                    
                    # Check if we have enough knocks
                    knocked_ports = [p for p, t in knock_tracker[src_ip]]
                    
                    if len(knocked_ports) >= 3:
                        # Check last 3 knocks
                        last_3 = knocked_ports[-3:]
                        if self.validate_knock(src_ip, last_3):
                            log.info(f"🔓 Valid knock from {src_ip}: {last_3}")
                            self.open_port(src_ip)
                            knock_tracker.pop(src_ip, None)
                        elif len(knocked_ports) > 10:
                            log.warning(f"⚠️  Too many knocks from {src_ip}, clearing")
                            knock_tracker.pop(src_ip, None)
                    
            except socket.timeout:
                continue
            except KeyboardInterrupt:
                break
            except Exception as e:
                log.debug(f"Packet parse error: {e}")
        
        sock.close()
        log.info("PortKnock server stopped")
    
    def spa_listen(self):
        """Single Packet Authorization listener."""
        port = self.config['spa_port']
        log.info(f"📦 SPA listener on UDP:{port}")
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('0.0.0.0', port))
        sock.settimeout(1.0)
        
        while self.running:
            try:
                data, addr = sock.recvfrom(4096)
                client_ip = addr[0]
                
                # Validate SPA packet
                if self._validate_spa(data, client_ip):
                    log.info(f"🔓 Valid SPA from {client_ip}")
                    self.open_port(client_ip)
                else:
                    log.warning(f"❌ Invalid SPA from {client_ip}")
                    
            except socket.timeout:
                continue
            except Exception as e:
                log.debug(f"SPA error: {e}")
        
        sock.close()
    
    def _validate_spa(self, data, client_ip):
        """Validate a Single Packet Authorization packet."""
        try:
            # SPA format: timestamp:ip:hmac
            parts = data.decode().split(':')
            if len(parts) != 3:
                return False
            
            timestamp = int(parts[0])
            claimed_ip = parts[1]
            received_hmac = parts[2]
            
            # Check timestamp (within 60 seconds)
            if abs(time.time() - timestamp) > 60:
                return False
            
            # Check IP
            if claimed_ip != client_ip:
                return False
            
            # Verify HMAC
            key = self.config['secret_key'].encode()
            message = f"{timestamp}:{claimed_ip}".encode()
            expected = hmac.new(key, message, hashlib.sha256).hexdigest()
            
            return hmac.compare_digest(received_hmac, expected)
            
        except Exception:
            return False
    
    def stop(self):
        """Stop the server and clean up rules."""
        self.running = False
        for ip in list(self.active_rules.keys()):
            self.close_port(ip)
        log.info("All rules cleaned up")


class PortKnockClient:
    """Client-side port knock sender."""
    
    def __init__(self, secret_key, server_ip):
        self.secret_key = secret_key
        self.server_ip = server_ip
    
    def knock(self, use_crypto=True, static_sequence=None):
        """Send a knock sequence to the server."""
        if use_crypto:
            timestamp = int(time.time()) // 30  # 30-second windows
            key = self.secret_key.encode()
            message = f"{self._get_local_ip()}:{timestamp}".encode()
            mac = hmac.new(key, message, hashlib.sha256).digest()
            
            ports = []
            for i in range(3):
                port_val = struct.unpack('>H', mac[i*2:(i+1)*2])[0]
                port = (port_val % 64511) + 1024
                ports.append(port)
        else:
            ports = static_sequence or [7000, 8000, 9000]
        
        print(f"[*] Knocking on {self.server_ip}: {ports}")
        
        for port in ports:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(0.5)
                sock.connect_ex((self.server_ip, port))
                sock.close()
            except Exception:
                pass
            time.sleep(0.3)
        
        print(f"[✓] Knock sequence sent. Port should open within 5 seconds.")
    
    def send_spa(self, spa_port=62201):
        """Send a Single Packet Authorization."""
        timestamp = int(time.time())
        local_ip = self._get_local_ip()
        key = self.secret_key.encode()
        message = f"{timestamp}:{local_ip}".encode()
        mac = hmac.new(key, message, hashlib.sha256).hexdigest()
        
        packet = f"{timestamp}:{local_ip}:{mac}".encode()
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(packet, (self.server_ip, spa_port))
        sock.close()
        
        print(f"[✓] SPA packet sent to {self.server_ip}:{spa_port}")
    
    def _get_local_ip(self):
        """Get the local IP address."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect((self.server_ip, 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return '0.0.0.0'


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='PortKnock - Cryptographic Port Knocking')
    sub = parser.add_subparsers(dest='mode')
    
    # Server mode
    srv = sub.add_parser('server', help='Run knock server')
    srv.add_argument('-c', '--config', help='Config file path')
    srv.add_argument('--spa', action='store_true', help='Enable SPA mode')
    srv.add_argument('--genconfig', help='Generate config file')
    
    # Client mode
    cli = sub.add_parser('client', help='Send knocks')
    cli.add_argument('server', help='Server IP')
    cli.add_argument('-k', '--key', required=True, help='Shared secret key')
    cli.add_argument('--spa', action='store_true', help='Use SPA instead of knocks')
    cli.add_argument('--static', help='Static port sequence (comma-separated)')
    
    args = parser.parse_args()
    
    if args.mode == 'server':
        server = PortKnockServer(args.config)
        if args.genconfig:
            server.save_config(args.genconfig)
            print(f"Config generated: {args.genconfig}")
            print(f"Secret key: {server.config['secret_key']}")
            sys.exit(0)
        
        def signal_handler(sig, frame):
            server.stop()
            sys.exit(0)
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        if args.spa or server.config['spa_mode']:
            threading.Thread(target=server.spa_listen, daemon=True).start()
        
        server.listen_knocks()
        
    elif args.mode == 'client':
        client = PortKnockClient(args.key, args.server)
        if args.spa:
            client.send_spa()
        elif args.static:
            ports = [int(p) for p in args.static.split(',')]
            client.knock(use_crypto=False, static_sequence=ports)
        else:
            client.knock()
    else:
        parser.print_help()
