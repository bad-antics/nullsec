"""NullSec WebTools — Main FastAPI Application"""

from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pathlib import Path
from . import config

app = FastAPI(title=config.APP_NAME, version=config.APP_VERSION)

# Static files + templates
STATIC_DIR = Path(__file__).parent / "static"
TEMPLATE_DIR = Path(__file__).parent / "templates"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "css").mkdir(exist_ok=True)
(STATIC_DIR / "js").mkdir(exist_ok=True)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))

# Template globals
templates.env.globals["APP_NAME"] = config.APP_NAME
templates.env.globals["APP_VERSION"] = config.APP_VERSION

# ─── Import routers ─────────────────────────────────────────────────────────
from .routers import dashboard, cluster, payloads, network, loot, terminal

app.include_router(dashboard.router)
app.include_router(cluster.router, prefix="/cluster", tags=["cluster"])
app.include_router(payloads.router, prefix="/payloads", tags=["payloads"])
app.include_router(network.router, prefix="/network", tags=["network"])
app.include_router(loot.router, prefix="/loot", tags=["loot"])
app.include_router(terminal.router, prefix="/terminal", tags=["terminal"])
