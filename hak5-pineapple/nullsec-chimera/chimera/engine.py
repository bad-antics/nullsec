"""
Chimera Engine — Binary polyglot structure validator.
Unlike doppelganger's magic-byte matching, chimera validates actual
format STRUCTURE to confirm a file genuinely parses as multiple types,
and identifies the polyglot construction technique used.
"""

import os
import struct
import zipfile
import gzip
from typing import List, Dict, Optional
from pathlib import Path


# Format validators — each returns True if the file is structurally valid
def _validate_pdf(data: bytes) -> Dict:
    """Validate PDF structure (not just %PDF magic)."""
    if not data.startswith(b'%PDF'):
        # Check for PDF anywhere in first 1KB (embedded polyglot technique)
        idx = data[:1024].find(b'%PDF')
        if idx == -1:
            return {"valid": False}
        return {
            "valid": True,
            "offset": idx,
            "technique": "EMBEDDED" if idx > 0 else "STANDARD",
            "has_eof": b'%%EOF' in data[-1024:],
            "has_xref": b'xref' in data or b'/XRef' in data,
        }
    return {
        "valid": True,
        "offset": 0,
        "technique": "STANDARD",
        "has_eof": b'%%EOF' in data[-1024:],
        "has_xref": b'xref' in data or b'/XRef' in data,
        "version": data[5:8].decode('ascii', errors='replace').strip(),
    }


def _validate_zip(data: bytes) -> Dict:
    """Validate ZIP structure (local file header + central directory)."""
    # ZIP can start with PK\x03\x04 or have it embedded
    idx = data.find(b'PK\x03\x04')
    if idx == -1:
        # Check for end-of-central-directory (ZIP appended to another format)
        eocd = data.rfind(b'PK\x05\x06')
        if eocd == -1:
            return {"valid": False}
        return {
            "valid": True,
            "offset": eocd,
            "technique": "APPENDED_EOCD_ONLY",
        }

    # Count local file headers
    local_headers = 0
    pos = idx
    while pos < len(data):
        next_pk = data.find(b'PK\x03\x04', pos + 1)
        if next_pk == -1:
            break
        local_headers += 1
        pos = next_pk
    local_headers += 1

    has_eocd = b'PK\x05\x06' in data
    has_central = b'PK\x01\x02' in data

    technique = "STANDARD"
    if idx > 0:
        technique = "APPENDED" if idx > 100 else "OFFSET"

    return {
        "valid": True,
        "offset": idx,
        "local_file_headers": local_headers,
        "has_central_directory": has_central,
        "has_eocd": has_eocd,
        "technique": technique,
    }


def _validate_png(data: bytes) -> Dict:
    """Validate PNG structure (signature + IHDR + IEND)."""
    PNG_SIG = b'\x89PNG\r\n\x1a\n'
    idx = data.find(PNG_SIG)
    if idx == -1:
        return {"valid": False}

    has_ihdr = b'IHDR' in data[idx:idx+25]
    has_iend = b'IEND' in data
    # Check for data after IEND (cavity for polyglot payload)
    iend_pos = data.find(b'IEND')
    cavity_size = 0
    if iend_pos != -1:
        cavity_size = len(data) - iend_pos - 12  # IEND chunk is 12 bytes

    return {
        "valid": True,
        "offset": idx,
        "has_ihdr": has_ihdr,
        "has_iend": has_iend,
        "cavity_after_iend": cavity_size if cavity_size > 0 else 0,
        "technique": "STANDARD" if idx == 0 else "EMBEDDED",
    }


def _validate_jpeg(data: bytes) -> Dict:
    """Validate JPEG structure (SOI + markers)."""
    SOI = b'\xff\xd8'
    idx = data.find(SOI)
    if idx == -1:
        return {"valid": False}

    # Check for JFIF or EXIF marker
    has_jfif = b'JFIF' in data[idx:idx+20]
    has_exif = b'Exif' in data[idx:idx+20]
    has_eoi = b'\xff\xd9' in data

    eoi_pos = data.rfind(b'\xff\xd9')
    cavity_size = len(data) - eoi_pos - 2 if eoi_pos != -1 else 0

    return {
        "valid": True,
        "offset": idx,
        "has_jfif": has_jfif,
        "has_exif": has_exif,
        "has_eoi": has_eoi,
        "cavity_after_eoi": cavity_size if cavity_size > 0 else 0,
        "technique": "STANDARD" if idx == 0 else "EMBEDDED",
    }


