"""NullSec WebTools — Cluster Manager"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates
from pathlib import Path
from ..services import get_all_node_stats, get_cluster_summary, run_on_node, load_nodes

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))


@router.get("/")
async def cluster_page(request: Request):
    return templates.TemplateResponse("cluster.html", {
        "request": request,
        "page": "cluster",
    })


@router.get("/api/nodes")
async def api_nodes():
    """Get all nodes with live stats."""
    nodes = get_all_node_stats()
    return [n.__dict__ for n in nodes]


@router.get("/api/summary")
async def api_summary():
    """Cluster summary stats."""
    return get_cluster_summary()


@router.post("/api/exec")
async def api_exec(request: Request):
    """Execute command on a node."""
    body = await request.json()
    node_name = body.get("node", "")
    command = body.get("command", "")

    if not node_name or not command:
        return {"error": "node and command required"}

    return run_on_node(node_name, command)


@router.post("/api/exec-all")
async def api_exec_all(request: Request):
    """Execute command on all online nodes."""
    body = await request.json()
    command = body.get("command", "")
    if not command:
        return {"error": "command required"}

    nodes = load_nodes()
    results = []
    for n in nodes:
        result = run_on_node(n.name, command)
        results.append(result)

    return {"results": results}
