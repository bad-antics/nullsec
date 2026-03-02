#!/usr/bin/env python3
"""
NullSec ProcessPhantom - Process Hollowing & Injection Detector
Detects advanced process manipulation techniques:
- Process hollowing (unmapped memory regions)
- Shared library injection (suspicious .so loads)
- ptrace-based injection
- /proc anomalies (deleted executables, modified maps)
- Hidden processes (PID discrepancies)
- Suspicious parent-child relationships
- Memory permission anomalies (RWX regions)

Author: bad-antics / NullSec
License: MIT
"""

import os
import re
import sys
import json
import time
import glob
import struct
import hashlib
from collections import defaultdict
from datetime import datetime
from pathlib import Path


class ProcessInspector:
    """Deep inspection of individual processes via /proc."""
    
    # Suspicious library patterns
    SUS_LIBS = [
        r'libpreload',
        r'/tmp/.*\.so',
        r'/dev/shm/.*\.so',
        r'/var/tmp/.*\.so',
        r'memfd:',         # Anonymous memory-mapped shared objects
        r'\(deleted\)',    # Deleted files still mapped
    ]
    
    # Known legitimate preload paths
    LEGIT_PRELOADS = {
        '/usr/lib/x86_64-linux-gnu/libgtk3-nocsd.so.0',
        '/usr/lib/libtcmalloc.so',
    }
    
    def __init__(self, pid):
        self.pid = pid
        self.proc_path = f'/proc/{pid}'
        self.alerts = []
    
    def exists(self):
        return os.path.exists(self.proc_path)
    
    def get_name(self):
        try:
            with open(f'{self.proc_path}/comm') as f:
                return f.read().strip()
        except:
            return 'unknown'
    
    def get_exe(self):
        try:
            return os.readlink(f'{self.proc_path}/exe')
        except:
            return None
    
    def get_cmdline(self):
        try:
            with open(f'{self.proc_path}/cmdline', 'rb') as f:
                return f.read().replace(b'\x00', b' ').decode('utf-8', errors='replace').strip()
        except:
            return ''
    
    def get_ppid(self):
        try:
            with open(f'{self.proc_path}/status') as f:
                for line in f:
                    if line.startswith('PPid:'):
                        return int(line.split(':')[1].strip())
        except:
            pass
        return 0
    
    def get_uid(self):
        try:
            with open(f'{self.proc_path}/status') as f:
                for line in f:
                    if line.startswith('Uid:'):
                        return int(line.split(':')[1].split()[0])
        except:
            pass
        return -1
    
    def check_exe_deleted(self):
        """Check if the executable has been deleted (hollowing indicator)."""
        try:
            link = os.readlink(f'{self.proc_path}/exe')
            if '(deleted)' in link:
                self.alerts.append({
                    'type': 'deleted_executable',
                    'severity': 'critical',
                    'detail': f'Process running from deleted binary: {link}'
                })
                return True
        except:
            pass
        return False
    
    def check_memory_maps(self):
        """Analyze /proc/PID/maps for suspicious regions."""
        findings = []
        try:
            with open(f'{self.proc_path}/maps') as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) < 6:
                        continue
                    
                    addr_range = parts[0]
                    perms = parts[1]
                    pathname = parts[5] if len(parts) > 5 else ''
                    
                    # Check for RWX (Read-Write-Execute) regions
                    if 'rwx' in perms:
                        findings.append({
                            'type': 'rwx_memory',
                            'severity': 'high',
                            'detail': f'RWX memory region: {addr_range} {perms} {pathname}'
                        })
                    
                    # Check for suspicious mapped libraries
                    for pattern in self.SUS_LIBS:
                        if re.search(pattern, pathname):
                            if pathname not in self.LEGIT_PRELOADS:
                                findings.append({
                                    'type': 'suspicious_mapping',
                                    'severity': 'high',
                                    'detail': f'Suspicious mapped file: {pathname} at {addr_range}'
                                })
                    
                    # Anonymous executable regions (potential shellcode)
                    if perms.startswith('r-x') and pathname == '' and addr_range != '':
                        start, end = addr_range.split('-')
                        size = int(end, 16) - int(start, 16)
                        if size > 4096:  # Skip small guard pages
                            findings.append({
                                'type': 'anon_executable',
                                'severity': 'medium',
                                'detail': f'Anonymous executable region: {addr_range} ({size} bytes)'
                            })
        except PermissionError:
            pass
        except:
            pass
        
        self.alerts.extend(findings)
        return findings
    
    def check_fd_anomalies(self):
        """Check file descriptors for suspicious patterns."""
        findings = []
        try:
            fd_path = f'{self.proc_path}/fd'
            for fd in os.listdir(fd_path):
                try:
                    link = os.readlink(f'{fd_path}/{fd}')
                    
                    # memfd (anonymous memory files - used in fileless attacks)
                    if 'memfd:' in link:
                        findings.append({
                            'type': 'memfd_usage',
                            'severity': 'high',
                            'detail': f'memfd file descriptor: fd={fd} -> {link}'
                        })
                    
                    # Deleted files
                    if '(deleted)' in link and '.so' in link:
                        findings.append({
                            'type': 'deleted_lib_fd',
                            'severity': 'high',
                            'detail': f'FD points to deleted library: fd={fd} -> {link}'
                        })
                    
                    # /dev/shm usage (shared memory, often used for injection)
                    if link.startswith('/dev/shm/') and link.endswith(('.so', '.bin', '.elf')):
                        findings.append({
                            'type': 'shm_executable',
                            'severity': 'high',
                            'detail': f'Executable in shared memory: fd={fd} -> {link}'
                        })
                except:
                    continue
        except:
            pass
        
        self.alerts.extend(findings)
        return findings
    
    def check_ptrace(self):
        """Check if process is being ptraced."""
        try:
            with open(f'{self.proc_path}/status') as f:
                for line in f:
                    if line.startswith('TracerPid:'):
                        tracer = int(line.split(':')[1].strip())
                        if tracer > 0:
                            self.alerts.append({
                                'type': 'active_ptrace',
                                'severity': 'high',
                                'detail': f'Process is being traced by PID {tracer}'
                            })
                            return tracer
        except:
            pass
        return 0
    
    def check_env_injection(self):
        """Check for LD_PRELOAD and other injection env vars."""
        findings = []
        suspicious_envs = ['LD_PRELOAD', 'LD_LIBRARY_PATH', 'LD_AUDIT', 'LD_DEBUG']
        
        try:
            with open(f'{self.proc_path}/environ', 'rb') as f:
                env_data = f.read()
            
            for env_var in env_data.split(b'\x00'):
                try:
                    decoded = env_var.decode('utf-8', errors='replace')
                    for sus_env in suspicious_envs:
                        if decoded.startswith(f'{sus_env}='):
                            value = decoded.split('=', 1)[1]
                            findings.append({
                                'type': 'env_injection',
                                'severity': 'high',
                                'detail': f'{sus_env}={value}'
                            })
                except:
                    continue
        except:
            pass
        
        self.alerts.extend(findings)
        return findings
    
    def get_hash(self):
        """Hash the process executable for integrity verification."""
        try:
            exe_path = os.readlink(f'{self.proc_path}/exe')
            if '(deleted)' in exe_path:
                return None
            with open(exe_path, 'rb') as f:
                return hashlib.sha256(f.read()).hexdigest()
        except:
            return None
    
    def full_scan(self):
        """Run all inspection checks on this process."""
        if not self.exists():
            return None
        
        result = {
            'pid': self.pid,
            'name': self.get_name(),
            'exe': self.get_exe(),
            'cmdline': self.get_cmdline(),
            'ppid': self.get_ppid(),
            'uid': self.get_uid(),
            'sha256': self.get_hash()
        }
        
        self.check_exe_deleted()
        self.check_memory_maps()
        self.check_fd_anomalies()
        self.check_ptrace()
        self.check_env_injection()
        
        result['alerts'] = self.alerts
        result['alert_count'] = len(self.alerts)
        result['max_severity'] = max(
            (a['severity'] for a in self.alerts),
            key=lambda s: {'critical': 4, 'high': 3, 'medium': 2, 'low': 1}.get(s, 0),
            default='clean'
        ) if self.alerts else 'clean'
        
        return result


