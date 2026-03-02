"""NullSec WebTools — Payload Service
Scans and manages the 163+ payload suite."""

import json
from pathlib import Path
from typing import List, Dict, Optional, Any
from .. import config


def get_all_payloads() -> List[Dict[str, Any]]:
    """Scan nullsec-suite/ and return all payload metadata."""
    payloads = []
    suite = config.SUITE_DIR
    if not suite.is_dir():
        return payloads

    for d in sorted(suite.iterdir()):
        if not d.is_dir():
            continue

        payload = {
            "name": d.name,
            "path": str(d),
            "has_payload_sh": (d / "payload.sh").exists(),
            "has_info_json": (d / "info.json").exists(),
            "category": "misc",
            "author": "",
            "description": "",
            "version": "1.0",
            "tags": [],
            "requirements": [],
            "errors": [],
        }

        info_path = d / "info.json"
        if info_path.exists():
            try:
                info = json.loads(info_path.read_text())
                payload["category"] = info.get("category", "misc")
                payload["author"] = info.get("author", "")
                payload["description"] = info.get("description", "")
                payload["version"] = info.get("version", "1.0")
                payload["tags"] = info.get("tags", [])
                payload["requirements"] = info.get("requirements", [])
            except json.JSONDecodeError:
                payload["errors"].append("Invalid info.json")

        if not payload["has_payload_sh"]:
            payload["errors"].append("Missing payload.sh")

        payloads.append(payload)

    return payloads


def get_payload(name: str) -> Optional[Dict[str, Any]]:
    """Get details for a single payload including source code."""
    d = config.SUITE_DIR / name
    if not d.is_dir():
        return None

    payloads = get_all_payloads()
    payload = next((p for p in payloads if p["name"] == name), None)
    if not payload:
        return None

    # Include source
    payload_sh = d / "payload.sh"
    if payload_sh.exists():
        payload["source"] = payload_sh.read_text()

    info_json = d / "info.json"
    if info_json.exists():
        payload["info_json_raw"] = info_json.read_text()

    # List all files
    payload["files"] = [str(f.relative_to(d)) for f in d.rglob("*") if f.is_file()]

    return payload


def get_payload_stats() -> Dict[str, Any]:
    """Aggregate stats across all payloads."""
    payloads = get_all_payloads()
    categories = {}
    tags = {}
    errors = 0

    for p in payloads:
        cat = p["category"]
        categories[cat] = categories.get(cat, 0) + 1
        for t in p.get("tags", []):
            tags[t] = tags.get(t, 0) + 1
        if p["errors"]:
            errors += 1

    return {
        "total": len(payloads),
        "categories": dict(sorted(categories.items(), key=lambda x: -x[1])),
        "top_tags": dict(sorted(tags.items(), key=lambda x: -x[1])[:20]),
        "with_errors": errors,
        "healthy": len(payloads) - errors,
    }


def search_payloads(query: str) -> List[Dict[str, Any]]:
    """Search payloads by name, description, tags, or category."""
    q = query.lower()
    results = []
    for p in get_all_payloads():
        if (q in p["name"].lower() or
            q in p["description"].lower() or
            q in p["category"].lower() or
            any(q in t.lower() for t in p.get("tags", []))):
            results.append(p)
    return results


def validate_payload(name: str) -> List[str]:
    """Validate a payload against NullSec standards."""
    errors = []
    d = config.SUITE_DIR / name
    if not d.is_dir():
        return ["Payload directory not found"]

    payload_sh = d / "payload.sh"
    info_json = d / "info.json"

    if not payload_sh.exists():
        errors.append("Missing payload.sh")
    else:
        content = payload_sh.read_text()
        if not content.startswith("#!/bin/bash"):
            errors.append("Missing #!/bin/bash shebang")
        if "Author:" not in content:
            errors.append("Missing Author header comment")
        if "/mmc/nullsec/" not in content:
            errors.append("LOOT_DIR should use /mmc/nullsec/")
        if "log()" not in content and "log " not in content:
            errors.append("No logging function detected")

    if not info_json.exists():
        errors.append("Missing info.json")
    else:
        try:
            data = json.loads(info_json.read_text())
            for key in ["name", "author", "description", "category", "version"]:
                if key not in data:
                    errors.append(f"info.json missing '{key}'")
        except json.JSONDecodeError:
            errors.append("info.json is invalid JSON")

    return errors
