#!/usr/bin/env python3
"""
NullSec NightShift — Overnight Cluster Compute Scheduler

Automated job scheduler that puts your cluster to work while you sleep.
Runs jobs across all available nodes based on priority, hardware capability,
and time windows.

Job categories:
  1. 💰 Revenue     — Hashcat cracking, bug bounty recon, compute rental
  2. 🔬 Research    — ML training, data collection, vulnerability scanning
  3. 🛡️  Hardening  — Security audits, backup verification, compliance checks
  4. 🧹 Maintenance — Disk cleanup, log rotation, update checks, health reports

Author: bad-antics / NullSec
License: MIT
"""

import json
import time
import logging
import asyncio
import socket
import subprocess
import os
import sys
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Any, Optional, Callable
from datetime import datetime, timedelta
from enum import Enum

try:
    import paramiko
    HAS_PARAMIKO = True
except ImportError:
    HAS_PARAMIKO = False

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

logger = logging.getLogger("nightshift")

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

NIGHTSHIFT_DIR = Path.home() / ".nullsec" / "nightshift"
JOBS_DIR = NIGHTSHIFT_DIR / "jobs"
RESULTS_DIR = NIGHTSHIFT_DIR / "results"
LOGS_DIR = NIGHTSHIFT_DIR / "logs"
NODES_CONF = Path.home() / ".nullsec" / "cluster" / "nodes.conf"

