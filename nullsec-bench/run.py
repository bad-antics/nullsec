#!/usr/bin/env python3
"""NullSec Bench — Cluster Benchmarking Dashboard"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=9003, reload=True)
