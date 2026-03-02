#!/usr/bin/env python3
"""
NullSec CertSnitch - SSL/TLS Certificate Intelligence Gatherer
Passively monitors and analyzes SSL certificates across your network.
Detects expiring certs, misconfigurations, weak crypto, and rogue CAs.

Author: bad-antics / NullSec
License: MIT
"""

import ssl
import socket
import json
import subprocess
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib

class CertSnitch:
    """SSL/TLS Certificate Intelligence & Security Auditor."""
    
    # Common ports that use TLS
    TLS_PORTS = [443, 8443, 993, 995, 465, 636, 989, 990, 5061, 8080, 9443, 3389]
    
    # Known weak configurations
    WEAK_CIPHERS = ['RC4', 'DES', 'MD5', '3DES', 'NULL', 'EXPORT', 'anon']
    WEAK_PROTOCOLS = ['SSLv2', 'SSLv3', 'TLSv1.0', 'TLSv1.1']
    
    def __init__(self, targets=None, subnet=None, output_dir="./certsnitch-output"):
        self.targets = targets or []
        self.subnet = subnet
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.results = []
        self.alerts = []
    
    def discover_tls_hosts(self):
        """Discover hosts with TLS services from ARP cache + common ports."""
        print("[*] Discovering TLS-enabled hosts...")
        hosts = set()
        
        if self.subnet:
            # Use ARP cache for subnet
            try:
                result = subprocess.run(['ip', 'neigh', 'show'], capture_output=True, text=True)
                for line in result.stdout.strip().split('\n'):
                    parts = line.split()
                    if parts and re.match(r'\d+\.\d+\.\d+\.\d+', parts[0]):
                        if parts[0].startswith(self.subnet.rsplit('.', 1)[0]):
                            hosts.add(parts[0])
            except Exception:
                pass
        
        for t in self.targets:
            hosts.add(t)
        
        print(f"  [+] {len(hosts)} potential TLS hosts")
        return list(hosts)
    
    def grab_certificate(self, host, port=443, timeout=5):
        """Grab and analyze a TLS certificate from a host:port."""
        try:
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            
            with socket.create_connection((host, port), timeout=timeout) as sock:
                with context.wrap_socket(sock, server_hostname=host) as ssock:
                    cert_bin = ssock.getpeercert(binary_form=True)
                    cert = ssock.getpeercert()
                    cipher = ssock.cipher()
                    version = ssock.version()
                    
                    # Parse certificate
                    cert_info = self._parse_cert(cert, cert_bin, host, port)
                    cert_info['cipher'] = {
                        'name': cipher[0] if cipher else 'unknown',
                        'protocol': cipher[1] if cipher and len(cipher) > 1 else 'unknown',
                        'bits': cipher[2] if cipher and len(cipher) > 2 else 0
                    }
                    cert_info['tls_version'] = version
                    
                    # Security checks
                    cert_info['alerts'] = self._audit_cert(cert_info)
                    
                    return cert_info
        except ssl.SSLError as e:
            return {'host': host, 'port': port, 'error': f'SSL Error: {e}', 'alerts': ['SSL handshake failed']}
        except (socket.timeout, ConnectionRefusedError, OSError) as e:
            return None  # No TLS service on this port
    
    def _parse_cert(self, cert, cert_bin, host, port):
        """Parse certificate details."""
        if not cert:
            return {'host': host, 'port': port, 'error': 'No certificate', 'alerts': []}
        
        # Subject
        subject = {}
        for item in cert.get('subject', ()):
            for key, val in item:
                subject[key] = val
        
        # Issuer
        issuer = {}
        for item in cert.get('issuer', ()):
            for key, val in item:
                issuer[key] = val
        
        # SANs
        sans = []
        for san_type, san_val in cert.get('subjectAltName', ()):
            sans.append(f"{san_type}:{san_val}")
        
        # Dates
        not_before = cert.get('notBefore', '')
        not_after = cert.get('notAfter', '')
        
        # Parse dates
        try:
            expire_dt = datetime.strptime(not_after, '%b %d %H:%M:%S %Y %Z')
            days_left = (expire_dt - datetime.utcnow()).days
        except Exception:
            expire_dt = None
            days_left = -999
        
        # Fingerprint
        fingerprint = hashlib.sha256(cert_bin).hexdigest() if cert_bin else ''
        
        # Serial
        serial = cert.get('serialNumber', '')
        
        return {
            'host': host,
            'port': port,
            'subject': subject,
            'issuer': issuer,
            'common_name': subject.get('commonName', ''),
            'issuer_cn': issuer.get('commonName', ''),
            'issuer_org': issuer.get('organizationName', ''),
            'sans': sans,
            'not_before': not_before,
            'not_after': not_after,
            'days_until_expiry': days_left,
            'serial': serial,
            'fingerprint_sha256': fingerprint,
            'version': cert.get('version', 0),
            'alerts': []
        }
    
    def _audit_cert(self, cert_info):
        """Run security audit on a certificate."""
        alerts = []
        
        # Expiry checks
        days = cert_info.get('days_until_expiry', -999)
        if days < 0:
            alerts.append(('CRITICAL', f'Certificate EXPIRED ({abs(days)} days ago)'))
        elif days < 7:
            alerts.append(('CRITICAL', f'Certificate expires in {days} days'))
        elif days < 30:
            alerts.append(('HIGH', f'Certificate expires in {days} days'))
        elif days < 90:
            alerts.append(('MEDIUM', f'Certificate expires in {days} days'))
        
        # Self-signed check
        if cert_info.get('subject') == cert_info.get('issuer') and cert_info.get('subject'):
            alerts.append(('HIGH', 'Self-signed certificate'))
        
        # Weak cipher check
        cipher_name = cert_info.get('cipher', {}).get('name', '')
        for weak in self.WEAK_CIPHERS:
            if weak.lower() in cipher_name.lower():
                alerts.append(('CRITICAL', f'Weak cipher: {cipher_name}'))
                break
        
        # Cipher bits check
        bits = cert_info.get('cipher', {}).get('bits', 0)
        if 0 < bits < 128:
            alerts.append(('CRITICAL', f'Weak key size: {bits} bits'))
        elif bits == 128:
            alerts.append(('MEDIUM', f'128-bit cipher (consider 256-bit)'))
        
        # TLS version check
        tls_ver = cert_info.get('tls_version', '')
        for weak_proto in self.WEAK_PROTOCOLS:
            if weak_proto.lower() in tls_ver.lower():
                alerts.append(('CRITICAL', f'Weak protocol: {tls_ver}'))
                break
        
        # Hostname mismatch
        cn = cert_info.get('common_name', '')
        host = cert_info.get('host', '')
        sans_hosts = [s.split(':')[1] for s in cert_info.get('sans', []) if s.startswith('DNS:')]
        
        if cn and host:
            name_match = False
            all_names = [cn] + sans_hosts
            for name in all_names:
                if name == host:
                    name_match = True
                    break
                if name.startswith('*.') and host.endswith(name[1:]):
                    name_match = True
                    break
            if not name_match:
                alerts.append(('HIGH', f'Hostname mismatch: cert={cn}, host={host}'))
        
        # Known bad issuers (revoked CAs, test certs)
        issuer_cn = cert_info.get('issuer_cn', '').lower()
        if any(bad in issuer_cn for bad in ['test', 'fake', 'example', 'localhost', 'snakeoil']):
            alerts.append(('HIGH', f'Suspicious issuer: {cert_info.get("issuer_cn")}'))
        
        # Very long validity (>825 days per Apple/Google policy)
        try:
            not_before = datetime.strptime(cert_info.get('not_before', ''), '%b %d %H:%M:%S %Y %Z')
            not_after = datetime.strptime(cert_info.get('not_after', ''), '%b %d %H:%M:%S %Y %Z')
            validity_days = (not_after - not_before).days
            if validity_days > 825:
                alerts.append(('MEDIUM', f'Long validity period: {validity_days} days (>825 limit)'))
        except Exception:
            pass
        
        return alerts
    
    def scan(self, ports=None):
        """Scan all targets for TLS certificates."""
        if ports is None:
            ports = self.TLS_PORTS
        
        hosts = self.discover_tls_hosts()
        
        print(f"[*] Scanning {len(hosts)} hosts on {len(ports)} ports...")
        
        tasks = [(h, p) for h in hosts for p in ports]
        total_certs = 0
        total_alerts = 0
        
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = {executor.submit(self.grab_certificate, h, p): (h, p) for h, p in tasks}
            
            for future in as_completed(futures):
                h, p = futures[future]
                try:
                    result = future.result()
                    if result and 'error' not in result:
                        self.results.append(result)
                        total_certs += 1
                        alerts = result.get('alerts', [])
                        if alerts:
                            total_alerts += len(alerts)
                            for severity, msg in alerts:
                                self.alerts.append((severity, h, p, msg))
                            print(f"  ⚠️  {h}:{p} - {result.get('common_name', '?')} - {len(alerts)} alerts")
                        else:
                            print(f"  ✅ {h}:{p} - {result.get('common_name', '?')} - OK")
                except Exception:
                    pass
        
        print(f"\n[*] Found {total_certs} certificates, {total_alerts} security alerts")
        return self.generate_report()
    
    def generate_report(self):
        """Generate comprehensive certificate audit report."""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Sort alerts by severity
        severity_order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3}
        self.alerts.sort(key=lambda x: severity_order.get(x[0], 4))
        
        # JSON export
        json_path = self.output_dir / f"certsnitch_{timestamp}.json"
        export = {
            'scan_time': datetime.now().isoformat(),
            'total_certs': len(self.results),
            'total_alerts': len(self.alerts),
            'certificates': self.results,
            'alerts': [{'severity': a[0], 'host': a[1], 'port': a[2], 'message': a[3]} for a in self.alerts]
        }
        with open(json_path, 'w') as f:
            json.dump(export, f, indent=2, default=str)
        
        # Markdown report
        md_path = self.output_dir / f"certsnitch_{timestamp}.md"
        with open(md_path, 'w') as f:
            f.write("# 🔐 CertSnitch - SSL/TLS Certificate Audit Report\n\n")
            f.write(f"**Scanned:** {datetime.now().isoformat()}\n")
            f.write(f"**Certificates Found:** {len(self.results)}\n")
            f.write(f"**Security Alerts:** {len(self.alerts)}\n\n")
            
            if self.alerts:
                f.write("## ⚠️ Security Alerts\n\n")
                f.write("| Severity | Host | Port | Finding |\n")
                f.write("|----------|------|------|---------|\n")
                for severity, host, port, msg in self.alerts:
                    icon = '🔴' if severity == 'CRITICAL' else '🟠' if severity == 'HIGH' else '🟡'
                    f.write(f"| {icon} {severity} | {host} | {port} | {msg} |\n")
            
            f.write("\n## 📜 Certificate Details\n\n")
            for cert in self.results:
                f.write(f"### {cert.get('host')}:{cert.get('port')}\n\n")
                f.write(f"- **Common Name:** {cert.get('common_name', '?')}\n")
                f.write(f"- **Issuer:** {cert.get('issuer_org', '?')} ({cert.get('issuer_cn', '?')})\n")
                f.write(f"- **Valid:** {cert.get('not_before', '?')} → {cert.get('not_after', '?')}\n")
                f.write(f"- **Days Until Expiry:** {cert.get('days_until_expiry', '?')}\n")
                f.write(f"- **TLS Version:** {cert.get('tls_version', '?')}\n")
                cipher = cert.get('cipher', {})
                f.write(f"- **Cipher:** {cipher.get('name', '?')} ({cipher.get('bits', '?')}-bit)\n")
                f.write(f"- **SANs:** {', '.join(cert.get('sans', []))}\n")
                f.write(f"- **SHA-256:** `{cert.get('fingerprint_sha256', '?')[:32]}...`\n\n")
        
        print(f"  [+] Report: {md_path}")
        print(f"  [+] Data: {json_path}")
        return md_path, json_path


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='CertSnitch - SSL/TLS Certificate Intelligence')
    parser.add_argument('targets', nargs='*', help='Target hosts or IPs')
    parser.add_argument('-s', '--subnet', help='Subnet to scan (e.g., 192.168.1)')
    parser.add_argument('-p', '--ports', help='Comma-separated ports', default='443,8443,993,995,465')
    parser.add_argument('-o', '--output', default='./certsnitch-output')
    args = parser.parse_args()
    
    ports = [int(p) for p in args.ports.split(',')]
    snitch = CertSnitch(targets=args.targets, subnet=args.subnet, output_dir=args.output)
    snitch.scan(ports=ports)
