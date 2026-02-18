#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
 libnullsec v1.0 — NullSec Shared Python Library
 Author: bad-antics
═══════════════════════════════════════════════════════════════════════════════

 Core utility library used by all NullSec Python tools.
 Provides: SSH connections, node discovery, config management, logging,
           payload helpers, cluster orchestration, and common patterns.

 Usage:
   from lib.nullsec import NullSecCluster, NullSecLogger, SSHClient
   cluster = NullSecCluster()
   for node in cluster.nodes():
       print(node.name, node.run("uptime"))
"""

import os
import sys
import json
import time
import socket
import hashlib
import logging
import platform
import subprocess
import threading
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict, Any, Callable, Tuple
from dataclasses import dataclass, field, asdict
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    import paramiko
    HAS_PARAMIKO = True
except ImportError:
    HAS_PARAMIKO = False

# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

VERSION = "1.0.0"
NULLSEC_DIR = os.path.expanduser("~/.nullsec")
CLUSTER_DIR = os.path.join(NULLSEC_DIR, "cluster")
NODES_CONF = os.path.join(CLUSTER_DIR, "nodes.conf")
NULLSEC_LOOT_DIR = "/mmc/nullsec/"
AUTHOR = "bad-antics"

COLORS = {
    "reset": "\033[0m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
    "bold": "\033[1m",
    "dim": "\033[2m",
}


# ═══════════════════════════════════════════════════════════════════════════════
# Logger
# ═══════════════════════════════════════════════════════════════════════════════

class NullSecLogger:
    """Colored, leveled logger with optional file output."""

    LEVEL_COLORS = {
        "DEBUG": "dim",
        "INFO": "green",
        "WARNING": "yellow",
        "ERROR": "red",
        "CRITICAL": "magenta",
    }

    def __init__(self, name: str = "nullsec", log_file: Optional[str] = None,
                 level: str = "INFO", use_color: bool = True):
        self.name = name
        self.use_color = use_color and sys.stdout.isatty()
        self.logger = logging.getLogger(name)
        self.logger.setLevel(getattr(logging, level.upper()))

        fmt = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(fmt, datefmt="%H:%M:%S"))
        self.logger.addHandler(handler)

        if log_file:
            fh = logging.FileHandler(log_file)
            fh.setFormatter(logging.Formatter(fmt, datefmt="%Y-%m-%d %H:%M:%S"))
            self.logger.addHandler(fh)

    def _colorize(self, level: str, msg: str) -> str:
        if not self.use_color:
            return msg
        c = COLORS.get(self.LEVEL_COLORS.get(level, "reset"), "")
        return f"{c}{msg}{COLORS['reset']}"

    def debug(self, msg): self.logger.debug(self._colorize("DEBUG", msg))
    def info(self, msg): self.logger.info(self._colorize("INFO", msg))
    def warning(self, msg): self.logger.warning(self._colorize("WARNING", msg))
    def error(self, msg): self.logger.error(self._colorize("ERROR", msg))
    def critical(self, msg): self.logger.critical(self._colorize("CRITICAL", msg))

    def success(self, msg):
        self.logger.info(f"{COLORS['green']}✓ {msg}{COLORS['reset']}" if self.use_color else f"[OK] {msg}")

    def fail(self, msg):
        self.logger.error(f"{COLORS['red']}✗ {msg}{COLORS['reset']}" if self.use_color else f"[FAIL] {msg}")

    def banner(self, text: str):
        width = 72
        border = "═" * width
        self.logger.info(f"\n{COLORS['green'] if self.use_color else ''}╔{border}╗")
        self.logger.info(f"║  {text:<{width - 2}}║")
        self.logger.info(f"╚{border}╝{COLORS['reset'] if self.use_color else ''}\n")


# ═══════════════════════════════════════════════════════════════════════════════
# Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class NodeInfo:
    """Represents a cluster node."""
    name: str
    ip: str
    port: int = 22
    user: str = "root"
    password: str = ""
    os_type: str = "linux"  # linux, windows
    cores: int = 0
    ram_gb: float = 0
    online: bool = False
    ssh_key: str = ""
    extra: Dict[str, Any] = field(default_factory=dict)

    @property
    def label(self) -> str:
        return f"{self.name}@{self.ip}"

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class PayloadInfo:
    """Represents a NullSec payload."""
    name: str
    path: str
    category: str = ""
    author: str = AUTHOR
    description: str = ""
    version: str = "1.0"
    has_info_json: bool = False
    has_payload_sh: bool = False
    errors: List[str] = field(default_factory=list)


@dataclass
class CommandResult:
    """Result of a remote command execution."""
    node: str
    command: str
    stdout: str
    stderr: str
    exit_code: int
    duration: float = 0.0

    @property
    def success(self) -> bool:
        return self.exit_code == 0


# ═══════════════════════════════════════════════════════════════════════════════
# SSH Client
# ═══════════════════════════════════════════════════════════════════════════════

class SSHClient:
    """Wrapper around paramiko for easy SSH operations."""

    def __init__(self, host: str, user: str = "root", password: str = "",
                 port: int = 22, key_file: str = "", timeout: int = 10):
        if not HAS_PARAMIKO:
            raise ImportError("paramiko is required: pip install paramiko")

        self.host = host
        self.user = user
        self.password = password
        self.port = port
        self.key_file = key_file
        self.timeout = timeout
        self._client = None
        self._sftp = None

    def connect(self) -> bool:
        """Establish SSH connection."""
        try:
            self._client = paramiko.SSHClient()
            self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            kwargs = {
                "hostname": self.host,
                "port": self.port,
                "username": self.user,
                "timeout": self.timeout,
                "allow_agent": False,
                "look_for_keys": False,
            }

            if self.key_file and os.path.exists(self.key_file):
                kwargs["key_filename"] = self.key_file
            elif self.password:
                kwargs["password"] = self.password
            else:
                kwargs["look_for_keys"] = True

            self._client.connect(**kwargs)
            return True
        except Exception:
            self._client = None
            return False

    def run(self, command: str, timeout: int = 30) -> CommandResult:
        """Execute a command and return result."""
        start = time.time()
        if not self._client:
            if not self.connect():
                return CommandResult(self.host, command, "", "Connection failed", -1)

        try:
            stdin, stdout, stderr = self._client.exec_command(command, timeout=timeout)
            exit_code = stdout.channel.recv_exit_status()
            return CommandResult(
                node=self.host,
                command=command,
                stdout=stdout.read().decode(errors="replace").strip(),
                stderr=stderr.read().decode(errors="replace").strip(),
                exit_code=exit_code,
                duration=time.time() - start,
            )
        except Exception as e:
            return CommandResult(self.host, command, "", str(e), -1, time.time() - start)

    def upload(self, local_path: str, remote_path: str) -> bool:
        """Upload a file via SFTP."""
        try:
            if not self._sftp:
                self._sftp = self._client.open_sftp()
            self._sftp.put(local_path, remote_path)
            return True
        except Exception:
            return False

    def download(self, remote_path: str, local_path: str) -> bool:
        """Download a file via SFTP."""
        try:
            if not self._sftp:
                self._sftp = self._client.open_sftp()
            self._sftp.get(remote_path, local_path)
            return True
        except Exception:
            return False

    def close(self):
        """Close connections."""
        if self._sftp:
            self._sftp.close()
        if self._client:
            self._client.close()

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, *args):
        self.close()


# ═══════════════════════════════════════════════════════════════════════════════
# Network Utilities
# ═══════════════════════════════════════════════════════════════════════════════

def ping(host: str, count: int = 1, timeout: int = 2) -> bool:
    """Quick ping check."""
    param = "-n" if platform.system().lower() == "windows" else "-c"
    try:
        result = subprocess.run(
            ["ping", param, str(count), "-W", str(timeout), host],
            capture_output=True, timeout=timeout + 2
        )
        return result.returncode == 0
    except Exception:
        return False


def port_open(host: str, port: int, timeout: float = 1.0) -> bool:
    """Check if a TCP port is open."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def scan_subnet(subnet: str, ports: List[int] = None, workers: int = 64) -> List[Dict]:
    """Fast subnet scan with optional port check."""
    if ports is None:
        ports = [22]

    results = []
    base = ".".join(subnet.split(".")[:3])

    def check_host(ip):
        for port in ports:
            if port_open(ip, port, timeout=0.5):
                try:
                    hostname = socket.gethostbyaddr(ip)[0]
                except socket.herror:
                    hostname = ""
                return {"ip": ip, "hostname": hostname, "open_ports": [port]}
        return None

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(check_host, f"{base}.{i}"): i for i in range(1, 255)}
        for future in as_completed(futures):
            result = future.result()
            if result:
                results.append(result)

    return sorted(results, key=lambda x: [int(o) for o in x["ip"].split(".")])


