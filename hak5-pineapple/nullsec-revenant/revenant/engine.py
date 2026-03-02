"""
Revenant Engine — Hunts zombie processes and orphans.
Finds the undead lurking in your process table —
zombies that refuse to die and orphans with no parent.
"""

import os
import time
from typing import List, Dict, Optional


def hunt_zombies() -> List[Dict]:
    """Find all zombie processes — the undead of the process table."""
    zombies = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)

        try:
            with open(f"/proc/{pid}/status", 'r') as f:
                status = f.read()

            state = ""
            name = ""
            ppid = 0
            uid = ""

            for line in status.split('\n'):
                if line.startswith('State:'):
                    state = line.split(':')[1].strip()
                elif line.startswith('Name:'):
                    name = line.split(':')[1].strip()
                elif line.startswith('PPid:'):
                    ppid = int(line.split(':')[1].strip())
                elif line.startswith('Uid:'):
                    uid = line.split(':')[1].strip().split()[0]

            if 'Z' in state or 'zombie' in state.lower():
                # Get parent info
                parent_name = "???"
                try:
                    with open(f"/proc/{ppid}/comm", 'r') as f:
                        parent_name = f.read().strip()
                except (FileNotFoundError, PermissionError):
                    pass

                zombies.append({
                    "pid": pid,
                    "name": name,
                    "state": state,
                    "ppid": ppid,
                    "parent_name": parent_name,
                    "uid": uid,
                    "emoji": "🧟",
                    "verdict": f"UNDEAD — parent {parent_name} (PID {ppid}) won't reap this child",
                })

        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue

    return zombies


def hunt_orphans() -> List[Dict]:
    """Find orphan processes — children whose parents have abandoned them."""
    orphans = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)

        try:
            with open(f"/proc/{pid}/status", 'r') as f:
                status = f.read()

            name = ""
            ppid = 0

            for line in status.split('\n'):
                if line.startswith('Name:'):
                    name = line.split(':')[1].strip()
                elif line.startswith('PPid:'):
                    ppid = int(line.split(':')[1].strip())

            # Orphans are reparented to PID 1 (init/systemd)
            if ppid == 1 and pid != 1:
                # Filter out legitimate system daemons
                try:
                    with open(f"/proc/{pid}/sessionid", 'r') as f:
                        session = f.read().strip()
                except (FileNotFoundError, PermissionError):
                    session = "?"

                # Get start time
                try:
                    with open(f"/proc/{pid}/stat", 'r') as f:
                        stat_parts = f.read().split()
                    starttime = int(stat_parts[21])
                    clk_tck = os.sysconf(os.sysconf_names['SC_CLK_TCK'])

                    with open("/proc/uptime", 'r') as f:
                        uptime = float(f.read().split()[0])

                    age = uptime - (starttime / clk_tck)
                except (IndexError, ValueError, FileNotFoundError):
                    age = 0

                orphans.append({
                    "pid": pid,
                    "name": name,
                    "age_seconds": round(age, 0),
                    "age_human": _human_time(age),
                    "session": session,
                    "emoji": "👶",
                })

        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue

    return orphans


def hunt_sleepers(min_sleep_seconds: float = 3600) -> List[Dict]:
    """Find long-sleeping processes — the comatose undead."""
    sleepers = []

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)

        try:
            with open(f"/proc/{pid}/status", 'r') as f:
                status = f.read()

            name = ""
            state = ""
            threads = 1
            voluntary_switches = 0

            for line in status.split('\n'):
                if line.startswith('Name:'):
                    name = line.split(':')[1].strip()
                elif line.startswith('State:'):
                    state = line.split(':')[1].strip()
                elif line.startswith('Threads:'):
                    threads = int(line.split(':')[1].strip())
                elif line.startswith('voluntary_ctxt_switches:'):
                    voluntary_switches = int(line.split(':')[1].strip())

            # Check if sleeping
            if 'S' in state:
                # Get age
                with open(f"/proc/{pid}/stat", 'r') as f:
                    stat_parts = f.read().split()
                starttime = int(stat_parts[21])
                utime = int(stat_parts[13])
                stime = int(stat_parts[14])
                clk_tck = os.sysconf(os.sysconf_names['SC_CLK_TCK'])

                with open("/proc/uptime", 'r') as f:
                    uptime = float(f.read().split()[0])

                age = uptime - (starttime / clk_tck)
                cpu_time = (utime + stime) / clk_tck

                # If the process is old but has barely used CPU, it's a deep sleeper
                if age > min_sleep_seconds and cpu_time < 1.0:
                    sleepers.append({
                        "pid": pid,
                        "name": name,
                        "age": _human_time(age),
                        "cpu_time_seconds": round(cpu_time, 2),
                        "threads": threads,
                        "emoji": "😴",
                    })

        except (FileNotFoundError, PermissionError, ProcessLookupError,
                IndexError, ValueError):
            continue

    return sleepers


def graveyard_report() -> Dict:
    """Full report on the process graveyard — zombies, orphans, sleepers."""
    zombies = hunt_zombies()
    orphans = hunt_orphans()
    sleepers = hunt_sleepers()

    total_procs = len([e for e in os.listdir("/proc") if e.isdigit()])

    report = {
        "total_processes": total_procs,
        "zombies": len(zombies),
        "orphans": len(orphans),
        "deep_sleepers": len(sleepers),
        "zombie_list": zombies,
        "orphan_list": orphans[:20],
        "sleeper_list": sleepers[:20],
    }

    undead_percent = (len(zombies) + len(sleepers)) / max(total_procs, 1) * 100

    if len(zombies) > 10:
        report["verdict"] = "💀 ZOMBIE OUTBREAK! The undead are taking over the process table!"
    elif len(zombies) > 0:
        report["verdict"] = f"🧟 {len(zombies)} zombies detected. Their parents refuse to let go."
    elif undead_percent > 10:
        report["verdict"] = "😴 Too many sleepers. The system is becoming a graveyard."
    else:
        report["verdict"] = "🌙 The graveyard is quiet. All processes rest in peace."

    return report


def _human_time(seconds: float) -> str:
    if seconds < 60: return f"{seconds:.0f}s"
    if seconds < 3600: return f"{seconds / 60:.0f}m"
    if seconds < 86400: return f"{seconds / 3600:.1f}h"
    return f"{seconds / 86400:.1f}d"