for d in [NIGHTSHIFT_DIR, JOBS_DIR, RESULTS_DIR, LOGS_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Time windows
DEFAULT_START_HOUR = 22   # 10 PM
DEFAULT_END_HOUR = 6      # 6 AM
MAX_JOB_DURATION_HOURS = 8


# ═══════════════════════════════════════════════════════════════════════════════
# Models
# ═══════════════════════════════════════════════════════════════════════════════


class JobCategory(str, Enum):
    REVENUE = "revenue"
    RESEARCH = "research"
    HARDENING = "hardening"
    MAINTENANCE = "maintenance"


class JobStatus(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class ClusterNode:
    name: str
    ip: str
    user: str = "root"
    port: int = 22
    os_type: str = "linux"
    cores: int = 0
    ram_mb: int = 0
    gpu: str = ""
    role: str = "worker"
    online: bool = False


@dataclass
class NightJob:
    name: str
    category: str
    description: str
    command: str                          # Shell command to execute
    target_os: str = "any"               # linux, windows, any
    requires_gpu: bool = False
    requires_root: bool = False
    min_cores: int = 1
    min_ram_mb: int = 512
    priority: int = 5                    # 1 = highest, 10 = lowest
    timeout_sec: int = 3600              # 1 hour default
    run_on: str = "any"                  # any, controller, workers, specific node name
    enabled: bool = True

    # Runtime state
    status: str = JobStatus.QUEUED
    assigned_node: str = ""
    start_time: float = 0
    end_time: float = 0
    output: str = ""
    error: str = ""
    exit_code: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Built-in Job Definitions
# ═══════════════════════════════════════════════════════════════════════════════

BUILTIN_JOBS: List[NightJob] = [
    # ── Revenue ──
    NightJob(
        name="hashcat-benchmark",
        category=JobCategory.REVENUE,
        description="Run hashcat benchmark to profile GPU cracking speed",
        command="hashcat -b --machine-readable 2>/dev/null || echo 'hashcat not installed'",
        requires_gpu=True,
        target_os="any",
        priority=3,
        timeout_sec=1800,
    ),
    NightJob(
        name="subfinder-recon",
        category=JobCategory.REVENUE,
        description="Enumerate subdomains for bug bounty targets (from ~/.nullsec/nightshift/targets.txt)",
        command=(
            "if [ -f ~/.nullsec/nightshift/targets.txt ]; then "
            "while IFS= read -r domain; do "
            "  subfinder -d \"$domain\" -silent >> ~/.nullsec/nightshift/results/subdomains_$(date +%Y%m%d).txt 2>/dev/null; "
            "done < ~/.nullsec/nightshift/targets.txt; "
            "echo \"Subdomains saved\"; "
            "else echo 'No targets.txt found — create ~/.nullsec/nightshift/targets.txt'; fi"
        ),
        target_os="linux",
        priority=4,
        timeout_sec=3600,
    ),
    NightJob(
        name="nuclei-scan",
        category=JobCategory.REVENUE,
        description="Run nuclei vulnerability scanner against discovered subdomains",
        command=(
            "if command -v nuclei &>/dev/null && [ -f ~/.nullsec/nightshift/results/subdomains_$(date +%Y%m%d).txt ]; then "
            "nuclei -l ~/.nullsec/nightshift/results/subdomains_$(date +%Y%m%d).txt "
            "-severity medium,high,critical -silent "
            "-o ~/.nullsec/nightshift/results/vulns_$(date +%Y%m%d).txt; "
            "echo \"Scan complete\"; "
            "else echo 'nuclei not installed or no subdomains file'; fi"
        ),
        target_os="linux",
        priority=4,
        timeout_sec=7200,
    ),

    # ── Research ──
    NightJob(
        name="shodan-monitor",
        category=JobCategory.RESEARCH,
        description="Collect Shodan data for network research (requires SHODAN_API_KEY env)",
        command=(
            "if [ -n \"$SHODAN_API_KEY\" ]; then "
            "curl -s \"https://api.shodan.io/shodan/host/search?key=$SHODAN_API_KEY&query=org:$(hostname -d 2>/dev/null || echo nullsec)\" "
            "> ~/.nullsec/nightshift/results/shodan_$(date +%Y%m%d).json; "
            "echo 'Shodan data collected'; "
            "else echo 'SHODAN_API_KEY not set'; fi"
        ),
        target_os="linux",
        run_on="controller",
        priority=6,
        timeout_sec=300,
    ),
    NightJob(
        name="wifi-survey",
        category=JobCategory.RESEARCH,
        description="Passive WiFi survey — capture beacon frames for 30 minutes",
        command=(
            "if command -v airodump-ng &>/dev/null; then "
            "timeout 1800 airodump-ng wlan0mon --write ~/.nullsec/nightshift/results/wifi_$(date +%Y%m%d) "
            "--output-format csv 2>/dev/null; "
            "echo 'WiFi survey complete'; "
            "else echo 'aircrack-ng not installed'; fi"
        ),
        target_os="linux",
        requires_root=True,
        priority=7,
        timeout_sec=2000,
    ),

    # ── Hardening ──
    NightJob(
        name="lynis-audit",
        category=JobCategory.HARDENING,
        description="Run Lynis system security audit",
        command=(
            "if command -v lynis &>/dev/null; then "
            "lynis audit system --no-colors --quick 2>/dev/null | tail -30; "
            "else echo 'lynis not installed — apt install lynis'; fi"
        ),
        target_os="linux",
        priority=5,
        timeout_sec=600,
    ),
    NightJob(
        name="rkhunter-check",
        category=JobCategory.HARDENING,
        description="Scan for rootkits with rkhunter",
        command=(
            "if command -v rkhunter &>/dev/null; then "
            "rkhunter --check --skip-keypress --report-warnings-only 2>/dev/null; "
            "else echo 'rkhunter not installed'; fi"
        ),
        target_os="linux",
        requires_root=True,
        priority=5,
        timeout_sec=900,
    ),
    NightJob(
        name="clamav-scan",
        category=JobCategory.HARDENING,
        description="Scan home directory with ClamAV",
        command=(
            "if command -v clamscan &>/dev/null; then "
            "clamscan -r --infected --exclude-dir='^/proc' --exclude-dir='^/sys' "
            "--max-filesize=100M --max-scansize=500M ~/  2>/dev/null | tail -20; "
            "else echo 'clamav not installed'; fi"
        ),
        target_os="linux",
        priority=6,
        timeout_sec=3600,
    ),
    NightJob(
        name="firewall-audit",
        category=JobCategory.HARDENING,
        description="Audit firewall rules and open ports",
        command=(
            "echo '=== Open Ports ===' && ss -tlnp 2>/dev/null && "
            "echo '=== iptables ===' && iptables -L -n --line-numbers 2>/dev/null && "
            "echo '=== UFW Status ===' && ufw status verbose 2>/dev/null || true"
        ),
        target_os="linux",
        priority=4,
        timeout_sec=60,
    ),

    # ── Maintenance ──
    NightJob(
        name="disk-cleanup",
        category=JobCategory.MAINTENANCE,
        description="Clean temp files, old logs, and package caches",
        command=(
            "echo '=== Before ===' && df -h / && "
            "find /tmp -type f -mtime +7 -delete 2>/dev/null; "
            "find /var/log -name '*.gz' -mtime +30 -delete 2>/dev/null; "
            "apt-get clean 2>/dev/null; "
            "pip cache purge 2>/dev/null; "
            "docker system prune -f 2>/dev/null; "
            "echo '=== After ===' && df -h /"
        ),
        target_os="linux",
        priority=8,
        timeout_sec=300,
    ),
    NightJob(
        name="update-check",
        category=JobCategory.MAINTENANCE,
        description="Check for available system updates",
        command=(
            "apt-get update -qq 2>/dev/null && "
            "apt list --upgradable 2>/dev/null | head -30"
        ),
        target_os="linux",
        priority=9,
        timeout_sec=300,
    ),
    NightJob(
        name="backup-nullsec-config",
        category=JobCategory.MAINTENANCE,
        description="Backup NullSec configuration files",
        command=(
            "tar czf ~/.nullsec/nightshift/results/config_backup_$(date +%Y%m%d).tar.gz "
            "-C ~/.nullsec cluster/ 2>/dev/null && "
            "echo 'Config backed up' && ls -lh ~/.nullsec/nightshift/results/config_backup_*.tar.gz | tail -3"
        ),
        target_os="linux",
        run_on="controller",
        priority=3,
        timeout_sec=120,
    ),
    NightJob(
        name="health-report",
        category=JobCategory.MAINTENANCE,
        description="Generate cluster health report",
        command=(
            "echo '=== System Health ===' && "
            "echo \"Hostname: $(hostname)\" && "
            "echo \"Uptime: $(uptime -p 2>/dev/null)\" && "
            "echo \"Load: $(cat /proc/loadavg 2>/dev/null)\" && "
            "echo \"Memory:\" && free -h 2>/dev/null && "
            "echo \"Disk:\" && df -h / 2>/dev/null && "
            "echo \"Top CPU:\" && ps aux --sort=-%cpu | head -6 && "
            "echo \"Top RAM:\" && ps aux --sort=-%mem | head -6"
        ),
        target_os="linux",
        priority=2,
        timeout_sec=60,
    ),
]


# ═══════════════════════════════════════════════════════════════════════════════
# Cluster Operations
# ═══════════════════════════════════════════════════════════════════════════════


def load_nodes() -> List[ClusterNode]:
    """Load cluster nodes from nodes.conf."""
    if not NODES_CONF.exists():
        return []
    nodes = []
    for line in NODES_CONF.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split("|")
        if len(p) >= 3:
            nodes.append(ClusterNode(
                name=p[0], ip=p[1], user=p[2],
                port=int(p[3]) if len(p) > 3 and p[3].isdigit() else 22,
                os_type=p[4] if len(p) > 4 else "linux",
                cores=int(p[6]) if len(p) > 6 and p[6].isdigit() else 0,
                ram_mb=int(p[7]) if len(p) > 7 and p[7].isdigit() else 0,
                gpu=p[8] if len(p) > 8 else "",
                role=p[9] if len(p) > 9 else "worker",
            ))
    return nodes


def check_online(node: ClusterNode) -> bool:
    """Quick TCP check if node is reachable."""
    try:
        with socket.create_connection((node.ip, node.port), timeout=2):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def ssh_run(node: ClusterNode, command: str, timeout: int = 60) -> tuple:
    """Execute command on remote node via SSH. Returns (stdout, stderr, exit_code)."""
    if not HAS_PARAMIKO:
        return "", "paramiko not installed", -1

    try:
        client = paramiko.SSHClient()
        # AutoAddPolicy is intentional — mesh nodes are trusted LAN peers
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(
            hostname=node.ip, port=node.port, username=node.user,
            timeout=5, allow_agent=False, look_for_keys=True, banner_timeout=5,
        )
        _, stdout, stderr = client.exec_command(command, timeout=timeout)
        exit_code = stdout.channel.recv_exit_status()
        out = stdout.read().decode(errors="replace")
        err = stderr.read().decode(errors="replace")
        client.close()
        return out.strip(), err.strip(), exit_code
    except Exception as e:
        return "", str(e), -1


def local_run(command: str, timeout: int = 60) -> tuple:
    """Execute command locally. Returns (stdout, stderr, exit_code)."""
    try:
        result = subprocess.run(
            command, shell=True, capture_output=True, text=True,
            timeout=timeout, cwd=str(Path.home()),
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", -1
    except Exception as e:
        return "", str(e), -1


# ═══════════════════════════════════════════════════════════════════════════════
# Job Scheduler
# ═══════════════════════════════════════════════════════════════════════════════


def is_nighttime(start_hour: int = DEFAULT_START_HOUR, end_hour: int = DEFAULT_END_HOUR) -> bool:
    """Check if current time is within the night shift window."""
    now = datetime.now().hour
    if start_hour > end_hour:  # Crosses midnight (e.g., 22:00 — 06:00)
        return now >= start_hour or now < end_hour
    return start_hour <= now < end_hour


def can_run_on_node(job: NightJob, node: ClusterNode) -> bool:
    """Check if a job is compatible with a node's capabilities."""
    # OS check
    if job.target_os != "any":
        node_os = node.os_type.lower()
        if job.target_os == "linux" and node_os in ("windows", "win", "win10", "win11"):
            return False
        if job.target_os == "windows" and node_os not in ("windows", "win", "win10", "win11"):
            return False

    # GPU check
    if job.requires_gpu and not node.gpu:
        return False

    # Resource checks
    if node.cores < job.min_cores:
        return False
    if node.ram_mb < job.min_ram_mb:
        return False

    # Role check
    if job.run_on == "controller" and node.role != "controller":
        return False
    if job.run_on == "workers" and node.role == "controller":
        return False
    if job.run_on not in ("any", "controller", "workers") and node.name != job.run_on:
        return False

    return True


def assign_jobs(jobs: List[NightJob], nodes: List[ClusterNode]) -> List[NightJob]:
    """Assign jobs to compatible online nodes, sorted by priority."""
    # Sort by priority (lower = higher priority)
    sorted_jobs = sorted(jobs, key=lambda j: j.priority)
    assigned_nodes = set()

    for job in sorted_jobs:
        if not job.enabled:
            job.status = JobStatus.SKIPPED
            continue

        # Find best node for this job
        for node in nodes:
            if not node.online or node.name in assigned_nodes:
                continue
            if can_run_on_node(job, node):
                job.assigned_node = node.name
                job.status = JobStatus.QUEUED
                # Don't mark node as assigned — allow multiple jobs per node
                break
        else:
            job.status = JobStatus.SKIPPED
            job.error = "No compatible online node available"

    return sorted_jobs


def execute_job(job: NightJob, nodes: List[ClusterNode]) -> NightJob:
    """Execute a single job on its assigned node."""
    job.status = JobStatus.RUNNING
    job.start_time = time.time()

    node = next((n for n in nodes if n.name == job.assigned_node), None)
    if not node:
        job.status = JobStatus.FAILED
        job.error = f"Assigned node '{job.assigned_node}' not found"
        job.end_time = time.time()
        return job

    logger.info("Executing '%s' on %s", job.name, node.name)

    # Run locally or via SSH
    if node.ip in ("127.0.0.1", "::1", "localhost"):
        stdout, stderr, exit_code = local_run(job.command, timeout=job.timeout_sec)
    else:
        stdout, stderr, exit_code = ssh_run(node, job.command, timeout=job.timeout_sec)

    job.output = stdout[:10000]  # Cap output at 10KB
    job.error = stderr[:5000] if stderr else ""
    job.exit_code = exit_code
    job.end_time = time.time()
    job.status = JobStatus.COMPLETED if exit_code == 0 else JobStatus.FAILED

    return job


# ═══════════════════════════════════════════════════════════════════════════════
# Shift Runner
# ═══════════════════════════════════════════════════════════════════════════════


def run_shift(
    jobs: Optional[List[NightJob]] = None,
    force: bool = False,
    categories: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """Run a complete night shift cycle.

    Args:
        jobs: Custom job list (default: BUILTIN_JOBS)
        force: Run even if not nighttime
        categories: Filter to specific categories
    """
    shift_start = time.time()
    shift_id = datetime.now().strftime("%Y%m%d_%H%M%S")

    if not force and not is_nighttime():
        return {
            "status": "skipped",
            "reason": f"Not nighttime (window: {DEFAULT_START_HOUR}:00 — {DEFAULT_END_HOUR}:00)",
            "current_hour": datetime.now().hour,
        }

    logger.info("═══ NightShift %s starting ═══", shift_id)

    # Load cluster
    nodes = load_nodes()
    for node in nodes:
        if node.ip in ("127.0.0.1", "::1", "localhost"):
            node.online = True
        else:
            node.online = check_online(node)

    online_nodes = [n for n in nodes if n.online]
    logger.info("Cluster: %d/%d nodes online", len(online_nodes), len(nodes))

    if not online_nodes:
        return {"status": "failed", "reason": "No online nodes"}

    # Prepare jobs
    all_jobs = jobs or [NightJob(**asdict(j)) for j in BUILTIN_JOBS]  # Deep copy
    if categories:
        all_jobs = [j for j in all_jobs if j.category in categories]

    # Assign to nodes
    assigned = assign_jobs(all_jobs, online_nodes)

    # Execute
    results = []
    for job in assigned:
        if job.status == JobStatus.SKIPPED:
            results.append(asdict(job))
            continue

        result = execute_job(job, nodes)
        results.append(asdict(result))
        logger.info(
            "  %s → %s on %s (%.1fs, exit %d)",
            "✓" if result.status == JobStatus.COMPLETED else "✗",
            result.name, result.assigned_node,
            result.end_time - result.start_time, result.exit_code,
        )

    # Generate report
    shift_end = time.time()
    report = {
        "shift_id": shift_id,
        "started": datetime.fromtimestamp(shift_start).isoformat(),
        "ended": datetime.fromtimestamp(shift_end).isoformat(),
        "duration_sec": round(shift_end - shift_start, 2),
        "nodes_online": len(online_nodes),
        "nodes_total": len(nodes),
        "jobs_total": len(results),
        "jobs_completed": sum(1 for r in results if r["status"] == JobStatus.COMPLETED),
        "jobs_failed": sum(1 for r in results if r["status"] == JobStatus.FAILED),
        "jobs_skipped": sum(1 for r in results if r["status"] == JobStatus.SKIPPED),
        "jobs": results,
    }

    # Save report
    report_path = RESULTS_DIR / f"shift_{shift_id}.json"
    report_path.write_text(json.dumps(report, indent=2, default=str))
    logger.info("Report saved: %s", report_path)

    return report


def get_shift_history(limit: int = 20) -> List[Dict]:
    """Load past shift reports."""
    reports = []
    for f in sorted(RESULTS_DIR.glob("shift_*.json"), reverse=True)[:limit]:
        try:
            reports.append(json.loads(f.read_text()))
        except Exception:
            pass
    return reports


# ═══════════════════════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════════════════════


def print_banner():
    print("""
  ╔══════════════════════════════════════════╗
  ║   🌙 NullSec NightShift v1.0            ║
  ║   Cluster overnight compute scheduler   ║
  ╚══════════════════════════════════════════╝
    """)


def cli():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    print_banner()

    if len(sys.argv) < 2:
        print("  Usage:")
        print("    nightshift.py run              Run night shift (only during night hours)")
        print("    nightshift.py run --force      Run regardless of time")
        print("    nightshift.py run --cat=revenue Run only revenue jobs")
        print("    nightshift.py status           Show cluster and job status")
        print("    nightshift.py history           Show past shift reports")
        print("    nightshift.py jobs             List all available jobs")
        print("    nightshift.py cron             Print crontab entry")
        print()
        return

    cmd = sys.argv[1]

    if cmd == "run":
        force = "--force" in sys.argv
        categories = None
        for arg in sys.argv:
            if arg.startswith("--cat="):
                categories = arg.split("=", 1)[1].split(",")

        report = run_shift(force=force, categories=categories)
        print(json.dumps(report, indent=2, default=str))

    elif cmd == "status":
        nodes = load_nodes()
        print(f"  Night window: {DEFAULT_START_HOUR}:00 — {DEFAULT_END_HOUR}:00")
        print(f"  Currently nighttime: {'YES' if is_nighttime() else 'NO'} (hour: {datetime.now().hour})")
        print(f"  Cluster nodes: {len(nodes)}")
        for n in nodes:
            online = "✓" if (check_online(n) if n.ip not in ("127.0.0.1",) else True) else "✗"
            print(f"    {online} {n.name:15s} {n.ip:16s} {n.cores:2d}c {n.ram_mb:6d}MB {n.gpu or '—':12s} {n.role}")
        print()

    elif cmd == "history":
        history = get_shift_history(10)
        if not history:
            print("  No shift history found.")
        for h in history:
            print(f"  [{h['shift_id']}] {h['jobs_completed']}/{h['jobs_total']} completed, "
                  f"{h['jobs_failed']} failed, {h['duration_sec']}s")

    elif cmd == "jobs":
        for j in BUILTIN_JOBS:
            status = "✓" if j.enabled else "✗"
            print(f"  {status} [{j.category:12s}] P{j.priority} {j.name:25s} — {j.description}")

    elif cmd == "cron":
        script_path = Path(__file__).resolve()
        print(f"  # Add to crontab (crontab -e):")
        print(f"  0 22 * * * cd {script_path.parent} && {sys.executable} {script_path} run --force >> ~/.nullsec/nightshift/logs/cron.log 2>&1")
        print()

    else:
        print(f"  Unknown command: {cmd}")


if __name__ == "__main__":
    cli()
