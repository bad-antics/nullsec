"""NullSec WebTools — Payload Manager"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates
from pathlib import Path
from ..services.payload_service import (
    get_all_payloads, get_payload, get_payload_stats,
    search_payloads, validate_payload,
)

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))


@router.get("/")
async def payloads_page(request: Request):
    return templates.TemplateResponse("payloads.html", {
        "request": request,
        "page": "payloads",
    })


@router.get("/api/list")
async def api_list(q: str = "", category: str = ""):
    """List/search payloads."""
    if q:
        payloads = search_payloads(q)
    else:
        payloads = get_all_payloads()

    if category:
        payloads = [p for p in payloads if p["category"] == category]

    return {"payloads": payloads, "total": len(payloads)}


@router.get("/api/stats")
async def api_stats():
    return get_payload_stats()


@router.get("/api/{name}")
async def api_detail(name: str):
    payload = get_payload(name)
    if not payload:
        return {"error": "Payload not found"}
    return payload


@router.get("/api/{name}/validate")
async def api_validate(name: str):
    errors = validate_payload(name)
    return {"name": name, "valid": len(errors) == 0, "errors": errors}


@router.get("/view/{name}")
async def payload_view(request: Request, name: str):
    payload = get_payload(name)
    return templates.TemplateResponse("payload_detail.html", {
        "request": request,
        "page": "payloads",
        "payload": payload,
    })