def get_local_ip() -> str:
    """Get primary local IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


# ═══════════════════════════════════════════════════════════════════════════════
# Cluster Management
# ═══════════════════════════════════════════════════════════════════════════════

class NullSecCluster:
    """Manages the NullSec mesh cluster."""

    def __init__(self, config_path: str = NODES_CONF):
        self.config_path = config_path
        self._nodes: List[NodeInfo] = []
        self.log = NullSecLogger("cluster")
        self.load()

    def load(self):
        """Load nodes from config file."""
        self._nodes = []
        if not os.path.exists(self.config_path):
            return

        with open(self.config_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("|")
                if len(parts) >= 3:
                    node = NodeInfo(
                        name=parts[0],
                        ip=parts[1],
                        user=parts[2] if len(parts) > 2 else "root",
                        password=parts[3] if len(parts) > 3 else "",
                        port=int(parts[4]) if len(parts) > 4 else 22,
                    )
                    self._nodes.append(node)

    def nodes(self) -> List[NodeInfo]:
        """Return all configured nodes."""
        return self._nodes

    def online_nodes(self, workers: int = 16) -> List[NodeInfo]:
        """Return nodes that respond to SSH."""
        def check(node):
            node.online = port_open(node.ip, node.port, timeout=2)
            return node

        with ThreadPoolExecutor(max_workers=workers) as pool:
            list(pool.map(check, self._nodes))

        return [n for n in self._nodes if n.online]

    def run_on_all(self, command: str, parallel: bool = True,
                   timeout: int = 30) -> List[CommandResult]:
        """Execute a command on all online nodes."""
        results = []
        nodes = self.online_nodes()

        if parallel:
            with ThreadPoolExecutor(max_workers=len(nodes) or 1) as pool:
                futures = {}
                for node in nodes:
                    ssh = SSHClient(node.ip, node.user, node.password, node.port)
                    futures[pool.submit(ssh.run, command, timeout)] = node

                for future in as_completed(futures):
                    result = future.result()
                    result.node = futures[future].name
                    results.append(result)
        else:
            for node in nodes:
                with SSHClient(node.ip, node.user, node.password, node.port) as ssh:
                    result = ssh.run(command, timeout)
                    result.node = node.name
                    results.append(result)

        return results

    def deploy_file(self, local_path: str, remote_path: str) -> Dict[str, bool]:
        """Deploy a file to all online nodes."""
        results = {}
        for node in self.online_nodes():
            with SSHClient(node.ip, node.user, node.password, node.port) as ssh:
                results[node.name] = ssh.upload(local_path, remote_path)
        return results

    def collect_stats(self) -> List[Dict[str, Any]]:
        """Collect system stats from all nodes."""
        cmd = (
            "echo \"$(hostname)|$(nproc)|"
            "$(free -g 2>/dev/null | awk '/Mem/{print $2}')|"
            "$(df -BG / | awk 'NR==2{print $4}')|"
            "$(uptime -p 2>/dev/null || uptime)|"
            "$(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3)\""
        )
        stats = []
        for result in self.run_on_all(cmd):
            if result.success:
                parts = result.stdout.split("|")
                if len(parts) >= 4:
                    stats.append({
                        "node": result.node,
                        "hostname": parts[0],
                        "cores": int(parts[1]) if parts[1].isdigit() else 0,
                        "ram_gb": parts[2],
                        "disk_free": parts[3],
                        "uptime": parts[4] if len(parts) > 4 else "",
                        "load": parts[5] if len(parts) > 5 else "",
                    })
        return stats

    def total_resources(self) -> Dict[str, Any]:
        """Sum total cluster resources."""
        stats = self.collect_stats()
        total_cores = sum(s.get("cores", 0) for s in stats)
        total_ram = sum(int(s.get("ram_gb", 0)) for s in stats if str(s.get("ram_gb", "")).isdigit())
        return {
            "nodes_online": len(stats),
            "total_cores": total_cores,
            "total_ram_gb": total_ram,
            "nodes": stats,
        }


# ═══════════════════════════════════════════════════════════════════════════════
# Payload Utilities
# ═══════════════════════════════════════════════════════════════════════════════

def find_payloads(suite_dir: str) -> List[PayloadInfo]:
    """Discover all payloads in a directory."""
    payloads = []
    suite = Path(suite_dir)

    if not suite.is_dir():
        return payloads

    for d in sorted(suite.iterdir()):
        if not d.is_dir():
            continue

        p = PayloadInfo(name=d.name, path=str(d))

        payload_sh = d / "payload.sh"
        info_json = d / "info.json"

        p.has_payload_sh = payload_sh.exists()
        p.has_info_json = info_json.exists()

        if not p.has_payload_sh:
            p.errors.append("Missing payload.sh")

        if p.has_info_json:
            try:
                with open(info_json) as f:
                    info = json.load(f)
                    p.category = info.get("category", "")
                    p.author = info.get("author", "")
                    p.description = info.get("description", "")
                    p.version = info.get("version", "1.0")
            except json.JSONDecodeError:
                p.errors.append("Invalid info.json")

        payloads.append(p)

    return payloads


def payload_checksum(payload_dir: str) -> str:
    """Generate a checksum for a payload directory."""
    h = hashlib.sha256()
    pdir = Path(payload_dir)

    for f in sorted(pdir.rglob("*")):
        if f.is_file():
            h.update(f.read_bytes())

    return h.hexdigest()[:16]


def validate_payload(payload_dir: str) -> List[str]:
    """Validate a payload against NullSec standards."""
    errors = []
    pdir = Path(payload_dir)

    payload_sh = pdir / "payload.sh"
    info_json = pdir / "info.json"

    if not payload_sh.exists():
        errors.append("Missing payload.sh")
    else:
        content = payload_sh.read_text()
        if not content.startswith("#!/bin/bash"):
            errors.append("Missing #!/bin/bash shebang")
        if "Author:" not in content:
            errors.append("Missing Author header")
        if NULLSEC_LOOT_DIR not in content:
            errors.append(f"LOOT_DIR should use {NULLSEC_LOOT_DIR}")

    if not info_json.exists():
        errors.append("Missing info.json")
    else:
        try:
            data = json.loads(info_json.read_text())
            for key in ["name", "author", "description", "category", "version"]:
                if key not in data:
                    errors.append(f"info.json missing '{key}'")
        except json.JSONDecodeError:
            errors.append("info.json is invalid JSON")

    return errors


# ═══════════════════════════════════════════════════════════════════════════════
# Config Helpers
# ═══════════════════════════════════════════════════════════════════════════════

class NullSecConfig:
    """JSON-based configuration management."""

    def __init__(self, path: Optional[str] = None):
        self.path = path or os.path.join(NULLSEC_DIR, "config.json")
        self._data = {}
        self.load()

    def load(self):
        if os.path.exists(self.path):
            with open(self.path) as f:
                self._data = json.load(f)

    def save(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w") as f:
            json.dump(self._data, f, indent=2)

    def get(self, key: str, default: Any = None) -> Any:
        keys = key.split(".")
        d = self._data
        for k in keys:
            if isinstance(d, dict):
                d = d.get(k)
            else:
                return default
            if d is None:
                return default
        return d

    def set(self, key: str, value: Any):
        keys = key.split(".")
        d = self._data
        for k in keys[:-1]:
            d = d.setdefault(k, {})
        d[keys[-1]] = value
        self.save()


# ═══════════════════════════════════════════════════════════════════════════════
# Decorators and Utilities
# ═══════════════════════════════════════════════════════════════════════════════

def timer(func: Callable) -> Callable:
    """Decorator to time function execution."""
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        elapsed = time.time() - start
        print(f"  ⏱ {func.__name__} completed in {elapsed:.2f}s")
        return result
    return wrapper


def retry(max_attempts: int = 3, delay: float = 1.0):
    """Decorator for retry logic with exponential backoff."""
    def decorator(func: Callable) -> Callable:
        def wrapper(*args, **kwargs):
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_attempts - 1:
                        raise
                    time.sleep(delay * (2 ** attempt))
        return wrapper
    return decorator


def human_size(nbytes: int) -> str:
    """Convert bytes to human-readable string."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if nbytes < 1024:
            return f"{nbytes:.1f} {unit}"
        nbytes /= 1024
    return f"{nbytes:.1f} PB"


def timestamp() -> str:
    """ISO timestamp string."""
    return datetime.now().strftime("%Y-%m-%d_%H-%M-%S")


def ensure_dir(path: str) -> str:
    """Create directory if it doesn't exist, return path."""
    os.makedirs(path, exist_ok=True)
    return path


# ═══════════════════════════════════════════════════════════════════════════════
# Module Info
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    log = NullSecLogger("nullsec")
    log.banner(f"libnullsec v{VERSION}")

    print(f"  NullSec Dir:   {NULLSEC_DIR}")
    print(f"  Cluster Conf:  {NODES_CONF}")
    print(f"  Local IP:      {get_local_ip()}")
    print(f"  Paramiko:      {'✓ Available' if HAS_PARAMIKO else '✗ Not installed'}")
    print()

    # Quick cluster status
    if os.path.exists(NODES_CONF):
        cluster = NullSecCluster()
        print(f"  Configured nodes: {len(cluster.nodes())}")
        online = cluster.online_nodes()
        print(f"  Online nodes:     {len(online)}")
        for n in online:
            print(f"    ✓ {n.name} ({n.ip})")
    else:
        print("  No cluster configured")
