"""NullSec WebTools — Cluster Service
Reads nodes.conf, checks node health, runs remote commands."""

import socket
import time
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any
from pathlib import Path
from .. import config

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


@dataclass
class Node:
    name: str
    ip: str
    user: str = "root"
    password: str = ""
    port: int = 22
    os_type: str = "linux"          # linux | windows | debian
    arch: str = "x86_64"
    conf_cores: int = 0             # from nodes.conf
    conf_ram_mb: int = 0            # from nodes.conf
    gpu: str = ""
    role: str = "worker"
    tags: str = ""
    online: bool = False
    cores: int = 0
    ram_gb: float = 0
    disk_free: str = ""
    uptime: str = ""
    load: str = ""
    hostname: str = ""
    os_info: str = ""
    last_check: float = 0


def load_nodes() -> List[Node]:
    """Load nodes from ~/.nullsec/cluster/nodes.conf
    Format: hostname|ip|user|port|os|arch|cores|ram_mb|gpu|role|tags"""
    nodes = []
    conf = config.NODES_CONF
    if not conf.exists():
        return nodes

    for line in conf.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) >= 3:
            port = 22
            if len(parts) > 3:
                try:
                    port = int(parts[3])
                except ValueError:
                    port = 22
            node = Node(
                name=parts[0],
                ip=parts[1],
                user=parts[2] if len(parts) > 2 else "root",
                port=port,
                os_type=parts[4] if len(parts) > 4 else "linux",
                arch=parts[5] if len(parts) > 5 else "x86_64",
                conf_cores=int(parts[6]) if len(parts) > 6 and parts[6].isdigit() else 0,
                conf_ram_mb=int(parts[7]) if len(parts) > 7 and parts[7].isdigit() else 0,
                gpu=parts[8] if len(parts) > 8 else "",
                role=parts[9] if len(parts) > 9 else "worker",
                tags=parts[10] if len(parts) > 10 else "",
            )
            nodes.append(node)
    return nodes


