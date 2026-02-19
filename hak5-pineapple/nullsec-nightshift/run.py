#!/usr/bin/env python3
"""Launch NullSec NightShift web dashboard."""
import os
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host=os.environ.get("NULLSEC_BIND", "0.0.0.0"),
        port=int(os.environ.get("NULLSEC_NIGHTSHIFT_PORT", "9006")),
        reload=os.environ.get("NULLSEC_DEBUG", "0") == "1",
    )
