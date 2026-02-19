#!/usr/bin/env python3
"""
NullSec NightShift — FastAPI Web Interface

Dashboard for managing overnight cluster compute jobs.
View schedule, trigger shifts, browse results.

Port: 9006
"""

from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

import asyncio
import json
import logging
import sys
import os

# Add parent dir so nightshift module is importable
sys.path.insert(0, str(Path(__file__).parent.parent))
from nightshift import (
    BUILTIN_JOBS, RESULTS_DIR, load_nodes, check_online,
    run_shift, get_shift_history, is_nighttime,
    DEFAULT_START_HOUR, DEFAULT_END_HOUR,
    NightJob, JobCategory, asdict,
)

logger = logging.getLogger("nightshift.web")

APP_NAME = "NullSec NightShift"
APP_VERSION = "1.0.0"

TEMPLATE_DIR = Path(__file__).parent.parent / "templates"
STATIC_DIR = Path(__file__).parent.parent / "static"

# Active WebSocket clients for live updates
ws_clients: list[WebSocket] = []

# Track running shift task
shift_task: Optional[asyncio.Task] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("[NightShift] Web dashboard starting on port %s",
                os.environ.get("NULLSEC_NIGHTSHIFT_PORT", "9006"))
    yield
    logger.info("[NightShift] Shutting down")


app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)

if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

templates = Jinja2Templates(directory=str(TEMPLATE_DIR))


# ─── Helpers ──────────────────────────────────────────────────────────────────

async def broadcast(msg: dict):
    dead = []
    text = json.dumps(msg, default=str)
    for ws in ws_clients:
        try:
            await ws.send_text(text)
        except Exception:
            dead.append(ws)
    for ws in dead:
        ws_clients.remove(ws)


async def run_shift_async(force: bool = False, categories=None):
    """Run a shift in a thread pool so it doesn't block the event loop."""
    loop = asyncio.get_event_loop()
    report = await loop.run_in_executor(
        None, lambda: run_shift(force=force, categories=categories)
    )
    return report


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    return templates.TemplateResponse("nightshift.html", {"request": request})


@app.get("/api/status")
async def api_status():
    nodes = load_nodes()
    online_count = 0
    node_list = []
    for n in nodes:
        is_local = n.ip in ("127.0.0.1", "::1", "localhost")
        online = is_local or check_online(n)
        if online:
            online_count += 1
        node_list.append({
            "name": n.name, "ip": n.ip, "os": n.os_type,
            "cores": n.cores, "ram_mb": n.ram_mb, "gpu": n.gpu,
            "role": n.role, "online": online,
        })
    return {
        "nighttime": is_nighttime(),
        "current_hour": __import__("datetime").datetime.now().hour,
        "window_start": DEFAULT_START_HOUR,
        "window_end": DEFAULT_END_HOUR,
        "nodes": node_list,
        "nodes_online": online_count,
        "nodes_total": len(nodes),
    }


@app.get("/api/jobs")
async def api_jobs():
    return [
        {
            "name": j.name, "category": j.category,
            "description": j.description, "priority": j.priority,
            "target_os": j.target_os, "requires_gpu": j.requires_gpu,
            "min_cores": j.min_cores, "min_ram_mb": j.min_ram_mb,
            "run_on": j.run_on, "timeout_sec": j.timeout_sec,
            "enabled": j.enabled,
        }
        for j in BUILTIN_JOBS
    ]


@app.post("/api/shift/run")
async def api_run_shift(request: Request):
    body = await request.json() if request.headers.get("content-type") == "application/json" else {}
    force = body.get("force", True)
    categories = body.get("categories", None)

    await broadcast({"type": "shift_start", "force": force})

    try:
        report = await run_shift_async(force=force, categories=categories)
        await broadcast({"type": "shift_complete", "report": report})
        return report
    except Exception as e:
        err = {"status": "error", "error": str(e)}
        await broadcast({"type": "shift_error", "error": str(e)})
        return JSONResponse(content=err, status_code=500)


@app.get("/api/history")
async def api_history(limit: int = 20):
    return get_shift_history(limit)


@app.get("/api/report/{shift_id}")
async def api_report(shift_id: str):
    report_path = RESULTS_DIR / f"shift_{shift_id}.json"
    if not report_path.exists():
        return JSONResponse(content={"error": "Not found"}, status_code=404)
    return json.loads(report_path.read_text())


@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    ws_clients.append(ws)
    try:
        while True:
            data = await ws.receive_text()
            msg = json.loads(data)
            if msg.get("action") == "run_shift":
                await broadcast({"type": "log", "msg": "Starting shift..."})
                report = await run_shift_async(
                    force=msg.get("force", True),
                    categories=msg.get("categories"),
                )
                await broadcast({"type": "shift_complete", "report": report})
    except WebSocketDisconnect:
        if ws in ws_clients:
            ws_clients.remove(ws)