def check_port(host: str, port: int = 22, timeout: float = 1.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def ssh_exec(node: Node, command: str, timeout: int = 10) -> Optional[str]:
    """Run a command on a node via SSH."""
    if not HAS_PARAMIKO:
        return None
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        kwargs = {
            "hostname": node.ip, "port": node.port,
            "username": node.user, "timeout": 3,
            "allow_agent": False, "look_for_keys": True,
            "banner_timeout": 3,
        }
        if node.password:
            kwargs["password"] = node.password
            kwargs["look_for_keys"] = False
        client.connect(**kwargs)
        _, stdout, _ = client.exec_command(command, timeout=timeout)
        result = stdout.read().decode(errors="replace").strip()
        client.close()
        return result
    except Exception:
        return None


def _is_windows(node: Node) -> bool:
    return node.os_type.lower() in ("windows", "win", "win10", "win11")


def _is_localhost(node: Node) -> bool:
    return node.ip in ("127.0.0.1", "::1", "localhost")


def _get_local_node_stats(node: Node) -> Node:
    """Populate stats for the local machine using psutil (no SSH)."""
    node.online = True
    node.last_check = time.time()
    if HAS_PSUTIL:
        import platform
        node.hostname = platform.node()
        node.cores = psutil.cpu_count() or 0
        node.ram_gb = round(psutil.virtual_memory().total / (1024 ** 3), 1)
        disk = psutil.disk_usage("/")
        node.disk_free = f"{round(disk.free / (1024 ** 3))}G"
        boot = psutil.boot_time()
        up_secs = time.time() - boot
        days = int(up_secs // 86400)
        hours = int((up_secs % 86400) // 3600)
        mins = int((up_secs % 3600) // 60)
        if days > 0:
            node.uptime = f"up {days} days, {hours} hours"
        elif hours > 0:
            node.uptime = f"up {hours} hours, {mins} minutes"
        else:
            node.uptime = f"up {mins} minutes"
        load = psutil.getloadavg() if hasattr(psutil, 'getloadavg') else (0, 0, 0)
        node.load = f"{load[0]:.2f} {load[1]:.2f} {load[2]:.2f}"
        node.os_info = f"{platform.system()} {platform.release()}"
    return node


def _get_windows_stats_cmd() -> str:
    """PowerShell one-liner to gather stats from a Windows node over SSH."""
    return (
        'powershell -NoProfile -Command "'
        '$h = hostname; '
        '$c = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum; '
        '$m = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB); '
        '$d = [math]::Round((Get-PSDrive C).Free / 1GB); '
        '$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; '
        '$up = (New-TimeSpan -Start $boot -End (Get-Date)); '
        '$ustr = \\\"up $($up.Days) days, $($up.Hours) hours\\\"; '
        '$os = (Get-CimInstance Win32_OperatingSystem).Caption -replace \\\"Microsoft \\\",\\\"\\\"; '
        'Write-Output \\\"$h|$c|$m|${d}G|$ustr|0|$os\\\"'
        '"'
    )


def _get_linux_stats_cmd() -> str:
    """Bash one-liner to gather stats from a Linux node over SSH."""
    return (
        "hostname && nproc && "
        "free -g 2>/dev/null | awk '/Mem/{print $2}' && "
        "df -BG / 2>/dev/null | awk 'NR==2{print $4}' && "
        "uptime -p 2>/dev/null || uptime | sed 's/.*up/up/' && "
        "cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3 && "
        "uname -sr 2>/dev/null"
    )


def get_node_stats(node: Node) -> Node:
    """Fetch live stats from a single node."""
    # Localhost → use psutil directly, skip SSH
    if _is_localhost(node):
        return _get_local_node_stats(node)

    node.online = check_port(node.ip, node.port)
    node.last_check = time.time()

    if not node.online:
        # Use config fallbacks for offline nodes
        node.cores = node.conf_cores
        node.ram_gb = round(node.conf_ram_mb / 1024, 1) if node.conf_ram_mb else 0
        return node

    if _is_windows(node):
        cmd = _get_windows_stats_cmd()
        result = ssh_exec(node, cmd, timeout=15)
        if result:
            # PowerShell outputs: hostname|cores|ram_gb|disk_free|uptime|load|os
            parts = result.strip().split("|")
            node.hostname = parts[0].strip('"') if len(parts) > 0 else ""
            node.cores = int(parts[1]) if len(parts) > 1 and parts[1].strip().isdigit() else node.conf_cores
            node.ram_gb = float(parts[2]) if len(parts) > 2 and parts[2].strip().replace(".", "").isdigit() else round(node.conf_ram_mb / 1024, 1)
            node.disk_free = parts[3].strip() if len(parts) > 3 else ""
            node.uptime = parts[4].strip() if len(parts) > 4 else ""
            node.load = parts[5].strip() if len(parts) > 5 else "—"
            node.os_info = parts[6].strip().strip('"') if len(parts) > 6 else "Windows"
        else:
            # SSH worked (port open) but command failed — use config values
            node.cores = node.conf_cores
            node.ram_gb = round(node.conf_ram_mb / 1024, 1) if node.conf_ram_mb else 0
            node.os_info = "Windows (cmd failed)"
    else:
        # Linux / Debian — use newline-separated output for reliability
        cmd = _get_linux_stats_cmd()
        result = ssh_exec(node, cmd)
        if result:
            lines = [l.strip() for l in result.strip().splitlines() if l.strip()]
            node.hostname = lines[0] if len(lines) > 0 else ""
            node.cores = int(lines[1]) if len(lines) > 1 and lines[1].isdigit() else 0
            node.ram_gb = float(lines[2]) if len(lines) > 2 and lines[2].replace(".", "").isdigit() else 0
            node.disk_free = lines[3] if len(lines) > 3 else ""
            node.uptime = lines[4] if len(lines) > 4 else ""
            node.load = lines[5] if len(lines) > 5 else ""
            node.os_info = lines[6] if len(lines) > 6 else ""

    return node


def get_all_node_stats() -> List[Node]:
    """Fetch stats from all nodes in parallel."""
    nodes = load_nodes()
    with ThreadPoolExecutor(max_workers=max(len(nodes), 1)) as pool:
        results = list(pool.map(get_node_stats, nodes))
    return results


def get_cluster_summary() -> Dict[str, Any]:
    """Aggregate cluster-wide stats."""
    nodes = get_all_node_stats()
    online = [n for n in nodes if n.online]
    return {
        "total": len(nodes),
        "total_nodes": len(nodes),
        "online": len(online),
        "online_nodes": len(online),
        "offline_nodes": len(nodes) - len(online),
        "total_cores": sum(n.cores for n in online),
        "total_ram_gb": sum(n.ram_gb for n in online),
        "total_disk_free": "—",
        "nodes": [n.__dict__ for n in nodes],
    }


def run_on_node(node_name: str, command: str) -> Dict[str, Any]:
    """Run a command on a specific node by name."""
    nodes = load_nodes()
    node = next((n for n in nodes if n.name == node_name), None)
    if not node:
        return {"error": f"Node '{node_name}' not found"}

    if not check_port(node.ip, node.port):
        return {"error": f"Node '{node_name}' is offline"}

    start = time.time()
    result = ssh_exec(node, command)
    duration = time.time() - start

    return {
        "node": node_name,
        "command": command,
        "output": result or "",
        "duration": round(duration, 2),
        "success": result is not None,
    }


def get_local_stats() -> Dict[str, Any]:
    """Get stats for the local machine."""
    if not HAS_PSUTIL:
        return {}
    return {
        "cpu_percent": psutil.cpu_percent(interval=0.5),
        "cpu_count": psutil.cpu_count(),
        "ram_total_gb": round(psutil.virtual_memory().total / (1024**3), 1),
        "ram_used_pct": psutil.virtual_memory().percent,
        "disk_total_gb": round(psutil.disk_usage("/").total / (1024**3), 1),
        "disk_used_pct": psutil.disk_usage("/").percent,
        "boot_time": psutil.boot_time(),
    }
