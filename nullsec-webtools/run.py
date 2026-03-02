#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════════════
 NullSec WebTools — Launch Script
 Start the web application network on http://0.0.0.0:9000
═══════════════════════════════════════════════════════════════════════════════
"""
import uvicorn
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=9000,
        reload=True,
        log_level="info",
    )
