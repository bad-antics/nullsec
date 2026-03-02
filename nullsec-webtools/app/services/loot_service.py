"""NullSec WebTools — Loot Service
Browse and search captured loot/data across payloads."""

import os
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime
from .. import config


def get_loot_dirs() -> List[Dict[str, Any]]:
    """Find all loot directories."""
    dirs = []
    loot_base = config.LOOT_BASE

    if not loot_base.exists():
        return dirs

    for d in sorted(loot_base.iterdir()):
        if not d.is_dir():
            continue

        files = list(d.rglob("*"))
        file_count = len([f for f in files if f.is_file()])
        total_size = sum(f.stat().st_size for f in files if f.is_file())

        # Find latest modification
        latest = 0
        for f in files:
            if f.is_file():
                mtime = f.stat().st_mtime
                if mtime > latest:
                    latest = mtime

        dirs.append({
            "name": d.name,
            "path": str(d),
            "file_count": file_count,
            "total_size": _human_size(total_size),
            "total_bytes": total_size,
            "last_modified": datetime.fromtimestamp(latest).isoformat() if latest else "",
        })

    return dirs


def get_loot_files(payload_name: str) -> List[Dict[str, Any]]:
    """List files inside a specific loot directory."""
    loot_dir = config.LOOT_BASE / payload_name
    if not loot_dir.is_dir():
        return []

    files = []
    for f in sorted(loot_dir.rglob("*")):
        if not f.is_file():
            continue
        files.append({
            "name": str(f.relative_to(loot_dir)),
            "path": str(f),
            "size": _human_size(f.stat().st_size),
            "size_bytes": f.stat().st_size,
            "modified": datetime.fromtimestamp(f.stat().st_mtime).isoformat(),
            "extension": f.suffix,
        })

    return files


def read_loot_file(payload_name: str, filename: str, max_bytes: int = 65536) -> Optional[Dict[str, Any]]:
    """Read contents of a loot file (text only, truncated for safety)."""
    file_path = config.LOOT_BASE / payload_name / filename
    if not file_path.is_file():
        return None

    # Security: ensure path doesn't escape loot directory
    try:
        file_path.resolve().relative_to(config.LOOT_BASE.resolve())
    except ValueError:
        return None

    size = file_path.stat().st_size
    is_text = file_path.suffix in (".txt", ".log", ".csv", ".json", ".xml", ".html", ".sh", ".conf", "")

    result = {
        "name": filename,
        "size": _human_size(size),
        "size_bytes": size,
        "is_text": is_text,
        "truncated": size > max_bytes,
    }

    if is_text:
        try:
            content = file_path.read_text(errors="replace")
            if len(content) > max_bytes:
                content = content[:max_bytes] + f"\n\n--- Truncated ({_human_size(size)} total) ---"
            result["content"] = content
        except Exception as e:
            result["content"] = f"Error reading file: {e}"
            result["is_text"] = False
    else:
        result["content"] = f"[Binary file: {_human_size(size)}]"

    return result


def search_loot(query: str) -> List[Dict[str, Any]]:
    """Search across all loot for files matching a query."""
    q = query.lower()
    results = []
    loot_base = config.LOOT_BASE

    if not loot_base.exists():
        return results

    for f in loot_base.rglob("*"):
        if not f.is_file():
            continue
        if q in f.name.lower() or q in str(f.parent.name).lower():
            results.append({
                "payload": f.relative_to(loot_base).parts[0] if len(f.relative_to(loot_base).parts) > 0 else "",
                "file": str(f.relative_to(loot_base)),
                "size": _human_size(f.stat().st_size),
                "modified": datetime.fromtimestamp(f.stat().st_mtime).isoformat(),
            })

    return results[:100]  # Limit results


def get_loot_stats() -> Dict[str, Any]:
    """Aggregate loot statistics."""
    dirs = get_loot_dirs()
    total_files = sum(d["file_count"] for d in dirs)
    total_size = sum(d["total_bytes"] for d in dirs)

    return {
        "payload_count": len(dirs),
        "total_files": total_files,
        "total_size": _human_size(total_size),
    }


def _human_size(nbytes: int) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if nbytes < 1024:
            return f"{nbytes:.1f} {unit}"
        nbytes /= 1024
    return f"{nbytes:.1f} PB"
