"""
Lamprey Engine — Finds parasitic dependencies, abandoned packages,
typosquat candidates, and supply chain infection vectors.
"""

import os
import json
import re
import hashlib
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime


# Known suspicious package name patterns
PARASITE_PATTERNS = [
    r".*-nightly$",          # Fake nightly builds
    r".*-[0-9]+$",           # Version-suffixed fakes
    r"^python-.*",           # Prefix squatting
    r".*[0-9]l[0-9].*",     # l/1 confusion
    r".*[0-9]O[0-9].*",     # O/0 confusion
]

# Common typosquat character swaps
TYPOSQUAT_SWAPS = {
    'a': ['@', '4'], 'e': ['3'], 'i': ['1', 'l'],
    'o': ['0'], 's': ['5', '$'], 't': ['7'],
    'l': ['1', 'i'], 'g': ['9'], 'b': ['6'],
}


def scan_requirements(filepath: str) -> List[Dict]:
    """Scan a requirements.txt for parasitic dependencies."""
    findings = []

    with open(filepath, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            # Extract package name
            pkg = re.split(r'[>=<!\[\];]', line)[0].strip()
            if not pkg:
                continue

            anomalies = _analyze_package_name(pkg)

            # Check for pinning
            if '==' not in line and '>=' not in line:
                anomalies.append({
                    "type": "UNPINNED",
                    "emoji": "📌",
                    "detail": f"'{pkg}' is not version-pinned — vulnerable to mutation",
                    "severity": "MEDIUM",
                })

            # Check for git/URL installs
            if 'git+' in line or 'http' in line:
                anomalies.append({
                    "type": "FOREIGN_HOST",
                    "emoji": "🌐",
                    "detail": f"Installing from external source — potential infection vector",
                    "severity": "HIGH",
                })

            if anomalies:
                findings.append({
                    "line": line_num,
                    "package": pkg,
                    "raw": line,
                    "anomalies": anomalies,
                })

    return findings


def scan_package_json(filepath: str) -> List[Dict]:
    """Scan a package.json for parasitic npm dependencies."""
    findings = []

    with open(filepath, 'r') as f:
        data = json.load(f)

    for dep_type in ["dependencies", "devDependencies", "peerDependencies"]:
        deps = data.get(dep_type, {})
        for pkg, version in deps.items():
            anomalies = _analyze_package_name(pkg)

            # Check for wildcard versions
            if version in ['*', 'latest', '']:
                anomalies.append({
                    "type": "WILDCARD",
                    "emoji": "🎰",
                    "detail": f"Wildcard version '{version}' — total mutation exposure",
                    "severity": "CRITICAL",
                })

            # Check for git URLs
            if 'git' in version or 'github' in version:
                anomalies.append({
                    "type": "GIT_PARASITE",
                    "emoji": "🦠",
                    "detail": f"Git dependency — mutable infection source",
                    "severity": "HIGH",
                })

            if anomalies:
                findings.append({
                    "package": pkg,
                    "version": version,
                    "section": dep_type,
                    "anomalies": anomalies,
                })

    return findings


def generate_typosquats(package_name: str) -> List[Dict]:
    """Generate potential typosquat variants of a package name."""
    variants = []

    # Character swaps
    for i, char in enumerate(package_name):
        if char.lower() in TYPOSQUAT_SWAPS:
            for swap in TYPOSQUAT_SWAPS[char.lower()]:
                variant = package_name[:i] + swap + package_name[i + 1:]
                variants.append({
                    "variant": variant,
                    "technique": "CHAR_SWAP",
                    "detail": f"'{char}' → '{swap}' at position {i}",
                })

    # Character deletion
    for i in range(len(package_name)):
        variant = package_name[:i] + package_name[i + 1:]
        if variant:
            variants.append({
                "variant": variant,
                "technique": "DELETION",
                "detail": f"Removed '{package_name[i]}' at position {i}",
            })

    # Adjacent key swaps (keyboard proximity)
    for i in range(len(package_name) - 1):
        variant = (package_name[:i] + package_name[i + 1] +
                   package_name[i] + package_name[i + 2:])
        variants.append({
            "variant": variant,
            "technique": "TRANSPOSITION",
            "detail": f"Swapped positions {i} and {i + 1}",
        })

    # Prefix/suffix attacks
    for prefix in ['python-', 'py-', 'node-', 'js-']:
        if not package_name.startswith(prefix):
            variants.append({
                "variant": prefix + package_name,
                "technique": "PREFIX_SQUAT",
                "detail": f"Added prefix '{prefix}'",
            })

    for suffix in ['-js', '-py', '-dev', '-beta', '-2']:
        if not package_name.endswith(suffix):
            variants.append({
                "variant": package_name + suffix,
                "technique": "SUFFIX_SQUAT",
                "detail": f"Added suffix '{suffix}'",
            })

    # Hyphen/underscore confusion
    if '-' in package_name:
        variants.append({
            "variant": package_name.replace('-', '_'),
            "technique": "SEPARATOR_SWAP",
            "detail": "Replaced hyphens with underscores",
        })
    if '_' in package_name:
        variants.append({
            "variant": package_name.replace('_', '-'),
            "technique": "SEPARATOR_SWAP",
            "detail": "Replaced underscores with hyphens",
        })

    return variants


def scan_installed_packages() -> List[Dict]:
    """Scan installed pip packages for parasitic indicators."""
    findings = []

    try:
        import subprocess
        result = subprocess.run(
            ["pip", "list", "--format=json"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            packages = json.loads(result.stdout)
            for pkg in packages:
                name = pkg.get("name", "")
                version = pkg.get("version", "")
                anomalies = _analyze_package_name(name)

                if anomalies:
                    findings.append({
                        "package": name,
                        "version": version,
                        "anomalies": anomalies,
                    })
    except Exception:
        pass

    return findings


def _analyze_package_name(name: str) -> List[Dict]:
    """Analyze a package name for parasitic indicators."""
    anomalies = []

    # Check against known suspicious patterns
    for pattern in PARASITE_PATTERNS:
        if re.match(pattern, name, re.IGNORECASE):
            anomalies.append({
                "type": "SUSPICIOUS_PATTERN",
                "emoji": "🦠",
                "detail": f"Name matches parasitic pattern: {pattern}",
                "severity": "MEDIUM",
            })

    # Check for homoglyph attacks
    suspicious_chars = set()
    for char in name:
        if ord(char) > 127:
            suspicious_chars.add(char)
    if suspicious_chars:
        anomalies.append({
            "type": "HOMOGLYPH",
            "emoji": "🎭",
            "detail": f"Non-ASCII characters detected: {suspicious_chars}",
            "severity": "CRITICAL",
        })

    # Very short names are suspicious
    if len(name) <= 2:
        anomalies.append({
            "type": "MICRO_PARASITE",
            "emoji": "🦠",
            "detail": f"Extremely short package name '{name}' — easy to typosquat",
            "severity": "LOW",
        })

    return anomalies
