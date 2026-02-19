"""NullSec WebTools — Loot Viewer"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates
from pathlib import Path
from ..services.loot_service import (
    get_loot_dirs, get_loot_files, read_loot_file,
    search_loot, get_loot_stats,
)

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))


@router.get("/")
async def loot_page(request: Request):
    return templates.TemplateResponse("loot.html", {
        "request": request,
        "page": "loot",
    })


@router.get("/api/dirs")
async def api_dirs():
    return {"dirs": get_loot_dirs()}


@router.get("/api/stats")
async def api_loot_stats():
    return get_loot_stats()


@router.get("/api/files/{payload_name}")
async def api_files(payload_name: str):
    return {"files": get_loot_files(payload_name)}


@router.get("/api/read/{payload_name}/{filename:path}")
async def api_read(payload_name: str, filename: str):
    result = read_loot_file(payload_name, filename)
    if not result:
        return {"error": "File not found"}
    return result


@router.get("/api/search")
async def api_search(q: str = ""):
    if not q:
        return {"results": []}
    return {"results": search_loot(q)}
