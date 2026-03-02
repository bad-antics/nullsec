#!/usr/bin/env python3
"""NullSec Scanner — Network Reconnaissance Tool"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=9002, reload=True)
