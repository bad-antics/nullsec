"""
Doppelgänger Engine — Files with identity crises.
Detects files masquerading as other file types, extension mismatches,
polyglot files, and double extensions.
"""

import os
import hashlib
from pathlib import Path
from typing import List, Dict, Optional

# Magic byte signatures for file type identification
MAGIC_SIGS = {
    b"\xff\xd8\xff": "JPEG",
    b"\x89PNG\r\n\x1a\n": "PNG",
    b"GIF87a": "GIF", b"GIF89a": "GIF",
    b"%PDF": "PDF",
    b"PK\x03\x04": "ZIP/DOCX/JAR",
    b"\x7fELF": "ELF",
    b"MZ": "PE/EXE",
    b"\x1f\x8b": "GZIP",
    b"BZh": "BZIP2",
    b"Rar!": "RAR",
    b"7z\xbc\xaf\x27\x1c": "7ZIP",
    b"SQLite format 3": "SQLITE",
    b"<!DOCTYPE html": "HTML", b"<html": "HTML",
    b"<?xml": "XML",
    b"#!/bin/bash": "BASH", b"#!/bin/sh": "SHELL",
    b"#!/usr/bin/env python": "PYTHON", b"#!/usr/bin/python": "PYTHON",
    b"\xca\xfe\xba\xbe": "JAVA_CLASS/MACH-O",
    b"\xfe\xed\xfa\xce": "MACH-O_32",
    b"\xfe\xed\xfa\xcf": "MACH-O_64",
    b"OggS": "OGG",
    b"fLaC": "FLAC",
    b"RIFF": "RIFF/WAV/AVI",
    b"\x00\x00\x01\x00": "ICO",
    b"\x00\x00\x00\x1c": "MP4",
    b"-----BEGIN": "PEM",
}

# Expected extensions for each type
TYPE_EXTENSIONS = {
    "JPEG": [".jpg", ".jpeg", ".jfif"],
    "PNG": [".png"],
    "GIF": [".gif"],
    "PDF": [".pdf"],
    "ZIP/DOCX/JAR": [".zip", ".docx", ".xlsx", ".jar", ".apk", ".odt"],
    "ELF": ["", ".so", ".elf", ".bin"],
    "PE/EXE": [".exe", ".dll", ".sys"],
    "GZIP": [".gz", ".tgz"],
    "SQLITE": [".db", ".sqlite", ".sqlite3"],
    "HTML": [".html", ".htm"],
    "PYTHON": [".py"],
    "BASH": [".sh", ".bash"],
    "SHELL": [".sh"],
}


def identify_true_face(filepath: str) -> Dict:
    """Identify the TRUE identity of a file by its magic bytes, ignoring extension."""
    result = {
        "filepath": filepath,
        "claimed_ext": Path(filepath).suffix.lower(),
        "true_type": "UNKNOWN",
        "has_identity_crisis": False,
        "anomalies": [],
    }

    try:
        with open(filepath, 'rb') as f:
            header = f.read(64)
    except (PermissionError, IsADirectoryError):
        result["anomalies"].append({"type": "INACCESSIBLE", "emoji": "🚫"})
        return result

    # Match against magic signatures
    for sig, file_type in MAGIC_SIGS.items():
        if header[:len(sig)] == sig:
            result["true_type"] = file_type
            break

    # Check for extension mismatch
    if result["true_type"] != "UNKNOWN":
        expected = TYPE_EXTENSIONS.get(result["true_type"], [])
        if expected and result["claimed_ext"] not in expected:
            result["has_identity_crisis"] = True
            result["anomalies"].append({
                "type": "DOPPELGÄNGER",
                "emoji": "👥",
                "detail": f"Claims to be '{result['claimed_ext']}' but is actually {result['true_type']}",
                "severity": "HIGH",
            })

    # Check for double extensions (evil.pdf.exe)
    name = Path(filepath).name
    dots = name.count('.')
    if dots > 1:
        result["anomalies"].append({
            "type": "DOUBLE_FACE",
            "emoji": "🎭",
            "detail": f"Multiple extensions detected: '{name}' ({dots} faces)",
            "severity": "MEDIUM",
        })

    # Check for null bytes in filename
    if '\x00' in str(filepath) or '\u200b' in str(filepath):
        result["anomalies"].append({
            "type": "INVISIBLE_FACE",
            "emoji": "👤",
            "detail": "Null/zero-width characters in filename",
            "severity": "CRITICAL",
        })

    # Check for right-to-left override
    if '\u202e' in str(filepath):
        result["anomalies"].append({
            "type": "MIRROR_FACE",
            "emoji": "🪞",
            "detail": "RTL override in filename — text direction attack",
            "severity": "CRITICAL",
        })

    # Check if executable bit set on non-executable type
    if os.access(filepath, os.X_OK):
        if result["true_type"] in ["JPEG", "PNG", "GIF", "PDF"]:
            result["anomalies"].append({
                "type": "POSSESSED",
                "emoji": "😈",
                "detail": f"{result['true_type']} file marked as executable — possession detected",
                "severity": "HIGH",
            })

    return result


def scan_directory(dirpath: str, recursive: bool = True) -> List[Dict]:
    """Scan a directory for files with identity crises."""
    results = []
    path = Path(dirpath)

    pattern = "**/*" if recursive else "*"
    for fpath in path.glob(pattern):
        if fpath.is_file():
            result = identify_true_face(str(fpath))
            if result["anomalies"]:
                results.append(result)

    return results


def find_twins(dirpath: str) -> List[Dict]:
    """Find files with identical content but different names (true doppelgängers)."""
    hashes = {}
    path = Path(dirpath)

    for fpath in path.rglob("*"):
        if fpath.is_file():
            try:
                with open(fpath, 'rb') as f:
                    h = hashlib.sha256(f.read(65536)).hexdigest()
                if h not in hashes:
                    hashes[h] = []
                hashes[h].append(str(fpath))
            except (PermissionError, OSError):
                pass

    twins = []
    for h, files in hashes.items():
        if len(files) > 1:
            twins.append({
                "hash": h[:16],
                "count": len(files),
                "files": files,
                "emoji": "👯",
            })

    return twins


def polyglot_check(filepath: str) -> Dict:
    """Check if a file is a polyglot — valid as multiple file types simultaneously."""
    result = {
        "filepath": filepath,
        "faces": [],
    }

    try:
        with open(filepath, 'rb') as f:
            data = f.read(1024)
    except (PermissionError, IsADirectoryError):
        return result

    for sig, file_type in MAGIC_SIGS.items():
        if sig in data:
            offset = data.find(sig)
            result["faces"].append({
                "type": file_type,
                "offset": f"0x{offset:04x}",
                "at_start": offset == 0,
            })

    result["is_polyglot"] = len(result["faces"]) > 1
    if result["is_polyglot"]:
        result["verdict"] = f"🎭 This file has {len(result['faces'])} faces — a true shapeshifter!"
    else:
        result["verdict"] = "👤 Single identity. For now."

    return result
