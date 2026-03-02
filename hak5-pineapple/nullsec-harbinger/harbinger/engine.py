"""
Harbinger Engine — Listens for screams in log files.
Detects panics, crashes, errors, security events, and anomalous patterns
in system and application logs.
"""

import os
import re
import time
from pathlib import Path
from typing import List, Dict, Optional, Callable
from collections import Counter

# The Harbinger's ears — patterns that trigger screams
SCREAM_PATTERNS = {
    "PANIC": {
        "patterns": [
            re.compile(r"kernel panic", re.I),
            re.compile(r"panic:", re.I),
            re.compile(r"FATAL", re.I),
            re.compile(r"Oops:", re.I),
        ],
        "severity": "CRITICAL",
        "emoji": "💀",
    },
    "SEGFAULT": {
        "patterns": [
            re.compile(r"segfault", re.I),
            re.compile(r"segmentation fault", re.I),
            re.compile(r"SIGSEGV", re.I),
            re.compile(r"core dumped", re.I),
        ],
        "severity": "CRITICAL",
        "emoji": "💥",
    },
    "AUTH_FAILURE": {
        "patterns": [
            re.compile(r"authentication fail", re.I),
            re.compile(r"Failed password", re.I),
            re.compile(r"invalid user", re.I),
            re.compile(r"pam_unix.*failure", re.I),
            re.compile(r"Access denied", re.I),
        ],
        "severity": "HIGH",
        "emoji": "🔐",
    },
    "BRUTE_FORCE": {
        "patterns": [
            re.compile(r"maximum authentication attempts", re.I),
            re.compile(r"Too many authentication failures", re.I),
            re.compile(r"Disconnecting.*Too many", re.I),
        ],
        "severity": "CRITICAL",
        "emoji": "🔨",
    },
    "OOM": {
        "patterns": [
            re.compile(r"Out of memory", re.I),
            re.compile(r"OOM killer", re.I),
            re.compile(r"oom-kill:", re.I),
            re.compile(r"Cannot allocate memory", re.I),
        ],
        "severity": "CRITICAL",
        "emoji": "🧠",
    },
    "DISK_ERROR": {
        "patterns": [
            re.compile(r"I/O error", re.I),
            re.compile(r"read-only file system", re.I),
            re.compile(r"disk full", re.I),
            re.compile(r"No space left on device", re.I),
        ],
        "severity": "HIGH",
        "emoji": "💽",
    },
    "PERMISSION": {
        "patterns": [
            re.compile(r"Permission denied", re.I),
            re.compile(r"Operation not permitted", re.I),
        ],
        "severity": "MEDIUM",
        "emoji": "🚫",
    },
    "NETWORK_SCREAM": {
        "patterns": [
            re.compile(r"Connection refused", re.I),
            re.compile(r"Connection timed out", re.I),
            re.compile(r"No route to host", re.I),
            re.compile(r"Network is unreachable", re.I),
        ],
        "severity": "MEDIUM",
        "emoji": "📡",
    },
    "SUSPICIOUS": {
        "patterns": [
            re.compile(r"reverse mapping.*POSSIBLE BREAK-IN", re.I),
            re.compile(r"port scan detected", re.I),
            re.compile(r"SYN flood", re.I),
            re.compile(r"possible exploit", re.I),
        ],
        "severity": "CRITICAL",
        "emoji": "⚠️",
    },
    "SERVICE_DEATH": {
        "patterns": [
            re.compile(r"service.*stopped", re.I),
            re.compile(r"service.*failed", re.I),
            re.compile(r"systemd.*Failed", re.I),
            re.compile(r"exited with error", re.I),
        ],
        "severity": "HIGH",
        "emoji": "⚰️",
    },
}


def listen_to_file(filepath: str, max_lines: int = 10000) -> List[Dict]:
    """Listen to a log file for screams."""
    screams = []

    try:
        with open(filepath, 'r', errors='replace') as f:
            lines = f.readlines()[-max_lines:]
    except (PermissionError, FileNotFoundError, IsADirectoryError):
        return screams

    for line_num, line in enumerate(lines, 1):
        for scream_type, config in SCREAM_PATTERNS.items():
            for pattern in config["patterns"]:
                if pattern.search(line):
                    screams.append({
                        "file": filepath,
                        "line_num": line_num,
                        "type": scream_type,
                        "severity": config["severity"],
                        "emoji": config["emoji"],
                        "content": line.strip()[:200],
                    })
                    break

    return screams


def listen_to_directory(dirpath: str, extensions: Optional[List[str]] = None) -> List[Dict]:
    """Listen to all log files in a directory."""
    if extensions is None:
        extensions = ['.log', '.err', '.out', '.warn', '.syslog', '']

    all_screams = []
    path = Path(dirpath)

    for fpath in path.rglob("*"):
        if fpath.is_file():
            if fpath.suffix.lower() in extensions or fpath.name in [
                'syslog', 'messages', 'auth.log', 'kern.log', 'daemon.log',
                'dmesg', 'secure', 'boot.log', 'faillog',
            ]:
                screams = listen_to_file(str(fpath))
                all_screams.extend(screams)

    return all_screams


def wail_analysis(screams: List[Dict]) -> Dict:
    """Analyze the collected screams — what story do they tell?"""
    if not screams:
        return {
            "total": 0,
            "verdict": "🌙 Silence. The logs are at peace... suspiciously so.",
        }

    # Count by type
    type_counts = Counter(s["type"] for s in screams)
    severity_counts = Counter(s["severity"] for s in screams)
    file_counts = Counter(s["file"] for s in screams)

    # Timeline analysis
    analysis = {
        "total": len(screams),
        "by_type": dict(type_counts.most_common()),
        "by_severity": dict(severity_counts),
        "loudest_file": file_counts.most_common(1)[0] if file_counts else None,
        "critical_count": severity_counts.get("CRITICAL", 0),
        "high_count": severity_counts.get("HIGH", 0),
    }

    # Generate verdict
    if analysis["critical_count"] > 10:
        analysis["verdict"] = "💀 THE HARBINGER WAILS! CRITICAL SYSTEM FAILURE DETECTED!"
    elif analysis["critical_count"] > 0:
        analysis["verdict"] = f"⚠️ {analysis['critical_count']} critical screams detected — investigate immediately."
    elif analysis["high_count"] > 5:
        analysis["verdict"] = f"🔶 {analysis['high_count']} high-severity issues — the harbinger stirs."
    elif len(screams) > 50:
        analysis["verdict"] = "📢 Many whispers in the logs — something is brewing."
    else:
        analysis["verdict"] = f"🔔 {len(screams)} minor screams — the system grumbles."

    return analysis


def listen_to_journald(lines: int = 1000, unit: Optional[str] = None) -> List[Dict]:
    """Listen to systemd journal for screams."""
    import subprocess

    cmd = ["journalctl", "--no-pager", "-n", str(lines), "--output", "cat"]
    if unit:
        cmd.extend(["-u", unit])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            return []
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []

    screams = []
    for line_num, line in enumerate(result.stdout.split('\n'), 1):
        for scream_type, config in SCREAM_PATTERNS.items():
            for pattern in config["patterns"]:
                if pattern.search(line):
                    screams.append({
                        "file": "journald" + (f":{unit}" if unit else ""),
                        "line_num": line_num,
                        "type": scream_type,
                        "severity": config["severity"],
                        "emoji": config["emoji"],
                        "content": line.strip()[:200],
                    })
                    break

    return screams
