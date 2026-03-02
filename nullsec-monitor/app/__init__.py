"""NullSec Monitor — Real-time Cluster Monitoring Dashboard"""

import json
import time
import asyncio
import socket
import platform
from pathlib import Path
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field, asdict
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

try:
    import paramiko
    HAS_PARAMIKO = True
except ImportError:
    HAS_PARAMIKO = False

# ─── Config ──────────────────────────────────────────────────────────────────

APP_NAME = "NullSec Monitor"
APP_VERSION = "1.0.0"
NODES_CONF = Path.home() / ".nullsec" / "cluster" / "nodes.conf"
HISTORY_DIR = Path.home() / ".nullsec" / "monitor"
HISTORY_DIR.mkdir(parents=True, exist_ok=True)

WEBTOOLS_PORT = 9000
SCANNER_PORT = 9002
BENCH_PORT = 9003

# ─── App Setup ───────────────────────────────────────────────────────────────

app = FastAPI(title=APP_NAME, version=APP_VERSION)

STATIC_DIR = Path(__file__).parent.parent / "static"
TEMPLATE_DIR = Path(__file__).parent.parent / "templates"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "css").mkdir(exist_ok=True)
(STATIC_DIR / "js").mkdir(exist_ok=True)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))
templates.env.globals["APP_NAME"] = APP_NAME
templates.env.globals["APP_VERSION"] = APP_VERSION

# ─── Node Model ──────────────────────────────────────────────────────────────

@dataclass
class Node:
    name: str
    ip: str
    user: str = "root"
    port: int = 22
    os_type: str = "linux"
    conf_cores: int = 0
    conf_ram_mb: int = 0
    gpu: str = ""
    role: str = "worker"
    online: bool = False
    cpu_pct: float = 0.0
    ram_pct: float = 0.0
    ram_total_gb: float = 0.0
    ram_used_gb: float = 0.0
    disk_pct: float = 0.0
    disk_total_gb: float = 0.0
    disk_free_gb: float = 0.0
    cores: int = 0
    load_1m: float = 0.0
    load_5m: float = 0.0
    load_15m: float = 0.0
    uptime: str = ""
    hostname: str = ""
    os_info: str = ""
    net_rx_mb: float = 0.0
    net_tx_mb: float = 0.0
    processes: int = 0
    temp_c: float = 0.0
    last_check: float = 0
    error: str = ""


def load_nodes() -> List[Node]:
    if not NODES_CONF.exists():
        return []
    nodes = []
    for line in NODES_CONF.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split("|")
        if len(p) >= 3:
            port = 22
            if len(p) > 3:
                try:
                    port = int(p[3])
                except ValueError:
                    port = 22
            nodes.append(Node(
                name=p[0], ip=p[1], user=p[2], port=port,
                os_type=p[4] if len(p) > 4 else "linux",
                conf_cores=int(p[6]) if len(p) > 6 and p[6].isdigit() else 0,
                conf_ram_mb=int(p[7]) if len(p) > 7 and p[7].isdigit() else 0,
                gpu=p[8] if len(p) > 8 else "",
                role=p[9] if len(p) > 9 else "worker",
            ))
    return nodes


