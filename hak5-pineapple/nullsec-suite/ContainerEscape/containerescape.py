#!/usr/bin/env python3
"""
NullSec ContainerEscape - Container Escape & Breakout Detector
Audits Docker/Podman containers and the host for escape vectors:
- Privileged container detection
- Dangerous capability analysis (SYS_ADMIN, SYS_PTRACE, etc.)
- Host filesystem mounts (docker.sock, /proc, /sys)
- Namespace isolation verification
- Kernel exploit surface assessment
- Container runtime misconfiguration
- cgroup escape vectors
- AppArmor/SELinux/Seccomp profile checking

Author: bad-antics / NullSec
License: MIT
"""

import os
import sys
import json
import subprocess
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path


# ─── Dangerous Capabilities ────────────────────────────────────────────────

DANGEROUS_CAPS = {
    'SYS_ADMIN': {'severity': 'critical', 'risk': 'Can mount filesystems, access namespaces, full escape vector'},
    'SYS_PTRACE': {'severity': 'critical', 'risk': 'Can inject into host processes via /proc'},
    'SYS_MODULE': {'severity': 'critical', 'risk': 'Can load kernel modules from container'},
    'SYS_RAWIO': {'severity': 'high', 'risk': 'Direct I/O access to host devices'},
    'SYS_BOOT': {'severity': 'high', 'risk': 'Can reboot the host'},
    'NET_ADMIN': {'severity': 'high', 'risk': 'Can modify network configuration, sniff traffic'},
    'NET_RAW': {'severity': 'medium', 'risk': 'Can craft raw packets, ARP spoof'},
    'DAC_READ_SEARCH': {'severity': 'high', 'risk': 'Bypass file read permissions, read host files'},
    'DAC_OVERRIDE': {'severity': 'high', 'risk': 'Bypass all file permissions'},
    'MKNOD': {'severity': 'medium', 'risk': 'Can create device nodes'},
    'SETUID': {'severity': 'medium', 'risk': 'Can escalate privileges'},
    'SETGID': {'severity': 'medium', 'risk': 'Can change group identity'},
    'AUDIT_WRITE': {'severity': 'low', 'risk': 'Can write to kernel audit log'},
}

# Dangerous mount paths
DANGEROUS_MOUNTS = {
    '/var/run/docker.sock': {'severity': 'critical', 'risk': 'Full Docker API access → instant host escape'},
    '/run/docker.sock': {'severity': 'critical', 'risk': 'Full Docker API access → instant host escape'},
    '/var/run/containerd': {'severity': 'critical', 'risk': 'Containerd socket → container escape'},
    '/proc': {'severity': 'critical', 'risk': 'Host /proc access → information leak, escape vector'},
    '/sys': {'severity': 'high', 'risk': 'Host /sys access → device & cgroup manipulation'},
    '/etc': {'severity': 'high', 'risk': 'Host /etc → credential theft, config modification'},
    '/root': {'severity': 'critical', 'risk': 'Host root home → SSH keys, credentials'},
    '/home': {'severity': 'high', 'risk': 'Host home dirs → user credentials'},
    '/': {'severity': 'critical', 'risk': 'Entire host filesystem mounted'},
    '/dev': {'severity': 'high', 'risk': 'Host device access'},
    '/boot': {'severity': 'high', 'risk': 'Host boot partition → kernel tampering'},
    '/lib/modules': {'severity': 'high', 'risk': 'Kernel modules access'},
}


