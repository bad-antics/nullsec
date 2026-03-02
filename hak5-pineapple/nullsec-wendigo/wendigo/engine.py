"""
Wendigo Engine — Finds processes that devour system resources.
The wendigo is never satisfied. It consumes CPU, memory, disk, and network
until nothing remains.
"""

import os
import time
from typing import List, Dict, Optional


def hunt_cpu_devourers(threshold: float = 5.0) -> List[Dict]:
    """Find processes devouring CPU — the hungry wendigos."""
    devourers = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)

        try:
            # Read CPU time
            with open(f"/proc/{pid}/stat", 'r') as f:
                stat = f.read().split()

            comm = stat[1].strip('()')
            utime = int(stat[13])
            stime = int(stat[14])
            total_time = utime + stime

            # Get process uptime
            with open("/proc/uptime", 'r') as f:
                uptime = float(f.read().split()[0])

            with open(f"/proc/{pid}/stat", 'r') as f:
                starttime = int(f.read().split()[21])

            clk_tck = os.sysconf(os.sysconf_names['SC_CLK_TCK'])
            process_uptime = uptime - (starttime / clk_tck)

            if process_uptime > 0:
                cpu_percent = (total_time / clk_tck / process_uptime) * 100
            else:
                cpu_percent = 0

            if cpu_percent >= threshold:
                hunger = _rate_hunger(cpu_percent)
                devourers.append({
                    "pid": pid,
                    "name": comm,
                    "cpu_percent": round(cpu_percent, 1),
                    "cpu_time_ticks": total_time,
                    "uptime_seconds": round(process_uptime, 0),
                    "hunger": hunger,
                    "emoji": _hunger_emoji(cpu_percent),
                })
        except (FileNotFoundError, PermissionError, ProcessLookupError,
                IndexError, ValueError, ZeroDivisionError):
            continue

    return sorted(devourers, key=lambda x: x["cpu_percent"], reverse=True)


def hunt_memory_devourers(threshold_mb: float = 50.0) -> List[Dict]:
    """Find processes devouring memory — the bloated wendigos."""
    devourers = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)

        try:
            with open(f"/proc/{pid}/status", 'r') as f:
                status = f.read()

            comm = ""
            rss_kb = 0
            vms_kb = 0
            threads = 1

            for line in status.split('\n'):
                if line.startswith('Name:'):
                    comm = line.split(':')[1].strip()
                elif line.startswith('VmRSS:'):
                    rss_kb = int(line.split(':')[1].strip().split()[0])
                elif line.startswith('VmSize:'):
                    vms_kb = int(line.split(':')[1].strip().split()[0])
                elif line.startswith('Threads:'):
                    threads = int(line.split(':')[1].strip())

            rss_mb = rss_kb / 1024

            if rss_mb >= threshold_mb:
                devourers.append({
                    "pid": pid,
                    "name": comm,
                    "rss_mb": round(rss_mb, 1),
                    "vms_mb": round(vms_kb / 1024, 1),
                    "threads": threads,
                    "hunger": _rate_hunger(rss_mb / 10),  # Scale for memory
                    "emoji": _hunger_emoji(rss_mb / 10),
                })
        except (FileNotFoundError, PermissionError, ProcessLookupError,
                ValueError):
            continue

    return sorted(devourers, key=lambda x: x["rss_mb"], reverse=True)