def check_port(host: str, port: int = 22, timeout: float = 1.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def ssh_exec(node: Node, command: str, timeout: int = 10) -> Optional[str]:
    if not HAS_PARAMIKO:
        return None
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(
            hostname=node.ip, port=node.port, username=node.user,
            timeout=3, allow_agent=False, look_for_keys=True, banner_timeout=3,
        )
        _, stdout, _ = client.exec_command(command, timeout=timeout)
        result = stdout.read().decode(errors="replace").strip()
        client.close()
        return result
    except Exception as e:
        return None


# ─── Stat Collection ─────────────────────────────────────────────────────────

def collect_local_stats(node: Node) -> Node:
    """Collect detailed stats for localhost using psutil."""
    node.online = True
    node.last_check = time.time()
    if not HAS_PSUTIL:
        return node

    node.hostname = platform.node()
    node.cores = psutil.cpu_count() or 0
    node.cpu_pct = psutil.cpu_percent(interval=0.5)

    mem = psutil.virtual_memory()
    node.ram_total_gb = round(mem.total / (1024**3), 1)
    node.ram_used_gb = round(mem.used / (1024**3), 1)
    node.ram_pct = mem.percent

    disk = psutil.disk_usage("/")
    node.disk_total_gb = round(disk.total / (1024**3), 1)
    node.disk_free_gb = round(disk.free / (1024**3), 1)
    node.disk_pct = disk.percent

    load = psutil.getloadavg() if hasattr(psutil, 'getloadavg') else (0, 0, 0)
    node.load_1m, node.load_5m, node.load_15m = load

    boot = psutil.boot_time()
    up = time.time() - boot
    d, h, m = int(up // 86400), int((up % 86400) // 3600), int((up % 3600) // 60)
    node.uptime = f"{d}d {h}h {m}m" if d else f"{h}h {m}m"

    net = psutil.net_io_counters()
    node.net_rx_mb = round(net.bytes_recv / (1024**2), 1)
    node.net_tx_mb = round(net.bytes_sent / (1024**2), 1)

    node.processes = len(psutil.pids())
    node.os_info = f"{platform.system()} {platform.release()}"

    temps = psutil.sensors_temperatures() if hasattr(psutil, 'sensors_temperatures') else {}
    if temps:
        for name, entries in temps.items():
            if entries:
                node.temp_c = entries[0].current
                break

    return node


def collect_linux_stats(node: Node) -> Node:
    """Collect detailed stats from a Linux node via SSH."""
    node.online = check_port(node.ip, node.port)
    node.last_check = time.time()
    if not node.online:
        node.cores = node.conf_cores
        node.ram_total_gb = round(node.conf_ram_mb / 1024, 1)
        return node

    cmd = (
        "hostname && nproc && "
        "grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; printf \"%.1f\\n\", u/t*100}' && "
        "free -b | awk '/Mem/{printf \"%d %d %.1f\\n\", $2, $3, $3/$2*100}' && "
        "df -B1 / | awk 'NR==2{printf \"%d %d %.1f\\n\", $2, $4, $5}' && "
        "cat /proc/loadavg | cut -d' ' -f1-3 && "
        "uptime -p 2>/dev/null || echo '?' && "
        "cat /proc/net/dev | awk '/eth0|ens|enp|wlan/{rx+=$2; tx+=$10} END{printf \"%d %d\\n\", rx, tx}' && "
        "ls -d /proc/[0-9]* 2>/dev/null | wc -l && "
        "uname -sr && "
        "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0"
    )
    result = ssh_exec(node, cmd, timeout=12)
    if not result:
        node.cores = node.conf_cores
        node.ram_total_gb = round(node.conf_ram_mb / 1024, 1)
        node.error = "SSH command failed"
        return node

    lines = [l.strip() for l in result.strip().splitlines() if l.strip()]
    try:
        node.hostname = lines[0] if len(lines) > 0 else ""
        node.cores = int(lines[1]) if len(lines) > 1 and lines[1].isdigit() else node.conf_cores
        node.cpu_pct = float(lines[2]) if len(lines) > 2 else 0

        if len(lines) > 3:
            mem_parts = lines[3].split()
            if len(mem_parts) >= 3:
                node.ram_total_gb = round(int(mem_parts[0]) / (1024**3), 1)
                node.ram_used_gb = round(int(mem_parts[1]) / (1024**3), 1)
                node.ram_pct = float(mem_parts[2])

        if len(lines) > 4:
            disk_parts = lines[4].split()
            if len(disk_parts) >= 3:
                node.disk_total_gb = round(int(disk_parts[0]) / (1024**3), 1)
                node.disk_free_gb = round(int(disk_parts[1]) / (1024**3), 1)
                node.disk_pct = float(disk_parts[2].rstrip('%'))

        if len(lines) > 5:
            load_parts = lines[5].split()
            if len(load_parts) >= 3:
                node.load_1m = float(load_parts[0])
                node.load_5m = float(load_parts[1])
                node.load_15m = float(load_parts[2])

        node.uptime = lines[6].replace("up ", "") if len(lines) > 6 else ""

        if len(lines) > 7:
            net_parts = lines[7].split()
            if len(net_parts) >= 2:
                node.net_rx_mb = round(int(net_parts[0]) / (1024**2), 1)
                node.net_tx_mb = round(int(net_parts[1]) / (1024**2), 1)

        node.processes = int(lines[8]) if len(lines) > 8 and lines[8].isdigit() else 0
        node.os_info = lines[9] if len(lines) > 9 else ""

        temp_raw = lines[10] if len(lines) > 10 else "0"
        if temp_raw.isdigit():
            node.temp_c = int(temp_raw) / 1000
    except (IndexError, ValueError):
        node.error = "Parse error"

    return node


def collect_windows_stats(node: Node) -> Node:
    """Collect stats from a Windows node via SSH + PowerShell."""
    node.online = check_port(node.ip, node.port)
    node.last_check = time.time()
    if not node.online:
        node.cores = node.conf_cores
        node.ram_total_gb = round(node.conf_ram_mb / 1024, 1)
        return node

    cmd = (
        'powershell -NoProfile -Command "'
        '$h = hostname; '
        '$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average; '
        '$cs = Get-CimInstance Win32_ComputerSystem; '
        '$os = Get-CimInstance Win32_OperatingSystem; '
        '$c = ($cs).NumberOfLogicalProcessors; '
        '$ramT = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1); '
        '$ramU = [math]::Round(($cs.TotalPhysicalMemory - $os.FreePhysicalMemory * 1KB) / 1GB, 1); '
        '$ramP = [math]::Round(($cs.TotalPhysicalMemory - $os.FreePhysicalMemory * 1KB) / $cs.TotalPhysicalMemory * 100, 1); '
        '$dk = Get-PSDrive C; '
        '$dkT = [math]::Round(($dk.Used + $dk.Free) / 1GB, 1); '
        '$dkF = [math]::Round($dk.Free / 1GB, 1); '
        '$dkP = [math]::Round($dk.Used / ($dk.Used + $dk.Free) * 100, 1); '
        '$boot = $os.LastBootUpTime; '
        '$up = (New-TimeSpan -Start $boot -End (Get-Date)); '
        '$uStr = \\\"$($up.Days)d $($up.Hours)h $($up.Minutes)m\\\"; '
        '$procs = (Get-Process).Count; '
        '$osN = $os.Caption -replace \\\"Microsoft \\\",\\\"\\\"; '
        'Write-Output \\\"$h|$c|$cpu|$ramT|$ramU|$ramP|$dkT|$dkF|$dkP|$uStr|$procs|$osN\\\"'
        '"'
    )
    result = ssh_exec(node, cmd, timeout=15)
    if result:
        p = [x.strip().strip('"') for x in result.strip().split("|")]
        try:
            node.hostname = p[0] if len(p) > 0 else ""
            node.cores = int(p[1]) if len(p) > 1 and p[1].isdigit() else node.conf_cores
            node.cpu_pct = float(p[2]) if len(p) > 2 else 0
            node.ram_total_gb = float(p[3]) if len(p) > 3 else round(node.conf_ram_mb / 1024, 1)
            node.ram_used_gb = float(p[4]) if len(p) > 4 else 0
            node.ram_pct = float(p[5]) if len(p) > 5 else 0
            node.disk_total_gb = float(p[6]) if len(p) > 6 else 0
            node.disk_free_gb = float(p[7]) if len(p) > 7 else 0
            node.disk_pct = float(p[8]) if len(p) > 8 else 0
            node.uptime = p[9] if len(p) > 9 else ""
            node.processes = int(p[10]) if len(p) > 10 and p[10].isdigit() else 0
            node.os_info = p[11] if len(p) > 11 else "Windows"
        except (ValueError, IndexError):
            node.cores = node.conf_cores
            node.ram_total_gb = round(node.conf_ram_mb / 1024, 1)
            node.error = "Parse error"
    else:
        node.cores = node.conf_cores
        node.ram_total_gb = round(node.conf_ram_mb / 1024, 1)
        node.error = "SSH cmd failed"

    return node


def collect_node_stats(node: Node) -> Node:
    if node.ip in ("127.0.0.1", "::1", "localhost"):
        return collect_local_stats(node)
    elif node.os_type.lower() in ("windows", "win", "win10", "win11"):
        return collect_windows_stats(node)
    else:
        return collect_linux_stats(node)


def collect_all_stats() -> List[Dict[str, Any]]:
    nodes = load_nodes()
    with ThreadPoolExecutor(max_workers=max(len(nodes), 1)) as pool:
        results = list(pool.map(collect_node_stats, nodes))
    return [asdict(n) for n in results]


# ─── History ─────────────────────────────────────────────────────────────────

_history: Dict[str, List[Dict]] = {}
MAX_HISTORY = 120  # 120 data points = 10 minutes at 5s intervals


def record_snapshot(nodes: List[Dict]) -> None:
    ts = time.time()
    for n in nodes:
        name = n["name"]
        if name not in _history:
            _history[name] = []
        _history[name].append({
            "ts": ts,
            "cpu": n.get("cpu_pct", 0),
            "ram": n.get("ram_pct", 0),
            "disk": n.get("disk_pct", 0),
            "load": n.get("load_1m", 0),
            "net_rx": n.get("net_rx_mb", 0),
            "net_tx": n.get("net_tx_mb", 0),
        })
        if len(_history[name]) > MAX_HISTORY:
            _history[name] = _history[name][-MAX_HISTORY:]


# ─── Alerts ──────────────────────────────────────────────────────────────────

_alerts: List[Dict] = []
MAX_ALERTS = 200


def check_alerts(nodes: List[Dict]) -> None:
    ts = time.time()
    for n in nodes:
        name = n["name"]
        if not n.get("online"):
            _alerts.append({"ts": ts, "node": name, "level": "critical",
                           "msg": f"{name} is OFFLINE"})
        elif n.get("cpu_pct", 0) > 90:
            _alerts.append({"ts": ts, "node": name, "level": "warning",
                           "msg": f"{name} CPU at {n['cpu_pct']:.1f}%"})
        elif n.get("ram_pct", 0) > 90:
            _alerts.append({"ts": ts, "node": name, "level": "warning",
                           "msg": f"{name} RAM at {n['ram_pct']:.1f}%"})
        elif n.get("disk_pct", 0) > 90:
            _alerts.append({"ts": ts, "node": name, "level": "warning",
                           "msg": f"{name} Disk at {n['disk_pct']:.1f}%"})
    # Trim
    while len(_alerts) > MAX_ALERTS:
        _alerts.pop(0)


# ─── WebSocket Live Feed ─────────────────────────────────────────────────────

_ws_clients: List[WebSocket] = []


async def broadcast(data: dict):
    dead = []
    for ws in _ws_clients:
        try:
            await ws.send_json(data)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _ws_clients.remove(ws)


async def monitor_loop():
    """Background task that collects stats and broadcasts to WebSocket clients."""
    while True:
        try:
            loop = asyncio.get_event_loop()
            nodes = await loop.run_in_executor(None, collect_all_stats)
            record_snapshot(nodes)
            check_alerts(nodes)

            summary = {
                "type": "update",
                "ts": time.time(),
                "nodes": nodes,
                "alerts": _alerts[-10:],
                "totals": {
                    "online": sum(1 for n in nodes if n["online"]),
                    "total": len(nodes),
                    "total_cores": sum(n["cores"] for n in nodes if n["online"]),
                    "total_ram": round(sum(n["ram_total_gb"] for n in nodes if n["online"]), 1),
                    "avg_cpu": round(sum(n["cpu_pct"] for n in nodes if n["online"]) / max(1, sum(1 for n in nodes if n["online"])), 1),
                    "avg_ram": round(sum(n["ram_pct"] for n in nodes if n["online"]) / max(1, sum(1 for n in nodes if n["online"])), 1),
                },
            }
            await broadcast(summary)
        except Exception as e:
            print(f"[Monitor] Error: {e}")
        await asyncio.sleep(5)


@app.on_event("startup")
async def startup():
    asyncio.create_task(monitor_loop())


# ─── Routes ──────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("monitor.html", {
        "request": request,
        "page": "monitor",
    })


@app.websocket("/ws")
async def ws_endpoint(websocket: WebSocket):
    await websocket.accept()
    _ws_clients.append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in _ws_clients:
            _ws_clients.remove(websocket)


@app.get("/api/snapshot")
async def api_snapshot():
    """One-time snapshot of all node stats."""
    loop = asyncio.get_event_loop()
    nodes = await loop.run_in_executor(None, collect_all_stats)
    record_snapshot(nodes)
    return {"nodes": nodes, "ts": time.time()}


@app.get("/api/history/{node_name}")
async def api_history(node_name: str):
    return {"node": node_name, "history": _history.get(node_name, [])}


@app.get("/api/alerts")
async def api_alerts(limit: int = 50):
    return {"alerts": _alerts[-limit:]}
