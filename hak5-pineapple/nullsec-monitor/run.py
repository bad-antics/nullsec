#!/usr/bin/env python3
"""NullSec Monitor — Real-time Cluster Monitoring"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=9001, reload=True)
