"""
nullsec-temporal — Filesystem Forensic Timestamp Analyzer
Detect timestomping, time anomalies, and anti-forensic manipulation.
"""

__version__ = "1.0.0"
__author__ = "bad-antics"

from .scanner import scan_path, check_file, build_timeline

__all__ = ["scan_path", "check_file", "build_timeline"]