def hunt_fd_devourers(threshold: int = 100) -> List[Dict]:
    """Find processes hoarding file descriptors — the greedy wendigos."""
    devourers = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)

        try:
            fds = os.listdir(f"/proc/{pid}/fd")
            fd_count = len(fds)

            if fd_count >= threshold:
                with open(f"/proc/{pid}/comm", 'r') as f:
                    comm = f.read().strip()

                # Categorize open FDs
                sockets = 0
                pipes = 0
                files = 0
                for fd in fds[:500]:
                    try:
                        link = os.readlink(f"/proc/{pid}/fd/{fd}")
                        if "socket" in link:
                            sockets += 1
                        elif "pipe" in link:
                            pipes += 1
                        else:
                            files += 1
                    except (PermissionError, FileNotFoundError):
                        pass

                devourers.append({
                    "pid": pid,
                    "name": comm,
                    "total_fds": fd_count,
                    "sockets": sockets,
                    "pipes": pipes,
                    "files": files,
                    "emoji": "🦷" if fd_count > 500 else "🍖",
                })
        except (FileNotFoundError, PermissionError):
            continue

    return sorted(devourers, key=lambda x: x["total_fds"], reverse=True)


def system_vitals() -> Dict:
    """Check system vital signs — is the wendigo killing the host?"""
    vitals = {}

    # CPU info
    try:
        with open("/proc/loadavg", 'r') as f:
            parts = f.read().split()
            vitals["load_1m"] = float(parts[0])
            vitals["load_5m"] = float(parts[1])
            vitals["load_15m"] = float(parts[2])
            vitals["running_procs"] = parts[3]
    except FileNotFoundError:
        pass

    # Memory info
    try:
        with open("/proc/meminfo", 'r') as f:
            meminfo = f.read()
        for line in meminfo.split('\n'):
            if line.startswith('MemTotal:'):
                vitals["mem_total_mb"] = int(line.split(':')[1].strip().split()[0]) / 1024
            elif line.startswith('MemAvailable:'):
                vitals["mem_available_mb"] = int(line.split(':')[1].strip().split()[0]) / 1024
            elif line.startswith('SwapTotal:'):
                vitals["swap_total_mb"] = int(line.split(':')[1].strip().split()[0]) / 1024
            elif line.startswith('SwapFree:'):
                vitals["swap_free_mb"] = int(line.split(':')[1].strip().split()[0]) / 1024

        if "mem_total_mb" in vitals and "mem_available_mb" in vitals:
            used = vitals["mem_total_mb"] - vitals["mem_available_mb"]
            vitals["mem_used_percent"] = round((used / vitals["mem_total_mb"]) * 100, 1)
    except FileNotFoundError:
        pass

    # Disk usage
    try:
        stat = os.statvfs("/")
        total = stat.f_blocks * stat.f_frsize
        free = stat.f_bfree * stat.f_frsize
        used = total - free
        vitals["disk_total_gb"] = round(total / (1024**3), 1)
        vitals["disk_used_gb"] = round(used / (1024**3), 1)
        vitals["disk_used_percent"] = round((used / total) * 100, 1)
    except OSError:
        pass

    # Process count
    try:
        vitals["total_processes"] = len([e for e in os.listdir("/proc") if e.isdigit()])
    except FileNotFoundError:
        pass

    # Generate health verdict
    vitals["verdict"] = _health_verdict(vitals)

    return vitals


def _rate_hunger(value: float) -> str:
    if value > 80: return "INSATIABLE"
    if value > 50: return "RAVENOUS"
    if value > 20: return "HUNGRY"
    if value > 10: return "PECKISH"
    return "DORMANT"


def _hunger_emoji(value: float) -> str:
    if value > 80: return "💀"
    if value > 50: return "🔥"
    if value > 20: return "🍖"
    if value > 10: return "🦴"
    return "😴"


def _health_verdict(vitals: Dict) -> str:
    warnings = 0
    if vitals.get("load_1m", 0) > 4: warnings += 1
    if vitals.get("mem_used_percent", 0) > 80: warnings += 1
    if vitals.get("disk_used_percent", 0) > 90: warnings += 1

    if warnings >= 3:
        return "💀 THE WENDIGO IS CONSUMING EVERYTHING. SYSTEM CRITICAL."
    elif warnings >= 2:
        return "🔥 Multiple resources under stress — the wendigo stirs."
    elif warnings >= 1:
        return "⚠️ One resource showing strain. Keep watching."
    else:
        return "🌙 The wendigo sleeps. System healthy... for now."
