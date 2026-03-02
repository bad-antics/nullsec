"""NullSec WebTools — Network Intelligence"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates
from pathlib import Path
from ..services.network_service import (
    quick_scan, subnet_scan, get_local_interfaces,
    get_wifi_info, get_arp_table,
)

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))


@router.get("/")
async def network_page(request: Request):
    return templates.TemplateResponse("network.html", {
        "request": request,
        "page": "network",
    })


@router.get("/api/interfaces")
async def api_interfaces():
    return {"interfaces": get_local_interfaces()}


@router.get("/api/wifi")
async def api_wifi():
    return get_wifi_info()


@router.get("/api/arp")
async def api_arp():
    return {"hosts": get_arp_table()}


@router.post("/api/scan")
async def api_scan(request: Request):
    """Run a port scan."""
    body = await request.json()
    target = body.get("target", "")
    ports = body.get("ports", None)

    if not target:
        return {"error": "target required"}

    if isinstance(ports, str):
        ports = [int(p.strip()) for p in ports.split(",") if p.strip().isdigit()]

    results = quick_scan(target, ports)
    return {"target": target, "ports": results, "count": len(results)}


@router.post("/api/discover")
async def api_discover(request: Request):
    """Discover hosts on a subnet."""
    body = await request.json()
    subnet = body.get("subnet", "192.168.40.0")
    port = body.get("port", 22)

    hosts = subnet_scan(subnet, port)
    return {"subnet": subnet, "hosts": hosts, "count": len(hosts)}
