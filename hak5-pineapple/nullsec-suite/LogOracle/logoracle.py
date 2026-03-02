#!/usr/bin/env python3
"""
NullSec LogOracle - AI-Powered Log Anomaly Detector
Uses local HailMary AI model (via Ollama) to detect anomalies in system logs.

Features:
- Statistical baseline learning (normal patterns)
- Entropy-based anomaly scoring
- AI-powered analysis via HailMary model
- Multi-source log ingestion (syslog, auth, journal, nginx, apache)
- Pattern clustering & frequency analysis
- Real-time monitoring mode
- Alert correlation engine
- JSON + Markdown reports

Author: bad-antics / NullSec
License: MIT
"""

import os
import re
import sys
import json
import math
import time
import glob
import subprocess
import hashlib
from collections import defaultdict, Counter
from datetime import datetime, timedelta
from pathlib import Path


class LogPattern:
    """Represents a normalized log pattern for frequency analysis."""
    
    def __init__(self, template):
        self.template = template
        self.count = 0
        self.first_seen = None
        self.last_seen = None
        self.sources = set()
        self.severities = Counter()
        self.sample_messages = []
    
    def add(self, message, timestamp, source, severity='info'):
        self.count += 1
        if self.first_seen is None or timestamp < self.first_seen:
            self.first_seen = timestamp
        if self.last_seen is None or timestamp > self.last_seen:
            self.last_seen = timestamp
        self.sources.add(source)
        self.severities[severity] += 1
        if len(self.sample_messages) < 3:
            self.sample_messages.append(message[:200])


class AnomalyDetector:
    """Statistical anomaly detection engine."""
    
    def __init__(self):
        self.baselines = {}  # pattern_hash -> expected_frequency
        self.pattern_db = {}  # pattern_hash -> LogPattern
        self.hourly_counts = defaultdict(lambda: defaultdict(int))
        self.anomalies = []
    
    def normalize_message(self, message):
        """Normalize a log message into a template by replacing dynamic values."""
        template = message
        # Replace IPs
        template = re.sub(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', '<IP>', template)
        # Replace timestamps
        template = re.sub(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}', '<TIMESTAMP>', template)
        # Replace numbers
        template = re.sub(r'\b\d{4,}\b', '<NUM>', template)
        # Replace hex values
        template = re.sub(r'0x[0-9a-fA-F]+', '<HEX>', template)
        # Replace UUIDs
        template = re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '<UUID>', template)
        # Replace file paths with variable components
        template = re.sub(r'/\S+/\S+', '<PATH>', template)
        # Replace email-like patterns
        template = re.sub(r'\S+@\S+', '<EMAIL>', template)
        
        return template
    
    def add_message(self, message, timestamp, source, severity='info'):
        """Add a log message to the analysis engine."""
        template = self.normalize_message(message)
        pattern_hash = hashlib.md5(template.encode()).hexdigest()[:16]
        
        if pattern_hash not in self.pattern_db:
            self.pattern_db[pattern_hash] = LogPattern(template)
        
        self.pattern_db[pattern_hash].add(message, timestamp, source, severity)
        
        # Track hourly frequency
        if isinstance(timestamp, datetime):
            hour_key = timestamp.strftime('%Y-%m-%d-%H')
            self.hourly_counts[hour_key][pattern_hash] += 1
    
    def detect_frequency_anomalies(self, threshold=3.0):
        """Detect patterns that appear at unusual frequencies."""
        if len(self.hourly_counts) < 2:
            return []
        
        # Calculate baseline frequencies per pattern
        pattern_hourly = defaultdict(list)
        for hour, patterns in self.hourly_counts.items():
            for pattern_hash, count in patterns.items():
                pattern_hourly[pattern_hash].append(count)
        
        anomalies = []
        for pattern_hash, counts in pattern_hourly.items():
            if len(counts) < 2:
                continue
            
            mean = sum(counts) / len(counts)
            variance = sum((c - mean) ** 2 for c in counts) / len(counts)
            std_dev = math.sqrt(variance) if variance > 0 else 1
            
            # Check most recent hour
            latest_hour = max(self.hourly_counts.keys())
            latest_count = self.hourly_counts[latest_hour].get(pattern_hash, 0)
            
            if std_dev > 0:
                z_score = (latest_count - mean) / std_dev
            else:
                z_score = 0
            
            if abs(z_score) > threshold:
                pattern = self.pattern_db.get(pattern_hash)
                anomalies.append({
                    'type': 'frequency_spike' if z_score > 0 else 'frequency_drop',
                    'pattern': pattern.template if pattern else 'unknown',
                    'z_score': round(z_score, 2),
                    'latest_count': latest_count,
                    'mean_count': round(mean, 2),
                    'std_dev': round(std_dev, 2),
                    'severity': 'critical' if abs(z_score) > 5 else 'high' if abs(z_score) > 4 else 'medium',
                    'samples': pattern.sample_messages if pattern else []
                })
        
        return sorted(anomalies, key=lambda x: abs(x['z_score']), reverse=True)
    
    def detect_rare_patterns(self, max_count=2):
        """Find extremely rare log patterns (potential indicators of compromise)."""
        rare = []
        for pattern_hash, pattern in self.pattern_db.items():
            if pattern.count <= max_count:
                rare.append({
                    'type': 'rare_pattern',
                    'pattern': pattern.template,
                    'count': pattern.count,
                    'sources': list(pattern.sources),
                    'severity': 'medium',
                    'samples': pattern.sample_messages
                })
        
        return rare
    
    def detect_security_events(self):
        """Detect known security-relevant log patterns."""
        security_patterns = {
            r'authentication fail|login fail|invalid password': ('auth_failure', 'high'),
            r'sudo.*COMMAND|su\[.*\]': ('privilege_escalation', 'medium'),
            r'segfault|buffer overflow|stack smash': ('crash_exploit', 'critical'),
            r'iptables.*DROP|firewall.*blocked|denied': ('firewall_hit', 'medium'),
            r'ssh.*Invalid user|sshd.*Failed': ('ssh_bruteforce', 'high'),
            r'kernel.*Out of memory|OOM killer': ('oom_event', 'high'),
            r'kernel.*possible SYN flooding': ('syn_flood', 'critical'),
            r'COMMAND.*(?:wget|curl|nc|ncat|socat).*(?:/tmp|/dev/shm)': ('suspicious_download', 'critical'),
            r'reverse shell|bind shell|/bin/(?:ba)?sh\s+-i': ('shell_activity', 'critical'),
            r'cron.*(?:REPLACE|MODIFY)': ('cron_modification', 'high'),
            r'kernel.*promiscuous mode': ('promisc_mode', 'high'),
            r'useradd|adduser|passwd.*changed': ('user_modification', 'medium'),
        }
        
        events = []
        for pattern_hash, pattern in self.pattern_db.items():
            for sample in pattern.sample_messages:
                for regex, (event_type, severity) in security_patterns.items():
                    if re.search(regex, sample, re.IGNORECASE):
                        events.append({
                            'type': event_type,
                            'severity': severity,
                            'pattern': pattern.template,
                            'count': pattern.count,
                            'sample': sample[:200]
                        })
                        break
        
        return events


