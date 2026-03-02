# 🔮 LogOracle

**AI-Powered Log Anomaly Detector**

Combines statistical analysis with local AI (HailMary via Ollama) to detect anomalies, security events, and indicators of compromise in system logs.

## Features

- 📊 **Statistical baseline** — Frequency analysis with Z-score anomaly detection
- 🤖 **AI analysis** — Local HailMary model analyzes findings via Ollama
- 🔍 **Security pattern matching** — 12+ built-in security event detectors
- 📝 **Multi-source ingestion** — syslog, auth.log, kern.log, nginx, apache, journald
- 🎯 **Pattern clustering** — Normalize and group similar log messages
- ⚡ **Rare event detection** — Flag patterns that appear only 1-2 times
- 📋 **JSON + Markdown reports**

## Usage

```bash
# Full analysis (all log sources + AI)
sudo python3 logoracle.py

# Specific sources
sudo python3 logoracle.py -s auth syslog

# Custom time window
sudo python3 logoracle.py --hours 48

# Without AI (statistical only)
sudo python3 logoracle.py --no-ai

# Analyze specific log file
sudo python3 logoracle.py -f /var/log/custom.log
```

## Detection Capabilities

| Category | Patterns |
|----------|----------|
| Authentication | Login failures, brute force, privilege escalation |
| Network | SYN floods, firewall blocks |
| System | OOM events, kernel crashes, segfaults |
| Malware | Suspicious downloads to /tmp, reverse shells |
| Persistence | Cron modifications, user account changes |
| Network | Promiscuous mode detection |

## AI Integration

LogOracle uses the **HailMary-research** profile (temp=0.6, focused analysis) via Ollama for:
- Contextual analysis of security findings
- Threat severity assessment
- Recommended response actions

Setup: `ollama pull hailmary-research` or use the HailMary launcher in `tools/hailmary-ai.sh`

## Requirements

- Python 3.6+
- Root for full log access
- Optional: Ollama + HailMary model for AI analysis

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
