"""NullSec Scanner — Network Reconnaissance Web App"""

import asyncio
import json
import socket
import struct
import time
import ipaddress
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, asdict
from datetime import datetime

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

# ─── Config ──────────────────────────────────────────────────────────────────

APP_NAME = "NullSec Scanner"
APP_VERSION = "1.0.0"
RESULTS_DIR = Path.home() / ".nullsec" / "scans"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

# Well-known service map
SERVICE_MAP = {
    21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
    80: "HTTP", 110: "POP3", 111: "RPCBind", 135: "MSRPC", 139: "NetBIOS",
    143: "IMAP", 443: "HTTPS", 445: "SMB", 465: "SMTPS", 587: "SMTP-SUB",
    993: "IMAPS", 995: "POP3S", 1433: "MSSQL", 1521: "Oracle", 1723: "PPTP",
    3306: "MySQL", 3389: "RDP", 5432: "PostgreSQL", 5900: "VNC", 5985: "WinRM",
    6379: "Redis", 8080: "HTTP-Alt", 8443: "HTTPS-Alt", 9000: "Custom",
    9001: "Custom", 9002: "Custom", 9003: "Custom", 9090: "WebConsole",
    27017: "MongoDB",
}

# Common port groups
PORT_GROUPS = {
    "quick": [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995,
              1433, 3306, 3389, 5432, 5900, 8080, 8443, 9090],
    "web": [80, 443, 8080, 8443, 8000, 8888, 9000, 9001, 9002, 9003, 3000, 4000, 5000],
    "database": [1433, 1521, 3306, 5432, 6379, 27017, 9200, 5984],
    "full": list(range(1, 1025)),
    "all": list(range(1, 65536)),
}

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

# ─── Scan History ────────────────────────────────────────────────────────────

_scan_history: List[Dict] = []


def save_scan(result: Dict):
    _scan_history.append(result)
    if len(_scan_history) > 100:
        _scan_history.pop(0)
    # Persist last scan
    try:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        path = RESULTS_DIR / f"scan_{ts}.json"
        path.write_text(json.dumps(result, indent=2, default=str))
    except Exception:
        pass


def load_scan_history() -> List[Dict]:
    """Load saved scan results."""
    results = []
    for f in sorted(RESULTS_DIR.glob("scan_*.json"), reverse=True)[:50]:
        try:
            results.append(json.loads(f.read_text()))
        except Exception:
            pass
    return results


# ─── Scanning Engine ─────────────────────────────────────────────────────────

def tcp_connect(host: str, port: int, timeout: float = 1.0) -> Tuple[bool, float, str]:
    """Test a single TCP port. Returns (is_open, latency_ms, banner)."""
    start = time.time()
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        latency = round((time.time() - start) * 1000, 1)

        # Try banner grab
        banner = ""
        try:
            sock.settimeout(1.0)
            # Send probe for HTTP
            if port in (80, 8080, 8000, 8443, 8888, 9000, 9001, 9002, 9003, 3000, 4000, 5000):
                sock.send(b"HEAD / HTTP/1.0\r\n\r\n")
            else:
                sock.send(b"\r\n")
            data = sock.recv(512)
            banner = data.decode(errors="replace").strip()[:200]
        except Exception:
            pass

        sock.close()
        return True, latency, banner
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False, 0, ""


def resolve_host(target: str) -> Optional[str]:
    """Resolve hostname to IP."""
    try:
        return socket.gethostbyname(target)
    except socket.gaierror:
        return None


def reverse_dns(ip: str) -> str:
    """Reverse DNS lookup."""
    try:
        return socket.gethostbyaddr(ip)[0]
    except (socket.herror, socket.gaierror, OSError):
        return ""


def scan_ports(target: str, ports: List[int], timeout: float = 1.0, max_workers: int = 100) -> Dict[str, Any]:
    """Scan multiple ports on a target."""
    ip = resolve_host(target) if not _is_ip(target) else target
    if not ip:
        return {"error": f"Cannot resolve {target}", "target": target}

    hostname = reverse_dns(ip) if _is_ip(target) else target
    start_time = time.time()
    open_ports = []
    closed = 0
    filtered = 0

    def check(port):
        is_open, latency, banner = tcp_connect(ip, port, timeout)
        if is_open:
            return {
                "port": port,
                "state": "open",
                "service": SERVICE_MAP.get(port, "unknown"),
                "latency_ms": latency,
                "banner": banner,
            }
        return None

    with ThreadPoolExecutor(max_workers=min(max_workers, len(ports))) as pool:
        futures = {pool.submit(check, p): p for p in ports}
        for f in as_completed(futures):
            result = f.result()
            if result:
                open_ports.append(result)
            else:
                closed += 1

    duration = round(time.time() - start_time, 2)
    open_ports.sort(key=lambda x: x["port"])

    result = {
        "type": "port_scan",
        "target": target,
        "ip": ip,
        "hostname": hostname,
        "ports_scanned": len(ports),
        "open_count": len(open_ports),
        "closed_count": closed,
        "open_ports": open_ports,
        "duration_sec": duration,
        "timestamp": datetime.now().isoformat(),
    }
    save_scan(result)
    return result


