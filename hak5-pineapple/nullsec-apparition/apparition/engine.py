"""
Apparition Engine — Environment Variable Security Audit.
Apparitions materialize from thin air — just like leaked secrets
in your environment variables. This tool finds them.
"""

import os
import re
import stat
from typing import List, Dict
from pathlib import Path


# Patterns that indicate secrets in environment variables
SECRET_PATTERNS = [
    (r'(?i)(api[_-]?key|apikey)', "API Key"),
    (r'(?i)(secret[_-]?key|secretkey)', "Secret Key"),
    (r'(?i)(access[_-]?token|auth[_-]?token)', "Access Token"),
    (r'(?i)(password|passwd|pwd)(?!.*path)', "Password"),
    (r'(?i)(private[_-]?key)', "Private Key"),
    (r'(?i)(aws[_-]?secret)', "AWS Secret"),
    (r'(?i)(database[_-]?url|db[_-]?url|db[_-]?pass)', "Database Credential"),
    (r'(?i)(github[_-]?token|gh[_-]?token)', "GitHub Token"),
    (r'(?i)(slack[_-]?token|slack[_-]?webhook)', "Slack Token"),
    (r'(?i)(stripe[_-]?key)', "Stripe Key"),
    (r'(?i)(twilio|sendgrid)', "Service API Key"),
    (r'(?i)(jwt[_-]?secret|signing[_-]?key)', "JWT/Signing Key"),
]

# Value patterns that look like actual secrets
VALUE_PATTERNS = [
    (r'^ghp_[A-Za-z0-9]{36,}$', "GitHub Personal Access Token"),
    (r'^gho_[A-Za-z0-9]{36,}$', "GitHub OAuth Token"),
    (r'^sk-[A-Za-z0-9]{20,}$', "OpenAI/Stripe Secret Key"),
    (r'^xoxb-[0-9]{10,}', "Slack Bot Token"),
    (r'^xoxp-[0-9]{10,}', "Slack User Token"),
    (r'^AKIA[0-9A-Z]{16}$', "AWS Access Key ID"),
    (r'^eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}', "JWT Token"),
    (r'^Bearer\s+[A-Za-z0-9_-]{20,}', "Bearer Token"),
]

# Dangerous environment variables
DANGEROUS_VARS = {
    "LD_PRELOAD": ("CRITICAL", "Library injection — loads .so before all others"),
    "LD_LIBRARY_PATH": ("HIGH", "Library path override — can hijack shared libraries"),
    "LD_AUDIT": ("CRITICAL", "Audit library injection — loads .so for every dynamic binary"),
    "LD_DEBUG": ("MEDIUM", "Debug mode — may leak internal library resolution info"),
    "PROMPT_COMMAND": ("HIGH", "Executes command before every prompt — persistence vector"),
    "BASH_ENV": ("HIGH", "Script executed for every non-interactive bash — persistence"),
    "ENV": ("MEDIUM", "Script executed for sh shells — persistence vector"),
    "PYTHONSTARTUP": ("MEDIUM", "Python startup script — code injection on python launch"),
    "PERL5OPT": ("HIGH", "Perl options injection — can load arbitrary modules"),
    "NODE_OPTIONS": ("MEDIUM", "Node.js options — can require arbitrary modules"),
    "HISTFILE": ("INFO", "Shell history file location"),
    "HISTSIZE": ("INFO", "Shell history size"),
    "http_proxy": ("MEDIUM", "HTTP proxy — traffic interception risk"),
    "https_proxy": ("MEDIUM", "HTTPS proxy — TLS interception risk"),
    "no_proxy": ("INFO", "Proxy bypass list"),
}


def scan_env_secrets() -> List[Dict]:
    """Scan environment variables for leaked secrets."""
    findings = []
    env = dict(os.environ)

    for var_name, var_value in env.items():
        # Check variable NAME against secret patterns
        for pattern, secret_type in SECRET_PATTERNS:
            if re.search(pattern, var_name):
                # Mask the value
                masked = var_value[:4] + "****" + var_value[-4:] if len(var_value) > 8 else "****"
                findings.append({
                    "type": "SECRET_IN_NAME",
                    "emoji": "🔑",
                    "severity": "HIGH",
                    "variable": var_name,
                    "secret_type": secret_type,
                    "value_preview": masked,
                    "value_length": len(var_value),
                })
                break

        # Check variable VALUE against known token formats
        for pattern, token_type in VALUE_PATTERNS:
            if re.search(pattern, var_value):
                masked = var_value[:8] + "****"
                findings.append({
                    "type": "TOKEN_IN_VALUE",
                    "emoji": "🎫",
                    "severity": "CRITICAL",
                    "variable": var_name,
                    "secret_type": token_type,
                    "value_preview": masked,
                })
                break

    return findings