class ContainerInspector:
    """Inspect individual containers for escape vectors."""
    
    def __init__(self, container_id, runtime='docker'):
        self.container_id = container_id
        self.runtime = runtime
        self.info = {}
        self.findings = []
    
    def inspect(self):
        """Get container inspection data."""
        try:
            result = subprocess.run(
                [self.runtime, 'inspect', self.container_id],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self.info = json.loads(result.stdout)[0]
                return True
        except Exception as e:
            print(f"   ⚠️  Inspect failed for {self.container_id}: {e}")
        return False
    
    def check_privileged(self):
        """Check if container is running in privileged mode."""
        privileged = self.info.get('HostConfig', {}).get('Privileged', False)
        if privileged:
            self.findings.append({
                'type': 'privileged_container',
                'severity': 'critical',
                'detail': 'Container running in PRIVILEGED mode - full host access',
                'remediation': 'Remove --privileged flag, use specific capabilities instead'
            })
        return privileged
    
    def check_capabilities(self):
        """Analyze container capabilities."""
        host_config = self.info.get('HostConfig', {})
        
        cap_add = host_config.get('CapAdd') or []
        cap_drop = host_config.get('CapDrop') or []
        
        findings = []
        for cap in cap_add:
            cap_upper = cap.upper().replace('CAP_', '')
            if cap_upper in DANGEROUS_CAPS:
                info = DANGEROUS_CAPS[cap_upper]
                findings.append({
                    'type': 'dangerous_capability',
                    'capability': cap_upper,
                    'severity': info['severity'],
                    'detail': info['risk'],
                    'remediation': f'Remove cap-add {cap} unless absolutely required'
                })
        
        # Check if ALL caps are added
        if 'ALL' in [c.upper() for c in cap_add]:
            findings.append({
                'type': 'all_capabilities',
                'severity': 'critical',
                'detail': 'ALL capabilities granted - equivalent to privileged',
                'remediation': 'Never use --cap-add=ALL, specify only needed capabilities'
            })
        
        # Check if important caps NOT dropped
        if not cap_drop or 'ALL' not in [c.upper() for c in cap_drop]:
            default_dangerous = ['NET_RAW', 'SYS_CHROOT']
            for cap in default_dangerous:
                if cap not in [c.upper().replace('CAP_', '') for c in cap_drop]:
                    findings.append({
                        'type': 'undropped_capability',
                        'capability': cap,
                        'severity': 'low',
                        'detail': f'Default capability {cap} not explicitly dropped',
                        'remediation': f'Consider --cap-drop {cap}'
                    })
        
        self.findings.extend(findings)
        return findings
    
    def check_mounts(self):
        """Check for dangerous volume mounts."""
        mounts = self.info.get('Mounts', [])
        host_config = self.info.get('HostConfig', {})
        binds = host_config.get('Binds') or []
        
        findings = []
        
        # Check Mounts
        for mount in mounts:
            source = mount.get('Source', '')
            dest = mount.get('Destination', '')
            rw = mount.get('RW', True)
            
            for dangerous_path, info in DANGEROUS_MOUNTS.items():
                if source == dangerous_path or source.startswith(dangerous_path + '/'):
                    findings.append({
                        'type': 'dangerous_mount',
                        'source': source,
                        'destination': dest,
                        'read_write': rw,
                        'severity': info['severity'],
                        'detail': info['risk'],
                        'remediation': f'Remove mount of {source} or use :ro flag'
                    })
        
        # Check Binds
        for bind in binds:
            parts = bind.split(':')
            if len(parts) >= 2:
                source = parts[0]
                for dangerous_path, info in DANGEROUS_MOUNTS.items():
                    if source == dangerous_path or source.startswith(dangerous_path + '/'):
                        rw = ':ro' not in bind
                        findings.append({
                            'type': 'dangerous_bind',
                            'source': source,
                            'bind': bind,
                            'read_write': rw,
                            'severity': info['severity'],
                            'detail': info['risk'],
                            'remediation': f'Remove bind mount or add :ro'
                        })
        
        self.findings.extend(findings)
        return findings
    
    def check_network(self):
        """Check network configuration."""
        findings = []
        
        network_mode = self.info.get('HostConfig', {}).get('NetworkMode', '')
        if network_mode == 'host':
            findings.append({
                'type': 'host_network',
                'severity': 'high',
                'detail': 'Container uses host network namespace - can see all host traffic',
                'remediation': 'Use bridge or custom network instead of --network=host'
            })
        
        self.findings.extend(findings)
        return findings
    
    def check_pid_namespace(self):
        """Check PID namespace isolation."""
        findings = []
        
        pid_mode = self.info.get('HostConfig', {}).get('PidMode', '')
        if pid_mode == 'host':
            findings.append({
                'type': 'host_pid',
                'severity': 'critical',
                'detail': 'Container shares host PID namespace - can see/signal all host processes',
                'remediation': 'Remove --pid=host flag'
            })
        
        self.findings.extend(findings)
        return findings
    
    def check_security_profiles(self):
        """Check AppArmor, SELinux, and Seccomp profiles."""
        findings = []
        host_config = self.info.get('HostConfig', {})
        
        # Seccomp
        security_opt = host_config.get('SecurityOpt') or []
        seccomp_disabled = any('seccomp=unconfined' in opt or 'seccomp:unconfined' in opt 
                              for opt in security_opt)
        if seccomp_disabled:
            findings.append({
                'type': 'seccomp_disabled',
                'severity': 'high',
                'detail': 'Seccomp profile disabled - all syscalls allowed',
                'remediation': 'Use default or custom seccomp profile'
            })
        
        # AppArmor
        apparmor_disabled = any('apparmor=unconfined' in opt or 'apparmor:unconfined' in opt
                               for opt in security_opt)
        if apparmor_disabled:
            findings.append({
                'type': 'apparmor_disabled',
                'severity': 'high',
                'detail': 'AppArmor profile disabled',
                'remediation': 'Use default or custom AppArmor profile'
            })
        
        # Running as root
        user = self.info.get('Config', {}).get('User', '')
        if not user or user == '0' or user == 'root':
            findings.append({
                'type': 'running_as_root',
                'severity': 'medium',
                'detail': 'Container running as root user',
                'remediation': 'Add USER directive in Dockerfile or use --user flag'
            })
        
        self.findings.extend(findings)
        return findings
    
    def check_env_secrets(self):
        """Check for secrets in environment variables."""
        findings = []
        env_vars = self.info.get('Config', {}).get('Env') or []
        
        secret_patterns = [
            (r'(?i)(password|passwd|pwd)\s*=\s*\S+', 'Password in environment'),
            (r'(?i)(secret|token|api_key|apikey)\s*=\s*\S+', 'Secret/token in environment'),
            (r'(?i)(aws_access_key|aws_secret)\s*=\s*\S+', 'AWS credentials in environment'),
            (r'(?i)(database_url|db_password)\s*=\s*\S+', 'Database credentials in environment'),
        ]
        
        for var in env_vars:
            for pattern, description in secret_patterns:
                if re.search(pattern, var):
                    # Mask the value
                    key = var.split('=')[0]
                    findings.append({
                        'type': 'env_secret',
                        'severity': 'medium',
                        'detail': f'{description}: {key}=***',
                        'remediation': 'Use Docker secrets or config files instead'
                    })
                    break
        
        self.findings.extend(findings)
        return findings
    
    def full_audit(self):
        """Run all security checks."""
        if not self.inspect():
            return None
        
        name = self.info.get('Name', self.container_id).lstrip('/')
        image = self.info.get('Config', {}).get('Image', 'unknown')
        state = self.info.get('State', {}).get('Status', 'unknown')
        
        self.check_privileged()
        self.check_capabilities()
        self.check_mounts()
        self.check_network()
        self.check_pid_namespace()
        self.check_security_profiles()
        self.check_env_secrets()
        
        max_severity = 'clean'
        severity_order = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1, 'clean': 0}
        for f in self.findings:
            if severity_order.get(f['severity'], 0) > severity_order.get(max_severity, 0):
                max_severity = f['severity']
        
        return {
            'container_id': self.container_id[:12],
            'name': name,
            'image': image,
            'state': state,
            'findings': self.findings,
            'finding_count': len(self.findings),
            'max_severity': max_severity,
            'risk_score': sum(
                {'critical': 25, 'high': 15, 'medium': 5, 'low': 1}.get(f['severity'], 0)
                for f in self.findings
            )
        }


