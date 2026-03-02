"""NullSec WebTools — Network Service
Network scanning, port checks, scan history."""

import json
import socket
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Dict, Any, Optional
from .. import config


def port_open(host: str, port: int, timeout: float = 1.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def quick_scan(target: str, ports: List[int] = None) -> List[Dict[str, Any]]:
    """Quick TCP port scan of a single host."""
    if ports is None:
        ports = [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445,
                 993, 995, 1433, 1471, 3306, 3389, 5432, 5900, 8080, 8443, 9090]

    results = []

    def check(port):
        start = time.time()
        is_open = port_open(target, port)
        latency = round((time.time() - start) * 1000, 1)
        if is_open:
            return {"port": port, "state": "open", "latency_ms": latency}
        return None

    with ThreadPoolExecutor(max_workers=50) as pool:
        futures = {pool.submit(check, p): p for p in ports}
        for f in as_completed(futures):
            result = f.result()
            if result:
                results.append(result)

    return sorted(results, key=lambda x: x["port"])


def subnet_scan(subnet: str, port: int = 22) -> List[Dict[str, Any]]:
    """Scan a /24 subnet for hosts with a specific port open."""
    base = ".".join(subnet.split(".")[:3])
    results = []

    def check_host(ip):
        if port_open(ip, port, timeout=0.5):
            try:
                hostname = socket.gethostbyaddr(ip)[0]
            except socket.herror:
                hostname = ""
            return {"ip": ip, "hostname": hostname, "port": port}
        return None

    with ThreadPoolExecutor(max_workers=64) as pool:
        futures = {pool.submit(check_host, f"{base}.{i}"): i for i in range(1, 255)}
        for f in as_completed(futures):
            result = f.result()
            if result:
                results.append(result)

    return sorted(results, key=lambda x: [int(o) for o in x["ip"].split(".")])


def get_local_interfaces() -> List[Dict[str, str]]:
    """Get local network interfaces."""
    try:
        result = subprocess.run(
            ["ip", "-j", "addr", "show"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except Exception:
        pass

    # Fallback
    try:
        result = subprocess.run(
            ["ip", "addr", "show"],
            capture_output=True, text=True, timeout=5
        )
        return [{"raw": result.stdout}]
    except Exception:
        return []


def get_wifi_info() -> Dict[str, Any]:
    """Get current WiFi connection info."""
    info = {}
    try:
        result = subprocess.run(
            ["iwconfig"], capture_output=True, text=True, timeout=5
        )
        info["iwconfig"] = result.stdout
    except Exception:
        info["iwconfig"] = "Not available"

    try:
        result = subprocess.run(
            ["iw", "dev"], capture_output=True, text=True, timeout=5
        )
        info["iw_dev"] = result.stdout
    except Exception:
        pass

    return info


def get_arp_table() -> List[Dict[str, str]]:
    """Get ARP table for known hosts."""
    hosts = []
    try:
        result = subprocess.run(
            ["arp", "-an"], capture_output=True, text=True, timeout=5
        )
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 4 and "(" in line:
                ip = parts[1].strip("()")
                mac = parts[3] if parts[3] != "<incomplete>" else ""
                hosts.append({"ip": ip, "mac": mac})
    except Exception:
        pass
    return hosts
