"""
NullSec Prompt Armor — Web API & Interactive Dashboard

Exposes the Prompt Armor engine as a FastAPI service with:
  - POST /api/scan          — Analyze text for prompt injection
  - POST /api/sanitize      — Sanitize text and return cleaned version
  - POST /api/canary/create — Generate a canary trap token
  - POST /api/canary/verify — Check if canary was leaked in AI output
  - POST /api/batch         — Analyze multiple inputs at once
  - GET  /api/signatures    — List detection pattern categories
  - GET  /                  — Interactive web dashboard
"""

import json
import time
import logging
from pathlib import Path
from contextlib import asynccontextmanager
from dataclasses import asdict

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

from armor import (
    analyze, sanitize, CanarySystem, ArmorVerdict,
    ROLE_HIJACK_PATTERNS, DELIMITER_ESCAPE_PATTERNS,
    EXFILTRATION_PATTERNS, JAILBREAK_PATTERNS, PAYLOAD_SMUGGLE_PATTERNS,
)

logger = logging.getLogger("prompt-armor-api")

APP_NAME = "NullSec Prompt Armor"
APP_VERSION = "1.0.0"

STATIC_DIR = Path(__file__).parent / "static"
TEMPLATE_DIR = Path(__file__).parent / "templates"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "css").mkdir(exist_ok=True)

HISTORY_DIR = Path.home() / ".nullsec" / "prompt-armor"
HISTORY_DIR.mkdir(parents=True, exist_ok=True)

# Scan history (in-memory, recent)
_scan_history = []
_canary_store = {}
canary_system = CanarySystem()


@asynccontextmanager
async def lifespan(application: FastAPI):
    logger.info("Prompt Armor engine online — %d signature patterns loaded",
                sum(len(p) for p in [ROLE_HIJACK_PATTERNS, DELIMITER_ESCAPE_PATTERNS,
                                      EXFILTRATION_PATTERNS, JAILBREAK_PATTERNS,
                                      PAYLOAD_SMUGGLE_PATTERNS]))
    yield


app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))
templates.env.globals["APP_NAME"] = APP_NAME
templates.env.globals["APP_VERSION"] = APP_VERSION

# ─── WebSocket clients ──────────────────────────────────────────────────────

_ws_clients = []


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
    return templates.TemplateResponse("armor.html", {
        "request": request,
        "page": "armor",
        "scan_count": len(_scan_history),
    })


