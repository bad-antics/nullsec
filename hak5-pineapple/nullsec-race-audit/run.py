#!/usr/bin/env python3
"""NullSec Race Audit — Launch Script"""
import uvicorn
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host=os.environ.get("NULLSEC_BIND", "0.0.0.0"),
        port=int(os.environ.get("NULLSEC_RACER_PORT", "9005")),
        reload=os.environ.get("NULLSEC_DEBUG", "0") == "1",
        log_level="info",
    )
