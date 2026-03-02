"""NullSec Bench — Cluster Benchmarking Web App"""

import asyncio
import json
import socket
import time
import platform
import hashlib
import os
from pathlib import Path
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
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

APP_NAME = "NullSec Bench"
APP_VERSION = "1.0.0"
NODES_CONF = Path.home() / ".nullsec" / "cluster" / "nodes.conf"
RESULTS_DIR = Path.home() / ".nullsec" / "benchmarks"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

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
    role: str = "worker"


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
            port = int(p[3]) if len(p) > 3 and p[3].isdigit() else 22
            nodes.append(Node(
                name=p[0], ip=p[1], user=p[2], port=port,
                os_type=p[4] if len(p) > 4 else "linux",
                conf_cores=int(p[6]) if len(p) > 6 and p[6].isdigit() else 0,
                conf_ram_mb=int(p[7]) if len(p) > 7 and p[7].isdigit() else 0,
                role=p[9] if len(p) > 9 else "worker",
            ))
    return nodes


def check_port(host: str, port: int = 22, timeout: float = 1.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def ssh_exec(node: Node, command: str, timeout: int = 30) -> Optional[str]:
    if not HAS_PARAMIKO:
        return None
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(
            hostname=node.ip, port=node.port, username=node.user,
            timeout=3, allow_agent=False, look_for_keys=True, banner_timeout=3,
        )
        _, stdout, stderr = client.exec_command(command, timeout=timeout)
        result = stdout.read().decode(errors="replace").strip()
        client.close()
        return result
    except Exception as e:
        return None


# ─── Benchmark Implementations ───────────────────────────────────────────────

def bench_cpu_local() -> Dict[str, Any]:
    """Local CPU benchmark: SHA-256 hashing speed."""
    data = os.urandom(1024 * 1024)  # 1MB
    iterations = 100
    start = time.time()
    for _ in range(iterations):
        hashlib.sha256(data).hexdigest()
    duration = time.time() - start
    rate = (iterations * len(data)) / duration / (1024 * 1024)

    # Multi-core: parallel hash
    import multiprocessing
    cores = multiprocessing.cpu_count()

    def hash_work(_):
        d = os.urandom(1024 * 1024)
        for _ in range(50):
            hashlib.sha256(d).hexdigest()

    start_mt = time.time()
    with multiprocessing.Pool(cores) as pool:
        pool.map(hash_work, range(cores))
    duration_mt = time.time() - start_mt
    rate_mt = (50 * cores * 1024 * 1024) / duration_mt / (1024 * 1024)

    return {
        "test": "cpu",
        "single_thread_mbps": round(rate, 1),
        "multi_thread_mbps": round(rate_mt, 1),
        "cores_used": cores,
        "duration_sec": round(duration + duration_mt, 2),
    }


def bench_memory_local() -> Dict[str, Any]:
    """Local memory benchmark: sequential read/write speed."""
    size_mb = 256
    data = bytearray(size_mb * 1024 * 1024)

    # Write
    start = time.time()
    for i in range(0, len(data), 4096):
        data[i:i+4096] = b'\xaa' * 4096
    write_dur = time.time() - start
    write_speed = size_mb / write_dur

    # Read
    start = time.time()
    total = 0
    for i in range(0, len(data), 4096):
        total += sum(data[i:i+4096])
    read_dur = time.time() - start
    read_speed = size_mb / read_dur

    return {
        "test": "memory",
        "write_mbps": round(write_speed, 1),
        "read_mbps": round(read_speed, 1),
        "size_mb": size_mb,
        "duration_sec": round(write_dur + read_dur, 2),
    }


def bench_disk_local() -> Dict[str, Any]:
    """Local disk I/O benchmark."""
    test_file = Path("/tmp/nullsec_bench_disk.tmp")
    size_mb = 100
    block_size = 1024 * 1024  # 1MB blocks

    # Write
    data = os.urandom(block_size)
    start = time.time()
    with open(test_file, "wb") as f:
        for _ in range(size_mb):
            f.write(data)
        f.flush()
        os.fsync(f.fileno())
    write_dur = time.time() - start
    write_speed = size_mb / write_dur

    # Read
    start = time.time()
    with open(test_file, "rb") as f:
        while f.read(block_size):
            pass
    read_dur = time.time() - start
    read_speed = size_mb / read_dur

    test_file.unlink(missing_ok=True)

    return {
        "test": "disk",
        "write_mbps": round(write_speed, 1),
        "read_mbps": round(read_speed, 1),
        "size_mb": size_mb,
        "duration_sec": round(write_dur + read_dur, 2),
    }


def bench_network_local(target_ip: str = "1.1.1.1", port: int = 443) -> Dict[str, Any]:
    """Network latency benchmark."""
    latencies = []
    for _ in range(10):
        start = time.time()
        try:
            with socket.create_connection((target_ip, port), timeout=5):
                latency = (time.time() - start) * 1000
                latencies.append(round(latency, 1))
        except Exception:
            latencies.append(-1)
        time.sleep(0.1)

    valid = [l for l in latencies if l >= 0]
    return {
        "test": "network",
        "target": target_ip,
        "avg_ms": round(sum(valid) / len(valid), 1) if valid else -1,
        "min_ms": min(valid) if valid else -1,
        "max_ms": max(valid) if valid else -1,
        "samples": len(valid),
        "lost": len(latencies) - len(valid),
    }


# ─── Remote Benchmarks via SSH ───────────────────────────────────────────────

LINUX_CPU_BENCH = """python3 -c "
import hashlib, os, time
data = os.urandom(1024*1024)
start = time.time()
for _ in range(100):
    hashlib.sha256(data).hexdigest()
dur = time.time() - start
rate = (100 * 1024 * 1024) / dur / (1024 * 1024)
print(f'{rate:.1f}')
" 2>/dev/null || echo "0"
"""

LINUX_DISK_BENCH = """
dd if=/dev/zero of=/tmp/ns_bench bs=1M count=100 oflag=dsync 2>&1 | tail -1 | awk '{print $(NF-1), $NF}'
rm -f /tmp/ns_bench
dd if=/dev/zero of=/tmp/ns_bench bs=1M count=100 2>/dev/null
dd if=/tmp/ns_bench of=/dev/null bs=1M 2>&1 | tail -1 | awk '{print $(NF-1), $NF}'
rm -f /tmp/ns_bench
"""

WINDOWS_CPU_BENCH = (
    'powershell -NoProfile -Command "'
    '$data = [byte[]]::new(1MB); '
    '(New-Object Random).NextBytes($data); '
    '$sw = [Diagnostics.Stopwatch]::StartNew(); '
    'for($i=0; $i -lt 100; $i++){ '
    '  $sha = [Security.Cryptography.SHA256]::Create(); '
    '  [void]$sha.ComputeHash($data); '
    '} '
    '$sw.Stop(); '
    '$rate = [math]::Round(100 * 1 / $sw.Elapsed.TotalSeconds, 1); '
    'Write-Output $rate'
    '"'
)


def bench_remote_cpu(node: Node) -> Dict[str, Any]:
    """Run CPU benchmark on a remote node."""
    if not check_port(node.ip, node.port):
        return {"node": node.name, "test": "cpu", "error": "offline"}

    is_win = node.os_type.lower() in ("windows", "win")
    cmd = WINDOWS_CPU_BENCH if is_win else LINUX_CPU_BENCH
    start = time.time()
    result = ssh_exec(node, cmd, timeout=60)
    duration = time.time() - start

    rate = 0
    if result:
        try:
            rate = float(result.strip().splitlines()[-1])
        except (ValueError, IndexError):
            rate = 0

    return {
        "node": node.name,
        "test": "cpu",
        "single_thread_mbps": rate,
        "duration_sec": round(duration, 2),
        "raw": result or "",
    }


def bench_remote_network(node: Node) -> Dict[str, Any]:
    """Measure network latency to a remote node."""
    latencies = []
    for _ in range(10):
        start = time.time()
        try:
            with socket.create_connection((node.ip, node.port), timeout=5):
                latency = (time.time() - start) * 1000
                latencies.append(round(latency, 1))
        except Exception:
            latencies.append(-1)
        time.sleep(0.05)

    valid = [l for l in latencies if l >= 0]
    return {
        "node": node.name,
        "test": "network",
        "avg_ms": round(sum(valid) / len(valid), 1) if valid else -1,
        "min_ms": min(valid) if valid else -1,
        "max_ms": max(valid) if valid else -1,
        "samples": len(valid),
    }


# ─── Results Storage ─────────────────────────────────────────────────────────

_results: List[Dict] = []
MAX_RESULTS = 200


def save_result(result: Dict):
    result["timestamp"] = datetime.now().isoformat()
    _results.append(result)
    if len(_results) > MAX_RESULTS:
        _results.pop(0)
    # Persist
    try:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        path = RESULTS_DIR / f"bench_{ts}.json"
        path.write_text(json.dumps(result, indent=2, default=str))
    except Exception:
        pass


def load_saved_results() -> List[Dict]:
    results = []
    for f in sorted(RESULTS_DIR.glob("bench_*.json"), reverse=True)[:50]:
        try:
            results.append(json.loads(f.read_text()))
        except Exception:
            pass
    return results


# ─── WebSocket for live progress ─────────────────────────────────────────────

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


# ─── Routes ──────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    nodes = load_nodes()
    online = []
    for n in nodes:
        n_online = check_port(n.ip, n.port) if n.ip not in ("127.0.0.1",) else True
        online.append({"name": n.name, "ip": n.ip, "online": n_online, "role": n.role,
                       "cores": n.conf_cores, "ram_mb": n.conf_ram_mb, "os_type": n.os_type})
    return templates.TemplateResponse("bench.html", {
        "request": request,
        "page": "bench",
        "nodes": online,
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


@app.post("/api/bench/local")
async def api_bench_local(request: Request):
    """Run all benchmarks on the local machine."""
    body = await request.json()
    tests = body.get("tests", ["cpu", "memory", "disk", "network"])

    await broadcast({"type": "bench_start", "node": "localhost", "tests": tests})

    loop = asyncio.get_event_loop()
    results = {"node": platform.node(), "ip": "127.0.0.1", "tests": {}}

    if "cpu" in tests:
        await broadcast({"type": "progress", "msg": "Running CPU benchmark..."})
        results["tests"]["cpu"] = await loop.run_in_executor(None, bench_cpu_local)

    if "memory" in tests:
        await broadcast({"type": "progress", "msg": "Running memory benchmark..."})
        results["tests"]["memory"] = await loop.run_in_executor(None, bench_memory_local)

    if "disk" in tests:
        await broadcast({"type": "progress", "msg": "Running disk I/O benchmark..."})
        results["tests"]["disk"] = await loop.run_in_executor(None, bench_disk_local)

    if "network" in tests:
        await broadcast({"type": "progress", "msg": "Running network latency test..."})
        results["tests"]["network"] = await loop.run_in_executor(None, bench_network_local)

    save_result(results)
    await broadcast({"type": "bench_complete", "result": results})
    return results


@app.post("/api/bench/node/{node_name}")
async def api_bench_node(node_name: str, request: Request):
    """Run benchmarks on a specific remote node."""
    body = await request.json()
    tests = body.get("tests", ["cpu", "network"])

    nodes = load_nodes()
    node = next((n for n in nodes if n.name == node_name), None)
    if not node:
        return {"error": f"Node '{node_name}' not found"}

    await broadcast({"type": "bench_start", "node": node_name, "tests": tests})

    loop = asyncio.get_event_loop()
    results = {"node": node_name, "ip": node.ip, "tests": {}}

    if "cpu" in tests:
        await broadcast({"type": "progress", "msg": f"Running CPU benchmark on {node_name}..."})
        results["tests"]["cpu"] = await loop.run_in_executor(None, bench_remote_cpu, node)

    if "network" in tests:
        await broadcast({"type": "progress", "msg": f"Testing network to {node_name}..."})
        results["tests"]["network"] = await loop.run_in_executor(None, bench_remote_network, node)

    save_result(results)
    await broadcast({"type": "bench_complete", "result": results})
    return results


@app.post("/api/bench/cluster")
async def api_bench_cluster(request: Request):
    """Run benchmarks across all online nodes."""
    body = await request.json()
    tests = body.get("tests", ["cpu", "network"])

    nodes = load_nodes()
    await broadcast({"type": "cluster_bench_start", "nodes": len(nodes)})

    loop = asyncio.get_event_loop()
    all_results = []

    # Local first
    await broadcast({"type": "progress", "msg": "Benchmarking localhost..."})
    local = {"node": platform.node(), "ip": "127.0.0.1", "tests": {}}
    if "cpu" in tests:
        local["tests"]["cpu"] = await loop.run_in_executor(None, bench_cpu_local)
    if "network" in tests:
        local["tests"]["network"] = bench_network_local()
    all_results.append(local)

    # Remote nodes
    for node in nodes:
        if node.ip in ("127.0.0.1", "::1", "localhost"):
            continue
        if not check_port(node.ip, node.port):
            all_results.append({"node": node.name, "ip": node.ip, "tests": {}, "error": "offline"})
            continue

        await broadcast({"type": "progress", "msg": f"Benchmarking {node.name}..."})
        result = {"node": node.name, "ip": node.ip, "tests": {}}

        if "cpu" in tests:
            result["tests"]["cpu"] = await loop.run_in_executor(None, bench_remote_cpu, node)
        if "network" in tests:
            result["tests"]["network"] = await loop.run_in_executor(None, bench_remote_network, node)

        all_results.append(result)

    cluster_result = {
        "type": "cluster_benchmark",
        "nodes": all_results,
        "total_nodes": len(all_results),
    }
    save_result(cluster_result)
    await broadcast({"type": "cluster_bench_complete", "result": cluster_result})
    return cluster_result


@app.get("/api/history")
async def api_history():
    return {"results": _results[-50:]}


@app.get("/api/saved")
async def api_saved():
    return {"results": load_saved_results()}