class ProcessPhantom:
    """System-wide process anomaly scanner."""
    
    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/processphantom')
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        self.results = []
        self.alerts = []
    
    def scan_all(self, verbose=False):
        """Scan all running processes."""
        print("👻 ProcessPhantom - Scanning all processes...")
        
        pids = []
        for entry in os.listdir('/proc'):
            if entry.isdigit():
                pids.append(int(entry))
        
        pids.sort()
        total = len(pids)
        flagged = 0
        
        for i, pid in enumerate(pids):
            inspector = ProcessInspector(pid)
            result = inspector.full_scan()
            
            if result:
                self.results.append(result)
                if result['alert_count'] > 0:
                    flagged += 1
                    self.alerts.extend(result['alerts'])
                    
                    if verbose:
                        sev_icon = {
                            'critical': '🔴', 'high': '🟠', 'medium': '🟡'
                        }.get(result['max_severity'], '🔵')
                        print(f"   {sev_icon} PID {pid:>6} ({result['name']:>20}) - {result['alert_count']} alerts [{result['max_severity']}]")
            
            if (i + 1) % 100 == 0:
                print(f"   Scanned {i+1}/{total} processes...")
        
        print(f"\n✅ Scan complete: {total} processes, {flagged} flagged")
        return self._generate_report()
    
    def scan_pid(self, pid):
        """Deep scan a specific process."""
        print(f"👻 ProcessPhantom - Deep scan PID {pid}")
        
        inspector = ProcessInspector(pid)
        result = inspector.full_scan()
        
        if result is None:
            print(f"❌ Process {pid} not found")
            return None
        
        self.results.append(result)
        
        # Print detailed results
        print(f"\n{'='*60}")
        print(f"  PID:     {result['pid']}")
        print(f"  Name:    {result['name']}")
        print(f"  Exe:     {result['exe']}")
        print(f"  Cmdline: {result['cmdline'][:80]}")
        print(f"  PPID:    {result['ppid']}")
        print(f"  UID:     {result['uid']}")
        print(f"  SHA256:  {result['sha256'] or 'N/A'}")
        print(f"  Status:  {result['max_severity'].upper()}")
        
        if result['alerts']:
            print(f"\n  ⚠️  ALERTS ({result['alert_count']}):")
            for alert in result['alerts']:
                sev_icon = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(alert['severity'], '⚪')
                print(f"    {sev_icon} [{alert['severity']}] {alert['type']}: {alert['detail']}")
        else:
            print(f"\n  ✅ No anomalies detected")
        
        print(f"{'='*60}")
        return result
    
    def detect_hidden_processes(self):
        """Detect hidden processes by cross-referencing /proc with ps."""
        import subprocess
        
        # Get PIDs from /proc
        proc_pids = set()
        for entry in os.listdir('/proc'):
            if entry.isdigit():
                proc_pids.add(int(entry))
        
        # Get PIDs from ps
        try:
            result = subprocess.run(['ps', '-eo', 'pid', '--no-headers'], 
                                   capture_output=True, text=True, timeout=10)
            ps_pids = set(int(line.strip()) for line in result.stdout.split('\n') if line.strip())
        except:
            return []
        
        # Look for discrepancies
        hidden_in_proc = proc_pids - ps_pids  # In /proc but not in ps
        hidden_in_ps = ps_pids - proc_pids    # In ps but not in /proc
        
        findings = []
        if hidden_in_proc:
            for pid in hidden_in_proc:
                findings.append({
                    'type': 'hidden_from_ps',
                    'severity': 'critical',
                    'pid': pid,
                    'detail': f'PID {pid} exists in /proc but hidden from ps'
                })
        
        if hidden_in_ps:
            for pid in hidden_in_ps:
                findings.append({
                    'type': 'hidden_from_proc',
                    'severity': 'critical',
                    'pid': pid,
                    'detail': f'PID {pid} in ps output but not in /proc (rootkit?)'
                })
        
        return findings
    
    def check_ld_preload_system(self):
        """Check system-wide LD_PRELOAD files."""
        findings = []
        
        # Check /etc/ld.so.preload
        preload_file = '/etc/ld.so.preload'
        if os.path.exists(preload_file):
            try:
                with open(preload_file) as f:
                    content = f.read().strip()
                if content:
                    findings.append({
                        'type': 'system_preload',
                        'severity': 'high',
                        'detail': f'/etc/ld.so.preload contains: {content}'
                    })
            except:
                pass
        
        # Check for suspicious .so files in common injection paths
        sus_paths = ['/tmp', '/dev/shm', '/var/tmp', '/run/shm']
        for spath in sus_paths:
            if os.path.exists(spath):
                for fpath in glob.glob(f'{spath}/**/*.so*', recursive=True):
                    findings.append({
                        'type': 'suspicious_library',
                        'severity': 'medium',
                        'detail': f'Shared library in suspicious path: {fpath}'
                    })
        
        return findings
    
    def _generate_report(self):
        """Generate analysis report."""
        # Hidden process check
        hidden = self.detect_hidden_processes()
        preload = self.check_ld_preload_system()
        
        flagged = [r for r in self.results if r['alert_count'] > 0]
        
        report = {
            'scan_time': datetime.now().isoformat(),
            'total_processes': len(self.results),
            'flagged_processes': len(flagged),
            'total_alerts': sum(r['alert_count'] for r in self.results),
            'hidden_processes': hidden,
            'system_preload': preload,
            'flagged': sorted(flagged, key=lambda x: x['alert_count'], reverse=True),
            'severity_breakdown': {
                'critical': sum(1 for a in self.alerts if a.get('severity') == 'critical'),
                'high': sum(1 for a in self.alerts if a.get('severity') == 'high'),
                'medium': sum(1 for a in self.alerts if a.get('severity') == 'medium'),
                'low': sum(1 for a in self.alerts if a.get('severity') == 'low'),
            }
        }
        
        # Save JSON
        json_path = os.path.join(self.output_dir, f"phantom-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Generate Markdown
        md_path = os.path.join(self.output_dir, f"phantom-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 👻 ProcessPhantom Scan Report\n\n")
            f.write(f"**Scan Time:** {report['scan_time']}\n\n")
            f.write(f"## Summary\n\n")
            f.write(f"| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Total Processes | {report['total_processes']} |\n")
            f.write(f"| Flagged | {report['flagged_processes']} |\n")
            f.write(f"| Total Alerts | {report['total_alerts']} |\n")
            f.write(f"| 🔴 Critical | {report['severity_breakdown']['critical']} |\n")
            f.write(f"| 🟠 High | {report['severity_breakdown']['high']} |\n")
            f.write(f"| 🟡 Medium | {report['severity_breakdown']['medium']} |\n\n")
            
            if hidden:
                f.write("## ⚠️ Hidden Processes\n\n")
                for h in hidden:
                    f.write(f"- **{h['type']}** PID {h.get('pid', 'N/A')}: {h['detail']}\n")
                f.write("\n")
            
            if preload:
                f.write("## 🔍 System Preload\n\n")
                for p in preload:
                    f.write(f"- [{p['severity']}] {p['detail']}\n")
                f.write("\n")
            
            if flagged:
                f.write("## 🚨 Flagged Processes\n\n")
                for proc in flagged[:30]:
                    f.write(f"### PID {proc['pid']} - {proc['name']}\n\n")
                    f.write(f"- **Exe:** {proc['exe']}\n")
                    f.write(f"- **Severity:** {proc['max_severity']}\n")
                    f.write(f"- **Alerts:** {proc['alert_count']}\n\n")
                    for alert in proc['alerts']:
                        sev = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(alert['severity'], '⚪')
                        f.write(f"  {sev} `{alert['type']}`: {alert['detail']}\n\n")
            
            f.write("---\n*Generated by NullSec ProcessPhantom*\n")
        
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  👻 ProcessPhantom v1.0               ║
    ║  Process Injection Detector           ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='ProcessPhantom - Process Hollowing & Injection Detector')
    parser.add_argument('-p', '--pid', type=int, help='Scan specific PID')
    parser.add_argument('-a', '--all', action='store_true', help='Scan all processes')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-o', '--output', help='Output directory')
    parser.add_argument('--hidden', action='store_true', help='Check for hidden processes only')
    
    args = parser.parse_args()
    
    phantom = ProcessPhantom(args.output)
    
    if args.pid:
        phantom.scan_pid(args.pid)
    elif args.hidden:
        results = phantom.detect_hidden_processes()
        if results:
            for r in results:
                print(f"🔴 {r['detail']}")
        else:
            print("✅ No hidden processes detected")
    elif args.all:
        phantom.scan_all(verbose=args.verbose)
    else:
        parser.print_help()
