"""NullSec WebTools — Dashboard (Command Center)"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates
from pathlib import Path
from ..services import get_cluster_summary, get_local_stats
from ..services.payload_service import get_payload_stats
from ..services.loot_service import get_loot_stats

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))


@router.get("/")
async def dashboard(request: Request):
    """Main command center dashboard."""
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "page": "dashboard",
    })


@router.get("/api/dashboard/stats")
async def dashboard_stats():
    """JSON API: dashboard stats for HTMX/JS polling."""
    cluster = get_cluster_summary()
    payload_stats = get_payload_stats()
    loot = get_loot_stats()
    local = get_local_stats()

    return {
        "total_nodes": cluster.get("total_nodes", 0),
        "nodes_online": cluster.get("online_nodes", 0),
        "total_cores": cluster.get("total_cores", 0),
        "total_ram_gb": cluster.get("total_ram_gb", 0),
        "total_payloads": payload_stats.get("total", 0),
        "total_tools": 7,
        "loot_dirs": loot.get("total_dirs", 0),
        "cluster": cluster,
        "payloads": payload_stats,
        "loot": loot,
        "local": local,
    }