def _validate_elf(data: bytes) -> Dict:
    """Validate ELF structure."""
    ELF_MAGIC = b'\x7fELF'
    idx = data.find(ELF_MAGIC)
    if idx == -1:
        return {"valid": False}

    if len(data) < idx + 20:
        return {"valid": False}

    ei_class = data[idx + 4]  # 1=32bit, 2=64bit
    ei_data = data[idx + 5]   # 1=LE, 2=BE
    e_type_offset = idx + 16
    if len(data) >= e_type_offset + 2:
        e_type = struct.unpack('<H' if ei_data == 1 else '>H',
                               data[e_type_offset:e_type_offset+2])[0]
    else:
        e_type = 0

    type_names = {0: "NONE", 1: "REL", 2: "EXEC", 3: "DYN", 4: "CORE"}

    return {
        "valid": True,
        "offset": idx,
        "bits": 64 if ei_class == 2 else 32,
        "endian": "LE" if ei_data == 1 else "BE",
        "type": type_names.get(e_type, f"UNKNOWN({e_type})"),
        "technique": "STANDARD" if idx == 0 else "EMBEDDED",
    }


def _validate_gzip(data: bytes) -> Dict:
    """Validate gzip structure."""
    GZIP_MAGIC = b'\x1f\x8b'
    idx = data.find(GZIP_MAGIC)
    if idx == -1:
        return {"valid": False}
    method = data[idx + 2] if len(data) > idx + 2 else 0
    return {
        "valid": True,
        "offset": idx,
        "method": "deflate" if method == 8 else f"unknown({method})",
        "technique": "STANDARD" if idx == 0 else "EMBEDDED",
    }


def _validate_html(data: bytes) -> Dict:
    """Validate HTML structure."""
    text = data[:8192].decode('ascii', errors='replace').lower()
    markers = ['<html', '<!doctype html', '<head', '<body', '<script']
    found = [m for m in markers if m in text]
    if not found:
        return {"valid": False}
    return {
        "valid": True,
        "offset": 0,
        "markers_found": found,
        "technique": "STANDARD",
    }


def _validate_javascript(data: bytes) -> Dict:
    """Check for embedded JavaScript (polyglot JS/image is a real attack)."""
    text = data[:16384].decode('ascii', errors='replace')
    js_patterns = ['function(', 'function (', 'var ', 'const ', 'let ',
                   'document.', 'window.', 'eval(', 'alert(']
    found = [p for p in js_patterns if p in text]
    if len(found) < 2:
        return {"valid": False}
    return {
        "valid": True,
        "offset": 0,
        "patterns_found": found[:5],
        "technique": "EMBEDDED",
    }


VALIDATORS = {
    "PDF": _validate_pdf,
    "ZIP": _validate_zip,
    "PNG": _validate_png,
    "JPEG": _validate_jpeg,
    "ELF": _validate_elf,
    "GZIP": _validate_gzip,
    "HTML": _validate_html,
    "JavaScript": _validate_javascript,
}


