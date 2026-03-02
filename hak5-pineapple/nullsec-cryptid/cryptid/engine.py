"""
Cryptid Engine — Hunts for hidden, undocumented endpoints and API paths
lurking in source code, binaries, and configuration files.
"""

import os
import re
import json
from pathlib import Path
from typing import List, Dict, Optional

# Patterns for hunting hidden endpoints
URL_PATTERNS = [
    re.compile(r'["\']/(api|v[0-9]+|admin|debug|internal|hidden|secret|test|staging|dev|_|\.well-known)/[^"\']*["\']'),
    re.compile(r'["\']https?://[^"\']+["\']'),
    re.compile(r'@(Get|Post|Put|Delete|Patch|Route|RequestMapping)\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'router\.(get|post|put|delete|patch|all|use)\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'app\.(get|post|put|delete|patch|route)\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'@app\.(get|post|put|delete|patch|route)\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'path\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'url\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'fetch\s*\(\s*["\'][^"\']*["\']'),
    re.compile(r'axios\.(get|post|put|delete)\s*\(\s*["\'][^"\']*["\']'),
]

# Suspicious endpoint keywords (cryptids love to hide here)
CRYPTID_KEYWORDS = [
    "admin", "debug", "internal", "hidden", "secret", "test", "staging",
    "dev", "backup", "old", "legacy", "deprecated", "private", "beta",
    "alpha", "temp", "tmp", "dump", "export", "import", "config",
    "setup", "install", "migrate", "seed", "reset", "flush",
    "swagger", "graphql", "graphiql", "playground", "console",
    "phpinfo", "phpmyadmin", "adminer", "health", "metrics",
    "trace", "actuator", "env", "configprops", "heapdump",
]

# Binary string patterns
BINARY_URL_PATTERN = re.compile(rb'https?://[\x20-\x7e]{5,200}')
BINARY_PATH_PATTERN = re.compile(rb'/(?:api|v[0-9]|admin|debug|internal|hidden|secret)[/\w.-]{2,100}')


def hunt_in_source(dirpath: str, recursive: bool = True,
                   extensions: Optional[List[str]] = None) -> List[Dict]:
    """Hunt for cryptid endpoints in source code files."""
    if extensions is None:
        extensions = ['.py', '.js', '.ts', '.java', '.go', '.rb', '.php',
                      '.rs', '.cs', '.jsx', '.tsx', '.vue', '.svelte',
                      '.yaml', '.yml', '.json', '.xml', '.conf', '.toml']

    findings = []
    path = Path(dirpath)
    pattern = "**/*" if recursive else "*"

    for fpath in path.glob(pattern):
        if not fpath.is_file():
            continue
        if fpath.suffix.lower() not in extensions:
            continue
        if any(p in str(fpath) for p in ['node_modules', '.git', '__pycache__', 'venv']):
            continue

        try:
            content = fpath.read_text(errors='replace')
        except (PermissionError, IsADirectoryError):
            continue

        for line_num, line in enumerate(content.split('\n'), 1):
            for pat in URL_PATTERNS:
                matches = pat.findall(line)
                if matches:
                    # Extract the actual URL/path
                    url_match = re.findall(r'["\']([^"\']+)["\']', line)
                    for url in url_match:
                        suspicion = _rate_suspicion(url)
                        if suspicion > 0:
                            findings.append({
                                "file": str(fpath),
                                "line": line_num,
                                "endpoint": url,
                                "context": line.strip()[:120],
                                "suspicion": suspicion,
                                "tags": _tag_endpoint(url),
                                "emoji": _suspicion_emoji(suspicion),
                            })

    # Deduplicate by endpoint
    seen = set()
    unique = []
    for f in findings:
        if f["endpoint"] not in seen:
            seen.add(f["endpoint"])
            unique.append(f)

    return sorted(unique, key=lambda x: x["suspicion"], reverse=True)


