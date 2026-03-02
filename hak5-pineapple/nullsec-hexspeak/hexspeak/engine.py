"""
Hexspeak encoding/decoding engine.
"""

import random
import re
from typing import List, Optional, Tuple

from .dictionary import HEXWORDS, LETTER_TO_HEX, HEX_TO_LETTER, CATEGORIES


def encode(text: str) -> str:
    """
    Encode text into hexspeak.
    Replaces letters with hex equivalents where possible.
    Non-encodable characters are dropped.

    Returns: hex string (uppercase, no 0x prefix)
    """
    result = []
    text = text.upper().strip()

    for char in text:
        if char in LETTER_TO_HEX:
            result.append(LETTER_TO_HEX[char])
        elif char in "0123456789":
            result.append(char)
        elif char == " ":
            result.append(" ")
        # Skip non-encodable characters

    return " ".join("".join(result).split())


def decode(hex_str: str) -> str:
    """
    Decode a hex string into readable text using hex-to-letter substitution.

    Input: hex string (with or without 0x prefix)
    Returns: readable English approximation
    """
    # Strip 0x prefix
    hex_str = hex_str.upper().strip()
    if hex_str.startswith("0X"):
        hex_str = hex_str[2:]

    # First check if the entire string is a known word
    if hex_str in HEXWORDS:
        return HEXWORDS[hex_str]

    # Try to split into known words
    words = _split_known_words(hex_str)
    if words:
        return " ".join(words)

    # Fall back to character-by-character substitution
    result = []
    for char in hex_str:
        if char in HEX_TO_LETTER:
            result.append(HEX_TO_LETTER[char])
        elif char == " ":
            result.append(" ")
        else:
            result.append(char)

    return "".join(result).lower()


def _split_known_words(hex_str: str) -> Optional[List[str]]:
    """Try to split a hex string into known dictionary words."""
    # Sort words by length (longest first) for greedy matching
    sorted_words = sorted(HEXWORDS.keys(), key=len, reverse=True)

    remaining = hex_str
    found = []

    while remaining:
        matched = False
        for word in sorted_words:
            if remaining.startswith(word):
                found.append(HEXWORDS[word])
                remaining = remaining[len(word):]
                matched = True
                break

        if not matched:
            return None  # Can't fully decompose

    return found if found else None


def search(query: str, category: Optional[str] = None) -> List[dict]:
    """
    Search hexwords by meaning, hex value, or category.

    Returns list of {hex, meaning, category} dicts.
    """
    query = query.lower().strip()
    results = []

    # Category search
    if category and category in CATEGORIES:
        for hex_val in CATEGORIES[category]:
            if hex_val in HEXWORDS:
                results.append({
                    "hex": f"0x{hex_val}",
                    "meaning": HEXWORDS[hex_val],
                    "category": category,
                })
        return results

    # Free-text search
    for hex_val, meaning in HEXWORDS.items():
        if query in meaning.lower() or query in hex_val.lower():
            # Find category
            cat = "uncategorized"
            for c, words in CATEGORIES.items():
                if hex_val in words:
                    cat = c
                    break
            results.append({
                "hex": f"0x{hex_val}",
                "meaning": meaning,
                "category": cat,
            })

    return sorted(results, key=lambda r: len(r["hex"]))


def random_words(count: int = 5, min_len: int = 4,
                 max_len: int = 12) -> List[dict]:
    """Generate random hex words from the dictionary."""
    candidates = [
        {"hex": f"0x{k}", "meaning": v}
        for k, v in HEXWORDS.items()
        if min_len <= len(k) <= max_len
    ]

    if not candidates:
        return []

    return random.sample(candidates, min(count, len(candidates)))


def is_hexspeak(hex_str: str) -> dict:
    """Check if a hex string is valid hexspeak."""
    clean = hex_str.upper().strip()
    if clean.startswith("0X"):
        clean = clean[2:]

    # Check if all characters are valid hex
    valid_hex = all(c in "0123456789ABCDEF" for c in clean)

    # Check if it's a known word
    known = clean in HEXWORDS
    meaning = HEXWORDS.get(clean, None)

    # Try to decode
    decoded = decode(clean) if valid_hex else None

    # Check if decoded version contains vowels (readable)
    readable = False
    if decoded:
        vowels = set("aeiou")
        readable = bool(vowels & set(decoded.lower()))

    return {
        "input": hex_str,
        "valid_hex": valid_hex,
        "known_word": known,
        "meaning": meaning,
        "decoded": decoded,
        "readable": readable,
        "hex_value": int(clean, 16) if valid_hex and clean else None,
    }


def scan_bytes(data: bytes, min_word_len: int = 4) -> List[dict]:
    """
    Scan binary data for known hexspeak patterns.
    Returns list of findings with offset, hex, and meaning.
    """
    findings = []
    hex_data = data.hex().upper()

    # Search for known words in the hex dump
    for hex_word, meaning in sorted(HEXWORDS.items(), key=lambda x: len(x[0]),
                                     reverse=True):
        if len(hex_word) < min_word_len:
            continue

        start = 0
        while True:
            idx = hex_data.find(hex_word, start)
            if idx == -1:
                break

            byte_offset = idx // 2
            findings.append({
                "offset": byte_offset,
                "hex_offset": f"0x{byte_offset:08X}",
                "hex": f"0x{hex_word}",
                "meaning": meaning,
                "length": len(hex_word) // 2,
            })
            start = idx + len(hex_word)

    return sorted(findings, key=lambda f: f["offset"])


def generate_poem(lines: int = 4) -> List[str]:
    """Generate a hex-word poem."""
    # Select words that work well in sequence
    word_pool = list(HEXWORDS.items())
    random.shuffle(word_pool)

    poem_lines = []
    for i in range(lines):
        # Pick 2-4 words per line
        word_count = random.randint(2, 4)
        line_words = []
        line_hex = []

        for _ in range(word_count):
            if word_pool:
                hex_val, meaning = word_pool.pop()
                line_words.append(meaning)
                line_hex.append(f"0x{hex_val}")

        poem_lines.append({
            "text": " ".join(line_words),
            "hex": " ".join(line_hex),
        })

    return poem_lines