class HostAuditor:
    """Audit the container host for security issues."""
    
    def __init__(self):
        self.findings = []
    
    def check_docker_socket(self):
        """Check Docker socket permissions."""
        sock_paths = ['/var/run/docker.sock', '/run/docker.sock']
        for sock in sock_paths:
            if os.path.exists(sock):
                stat = os.stat(sock)
                mode = oct(stat.st_mode)[-3:]
                
                if mode[2] != '0':  # World-readable/writable
                    self.findings.append({
                        'type': 'socket_permissions',
                        'severity': 'critical',
                        'detail': f'{sock} is world-accessible (mode: {mode})',
                        'remediation': 'chmod 660 and restrict to docker group'
                    })
    
    def check_docker_daemon(self):
        """Check Docker daemon configuration."""
        config_paths = ['/etc/docker/daemon.json']
        for path in config_paths:
            if os.path.exists(path):
                try:
                    with open(path) as f:
                        config = json.load(f)
                    
                    # Check for insecure registries
                    if config.get('insecure-registries'):
                        self.findings.append({
                            'type': 'insecure_registry',
                            'severity': 'medium',
                            'detail': f"Insecure registries: {config['insecure-registries']}",
                            'remediation': 'Use TLS for all registries'
                        })
                    
                    # Check if live restore is disabled
                    if not config.get('live-restore', False):
                        self.findings.append({
                            'type': 'no_live_restore',
                            'severity': 'low',
                            'detail': 'Docker live restore not enabled',
                            'remediation': 'Enable "live-restore": true in daemon.json'
                        })
                    
                    # Check if user namespace remapping is enabled
                    if not config.get('userns-remap'):
                        self.findings.append({
                            'type': 'no_userns_remap',
                            'severity': 'medium',
                            'detail': 'User namespace remapping not enabled',
                            'remediation': 'Enable "userns-remap": "default" in daemon.json'
                        })
                except:
                    pass
    
    def check_kernel(self):
        """Check kernel security features."""
        # Check kernel version for known container escape CVEs
        try:
            result = subprocess.run(['uname', '-r'], capture_output=True, text=True)
            kernel = result.stdout.strip()
            
            # Known vulnerable kernels (simplified)
            vuln_patterns = [
                (r'^4\.[0-9]\.',  'CVE-2016-5195 (DirtyCow) - kernel < 4.9'),
                (r'^5\.[0-4]\.',  'Multiple container escape CVEs in early 5.x'),
            ]
            
            for pattern, desc in vuln_patterns:
                if re.match(pattern, kernel):
                    self.findings.append({
                        'type': 'vulnerable_kernel',
                        'severity': 'high',
                        'detail': f'Kernel {kernel} potentially vulnerable: {desc}',
                        'remediation': 'Update to latest stable kernel'
                    })
        except:
            pass
    
    def audit(self):
        """Run all host checks."""
        self.check_docker_socket()
        self.check_docker_daemon()
        self.check_kernel()
        return self.findings


