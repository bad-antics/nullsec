"""
nullsec-miasma — File Entropy Analyzer
Detect hidden data, weak crypto, and packed malware through entropy analysis.
"""

__version__ = "1.0.0"
__author__ = "bad-antics"

from .analyzer import analyze_file, analyze_bytes, entropy_map, classify_file

__all__ = ["analyze_file", "analyze_bytes", "entropy_map", "classify_file"]
