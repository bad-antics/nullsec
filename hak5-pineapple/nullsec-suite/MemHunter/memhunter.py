#!/usr/bin/env python3
"""
NullSec MemHunter - Memory Forensics & Artifact Extractor
Analyzes live system memory and process memory for:
- Credential extraction (passwords, tokens, keys from memory)
- Encryption key recovery (AES, RSA key schedules)
- Network artifact extraction (URLs, IPs, domains)
- Strings analysis with context-aware filtering
- Memory-resident malware indicators
- Process memory dump & analysis
- Heap/stack spray detection
- Shellcode signature scanning

Author: bad-antics / NullSec
License: MIT
"""

import os
import re
import sys
import json
import struct
import mmap
import hashlib
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path


# ─── Pattern Definitions ──────────────────────────────────────────────────

CREDENTIAL_PATTERNS = {
    'password_field': re.compile(rb'(?:password|passwd|pwd)\s*[=:]\s*([^\s\x00]{3,64})', re.IGNORECASE),
    'auth_token': re.compile(rb'(?:token|bearer|api.?key|authorization)\s*[=:]\s*([A-Za-z0-9+/=_\-]{20,128})', re.IGNORECASE),
    'jwt_token': re.compile(rb'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    'aws_key': re.compile(rb'AKIA[0-9A-Z]{16}'),
    'aws_secret': re.compile(rb'(?:aws.?secret|secret.?key)\s*[=:]\s*([A-Za-z0-9/+=]{40})', re.IGNORECASE),
    'private_key': re.compile(rb'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'),
    'ssh_key': re.compile(rb'ssh-(?:rsa|ed25519|ecdsa)\s+[A-Za-z0-9+/=]+'),
    'github_token': re.compile(rb'gh[ps]_[A-Za-z0-9_]{36,255}'),
    'base64_cred': re.compile(rb'(?:Basic|Bearer)\s+([A-Za-z0-9+/=]{10,128})'),
    'cookie_session': re.compile(rb'(?:session|sess|sid|connect\.sid)\s*[=:]\s*([A-Za-z0-9+/=_\-]{16,128})', re.IGNORECASE),
}

NETWORK_PATTERNS = {
    'ipv4': re.compile(rb'\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d?\d)\b'),
    'url': re.compile(rb'https?://[A-Za-z0-9._~:/?#\[\]@!$&\'()*+,;=%\-]{10,256}'),
    'email': re.compile(rb'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Z|a-z]{2,}'),
    'domain': re.compile(rb'(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}'),
    'mac_address': re.compile(rb'(?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}'),
}

CRYPTO_PATTERNS = {
    # AES key schedule detection (16/24/32 byte aligned patterns)
    'aes_key_128': re.compile(rb'[\x00-\xff]{16}', re.DOTALL),  # placeholder - real detection uses entropy
    'rsa_modulus': re.compile(rb'\x00\x01[\xff]{8,}\x00'),  # PKCS#1 padding
    'pgp_header': re.compile(rb'\xc6[\x01-\xff]'),  # PGP packet tag
}

SHELLCODE_SIGNATURES = {
    # Common shellcode patterns
    'nop_sled': re.compile(rb'\x90{16,}'),                          # NOP sled
    'int80_syscall': re.compile(rb'\xcd\x80'),                      # int 0x80 (Linux syscall)
    'syscall_instr': re.compile(rb'\x0f\x05'),                      # syscall instruction
    'shell_exec': re.compile(rb'/bin/(?:ba)?sh\x00'),               # /bin/sh string
    'msfvenom_x86': re.compile(rb'\x31\xc0\x50\x68'),              # xor eax,eax; push eax; push
    'msfvenom_x64': re.compile(rb'\x48\x31\xc0\x48'),              # xor rax,rax (x64)
    'egg_hunter': re.compile(rb'\x66\x81\xca\xff\x0f'),            # egg hunter pattern
    'reverse_shell': re.compile(rb'\x6a\x29\x58\x99'),             # socket() shellcode
}


class MemoryRegion:
    """Represents a mapped memory region from /proc/PID/maps."""
    
    def __init__(self, start, end, perms, offset, dev, inode, pathname):
        self.start = start
        self.end = end
        self.perms = perms
        self.offset = offset
        self.dev = dev
        self.inode = inode
        self.pathname = pathname
        self.size = end - start
    
    @property
    def readable(self):
        return 'r' in self.perms
    
    @property
    def writable(self):
        return 'w' in self.perms
    
    @property
    def executable(self):
        return 'x' in self.perms


class ProcessMemoryAnalyzer:
    """Analyze a process's memory space."""
    
    def __init__(self, pid):
        self.pid = pid
        self.regions = []
        self.findings = []
        self._load_maps()
    
    def _load_maps(self):
        """Parse /proc/PID/maps."""
        try:
            with open(f'/proc/{self.pid}/maps') as f:
                for line in f:
                    parts = line.strip().split(None, 5)
                    if len(parts) < 5:
                        continue
                    
                    addr_range = parts[0].split('-')
                    start = int(addr_range[0], 16)
                    end = int(addr_range[1], 16)
                    perms = parts[1]
                    offset = int(parts[2], 16)
                    dev = parts[3]
                    inode = int(parts[4])
                    pathname = parts[5] if len(parts) > 5 else ''
                    
                    self.regions.append(MemoryRegion(start, end, perms, offset, dev, inode, pathname.strip()))
        except PermissionError:
            pass
        except FileNotFoundError:
            pass
    
    def read_region(self, region, max_size=10*1024*1024):
        """Read bytes from a memory region."""
        if not region.readable:
            return None
        
        size = min(region.size, max_size)
        
        try:
            with open(f'/proc/{self.pid}/mem', 'rb') as f:
                f.seek(region.start)
                return f.read(size)
        except:
            return None
    
    def scan_credentials(self):
        """Scan process memory for credentials."""
        findings = []
        
        for region in self.regions:
            if not region.readable:
                continue
            
            # Skip very large regions
            if region.size > 50 * 1024 * 1024:
                continue
            
            data = self.read_region(region)
            if not data:
                continue
            
            for name, pattern in CREDENTIAL_PATTERNS.items():
                matches = pattern.finditer(data)
                for match in matches:
                    offset = match.start()
                    context = data[max(0, offset-20):min(len(data), offset+80)]
                    
                    # Filter false positives
                    matched_text = match.group(0)
                    if len(matched_text) < 4:
                        continue
                    
                    findings.append({
                        'type': 'credential',
                        'pattern': name,
                        'region': f'{region.start:#x}-{region.end:#x} {region.perms} {region.pathname}',
                        'offset': f'{region.start + offset:#x}',
                        'preview': self._safe_preview(matched_text),
                        'context': self._safe_preview(context),
                        'severity': self._cred_severity(name)
                    })
        
        self.findings.extend(findings)
        return findings
    
    def scan_network_artifacts(self):
        """Scan for network-related strings."""
        findings = []
        seen = set()  # Dedup
        
        for region in self.regions:
            if not region.readable or region.size > 50 * 1024 * 1024:
                continue
            
            data = self.read_region(region)
            if not data:
                continue
            
            for name, pattern in NETWORK_PATTERNS.items():
                # Limit matches per region
                match_count = 0
                for match in pattern.finditer(data):
                    if match_count > 100:
                        break
                    
                    value = match.group(0)
                    value_str = value.decode('utf-8', errors='replace')
                    
                    if value_str in seen:
                        continue
                    seen.add(value_str)
                    
                    # Filter noise
                    if name == 'ipv4' and value_str in ('0.0.0.0', '127.0.0.1', '255.255.255.255'):
                        continue
                    if name == 'domain' and len(value_str) < 5:
                        continue
                    
                    findings.append({
                        'type': 'network_artifact',
                        'pattern': name,
                        'value': value_str[:200],
                        'region': f'{region.perms} {region.pathname}'
                    })
                    match_count += 1
        
        self.findings.extend(findings)
        return findings
    
    def scan_shellcode(self):
        """Scan for shellcode signatures."""
        findings = []
        
        for region in self.regions:
            if not region.readable:
                continue
            
            data = self.read_region(region)
            if not data:
                continue
            
            for name, pattern in SHELLCODE_SIGNATURES.items():
                matches = list(pattern.finditer(data))[:5]  # Limit
                for match in matches:
                    offset = match.start()
                    
                    findings.append({
                        'type': 'shellcode_indicator',
                        'signature': name,
                        'severity': 'high' if name not in ('nop_sled',) else 'medium',
                        'region': f'{region.start:#x} {region.perms} {region.pathname}',
                        'offset': f'{region.start + offset:#x}',
                        'size': len(match.group(0))
                    })
        
        self.findings.extend(findings)
        return findings
    
    def detect_heap_spray(self, threshold=0.7):
        """Detect heap spray by looking for repeated patterns in heap."""
        findings = []
        
        for region in self.regions:
            if '[heap]' not in region.pathname:
                continue
            
            data = self.read_region(region, max_size=5*1024*1024)
            if not data or len(data) < 4096:
                continue
            
            # Check for repeated 4-byte patterns
            chunks = [data[i:i+4] for i in range(0, min(len(data), 100000), 4)]
            if not chunks:
                continue
            
            counter = Counter(chunks)
            most_common = counter.most_common(1)[0]
            ratio = most_common[1] / len(chunks)
            
            if ratio > threshold and most_common[0] != b'\x00\x00\x00\x00':
                findings.append({
                    'type': 'heap_spray_suspect',
                    'severity': 'critical',
                    'region': f'{region.start:#x}-{region.end:#x}',
                    'pattern': most_common[0].hex(),
                    'ratio': round(ratio, 4),
                    'detail': f'Heap contains {ratio*100:.1f}% repeated pattern 0x{most_common[0].hex()}'
                })
        
        self.findings.extend(findings)
        return findings
    
    def entropy_analysis(self, block_size=4096):
        """Analyze entropy of memory regions to find encrypted/packed data."""
        import math
        
        findings = []
        
        for region in self.regions:
            if not region.readable or region.size < block_size:
                continue
            
            data = self.read_region(region, max_size=1*1024*1024)
            if not data:
                continue
            
            # Calculate entropy
            counts = Counter(data)
            length = len(data)
            entropy = 0.0
            for count in counts.values():
                p = count / length
                if p > 0:
                    entropy -= p * math.log2(p)
            
            # High entropy in writable regions = suspicious
            if entropy > 7.5 and region.writable and not region.pathname:
                findings.append({
                    'type': 'high_entropy_region',
                    'severity': 'medium',
                    'region': f'{region.start:#x}-{region.end:#x} {region.perms}',
                    'entropy': round(entropy, 4),
                    'size': region.size,
                    'detail': 'High entropy anonymous region (possible encrypted/packed content)'
                })
        
        self.findings.extend(findings)
        return findings
    
    def full_scan(self):
        """Run all memory analysis modules."""
        results = {
            'credentials': self.scan_credentials(),
            'network': self.scan_network_artifacts(),
            'shellcode': self.scan_shellcode(),
            'heap_spray': self.detect_heap_spray(),
            'entropy': self.entropy_analysis(),
        }
        return results
    
    def _safe_preview(self, data, max_len=60):
        """Create a safe preview of binary data."""
        if isinstance(data, bytes):
            # Replace non-printable chars
            preview = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[:max_len])
            return preview
        return str(data)[:max_len]
    
    def _cred_severity(self, pattern_name):
        """Determine severity based on credential type."""
        critical = ['private_key', 'aws_key', 'aws_secret', 'github_token']
        high = ['jwt_token', 'auth_token', 'ssh_key', 'password_field']
        return 'critical' if pattern_name in critical else 'high' if pattern_name in high else 'medium'


