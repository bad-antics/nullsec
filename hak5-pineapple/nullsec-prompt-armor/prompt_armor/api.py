"""
Prompt Armor API — hosted scanning service.

Tiered access:
  Free:       100 scans/day, basic analysis
  Pro:        10,000 scans/day, full analysis, webhooks, batch scan
  Enterprise: Unlimited, custom rules, SLA, dedicated support

Start:
    prompt-armor server --port 8080
    # or: uvicorn prompt_armor.api:app --port 8080

Endpoints:
    POST /v1/scan          — Scan a single prompt
    POST /v1/scan/batch    — Scan multiple prompts (Pro+)
    POST /v1/sanitize      — Sanitize a prompt
    GET  /v1/health        — Health check
    GET  /v1/usage         — Check API key usage
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger("prompt_armor.api")

# ── Rate Limiting ────────────────────────────────────────────────

@dataclass
class RateBucket:
    """Sliding window rate limiter per API key."""
    count: int = 0
    window_start: float = 0.0

    def check(self, limit: int, window: int = 86400) -> bool:
        now = time.time()
        if now - self.window_start > window:
            self.count = 0
            self.window_start = now
        if self.count >= limit:
            return False
        self.count += 1
        return True

    @property
    def remaining(self) -> int:
        return max(0, self._limit - self.count) if hasattr(self, '_limit') else 0


# ── Tier Configuration ───────────────────────────────────────────

TIERS = {
    "free": {
        "name": "Free",
        "daily_limit": 100,
        "batch_enabled": False,
        "webhooks_enabled": False,
        "custom_rules": False,
        "layers": ["lexical", "structural", "entropy", "semantic_drift"],
        "price_monthly": 0,
    },
    "pro": {
        "name": "Pro",
        "daily_limit": 10_000,
        "batch_enabled": True,
        "webhooks_enabled": True,
        "custom_rules": False,
        "layers": None,  # all layers
        "price_monthly": 29,
    },
    "enterprise": {
        "name": "Enterprise",
        "daily_limit": -1,  # unlimited
        "batch_enabled": True,
        "webhooks_enabled": True,
        "custom_rules": True,
        "layers": None,  # all layers
        "price_monthly": 149,
    },
}

# ── In-memory key store (replace with DB in production) ──────────

@dataclass
class APIKey:
    key: str
    tier: str
    owner: str
    created: float = field(default_factory=time.time)
    active: bool = True
    webhook_url: Optional[str] = None

# Bootstrap demo keys from environment or use defaults
_KEYS: dict[str, APIKey] = {}
_RATE: dict[str, RateBucket] = defaultdict(RateBucket)


def _init_demo_keys():
    """Create demo keys if none exist."""
    if not _KEYS:
        demo = os.environ.get("PROMPT_ARMOR_DEMO_KEY", "pa_free_demo_key_2024")
        _KEYS[demo] = APIKey(key=demo, tier="free", owner="demo")
        pro = os.environ.get("PROMPT_ARMOR_PRO_KEY", "")
        if pro:
            _KEYS[pro] = APIKey(key=pro, tier="pro", owner="pro-user")
        ent = os.environ.get("PROMPT_ARMOR_ENT_KEY", "")
        if ent:
            _KEYS[ent] = APIKey(key=ent, tier="enterprise", owner="enterprise-user")


def _generate_key(tier: str = "free", owner: str = "user") -> str:
    """Generate an API key."""
    prefix = {"free": "pa_free_", "pro": "pa_pro_", "enterprise": "pa_ent_"}
    raw = f"{tier}:{owner}:{time.time()}:{os.urandom(16).hex()}"
    h = hashlib.sha256(raw.encode()).hexdigest()[:32]
    key = prefix.get(tier, "pa_") + h
    _KEYS[key] = APIKey(key=key, tier=tier, owner=owner)
    return key


# ── FastAPI App Factory ──────────────────────────────────────────

def create_app():
    """Create the FastAPI application."""
    try:
        from fastapi import FastAPI, HTTPException, Request, Depends, Header
        from fastapi.responses import JSONResponse
        from fastapi.middleware.cors import CORSMiddleware
    except ImportError:
        raise ImportError(
            "FastAPI not installed. Run: pip install nullsec-prompt-armor[api]"
        )

    from prompt_armor.armor.engine import (
        analyze,
        sanitize,
    )

    _init_demo_keys()

    app = FastAPI(
        title="Prompt Armor API",
        version="2.0.0",
        description="AI prompt injection detection engine — 8-layer defense",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Auth dependency ──────────────────────────────────────────

    async def get_api_key(x_api_key: str = Header(None, alias="X-API-Key")):
        """Validate API key and enforce rate limits."""
        if not x_api_key:
            # Allow unauthenticated access at free tier
            x_api_key = "pa_free_demo_key_2024"
            if x_api_key not in _KEYS:
                _init_demo_keys()

        if x_api_key not in _KEYS:
            raise HTTPException(status_code=401, detail="Invalid API key")

        key_obj = _KEYS[x_api_key]
        if not key_obj.active:
            raise HTTPException(status_code=403, detail="API key deactivated")

        tier_config = TIERS[key_obj.tier]
        limit = tier_config["daily_limit"]

        if limit > 0:
            bucket = _RATE[x_api_key]
            if not bucket.check(limit):
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded ({limit}/day). Upgrade at https://github.com/bad-antics/nullsec-prompt-armor",
                )

        return key_obj

    # ── Endpoints ────────────────────────────────────────────────

    @app.get("/v1/health")
    async def health():
        return {"status": "ok", "version": "2.0.0", "engine": "8-layer"}

    @app.post("/v1/scan")
    async def scan_prompt(request: Request, api_key: APIKey = Depends(get_api_key)):
        """Scan a single prompt for injection attacks."""
        body = await request.json()
        text = body.get("text", body.get("prompt", ""))

        if not text:
            raise HTTPException(status_code=400, detail="Missing 'text' field")

        if len(text) > 50_000:
            raise HTTPException(status_code=400, detail="Input exceeds 50k character limit")

        tier_config = TIERS[api_key.tier]
        layers = body.get("layers", tier_config["layers"])

        t0 = time.perf_counter()
        verdict = analyze(text, layers=layers)
        elapsed_ms = (time.perf_counter() - t0) * 1000

        result = {
            "risk_score": verdict.score,
            "threat_level": verdict.threat_level,
            "findings": [
                {
                    "layer": f.get("layer", ""),
                    "vector": f["vector"].name if f.get("vector") else None,
                    "description": f.get("description", ""),
                    "confidence": f.get("confidence", 0),
                    "evidence": f.get("evidence", "")[:100],
                }
                for f in verdict.findings
            ],
            "input_hash": verdict.input_hash,
            "scan_time_ms": round(elapsed_ms, 2),
            "tier": api_key.tier,
        }

        # Webhook notification for hostile+ (Pro/Enterprise)
        if (
            tier_config["webhooks_enabled"]
            and api_key.webhook_url
            and verdict.threat_level in ("hostile", "critical")
        ):
            _fire_webhook(api_key.webhook_url, result)

        return result

    @app.post("/v1/scan/batch")
    async def scan_batch(request: Request, api_key: APIKey = Depends(get_api_key)):
        """Scan multiple prompts in batch (Pro+ only)."""
        tier_config = TIERS[api_key.tier]
        if not tier_config["batch_enabled"]:
            raise HTTPException(
                status_code=403,
                detail="Batch scanning requires Pro tier. Upgrade at https://github.com/bad-antics/nullsec-prompt-armor",
            )

        body = await request.json()
        texts = body.get("texts", body.get("prompts", []))

        if not texts or not isinstance(texts, list):
            raise HTTPException(status_code=400, detail="Missing 'texts' array")

        if len(texts) > 100:
            raise HTTPException(status_code=400, detail="Maximum 100 texts per batch")

        results = []
        for text in texts:
            if isinstance(text, str) and text.strip():
                verdict = analyze(text[:50_000])
                results.append({
                    "risk_score": verdict.score,
                    "threat_level": verdict.threat_level,
                    "finding_count": len(verdict.findings),
                    "input_hash": verdict.input_hash,
                })

        return {"results": results, "count": len(results)}

    @app.post("/v1/sanitize")
    async def sanitize_prompt(request: Request, api_key: APIKey = Depends(get_api_key)):
        """Sanitize a prompt — strip injection attempts."""
        body = await request.json()
        text = body.get("text", body.get("prompt", ""))
        aggressive = body.get("aggressive", False)

        if not text:
            raise HTTPException(status_code=400, detail="Missing 'text' field")

        result = sanitize(text, aggressive=aggressive)
        return {"sanitized": result, "original_length": len(text), "sanitized_length": len(result)}

    @app.get("/v1/usage")
    async def usage(api_key: APIKey = Depends(get_api_key)):
        """Check current API key usage."""
        tier_config = TIERS[api_key.tier]
        bucket = _RATE.get(api_key.key, RateBucket())
        limit = tier_config["daily_limit"]
        return {
            "tier": api_key.tier,
            "tier_name": tier_config["name"],
            "daily_limit": limit if limit > 0 else "unlimited",
            "used_today": bucket.count,
            "remaining": max(0, limit - bucket.count) if limit > 0 else "unlimited",
            "features": {
                "batch": tier_config["batch_enabled"],
                "webhooks": tier_config["webhooks_enabled"],
                "custom_rules": tier_config["custom_rules"],
            },
            "price_monthly": tier_config["price_monthly"],
        }

    @app.get("/v1/tiers")
    async def list_tiers():
        """List available pricing tiers."""
        return {"tiers": TIERS}

    return app


def _fire_webhook(url: str, payload: dict):
    """Fire a webhook notification (best-effort, non-blocking)."""
    try:
        import httpx
        httpx.post(url, json=payload, timeout=5.0)
    except Exception:
        logger.warning(f"Webhook delivery failed: {url}")


# Convenience: allow `uvicorn prompt_armor.api:app`
try:
    app = create_app()
except ImportError:
    app = None
