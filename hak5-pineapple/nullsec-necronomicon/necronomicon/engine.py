"""
The Necronomicon — The book that should not be read.
System-wide dark ritual scanner that combines multiple analysis techniques
into one terrifying report: the Necronomicon Assessment.
"""

import os
import time
import hashlib
import socket
import struct
import math
import re
from typing import List, Dict, Optional
from pathlib import Path
from collections import Counter


def perform_dark_ritual(target_dir: str = "/") -> Dict:
    """
    The Dark Ritual — a comprehensive system assessment combining
    multiple analysis vectors into one unholy report.
    """
    ritual = {
        "timestamp": time.time(),
        "hostname": socket.gethostname(),
        "chapters": {},
    }

    # Chapter I: The Flesh (System Health)
    ritual["chapters"]["flesh"] = _chapter_flesh()

    # Chapter II: The Blood (Network)
    ritual["chapters"]["blood"] = _chapter_blood()

    # Chapter III: The Bones (Filesystem)
    ritual["chapters"]["bones"] = _chapter_bones(target_dir)

    # Chapter IV: The Spirits (Processes)
    ritual["chapters"]["spirits"] = _chapter_spirits()

    # Chapter V: The Seals (Security)
    ritual["chapters"]["seals"] = _chapter_seals()

    # Final Verdict
    ritual["verdict"] = _final_verdict(ritual)

    return ritual


def _chapter_flesh() -> Dict:
    """Chapter I: The Flesh — System vitals and health."""
    flesh = {"title": "📖 Chapter I: The Flesh", "findings": []}

    # Load average
    try:
        with open("/proc/loadavg", 'r') as f:
            load = f.read().split()
        flesh["load"] = [float(load[0]), float(load[1]), float(load[2])]
        if float(load[0]) > 4:
            flesh["findings"].append({
                "emoji": "🔥", "severity": "HIGH",
                "detail": f"High load average: {load[0]}",
            })
    except FileNotFoundError:
        pass

    # Memory
    try:
        with open("/proc/meminfo", 'r') as f:
            mem = f.read()
        total = int(re.search(r'MemTotal:\s+(\d+)', mem).group(1))
        avail = int(re.search(r'MemAvailable:\s+(\d+)', mem).group(1))
        used_pct = ((total - avail) / total) * 100
        flesh["mem_used_pct"] = round(used_pct, 1)
        if used_pct > 90:
            flesh["findings"].append({
                "emoji": "🧠", "severity": "CRITICAL",
                "detail": f"Memory critically low: {used_pct:.0f}% used",
            })
    except (FileNotFoundError, AttributeError):
        pass

    # Disk
    try:
        st = os.statvfs("/")
        disk_pct = ((st.f_blocks - st.f_bfree) / st.f_blocks) * 100
        flesh["disk_used_pct"] = round(disk_pct, 1)
        if disk_pct > 90:
            flesh["findings"].append({
                "emoji": "💽", "severity": "CRITICAL",
                "detail": f"Disk critically full: {disk_pct:.0f}% used",
            })
    except OSError:
        pass

    # Uptime
    try:
        with open("/proc/uptime", 'r') as f:
            uptime = float(f.read().split()[0])
        flesh["uptime_hours"] = round(uptime / 3600, 1)
    except FileNotFoundError:
        pass

    return flesh


def _chapter_blood() -> Dict:
    """Chapter II: The Blood — Network analysis."""
    blood = {"title": "📖 Chapter II: The Blood", "findings": []}

    # Listening ports
    try:
        with open("/proc/net/tcp", 'r') as f:
            lines = f.readlines()[1:]
        listeners = []
        for line in lines:
            parts = line.strip().split()
            if len(parts) >= 4 and parts[3] == "0A":
                addr = parts[1]
                ip_hex, port_hex = addr.split(':')
                port = int(port_hex, 16)
                listeners.append(port)

        blood["listening_ports"] = sorted(set(listeners))
        blood["listener_count"] = len(set(listeners))

        # Flag suspicious ports
        suspicious_ports = {4444, 5555, 6666, 31337, 12345, 54321, 1337}
        sus = set(listeners) & suspicious_ports
        if sus:
            blood["findings"].append({
                "emoji": "⚠️", "severity": "CRITICAL",
                "detail": f"Suspicious ports open: {sorted(sus)}",
            })
    except (FileNotFoundError, PermissionError):
        pass

    # Established connections
    try:
        established = sum(1 for line in lines if line.strip().split()[3] == "01")
        blood["established_connections"] = established
    except (UnboundLocalError, IndexError):
        pass

    return blood