@app.websocket("/ws")
async def ws_endpoint(websocket: WebSocket):
    await websocket.accept()
    _ws_clients.append(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Live scan from WebSocket
            try:
                payload = json.loads(data)
                text = payload.get("text", "")
                if text:
                    verdict = analyze(text, aggressive_sanitize=payload.get("aggressive", False))
                    await websocket.send_json({"type": "verdict", "result": asdict(verdict)})
            except json.JSONDecodeError:
                verdict = analyze(data)
                await websocket.send_json({"type": "verdict", "result": asdict(verdict)})
    except WebSocketDisconnect:
        if websocket in _ws_clients:
            _ws_clients.remove(websocket)


@app.post("/api/scan")
async def api_scan(request: Request):
    """Analyze text for prompt injection attacks."""
    body = await request.json()
    text = body.get("text", "")
    layers = body.get("layers", None)
    aggressive = body.get("aggressive", False)

    if not text:
        return {"error": "text field required"}

    verdict = analyze(text, aggressive_sanitize=aggressive, layers=layers)
    result = asdict(verdict)

    # Record
    _scan_history.append({
        "timestamp": time.time(),
        "input_length": len(text),
        "threat_level": verdict.threat_level,
        "score": verdict.score,
        "finding_count": len(verdict.findings),
    })
    if len(_scan_history) > 500:
        _scan_history.pop(0)

    await broadcast({"type": "scan_result", "result": result})
    return result


@app.post("/api/sanitize")
async def api_sanitize(request: Request):
    """Sanitize text, removing injection payloads."""
    body = await request.json()
    text = body.get("text", "")
    aggressive = body.get("aggressive", True)

    if not text:
        return {"error": "text field required"}

    cleaned = sanitize(text, aggressive=aggressive)
    return {
        "original_length": len(text),
        "sanitized_length": len(cleaned),
        "sanitized": cleaned,
        "chars_removed": len(text) - len(cleaned),
    }


@app.post("/api/canary/create")
async def api_canary_create(request: Request):
    """Generate a canary token to embed in a system prompt."""
    body = await request.json()
    session_id = body.get("session_id", "default")
    system_prompt = body.get("system_prompt", "")

    canary = canary_system.generate_canary(session_id)
    _canary_store[session_id] = canary

    result = {"session_id": session_id, "canary": canary}
    if system_prompt:
        result["armored_prompt"] = canary_system.inject_canary(system_prompt, canary)

    return result


@app.post("/api/canary/verify")
async def api_canary_verify(request: Request):
    """Check if a canary was leaked in AI output."""
    body = await request.json()
    session_id = body.get("session_id", "default")
    ai_output = body.get("output", "")

    canary = _canary_store.get(session_id)
    if not canary:
        return {"error": f"No canary found for session '{session_id}'"}

    findings = canary_system.verify_output(ai_output, canary)
    return {
        "session_id": session_id,
        "canary_intact": len(findings) == 0,
        "findings": [asdict(f) for f in findings],
    }


@app.post("/api/batch")
async def api_batch(request: Request):
    """Analyze multiple inputs at once."""
    body = await request.json()
    inputs = body.get("inputs", [])

    if not inputs:
        return {"error": "inputs array required"}

    results = []
    for i, text in enumerate(inputs[:100]):  # Cap at 100
        verdict = analyze(str(text))
        results.append({
            "index": i,
            "threat_level": verdict.threat_level,
            "score": verdict.score,
            "finding_count": len(verdict.findings),
        })

    summary = {
        "total": len(results),
        "clean": sum(1 for r in results if r["threat_level"] == "clean"),
        "suspicious": sum(1 for r in results if r["threat_level"] == "suspicious"),
        "hostile": sum(1 for r in results if r["threat_level"] == "hostile"),
        "critical": sum(1 for r in results if r["threat_level"] == "critical"),
    }

    return {"summary": summary, "results": results}


@app.get("/api/signatures")
async def api_signatures():
    """List available detection signature categories."""
    return {
        "categories": {
            "role_hijack": len(ROLE_HIJACK_PATTERNS),
            "delimiter_escape": len(DELIMITER_ESCAPE_PATTERNS),
            "data_exfiltration": len(EXFILTRATION_PATTERNS),
            "jailbreak": len(JAILBREAK_PATTERNS),
            "payload_smuggle": len(PAYLOAD_SMUGGLE_PATTERNS),
        },
        "total_patterns": sum(len(p) for p in [
            ROLE_HIJACK_PATTERNS, DELIMITER_ESCAPE_PATTERNS,
            EXFILTRATION_PATTERNS, JAILBREAK_PATTERNS, PAYLOAD_SMUGGLE_PATTERNS,
        ]),
        "layers": ["lexical", "structural", "entropy", "semantic", "canary"],
    }


@app.get("/api/stats")
async def api_stats():
    """Dashboard statistics."""
    recent = _scan_history[-100:]
    return {
        "total_scans": len(_scan_history),
        "recent_100": {
            "clean": sum(1 for s in recent if s["threat_level"] == "clean"),
            "suspicious": sum(1 for s in recent if s["threat_level"] == "suspicious"),
            "hostile": sum(1 for s in recent if s["threat_level"] == "hostile"),
            "critical": sum(1 for s in recent if s["threat_level"] == "critical"),
        },
        "avg_score": round(sum(s["score"] for s in recent) / max(len(recent), 1), 1),
    }
