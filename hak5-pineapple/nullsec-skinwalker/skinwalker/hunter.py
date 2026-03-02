"""
Skinwalker Engine — Finds processes wearing the skin of other processes.
Detects process name spoofing, path mismatches, and impostor binaries.
"""

import os
import hashlib
import re
from pathlib import Path
from typing import List, Dict, Optional

# Known legitimate process→path mappings
KNOWN_SKINS = {
    "sshd": ["/usr/sbin/sshd", "/usr/bin/sshd"],
    "bash": ["/bin/bash", "/usr/bin/bash"],
    "python3": ["/usr/bin/python3"],
    "systemd": ["/lib/systemd/systemd", "/usr/lib/systemd/systemd"],
    "cron": ["/usr/sbin/cron", "/usr/sbin/crond"],
    "nginx": ["/usr/sbin/nginx"],
    "apache2": ["/usr/sbin/apache2"],
    "httpd": ["/usr/sbin/httpd"],
}

# Suspicious name patterns (things malware pretends to be)
SHAPESHIFTER_NAMES = [
    r"^svchost\.exe$",    # Windows process on Linux? SUS
    r"^csrss\.exe$",
    r"^lsass\.exe$",
    r"^kworker/\d+:\d+H?$",  # Fake kernel worker
    r"^\[.*\]$",          # Fake kernel thread brackets
    r"^\..*$",            # Hidden dot-prefix process
]


def _read_proc(pid: int, field: str) -> Optional[str]:
    """Read a field from /proc/<pid>/"""
    try:
        path = f"/proc/{pid}/{field}"
        with open(path, 'r') as f:
            return f.read().strip()
    except (PermissionError, FileNotFoundError, ProcessLookupError):
        return None


def _get_exe(pid: int) -> Optional[str]:
    """Get the actual executable path for a PID."""
    try:
        return os.readlink(f"/proc/{pid}/exe")
    except (PermissionError, FileNotFoundError, ProcessLookupError):
        return None


def _get_cmdline(pid: int) -> Optional[str]:
    """Get the command line of a process."""
    try:
        with open(f"/proc/{pid}/cmdline", 'rb') as f:
            return f.read().replace(b'\x00', b' ').decode('utf-8', errors='replace').strip()
    except (PermissionError, FileNotFoundError, ProcessLookupError):
        return None


def _get_comm(pid: int) -> Optional[str]:
    """Get the comm name (what the process calls itself)."""
    return _read_proc(pid, "comm")


def scan_skinwalkers(verbose: bool = False) -> List[Dict]:
    """Scan all processes for shapeshifting behavior."""
    findings = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue

        pid = int(entry)
        comm = _get_comm(pid)
        exe = _get_exe(pid)
        cmdline = _get_cmdline(pid)

        if not comm:
            continue

        anomalies = []

        # Check 1: Process name vs actual binary mismatch
        if exe and comm:
            exe_basename = os.path.basename(exe).replace(" (deleted)", "")
            if comm != exe_basename and exe_basename not in comm:
                anomalies.append({
                    "type": "SKIN_MISMATCH",
                    "detail": f"Claims to be '{comm}' but binary is '{exe_basename}'",
                    "severity": "HIGH",
                    "emoji": "🐺",
                })

        # Check 2: Known process running from wrong path
        if comm in KNOWN_SKINS and exe:
            clean_exe = exe.replace(" (deleted)", "")
            if clean_exe not in KNOWN_SKINS[comm]:
                anomalies.append({
                    "type": "WRONG_TERRITORY",
                    "detail": f"'{comm}' should be at {KNOWN_SKINS[comm]} but found at '{clean_exe}'",
                    "severity": "CRITICAL",
                    "emoji": "💀",
                })

        # Check 3: Shapeshifter name patterns
        for pattern in SHAPESHIFTER_NAMES:
            if re.match(pattern, comm):
                anomalies.append({
                    "type": "SHAPESHIFTER",
                    "detail": f"Suspicious process name pattern: '{comm}'",
                    "severity": "MEDIUM",
                    "emoji": "👤",
                })

        # Check 4: Deleted binary (process outlived its skin)
        if exe and "(deleted)" in exe:
            anomalies.append({
                "type": "GHOST_SKIN",
                "detail": f"Running from deleted binary: '{exe}'",
                "severity": "HIGH",
                "emoji": "👻",
            })

        # Check 5: Cmdline doesn't match comm
        if cmdline and comm and cmdline.strip():
            cmd_base = os.path.basename(cmdline.split()[0]) if cmdline.split() else ""
            if cmd_base and comm not in cmd_base and cmd_base not in comm:
                if not comm.startswith("["):  # Skip kernel threads
                    anomalies.append({
                        "type": "VOICE_MISMATCH",
                        "detail": f"Says '{comm}' but speaks '{cmd_base}'",
                        "severity": "LOW",
                        "emoji": "🗣️",
                    })

        if anomalies or verbose:
            findings.append({
                "pid": pid,
                "comm": comm,
                "exe": exe or "???",
                "cmdline": (cmdline or "")[:120],
                "anomalies": anomalies,
                "is_skinwalker": len(anomalies) > 0,
            })

    return findings