def detect_chimera(filepath: str) -> Dict:
    """
    Full structural polyglot analysis of a file.
    Returns which formats the file genuinely validates as,
    and the construction technique used.
    """
    result = {
        "filepath": filepath,
        "size": 0,
        "faces": [],
        "is_chimera": False,
        "construction": None,
        "danger_level": "NONE",
    }

    try:
        data = Path(filepath).read_bytes()
    except (PermissionError, IsADirectoryError, FileNotFoundError):
        result["error"] = "Cannot read file"
        return result

    result["size"] = len(data)
    if len(data) < 4:
        return result

    # Run all validators
    for fmt_name, validator in VALIDATORS.items():
        try:
            v = validator(data)
            if v.get("valid"):
                v["format"] = fmt_name
                result["faces"].append(v)
        except Exception:
            pass

    result["is_chimera"] = len(result["faces"]) > 1

    if result["is_chimera"]:
        # Determine construction technique
        techniques = set(f.get("technique", "UNKNOWN") for f in result["faces"])
        offsets = [f.get("offset", 0) for f in result["faces"]]
        formats = [f["format"] for f in result["faces"]]

        if "APPENDED" in techniques:
            result["construction"] = "CAVITY_APPEND"
            result["detail"] = "Second format appended after first format's EOF marker"
        elif any(f.get("cavity_after_iend", 0) > 0 or f.get("cavity_after_eoi", 0) > 0
                 for f in result["faces"]):
            result["construction"] = "EOF_CAVITY"
            result["detail"] = "Data hidden in cavity after image EOF marker"
        elif "EMBEDDED" in techniques:
            result["construction"] = "FORMAT_EMBEDDING"
            result["detail"] = "One format embedded within another"
        elif 0 in offsets and any(o > 0 for o in offsets):
            result["construction"] = "OFFSET_TRICK"
            result["detail"] = "Second format starts at non-zero offset"
        else:
            result["construction"] = "PARALLEL_PARSE"
            result["detail"] = "Both formats parse from the beginning (rare)"

        # Danger assessment
        dangerous_combos = [
            ({"HTML", "JavaScript"}, {"JPEG", "PNG", "PDF"}),
            ({"ELF"}, {"PDF", "ZIP", "PNG", "JPEG"}),
            ({"JavaScript"}, {"JPEG", "PNG"}),
        ]
        fmt_set = set(formats)
        for attack_set, carrier_set in dangerous_combos:
            if attack_set & fmt_set and carrier_set & fmt_set:
                result["danger_level"] = "CRITICAL"
                break
        if result["danger_level"] == "NONE" and len(result["faces"]) > 2:
            result["danger_level"] = "HIGH"
        elif result["danger_level"] == "NONE":
            result["danger_level"] = "MEDIUM"

    return result


def analyze_construction(filepath: str) -> Dict:
    """Deep analysis of HOW a polyglot was constructed."""
    result = detect_chimera(filepath)
    if not result["is_chimera"]:
        return result

    try:
        data = Path(filepath).read_bytes()
    except Exception:
        return result

    # Entropy analysis of different regions
    regions = []
    chunk_size = min(len(data) // 4, 4096)
    if chunk_size > 0:
        for i in range(0, len(data), chunk_size):
            chunk = data[i:i+chunk_size]
            entropy = _shannon(chunk)
            regions.append({
                "offset": f"0x{i:08x}",
                "size": len(chunk),
                "entropy": round(entropy, 2),
                "pattern": "HIGH_ENTROPY" if entropy > 7.0 else
                          "STRUCTURED" if entropy > 4.0 else "LOW_ENTROPY",
            })

    result["entropy_map"] = regions[:20]

    # Check for format boundaries
    boundaries = []
    for face in result["faces"]:
        offset = face.get("offset", 0)
        if offset > 0:
            boundaries.append({
                "format": face["format"],
                "starts_at": f"0x{offset:08x}",
                "hex_at_boundary": data[max(0,offset-4):offset+8].hex(),
            })
    result["boundaries"] = boundaries

    return result


def scan_directory_chimeras(directory: str, max_files: int = 500) -> List[Dict]:
    """Scan a directory for chimera files (structural polyglots)."""
    chimeras = []
    scanned = 0

    for root, dirs, files in os.walk(directory):
        # Skip hidden and system dirs
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fname in files:
            if scanned >= max_files:
                return chimeras
            fpath = os.path.join(root, fname)
            try:
                if os.path.getsize(fpath) > 50 * 1024 * 1024:  # Skip >50MB
                    continue
                if os.path.getsize(fpath) < 8:
                    continue
            except OSError:
                continue
            scanned += 1
            result = detect_chimera(fpath)
            if result["is_chimera"]:
                chimeras.append(result)

    return chimeras


def _shannon(data: bytes) -> float:
    if not data:
        return 0.0
    import math
    freq = {}
    for b in data:
        freq[b] = freq.get(b, 0) + 1
    entropy = 0.0
    for count in freq.values():
        p = count / len(data)
        if p > 0:
            entropy -= p * math.log2(p)
    return entropy
