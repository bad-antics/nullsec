"""
NullSec Race Audit — Web API & Dashboard

Exposes the race condition audit engine as a FastAPI service:
  - POST /api/audit       — Run full audit against a target
  - POST /api/probe       — Run a single probe
  - GET  /api/probes      — List available probes
  - GET  /api/history     — Past audit results
  - GET  /                — Interactive dashboard
"""

import asyncio
import json
import time
import logging
from pathlib import Path
from dataclasses import asdict
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

from racer import (
    run_audit, probe_session_confusion, probe_toctou_prompt,
    probe_context_collision, probe_rate_race_bypass,
    probe_state_corruption, probe_response_hijack,
    RaceType, Severity,
)

logger = logging.getLogger("race-audit-api")

APP_NAME = "NullSec Race Audit"
APP_VERSION = "1.0.0"

STATIC_DIR = Path(__file__).parent / "static"
TEMPLATE_DIR = Path(__file__).parent / "templates"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "css").mkdir(exist_ok=True)

RESULTS_DIR = Path.home() / ".nullsec" / "race-audits"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

_audit_history = []
_ws_clients = []

PROBE_INFO = {
    "session_confusion": {
        "name": "Session Confusion",
        "description": "Detects cross-session data leaks via concurrent canary-tagged requests",
        "risk": "Data from one user's session leaks into another user's response",
        "severity_range": "HIGH — CRITICAL",
    },
    "toctou_prompt": {
        "name": "TOCTOU Prompt Attack",
        "description": "Exploits time gap between prompt validation and model inference",
        "risk": "Hostile system prompt replaces validated prompt during race window",
        "severity_range": "MEDIUM — HIGH",
    },
    "context_collision": {
        "name": "Context Collision",
        "description": "Sends parallel conversations with unique topics to detect context bleed",
        "risk": "Parallel user conversations contaminate each other",
        "severity_range": "MEDIUM — HIGH",
    },
    "rate_race_bypass": {
        "name": "Rate-Race Bypass",
        "description": "Burst-fires concurrent requests to test rate limiter atomicity",
        "risk": "Rate limiter fails under concurrent load — enables abuse/DoS",
        "severity_range": "LOW — MEDIUM",
    },
    "state_corruption": {
        "name": "State Corruption",
        "description": "Fires concurrent writes to shared state to detect corruption",
        "risk": "Shared memory/config corrupted by non-atomic concurrent writes",
        "severity_range": "MEDIUM",
    },
    "response_hijack": {
        "name": "Response Hijack",
        "description": "Races client abort against server response to capture partial data",
        "risk": "Partial responses leak data that should have been filtered",
        "severity_range": "LOW — MEDIUM",
    },
}


@asynccontextmanager
async def lifespan(application: FastAPI):
    logger.info("Race Audit engine online — %d probes available", len(PROBE_INFO))
    yield


app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))
templates.env.globals["APP_NAME"] = APP_NAME
templates.env.globals["APP_VERSION"] = APP_VERSION


async def broadcast(data: dict):
    dead = []
    for ws in _ws_clients:
        try:
            await ws.send_json(data)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _ws_clients.remove(ws)


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("racer.html", {
        "request": request,
        "page": "racer",
        "probes": PROBE_INFO,
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


@app.post("/api/audit")
async def api_audit(request: Request):
    """Run a full race condition audit."""
    body = await request.json()
    target = body.get("target", "").strip()
    probes = body.get("probes", None)
    config = body.get("config", {})

    if not target:
        return {"error": "target URL required"}

    await broadcast({"type": "audit_start", "target": target, "probes": probes or list(PROBE_INFO.keys())})

    report = await run_audit(target, probes=probes, config=config)
    result = asdict(report)

    # Save
    _audit_history.append(result)
    if len(_audit_history) > 100:
        _audit_history.pop(0)

    try:
        ts = time.strftime("%Y%m%d_%H%M%S")
        (RESULTS_DIR / f"audit_{ts}.json").write_text(json.dumps(result, indent=2, default=str))
    except Exception:
        pass

    await broadcast({"type": "audit_complete", "result": result})
    return result


@app.post("/api/probe")
async def api_probe(request: Request):
    """Run a single probe."""
    body = await request.json()
    target = body.get("target", "").strip()
    probe_name = body.get("probe", "").strip()

    if not target or not probe_name:
        return {"error": "target and probe required"}

    probe_map = {
        "session_confusion": probe_session_confusion,
        "toctou_prompt": probe_toctou_prompt,
        "context_collision": probe_context_collision,
        "rate_race_bypass": probe_rate_race_bypass,
        "state_corruption": probe_state_corruption,
        "response_hijack": probe_response_hijack,
    }

    fn = probe_map.get(probe_name)
    if not fn:
        return {"error": f"Unknown probe: {probe_name}"}

    await broadcast({"type": "probe_start", "probe": probe_name, "target": target})
    finding = await fn(target)
    result = asdict(finding)
    await broadcast({"type": "probe_complete", "result": result})
    return result


@app.get("/api/probes")
async def api_probes():
    """List available probes."""
    return {"probes": PROBE_INFO}


@app.get("/api/history")
async def api_history():
    """Get past audit results."""
    return {"audits": _audit_history[-50:]}