def hunt_in_binary(filepath: str) -> List[Dict]:
    """Hunt for cryptid endpoints embedded in binary files."""
    findings = []

    try:
        with open(filepath, 'rb') as f:
            data = f.read()
    except (PermissionError, IsADirectoryError):
        return findings

    # Find URLs
    for match in BINARY_URL_PATTERN.finditer(data):
        url = match.group().decode('ascii', errors='replace')
        findings.append({
            "type": "URL",
            "value": url,
            "offset": f"0x{match.start():08x}",
            "suspicion": _rate_suspicion(url),
            "emoji": "🌐",
        })

    # Find API paths
    for match in BINARY_PATH_PATTERN.finditer(data):
        path = match.group().decode('ascii', errors='replace')
        findings.append({
            "type": "PATH",
            "value": path,
            "offset": f"0x{match.start():08x}",
            "suspicion": _rate_suspicion(path),
            "emoji": "🛤️",
        })

    return sorted(findings, key=lambda x: x["suspicion"], reverse=True)


def hunt_env_secrets(dirpath: str) -> List[Dict]:
    """Hunt for secrets and API keys lurking in env files and configs."""
    findings = []
    path = Path(dirpath)

    secret_patterns = [
        re.compile(r'(?:api[_-]?key|secret[_-]?key|password|token|auth|credential)\s*[=:]\s*["\']?([^"\'\s]+)', re.I),
        re.compile(r'(?:AWS_ACCESS_KEY|AWS_SECRET|GITHUB_TOKEN|SLACK_TOKEN|DATABASE_URL)\s*[=:]\s*["\']?([^"\'\s]+)', re.I),
        re.compile(r'Bearer\s+([A-Za-z0-9._-]{20,})', re.I),
        re.compile(r'-----BEGIN\s+(RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'),
    ]

    target_files = ['.env', '.env.local', '.env.production', '.env.development',
                    'config.yaml', 'config.yml', 'config.json', 'secrets.json',
                    '.npmrc', '.pypirc', 'credentials', 'docker-compose.yml']

    for fpath in path.rglob("*"):
        if not fpath.is_file():
            continue
        if fpath.name not in target_files and fpath.suffix not in ['.env', '.cfg', '.ini', '.conf']:
            continue

        try:
            content = fpath.read_text(errors='replace')
        except PermissionError:
            continue

        for line_num, line in enumerate(content.split('\n'), 1):
            for pat in secret_patterns:
                if pat.search(line):
                    findings.append({
                        "file": str(fpath),
                        "line": line_num,
                        "preview": _redact_secret(line.strip()),
                        "type": "SECRET",
                        "emoji": "🔑",
                    })

    return findings


def _rate_suspicion(url: str) -> int:
    """Rate how suspicious/hidden an endpoint appears (0-10)."""
    score = 0
    url_lower = url.lower()

    for keyword in CRYPTID_KEYWORDS:
        if keyword in url_lower:
            score += 2

    if url_lower.startswith('/api/') or '/v1/' in url_lower:
        score += 1
    if 'internal' in url_lower or 'hidden' in url_lower:
        score += 3
    if 'debug' in url_lower or 'admin' in url_lower:
        score += 2
    if url_lower.startswith('/_') or '/_' in url_lower:
        score += 2

    return min(score, 10)


def _tag_endpoint(url: str) -> List[str]:
    tags = []
    url_lower = url.lower()
    if 'admin' in url_lower: tags.append("ADMIN")
    if 'debug' in url_lower: tags.append("DEBUG")
    if 'api' in url_lower: tags.append("API")
    if 'internal' in url_lower: tags.append("INTERNAL")
    if 'secret' in url_lower or 'hidden' in url_lower: tags.append("HIDDEN")
    if 'test' in url_lower or 'staging' in url_lower: tags.append("NON-PROD")
    return tags


def _suspicion_emoji(score: int) -> str:
    if score >= 8: return "🔴"
    if score >= 5: return "🟠"
    if score >= 3: return "🟡"
    return "🟢"


def _redact_secret(line: str) -> str:
    """Partially redact secrets for safe display."""
    parts = re.split(r'[=:]', line, maxsplit=1)
    if len(parts) == 2:
        key = parts[0]
        value = parts[1].strip().strip('"\'')
        if len(value) > 8:
            return f"{key}={value[:4]}{'*' * (len(value) - 4)}"
    return line[:60] + "..."