def discover_subnet(subnet: str, port: int = 22, timeout: float = 0.5) -> Dict[str, Any]:
    """Discover live hosts on a /24 subnet."""
    try:
        network = ipaddress.ip_network(subnet if "/" in subnet else f"{subnet}/24", strict=False)
    except ValueError:
        return {"error": f"Invalid subnet: {subnet}"}

    start_time = time.time()
    hosts = []

    def check_host(ip_str):
        is_open, latency, _ = tcp_connect(ip_str, port, timeout)
        if is_open:
            hostname = reverse_dns(ip_str)
            # Quick fingerprint — check a few ports
            services = []
            for p in [22, 80, 443, 3389, 445]:
                if p == port:
                    services.append(SERVICE_MAP.get(p, str(p)))
                    continue
                o, _, _ = tcp_connect(ip_str, p, 0.3)
                if o:
                    services.append(SERVICE_MAP.get(p, str(p)))
            return {
                "ip": ip_str,
                "hostname": hostname,
                "latency_ms": latency,
                "services": services,
                "port": port,
            }
        return None

    ips = [str(ip) for ip in network.hosts()]
    with ThreadPoolExecutor(max_workers=64) as pool:
        futures = {pool.submit(check_host, ip): ip for ip in ips}
        for f in as_completed(futures):
            result = f.result()
            if result:
                hosts.append(result)

    duration = round(time.time() - start_time, 2)
    hosts.sort(key=lambda x: [int(o) for o in x["ip"].split(".")])

    result = {
        "type": "subnet_discovery",
        "subnet": str(network),
        "probe_port": port,
        "hosts_found": len(hosts),
        "ips_scanned": len(ips),
        "hosts": hosts,
        "duration_sec": duration,
        "timestamp": datetime.now().isoformat(),
    }
    save_scan(result)
    return result


def fingerprint_host(target: str) -> Dict[str, Any]:
    """Detailed fingerprint of a single host."""
    ip = resolve_host(target) if not _is_ip(target) else target
    if not ip:
        return {"error": f"Cannot resolve {target}"}

    hostname = reverse_dns(ip) if _is_ip(target) else target
    start_time = time.time()

    # Scan common ports
    scan = scan_ports(ip, PORT_GROUPS["quick"], timeout=1.5, max_workers=50)
    open_ports = scan.get("open_ports", [])

    # Determine OS hints
    os_hints = []
    port_nums = [p["port"] for p in open_ports]
    if 3389 in port_nums or 445 in port_nums or 135 in port_nums:
        os_hints.append("Windows")
    if 22 in port_nums:
        os_hints.append("Linux/Unix")
    if 548 in port_nums:
        os_hints.append("macOS")
    if 80 in port_nums or 443 in port_nums:
        os_hints.append("Web Server")

    # TTL-based OS detection via ICMP would need root, so skip

    duration = round(time.time() - start_time, 2)

    result = {
        "type": "fingerprint",
        "target": target,
        "ip": ip,
        "hostname": hostname,
        "open_ports": open_ports,
        "os_hints": os_hints,
        "services": list(set(p["service"] for p in open_ports if p["service"] != "unknown")),
        "banners": {p["port"]: p["banner"] for p in open_ports if p["banner"]},
        "duration_sec": duration,
        "timestamp": datetime.now().isoformat(),
    }
    save_scan(result)
    return result


def _is_ip(s: str) -> bool:
    try:
        ipaddress.ip_address(s)
        return True
    except ValueError:
        return False


# ─── WebSocket for live scan progress ────────────────────────────────────────

_ws_clients: List[WebSocket] = []


async def broadcast_progress(data: dict):
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
    return templates.TemplateResponse("scanner.html", {
        "request": request,
        "page": "scanner",
        "port_groups": list(PORT_GROUPS.keys()),
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


@app.post("/api/scan")
async def api_scan(request: Request):
    """Port scan a target."""
    body = await request.json()
    target = body.get("target", "").strip()
    port_group = body.get("port_group", "quick")
    custom_ports = body.get("ports", "")
    timeout = float(body.get("timeout", 1.0))

    if not target:
        return {"error": "target required"}

    if custom_ports:
        ports = []
        for part in custom_ports.split(","):
            part = part.strip()
            if "-" in part:
                lo, hi = part.split("-", 1)
                if lo.isdigit() and hi.isdigit():
                    ports.extend(range(int(lo), int(hi) + 1))
            elif part.isdigit():
                ports.append(int(part))
    else:
        ports = PORT_GROUPS.get(port_group, PORT_GROUPS["quick"])

    await broadcast_progress({"type": "scan_start", "target": target, "ports": len(ports)})

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, scan_ports, target, ports, timeout, 100)

    await broadcast_progress({"type": "scan_complete", "result": result})
    return result


@app.post("/api/discover")
async def api_discover(request: Request):
    """Discover hosts on a subnet."""
    body = await request.json()
    subnet = body.get("subnet", "192.168.40.0/24")
    port = int(body.get("port", 22))

    await broadcast_progress({"type": "discover_start", "subnet": subnet})

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, discover_subnet, subnet, port)

    await broadcast_progress({"type": "discover_complete", "result": result})
    return result


@app.post("/api/fingerprint")
async def api_fingerprint(request: Request):
    """Detailed host fingerprint."""
    body = await request.json()
    target = body.get("target", "").strip()
    if not target:
        return {"error": "target required"}

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, fingerprint_host, target)
    return result


@app.get("/api/history")
async def api_history():
    """Get scan history."""
    return {"scans": _scan_history[-50:]}


@app.get("/api/saved")
async def api_saved():
    """Get saved scan files."""
    return {"scans": load_scan_history()}