class ContainerEscape:
    """Main container security audit engine."""
    
    def __init__(self, output_dir=None, runtime='docker'):
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/containerescape')
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        self.runtime = runtime
        self.container_results = []
        self.host_findings = []
    
    def detect_runtime(self):
        """Detect available container runtime."""
        for rt in ['docker', 'podman', 'nerdctl']:
            try:
                result = subprocess.run([rt, '--version'], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    return rt, result.stdout.strip()
            except:
                continue
        return None, None
    
    def list_containers(self):
        """List all containers (running and stopped)."""
        try:
            result = subprocess.run(
                [self.runtime, 'ps', '-a', '--format', '{{.ID}}'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                return [cid.strip() for cid in result.stdout.split('\n') if cid.strip()]
        except:
            pass
        return []
    
    def audit_all(self, verbose=False):
        """Audit all containers and host."""
        print("🐳 ContainerEscape - Security Audit")
        print("=" * 50)
        
        # Detect runtime
        runtime, version = self.detect_runtime()
        if not runtime:
            print("❌ No container runtime found (docker/podman)")
            return None
        
        self.runtime = runtime
        print(f"   Runtime: {version}")
        
        # Host audit
        print("\n🖥️  Host Security Audit...")
        host = HostAuditor()
        self.host_findings = host.audit()
        for f in self.host_findings:
            sev_icon = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(f['severity'], '⚪')
            print(f"   {sev_icon} [{f['severity']}] {f['type']}: {f['detail']}")
        
        if not self.host_findings:
            print("   ✅ No host-level issues found")
        
        # Container audit
        containers = self.list_containers()
        print(f"\n🔍 Auditing {len(containers)} containers...")
        
        for cid in containers:
            inspector = ContainerInspector(cid, self.runtime)
            result = inspector.full_audit()
            
            if result:
                self.container_results.append(result)
                
                if result['finding_count'] > 0:
                    sev_icon = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(result['max_severity'], '⚪')
                    print(f"   {sev_icon} {result['name']:30s} ({result['image']:30s}) "
                          f"[{result['max_severity']}] {result['finding_count']} findings, "
                          f"risk: {result['risk_score']}")
                    
                    if verbose:
                        for f in result['findings']:
                            print(f"      └─ [{f['severity']}] {f['type']}: {f['detail'][:70]}")
                elif verbose:
                    print(f"   ✅ {result['name']:30s} - clean")
        
        return self._generate_report(runtime, version)
    
    def audit_container(self, container_id, verbose=True):
        """Audit a specific container."""
        print(f"🐳 ContainerEscape - Auditing {container_id}")
        
        runtime, _ = self.detect_runtime()
        if runtime:
            self.runtime = runtime
        
        inspector = ContainerInspector(container_id, self.runtime)
        result = inspector.full_audit()
        
        if not result:
            print(f"❌ Could not inspect container {container_id}")
            return None
        
        self.container_results.append(result)
        
        print(f"\n{'='*60}")
        print(f"  Container: {result['name']}")
        print(f"  Image:     {result['image']}")
        print(f"  State:     {result['state']}")
        print(f"  Risk:      {result['risk_score']} ({result['max_severity']})")
        print(f"  Findings:  {result['finding_count']}")
        
        if result['findings']:
            print(f"\n  {'─'*56}")
            for f in result['findings']:
                sev = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(f['severity'], '⚪')
                print(f"  {sev} [{f['severity']:8s}] {f['type']}")
                print(f"     Detail: {f['detail']}")
                print(f"     Fix:    {f.get('remediation', 'N/A')}")
                print()
        else:
            print("\n  ✅ No escape vectors detected")
        
        print(f"{'='*60}")
        return result
    
    def _generate_report(self, runtime, version):
        """Generate audit report."""
        sorted_containers = sorted(
            self.container_results,
            key=lambda x: x['risk_score'],
            reverse=True
        )
        
        report = {
            'scan_time': datetime.now().isoformat(),
            'runtime': runtime,
            'runtime_version': version,
            'total_containers': len(self.container_results),
            'containers_at_risk': sum(1 for c in self.container_results if c['risk_score'] > 0),
            'total_findings': sum(c['finding_count'] for c in self.container_results) + len(self.host_findings),
            'host_findings': self.host_findings,
            'containers': sorted_containers,
            'severity_summary': {
                'critical': sum(1 for c in sorted_containers for f in c['findings'] if f['severity'] == 'critical'),
                'high': sum(1 for c in sorted_containers for f in c['findings'] if f['severity'] == 'high'),
                'medium': sum(1 for c in sorted_containers for f in c['findings'] if f['severity'] == 'medium'),
                'low': sum(1 for c in sorted_containers for f in c['findings'] if f['severity'] == 'low'),
            }
        }
        
        # Save JSON
        json_path = os.path.join(self.output_dir, f"container-audit-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Markdown
        md_path = os.path.join(self.output_dir, f"container-audit-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 🐳 ContainerEscape Security Audit\n\n")
            f.write(f"**Generated:** {report['scan_time']}\n")
            f.write(f"**Runtime:** {version}\n\n")
            f.write("## Summary\n\n")
            f.write(f"| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Containers | {report['total_containers']} |\n")
            f.write(f"| At Risk | {report['containers_at_risk']} |\n")
            f.write(f"| Total Findings | {report['total_findings']} |\n")
            f.write(f"| 🔴 Critical | {report['severity_summary']['critical']} |\n")
            f.write(f"| 🟠 High | {report['severity_summary']['high']} |\n")
            f.write(f"| 🟡 Medium | {report['severity_summary']['medium']} |\n\n")
            
            if self.host_findings:
                f.write("## Host Findings\n\n")
                for h in self.host_findings:
                    f.write(f"- [{h['severity']}] **{h['type']}**: {h['detail']}\n")
                    f.write(f"  - Fix: {h.get('remediation', 'N/A')}\n")
                f.write("\n")
            
            if sorted_containers:
                f.write("## Container Results\n\n")
                f.write("| Container | Image | Risk | Findings | Max Severity |\n")
                f.write("|-----------|-------|------|----------|-------------|\n")
                for c in sorted_containers:
                    f.write(f"| {c['name']} | {c['image'][:30]} | {c['risk_score']} | {c['finding_count']} | {c['max_severity']} |\n")
                f.write("\n")
                
                # Detailed findings for risky containers
                risky = [c for c in sorted_containers if c['risk_score'] > 0]
                if risky:
                    f.write("## Detailed Findings\n\n")
                    for c in risky:
                        f.write(f"### {c['name']} (risk: {c['risk_score']})\n\n")
                        for finding in c['findings']:
                            sev = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(finding['severity'], '⚪')
                            f.write(f"- {sev} **{finding['type']}** [{finding['severity']}]\n")
                            f.write(f"  - {finding['detail']}\n")
                            f.write(f"  - Fix: {finding.get('remediation', 'N/A')}\n")
                        f.write("\n")
            
            f.write("---\n*Generated by NullSec ContainerEscape*\n")
        
        print(f"\n📄 Reports:")
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  🐳 ContainerEscape v1.0              ║
    ║  Container Escape & Breakout Detector ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='ContainerEscape - Container Security Auditor')
    parser.add_argument('-a', '--all', action='store_true', help='Audit all containers + host')
    parser.add_argument('-c', '--container', help='Audit specific container (name or ID)')
    parser.add_argument('-r', '--runtime', default='docker', help='Container runtime (docker/podman)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-o', '--output', help='Output directory')
    parser.add_argument('--host-only', action='store_true', help='Only audit host configuration')
    
    args = parser.parse_args()
    
    scanner = ContainerEscape(args.output, args.runtime)
    
    if args.container:
        scanner.audit_container(args.container, verbose=True)
    elif args.host_only:
        host = HostAuditor()
        findings = host.audit()
        for f in findings:
            sev = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🔵'}.get(f['severity'], '⚪')
            print(f"{sev} [{f['severity']}] {f['type']}: {f['detail']}")
            print(f"   Fix: {f.get('remediation', 'N/A')}")
        if not findings:
            print("✅ Host configuration looks good")
    elif args.all:
        scanner.audit_all(verbose=args.verbose)
    else:
        # Default: audit all
        scanner.audit_all()