def _chapter_bones() -> Dict:
    pass  # Placeholder


def _chapter_bones(target_dir: str) -> Dict:
    """Chapter III: The Bones — Filesystem analysis."""
    bones = {"title": "📖 Chapter III: The Bones", "findings": []}

    # Check world-writable directories
    writable_dirs = []
    for check_dir in ["/tmp", "/var/tmp", "/dev/shm"]:
        if os.path.exists(check_dir):
            try:
                for entry in os.scandir(check_dir):
                    if entry.is_file() and entry.name.startswith('.'):
                        bones["findings"].append({
                            "emoji": "👻", "severity": "MEDIUM",
                            "detail": f"Hidden file in world-writable dir: {entry.path}",
                        })
            except PermissionError:
                pass

    # SUID binaries count
    suid_count = 0
    for check_dir in ["/usr/bin", "/usr/sbin", "/bin", "/sbin"]:
        if os.path.exists(check_dir):
            try:
                for entry in os.scandir(check_dir):
                    try:
                        if entry.is_file() and entry.stat().st_mode & 0o4000:
                            suid_count += 1
                    except (PermissionError, OSError):
                        pass
            except PermissionError:
                pass

    bones["suid_binaries"] = suid_count
    if suid_count > 50:
        bones["findings"].append({
            "emoji": "⚡", "severity": "MEDIUM",
            "detail": f"High SUID binary count: {suid_count}",
        })

    return bones


def _chapter_spirits() -> Dict:
    """Chapter IV: The Spirits — Process analysis."""
    spirits = {"title": "📖 Chapter IV: The Spirits", "findings": []}

    proc_count = 0
    zombie_count = 0

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        proc_count += 1
        pid = int(entry)

        try:
            with open(f"/proc/{pid}/status", 'r') as f:
                status = f.read()

            if 'Z (zombie)' in status:
                zombie_count += 1

            # Check for deleted binaries
            try:
                exe = os.readlink(f"/proc/{pid}/exe")
                if "(deleted)" in exe:
                    name_match = re.search(r'Name:\s+(\S+)', status)
                    name = name_match.group(1) if name_match else "?"
                    spirits["findings"].append({
                        "emoji": "💀", "severity": "HIGH",
                        "detail": f"PID {pid} ({name}) running deleted binary: {exe}",
                    })
            except (PermissionError, FileNotFoundError):
                pass

        except (FileNotFoundError, PermissionError):
            continue

    spirits["total_processes"] = proc_count
    spirits["zombies"] = zombie_count

    if zombie_count > 5:
        spirits["findings"].append({
            "emoji": "🧟", "severity": "HIGH",
            "detail": f"Zombie outbreak: {zombie_count} undead processes",
        })

    return spirits


