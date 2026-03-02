"""
nullsec-hexspeak — Hexadecimal Word Encoder
Encode messages using valid hex characters that spell English words.
"""

__version__ = "1.0.0"
__author__ = "bad-antics"

from .engine import encode, decode, search, random_words, scan_bytes, is_hexspeak
from .dictionary import HEXWORDS

__all__ = ["encode", "decode", "search", "random_words",
           "scan_bytes", "is_hexspeak", "HEXWORDS"]