def hunt_doppelganger(name: str) -> List[Dict]:
    """Find all processes claiming to be a specific name."""
    results = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        comm = _get_comm(pid)
        exe = _get_exe(pid)
        cmdline = _get_cmdline(pid)

        if comm and name.lower() in comm.lower():
            exe_hash = None
            if exe and os.path.exists(exe.replace(" (deleted)", "")):
                try:
                    with open(exe.replace(" (deleted)", ""), 'rb') as f:
                        exe_hash = hashlib.sha256(f.read(4096)).hexdigest()[:16]
                except (PermissionError, IsADirectoryError):
                    pass

            results.append({
                "pid": pid,
                "comm": comm,
                "exe": exe,
                "cmdline": (cmdline or "")[:120],
                "exe_hash": exe_hash,
            })

    return results


def autopsy(pid: int) -> Dict:
    """Deep inspection of a single process — peel back its skin."""
    result = {
        "pid": pid,
        "exists": os.path.exists(f"/proc/{pid}"),
    }

    if not result["exists"]:
        result["verdict"] = "💨 This spirit has already departed..."
        return result

    result["comm"] = _get_comm(pid)
    result["exe"] = _get_exe(pid)
    result["cmdline"] = _get_cmdline(pid)
    result["status"] = _read_proc(pid, "status")

    # Environment variables
    try:
        with open(f"/proc/{pid}/environ", 'rb') as f:
            env_raw = f.read()
            envs = env_raw.split(b'\x00')
            result["env_count"] = len(envs)
            # Look for suspicious env vars
            sus_env = [e.decode('utf-8', errors='replace') for e in envs
                       if any(k in e.upper() for k in [b'PASSWORD', b'SECRET', b'TOKEN', b'KEY', b'CRED'])]
            result["suspicious_env"] = sus_env
    except (PermissionError, FileNotFoundError):
        result["env_count"] = "ACCESS_DENIED"

    # File descriptors
    try:
        fds = os.listdir(f"/proc/{pid}/fd")
        result["open_files"] = len(fds)
        # Check for network connections
        network_fds = 0
        for fd in fds[:50]:
            try:
                link = os.readlink(f"/proc/{pid}/fd/{fd}")
                if "socket" in link:
                    network_fds += 1
            except (PermissionError, FileNotFoundError):
                pass
        result["network_connections"] = network_fds
    except (PermissionError, FileNotFoundError):
        result["open_files"] = "ACCESS_DENIED"

    # Memory maps for injected libraries
    maps = _read_proc(pid, "maps")
    if maps:
        lines = maps.strip().split("\n")
        result["memory_regions"] = len(lines)
        sus_maps = [l for l in lines if "/tmp/" in l or "/dev/shm/" in l]
        result["suspicious_maps"] = sus_maps[:5]

    return result