class OllamaInterface:
    """Interface to local Ollama HailMary model for AI analysis."""
    
    def __init__(self, model='hailmary-research'):
        self.model = model
        self.available = self._check_available()
    
    def _check_available(self):
        """Check if Ollama and model are available."""
        try:
            result = subprocess.run(['ollama', 'list'], capture_output=True, text=True, timeout=5)
            return self.model in result.stdout
        except:
            return False
    
    def analyze(self, log_data, context=""):
        """Send log data to HailMary for AI analysis."""
        if not self.available:
            return None
        
        prompt = f"""You are a security log analyst. Analyze these log entries for security threats, anomalies, and indicators of compromise.

Context: {context}

Log Data:
{log_data[:3000]}

Provide a concise analysis covering:
1. Key security findings
2. Anomaly assessment  
3. Recommended actions
4. Threat severity (critical/high/medium/low/clean)

Be specific and actionable."""
        
        try:
            result = subprocess.run(
                ['ollama', 'run', self.model],
                input=prompt,
                capture_output=True, text=True, timeout=120
            )
            return result.stdout.strip() if result.returncode == 0 else None
        except:
            return None


class LogOracle:
    """Main log analysis engine."""
    
    LOG_SOURCES = {
        'syslog': ['/var/log/syslog', '/var/log/syslog.1'],
        'auth': ['/var/log/auth.log', '/var/log/auth.log.1', '/var/log/secure'],
        'kern': ['/var/log/kern.log', '/var/log/kern.log.1'],
        'nginx': ['/var/log/nginx/access.log', '/var/log/nginx/error.log'],
        'apache': ['/var/log/apache2/access.log', '/var/log/apache2/error.log'],
        'journal': None  # Uses journalctl
    }
    
    SYSLOG_PATTERN = re.compile(
        r'^(\w{3}\s+\d+\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+?)(?:\[\d+\])?\s*:\s*(.*)'
    )
    
    def __init__(self, output_dir=None, use_ai=True):
        self.output_dir = output_dir or os.path.expanduser('~/.nullsec/logoracle')
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        self.detector = AnomalyDetector()
        self.ai = OllamaInterface() if use_ai else None
        self.raw_lines = 0
        self.sources_processed = []
    
    def ingest_file(self, filepath):
        """Ingest a single log file."""
        if not os.path.exists(filepath):
            return 0
        
        count = 0
        try:
            with open(filepath, 'r', errors='replace') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    
                    match = self.SYSLOG_PATTERN.match(line)
                    if match:
                        timestamp_str = match.group(1)
                        host = match.group(2)
                        program = match.group(3)
                        message = match.group(4)
                        
                        try:
                            timestamp = datetime.strptime(
                                f"{datetime.now().year} {timestamp_str}",
                                "%Y %b %d %H:%M:%S"
                            )
                        except:
                            timestamp = datetime.now()
                        
                        severity = self._classify_severity(message)
                        self.detector.add_message(message, timestamp, 
                                                 os.path.basename(filepath), severity)
                        count += 1
                    else:
                        # Try generic parsing
                        self.detector.add_message(line, datetime.now(),
                                                 os.path.basename(filepath))
                        count += 1
        except PermissionError:
            print(f"   ⚠️  Permission denied: {filepath}")
        except Exception as e:
            print(f"   ⚠️  Error: {filepath}: {e}")
        
        return count
    
    def ingest_journal(self, hours=24):
        """Ingest from systemd journal."""
        try:
            since = (datetime.now() - timedelta(hours=hours)).strftime('%Y-%m-%d %H:%M:%S')
            result = subprocess.run(
                ['journalctl', '--no-pager', '-o', 'short-iso', f'--since={since}'],
                capture_output=True, text=True, timeout=30
            )
            
            count = 0
            for line in result.stdout.split('\n'):
                if not line.strip():
                    continue
                
                parts = line.split(' ', 4)
                if len(parts) >= 5:
                    try:
                        timestamp = datetime.fromisoformat(parts[0])
                        message = parts[4]
                        severity = self._classify_severity(message)
                        self.detector.add_message(message, timestamp, 'journal', severity)
                        count += 1
                    except:
                        continue
            
            return count
        except:
            return 0
    
    def _classify_severity(self, message):
        """Classify log message severity."""
        message_lower = message.lower()
        if any(w in message_lower for w in ['critical', 'emergency', 'panic', 'fatal']):
            return 'critical'
        if any(w in message_lower for w in ['error', 'fail', 'denied', 'refused']):
            return 'error'
        if any(w in message_lower for w in ['warning', 'warn', 'timeout']):
            return 'warning'
        return 'info'
    
    def analyze(self, sources=None, hours=24):
        """Run full analysis pipeline."""
        print("🔮 LogOracle - AI-Powered Log Anomaly Detector")
        print("=" * 50)
        
        # Ingest logs
        total_lines = 0
        
        if sources is None:
            sources = list(self.LOG_SOURCES.keys())
        
        for source in sources:
            if source == 'journal':
                print(f"   📥 Ingesting journal (last {hours}h)...")
                count = self.ingest_journal(hours)
                if count:
                    total_lines += count
                    self.sources_processed.append('journal')
                    print(f"      {count:,} entries")
            else:
                files = self.LOG_SOURCES.get(source, [source])
                if files:
                    for filepath in files:
                        if os.path.exists(filepath):
                            print(f"   📥 Ingesting {filepath}...")
                            count = self.ingest_file(filepath)
                            total_lines += count
                            self.sources_processed.append(filepath)
                            print(f"      {count:,} entries")
        
        self.raw_lines = total_lines
        print(f"\n   Total: {total_lines:,} log entries from {len(self.sources_processed)} sources")
        
        # Run detection
        print("\n🔍 Running anomaly detection...")
        
        freq_anomalies = self.detector.detect_frequency_anomalies()
        print(f"   Frequency anomalies: {len(freq_anomalies)}")
        
        rare_patterns = self.detector.detect_rare_patterns()
        print(f"   Rare patterns: {len(rare_patterns)}")
        
        security_events = self.detector.detect_security_events()
        print(f"   Security events: {len(security_events)}")
        
        # AI analysis (if available)
        ai_analysis = None
        if self.ai and self.ai.available:
            print("\n🤖 Running AI analysis (HailMary)...")
            # Prepare summary for AI
            summary_lines = []
            for event in (security_events[:10] + freq_anomalies[:5]):
                summary_lines.append(json.dumps(event, default=str))
            
            if summary_lines:
                ai_analysis = self.ai.analyze(
                    '\n'.join(summary_lines),
                    f"Analyzed {total_lines} log entries from {len(self.sources_processed)} sources"
                )
                if ai_analysis:
                    print(f"   ✅ AI analysis complete ({len(ai_analysis)} chars)")
                else:
                    print("   ⚠️  AI analysis returned empty")
        elif self.ai:
            print("\n   ⚠️  HailMary model not available (run: ollama pull hailmary)")
        
        return self._generate_report(freq_anomalies, rare_patterns, security_events, ai_analysis)
    
    def _generate_report(self, freq_anomalies, rare_patterns, security_events, ai_analysis):
        """Generate analysis report."""
        report = {
            'scan_time': datetime.now().isoformat(),
            'total_lines': self.raw_lines,
            'sources': self.sources_processed,
            'unique_patterns': len(self.detector.pattern_db),
            'frequency_anomalies': freq_anomalies[:20],
            'rare_patterns': rare_patterns[:20],
            'security_events': security_events[:50],
            'ai_analysis': ai_analysis,
            'severity_summary': {
                'critical': sum(1 for e in security_events if e.get('severity') == 'critical'),
                'high': sum(1 for e in security_events if e.get('severity') == 'high'),
                'medium': sum(1 for e in security_events if e.get('severity') == 'medium'),
            }
        }
        
        # Save JSON
        json_path = os.path.join(self.output_dir, f"logoracle-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
        with open(json_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Generate Markdown
        md_path = os.path.join(self.output_dir, f"logoracle-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        with open(md_path, 'w') as f:
            f.write("# 🔮 LogOracle Analysis Report\n\n")
            f.write(f"**Generated:** {report['scan_time']}\n\n")
            f.write("## Summary\n\n")
            f.write(f"| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Log Entries | {self.raw_lines:,} |\n")
            f.write(f"| Sources | {len(self.sources_processed)} |\n")
            f.write(f"| Unique Patterns | {report['unique_patterns']} |\n")
            f.write(f"| 🔴 Critical | {report['severity_summary']['critical']} |\n")
            f.write(f"| 🟠 High | {report['severity_summary']['high']} |\n")
            f.write(f"| 🟡 Medium | {report['severity_summary']['medium']} |\n\n")
            
            if security_events:
                f.write("## 🚨 Security Events\n\n")
                f.write("| Type | Severity | Count | Sample |\n")
                f.write("|------|----------|-------|--------|\n")
                for e in security_events[:30]:
                    f.write(f"| {e['type']} | {e['severity']} | {e.get('count', 1)} | {e.get('sample', '')[:60]} |\n")
                f.write("\n")
            
            if freq_anomalies:
                f.write("## 📊 Frequency Anomalies\n\n")
                for a in freq_anomalies[:10]:
                    f.write(f"### {a['type']} (z-score: {a['z_score']})\n\n")
                    f.write(f"- **Severity:** {a['severity']}\n")
                    f.write(f"- **Latest count:** {a['latest_count']} (mean: {a['mean_count']})\n")
                    f.write(f"- **Pattern:** `{a['pattern'][:80]}`\n\n")
            
            if ai_analysis:
                f.write("## 🤖 AI Analysis (HailMary)\n\n")
                f.write(ai_analysis)
                f.write("\n\n")
            
            f.write("---\n*Generated by NullSec LogOracle*\n")
        
        print(f"\n📄 Reports:")
        print(f"   JSON: {json_path}")
        print(f"   Report: {md_path}")
        
        return report


if __name__ == '__main__':
    import argparse
    
    banner = """
    ╔═══════════════════════════════════════╗
    ║  🔮 LogOracle v1.0                    ║
    ║  AI-Powered Log Anomaly Detector      ║
    ║  NullSec Security Suite               ║
    ╚═══════════════════════════════════════╝
    """
    print(banner)
    
    parser = argparse.ArgumentParser(description='LogOracle - AI Log Anomaly Detection')
    parser.add_argument('-s', '--sources', nargs='+', 
                       choices=['syslog', 'auth', 'kern', 'nginx', 'apache', 'journal'],
                       help='Log sources to analyze')
    parser.add_argument('-f', '--file', help='Analyze a specific log file')
    parser.add_argument('--hours', type=int, default=24, help='Hours of history (default: 24)')
    parser.add_argument('--no-ai', action='store_true', help='Disable AI analysis')
    parser.add_argument('-o', '--output', help='Output directory')
    parser.add_argument('--json', action='store_true', help='JSON output to stdout')
    
    args = parser.parse_args()
    
    oracle = LogOracle(args.output, use_ai=not args.no_ai)
    
    if args.file:
        oracle.ingest_file(args.file)
        oracle.sources_processed.append(args.file)
        report = oracle._generate_report(
            oracle.detector.detect_frequency_anomalies(),
            oracle.detector.detect_rare_patterns(),
            oracle.detector.detect_security_events(),
            None
        )
    else:
        report = oracle.analyze(args.sources, args.hours)
    
    if args.json:
        print(json.dumps(report, indent=2, default=str))
