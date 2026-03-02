# ⏱️ nullsec-temporal

**Filesystem Forensic Timestamp Analyzer — Catch Timestomping & Time Anomalies**

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://python.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![bad-antics](https://img.shields.io/badge/by-bad--antics-red.svg)](https://github.com/bad-antics)

> Time lies. Temporal catches it.

nullsec-temporal detects filesystem timestamp anomalies that indicate tampering, anti-forensic techniques, or suspicious activity. It catches timestomping (modified timestamps), future-dated files, impossible creation sequences, and timezone inconsistencies.

## 🎯 Use Cases

- **DFIR** — Detect timestomping in incident response investigations
- **Malware Analysis** — Identify malware that modifies its own timestamps
- **Insider Threat** — Catch backdated document manipulation
- **Compliance Auditing** — Verify file chronology integrity
- **Red Team Detection** — Find anti-forensic timestamp manipulation
- **CTF Challenges** — Discover hidden flags via time-based clues

## ⚡ Quick Start

```bash
# Install
pip install nullsec-temporal

# Scan a directory for timestamp anomalies
temporal scan /path/to/investigate

# Scan recursively with full report
temporal scan /path/to/investigate --recursive --verbose

# Check a single file
temporal check /path/to/suspicious.exe

# Timeline — chronological file activity
temporal timeline /path/to/dir --last 7d

# Find files modified in the future
temporal future /path/to/dir

# JSON output for SIEM ingestion
temporal scan /path/to/dir --json
```

## 🔍 What It Detects

| Anomaly | Description | Severity |
|---------|-------------|----------|
| **Timestomping** | mtime before ctime (modified before created) | 🔴 High |
| **Future Files** | Timestamps set in the future | 🔴 High |
| **Precision Mismatch** | Nanosecond timestamps on FAT32 (only supports 2s) | 🟡 Medium |
| **Cluster Anomalies** | Files with identical timestamps (mass copy/tool artifacts) | 🟡 Medium |
| **Gap Detection** | Suspicious gaps in otherwise sequential file creation | 🟡 Medium |
| **Weekend/Night Edits** | Files modified at unusual hours (configurable) | 🟢 Info |
| **Ancient Files** | Files dated before the filesystem was created | 🔴 High |
| **Epoch Artifacts** | Timestamps at Unix epoch (Jan 1, 1970) or Windows epoch | 🟡 Medium |

## 📄 License

MIT — built by [bad-antics](https://github.com/bad-antics) for the nullsec project.