def audit_path_hijack() -> List[Dict]:
    """Audit PATH for hijack vulnerabilities."""
    findings = []
    path = os.environ.get("PATH", "")
    dirs = path.split(":")

    seen = set()
    for i, d in enumerate(dirs):
        if not d:
            findings.append({
                "type": "EMPTY_PATH_ENTRY",
                "emoji": "⚠️",
                "severity": "HIGH",
                "detail": f"Empty PATH entry at position {i} — resolves to CWD (hijack vector)",
                "position": i,
            })
            continue

        if d in seen:
            findings.append({
                "type": "DUPLICATE_PATH",
                "emoji": "🔄",
                "severity": "LOW",
                "detail": f"Duplicate PATH entry: {d}",
                "path": d,
            })
            continue
        seen.add(d)

        if not os.path.isabs(d):
            findings.append({
                "type": "RELATIVE_PATH",
                "emoji": "🎯",
                "severity": "CRITICAL",
                "detail": f"Relative PATH entry: '{d}' — attacker can create malicious binaries in CWD",
                "path": d,
            })
            continue

        if not os.path.exists(d):
            findings.append({
                "type": "NONEXISTENT_PATH",
                "emoji": "👻",
                "severity": "MEDIUM",
                "detail": f"PATH entry doesn't exist: {d}",
                "path": d,
            })
            continue

        # Check if writable by current user or world-writable
        try:
            st = os.stat(d)
            if st.st_mode & stat.S_IWOTH:
                findings.append({
                    "type": "WORLD_WRITABLE_PATH",
                    "emoji": "🔓",
                    "severity": "CRITICAL",
                    "detail": f"World-writable PATH directory: {d}",
                    "path": d,
                    "position": i,
                })
            elif os.access(d, os.W_OK) and st.st_uid != 0:
                findings.append({
                    "type": "USER_WRITABLE_PATH",
                    "emoji": "📝",
                    "severity": "MEDIUM",
                    "detail": f"User-writable PATH directory (owned by UID {st.st_uid}): {d}",
                    "path": d,
                })
        except OSError:
            pass

    # Check for common hijackable positions
    if dirs and dirs[0] != "/usr/local/sbin" and dirs[0] not in ("/usr/local/bin", "/usr/sbin", "/usr/bin"):
        findings.append({
            "type": "UNUSUAL_FIRST_PATH",
            "emoji": "🔍",
            "severity": "INFO",
            "detail": f"First PATH entry is non-standard: {dirs[0]}",
            "path": dirs[0],
        })

    return findings


def check_dangerous_vars() -> List[Dict]:
    """Check for dangerous environment variables."""
    findings = []
    env = dict(os.environ)

    for var_name, (severity, description) in DANGEROUS_VARS.items():
        if var_name in env:
            value = env[var_name]
            finding = {
                "type": "DANGEROUS_VAR",
                "emoji": "☠️" if severity == "CRITICAL" else "⚠️",
                "severity": severity,
                "variable": var_name,
                "description": description,
                "value": value if len(value) < 100 else value[:100] + "...",
            }

            # Extra checks for specific vars
            if var_name == "LD_PRELOAD":
                # Check if the .so files exist and are suspicious
                for lib in value.split(":"):
                    lib = lib.strip()
                    if lib and not os.path.exists(lib):
                        finding["extra"] = f"Preloaded library MISSING: {lib}"
                        finding["severity"] = "CRITICAL"

            elif var_name == "HISTFILE":
                if value == "/dev/null" or value == "":
                    finding["extra"] = "History disabled — anti-forensics indicator"
                    finding["severity"] = "HIGH"

            elif var_name == "HISTSIZE":
                if value == "0":
                    finding["extra"] = "History size set to 0 — anti-forensics indicator"
                    finding["severity"] = "HIGH"

            findings.append(finding)

    # Check for HISTCONTROL ignorespace (allows hiding commands with leading space)
    histcontrol = env.get("HISTCONTROL", "")
    if "ignorespace" in histcontrol or "ignoreboth" in histcontrol:
        findings.append({
            "type": "HISTORY_EVASION",
            "emoji": "🕵️",
            "severity": "MEDIUM",
            "variable": "HISTCONTROL",
            "description": "Commands with leading space are hidden from history",
            "value": histcontrol,
        })

    return findings


def full_apparition_scan() -> Dict:
    """Full environment variable security scan."""
    return {
        "secrets": scan_env_secrets(),
        "path_hijack": audit_path_hijack(),
        "dangerous_vars": check_dangerous_vars(),
        "total_env_vars": len(os.environ),
    }