class MemHunter:
    """Main memory forensics engine."""
    
    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/memhunter')
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        self.results = []
    
    def scan_process(self, pid, verbose=False):
        """Scan a specific process."""
        print(f"🧠 MemHunter - Scanning PID {pid}")
        
        # Get process info
        try:
            with open(f'/proc/{pid}/comm') as f:
                name = f.read().strip()
            with open(f'/proc/{pid}/cmdline', 'rb') as f:
                cmdline = f.read().replace(b'\x00', b' ').decode('utf-8', errors='replace').strip()
        except:
            name = 'unknown'
            cmdline = ''
        
        analyzer = ProcessMemoryAnalyzer(pid)
        
        if not analyzer.regions:
            print(f"   ❌ Cannot access process memory (need root or same user)")
            return None
        
        print(f"   Process: {name} (PID {pid})")
        print(f"   Cmdline: {cmdline[:80]}")
        print(f"   Memory regions: {len(analyzer.regions)}")
        print(f"   Total mapped: {sum(r.size for r in analyzer.regions) / (1024*1024):.1f} MB")
        
        print("\n   🔍 Scanning for credentials...")
        creds = analyzer.scan_credentials()
        print(f"      Found: {len(creds)} potential credentials")
        
        print("   🌐 Scanning for network artifacts...")
        network = analyzer.scan_network_artifacts()
        print(f"      Found: {len(network)} network artifacts")
        
        print("   🐛 Scanning for shellcode...")
        shellcode = analyzer.scan_shellcode()
        print(f"      Found: {len(shellcode)} shellcode indicators")
        
        print("   📊 Entropy analysis...")
        entropy = analyzer.entropy_analysis()
        print(f"      Found: {len(entropy)} high-entropy regions")
        
        print("   💉 Checking for heap spray...")
        heap = analyzer.detect_heap_spray()
        print(f"      Found: {len(heap)} heap spray indicators")
        
        result = {
            'pid': pid,
            'name': name,
            'cmdline': cmdline,
            'regions': len(analyzer.regions),
            'total_memory_mb': round(sum(r.size for r in analyzer.regions) / (1024*1024), 2),
            'credentials': creds,
            'network_artifacts': network[:100],
            'shellcode': shellcode,
            'high_entropy': entropy,
            'heap_spray': heap,
            'total_findings': len(creds) + len(shellcode) + len(entropy) + len(heap)
        }
        
        if verbose:
            for finding in creds[:10]:
                print(f"      🔑 [{finding['severity']}] {finding['pattern']}: {finding['preview']}")
            for finding in shellcode:
                print(f"      🐛 [{finding['severity']}] {finding['signature']} at {finding['offset']}")
        
        self.results.append(result)
        return result
    
    def scan_all_processes(self, verbose=False):
        """Scan all accessible processes."""
        print("🧠 MemHunter - Scanning all processes")
        print("=" * 50)
        
        pids = []
        for entry in os.listdir('/proc'):
            if entry.isdigit():
                pids.append(int(entry))
        
        pids.sort()
        scanned = 0
        flagged = 0
        
        for pid in pids:
            analyzer = ProcessMemoryAnalyzer(pid)
            if not analyzer.regions:
                continue
            
            # Quick scan (credentials + shellcode only)
            creds = analyzer.scan_credentials()
            shellcode = analyzer.scan_shellcode()
            
            if creds or shellcode:
                flagged += 1
                try:
                    with open(f'/proc/{pid}/comm') as f:
                        name = f.read().strip()
                except:
                    name = '?'
                
                findings = len(creds) + len(shellcode)
                print(f"   ⚠️  PID {pid:>6} ({name:>20}) - {findings} findings "
                      f"({len(creds)} creds, {len(shellcode)} shellcode)")
                
                self.results.append({
                    'pid': pid,
                    'name': name,
                    'credentials': creds,
                    'shellcode': shellcode,
                    'total_findings': findings
                })
            
            scanned += 1
        
        print(f"\n✅ Scanned {scanned} processes, {flagged} flagged")
        return self._generate_report()
    
    def dump_strings(self, pid, min_length=6, output_file=None):
        """Extract all readable strings from process memory."""
        print(f"📜 Extracting strings from PID {pid}...")
        
        analyzer = ProcessMemoryAnalyzer(pid)
        strings_found = []
        
        string_pattern = re.compile(rb'[\x20-\x7e]{' + str(min_length).encode() + rb',}')
        
        for region in analyzer.regions:
            if not region.readable:
                continue
            
            data = analyzer.read_region(region, max_size=10*1024*1024)
            if not data:
                continue
            
            for match in string_pattern.finditer(data):
                string = match.group(0).decode('ascii', errors='replace')
                strings_found.append({
                    'string': string,
                    'offset': f'{region.start + match.start():#x}',
                    'region': region.pathname or 'anonymous'
                })
        
        if output_file:
            with open(output_file, 'w') as f:
                for s in strings_found:
                    f.write(f"{s['offset']}\t{s['region']}\t{s['string']}\n")
            print(f"   Saved {len(strings_found)} strings to {output_file}")
        
        print(f"   Extracted {len(strings_found)} strings")
        return strings_found
    
    def _generate_report(self):
        """Generate forensics report."""
        report = {
            'scan_time': datetime.now().isoformat(),
            'processes_scanned': len(self.results),
            'total_findings': sum(r.get('total_findings', 0) for r in self.results),
            'results': self.results
        }
        
        json_path = os.path.join(self.output_dir, f"memhunter-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        md_path = os.path.join(self.output_dir, f"memhunter-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 🧠 MemHunter Forensics Report\n\n")
            f.write(f"**Generated:** {report['scan_time']}\n\n")
            f.write("## Summary\n\n")
            f.write(f"| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Processes Scanned | {report['processes_scanned']} |\n")
            f.write(f"| Total Findings | {report['total_findings']} |\n\n")
            
            flagged = [r for r in self.results if r.get('total_findings', 0) > 0]
            if flagged:
                f.write("## Flagged Processes\n\n")
                for r in sorted(flagged, key=lambda x: x.get('total_findings', 0), reverse=True):
                    f.write(f"### PID {r['pid']} - {r.get('name', 'unknown')}\n\n")
                    
                    if r.get('credentials'):
                        f.write("**Credentials Found:**\n\n")
                        for c in r['credentials'][:10]:
                            f.write(f"- [{c['severity']}] `{c['pattern']}` at {c['offset']}\n")
                        f.write("\n")
                    
                    if r.get('shellcode'):
                        f.write("**Shellcode Indicators:**\n\n")
                        for s in r['shellcode']:
                            f.write(f"- [{s['severity']}] `{s['signature']}` at {s['offset']}\n")
                        f.write("\n")
                    
                    if r.get('high_entropy'):
                        f.write("**High Entropy Regions:**\n\n")
                        for e in r['high_entropy']:
                            f.write(f"- Entropy: {e['entropy']} | {e['region']}\n")
                        f.write("\n")
            
            f.write("---\n*Generated by NullSec MemHunter*\n")
        
        print(f"\n📄 Reports:")
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  🧠 MemHunter v1.0                    ║
    ║  Memory Forensics & Artifact Hunter   ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='MemHunter - Memory Forensics Tool')
    parser.add_argument('-p', '--pid', type=int, help='Scan specific process')
    parser.add_argument('-a', '--all', action='store_true', help='Scan all processes')
    parser.add_argument('-s', '--strings', type=int, metavar='PID', help='Extract strings from PID')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-o', '--output', help='Output directory')
    parser.add_argument('--min-string-len', type=int, default=6, help='Min string length (default: 6)')
    
    args = parser.parse_args()
    
    hunter = MemHunter(args.output)
    
    if args.pid:
        result = hunter.scan_process(args.pid, verbose=args.verbose)
        if result:
            hunter._generate_report()
    elif args.strings:
        strings_file = os.path.join(
            hunter.output_dir, 
            f"strings-{args.strings}-{datetime.now().strftime('%Y%m%d-%H%M%S')}.txt"
        )
        hunter.dump_strings(args.strings, args.min_string_len, strings_file)
    elif args.all:
        hunter.scan_all_processes(verbose=args.verbose)
    else:
        parser.print_help()