def _chapter_seals() -> Dict:
    """Chapter V: The Seals — Security checks."""
    seals = {"title": "📖 Chapter V: The Seals", "findings": []}

    # SSH config check
    ssh_config = "/etc/ssh/sshd_config"
    if os.path.exists(ssh_config):
        try:
            with open(ssh_config, 'r') as f:
                config = f.read()
            if re.search(r'PermitRootLogin\s+yes', config):
                seals["findings"].append({
                    "emoji": "🔓", "severity": "HIGH",
                    "detail": "SSH root login is ENABLED",
                })
            if re.search(r'PasswordAuthentication\s+yes', config):
                seals["findings"].append({
                    "emoji": "🔑", "severity": "MEDIUM",
                    "detail": "SSH password authentication is ENABLED",
                })
        except PermissionError:
            pass

    # Check for authorized_keys
    home_dirs = []
    try:
        for entry in os.scandir("/home"):
            if entry.is_dir():
                home_dirs.append(entry.path)
    except (PermissionError, FileNotFoundError):
        pass

    for home in home_dirs:
        ak_path = os.path.join(home, ".ssh", "authorized_keys")
        if os.path.exists(ak_path):
            try:
                with open(ak_path, 'r') as f:
                    keys = [l for l in f.readlines() if l.strip() and not l.startswith('#')]
                seals["findings"].append({
                    "emoji": "🔐", "severity": "INFO",
                    "detail": f"{ak_path}: {len(keys)} authorized keys",
                })
            except PermissionError:
                pass

    # Check for core dumps enabled
    try:
        with open("/proc/sys/kernel/core_pattern", 'r') as f:
            core_pattern = f.read().strip()
        if core_pattern and not core_pattern.startswith('|'):
            seals["findings"].append({
                "emoji": "📋", "severity": "LOW",
                "detail": f"Core dumps enabled: {core_pattern}",
            })
    except FileNotFoundError:
        pass

    return seals


def _final_verdict(ritual: Dict) -> Dict:
    """Generate the final dark verdict."""
    all_findings = []
    for chapter in ritual["chapters"].values():
        all_findings.extend(chapter.get("findings", []))

    critical = sum(1 for f in all_findings if f.get("severity") == "CRITICAL")
    high = sum(1 for f in all_findings if f.get("severity") == "HIGH")
    total = len(all_findings)

    if critical > 3:
        verdict_text = "📕 THE NECRONOMICON SCREAMS. THIS SYSTEM IS CURSED BEYOND REDEMPTION."
        threat_level = "APOCALYPTIC"
    elif critical > 0:
        verdict_text = f"📙 The dark book reveals {critical} critical curses. Cleanse them."
        threat_level = "SEVERE"
    elif high > 5:
        verdict_text = f"📒 {high} warnings from the dark book. The system is troubled."
        threat_level = "ELEVATED"
    elif total > 10:
        verdict_text = f"📓 {total} whispers from the necronomicon. Minor concerns."
        threat_level = "GUARDED"
    else:
        verdict_text = "📗 The necronomicon is silent. The system is clean... for now."
        threat_level = "LOW"

    return {
        "text": verdict_text,
        "threat_level": threat_level,
        "total_findings": total,
        "critical": critical,
        "high": high,
    }


def generate_dark_report(ritual: Dict) -> str:
    """Generate a formatted dark report from the ritual results."""
    lines = []
    lines.append("=" * 60)
    lines.append("  📕 THE NECRONOMICON — SYSTEM DARK ASSESSMENT")
    lines.append(f"  Host: {ritual['hostname']}")
    lines.append(f"  Time: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(ritual['timestamp']))}")
    lines.append("=" * 60)

    for chapter_key, chapter in ritual["chapters"].items():
        lines.append(f"\n  {chapter.get('title', chapter_key)}")
        lines.append("  " + "-" * 40)

        # Print non-findings data
        for k, v in chapter.items():
            if k not in ("title", "findings") and not isinstance(v, (list, dict)):
                lines.append(f"    {k}: {v}")

        # Print findings
        for f in chapter.get("findings", []):
            lines.append(f"    {f['emoji']} [{f['severity']}] {f['detail']}")

        if not chapter.get("findings"):
            lines.append("    ✅ No issues detected")

    lines.append(f"\n{'=' * 60}")
    verdict = ritual["verdict"]
    lines.append(f"  THREAT LEVEL: {verdict['threat_level']}")
    lines.append(f"  {verdict['text']}")
    lines.append(f"  Findings: {verdict['total_findings']} total, "
                 f"{verdict['critical']} critical, {verdict['high']} high")
    lines.append("=" * 60)

    return "\n".join(lines)
