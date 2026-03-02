"""
Imp Engine — Shell History Auditor.
Mischievous little demons that dig through your command history
looking for secrets you typed, dangerous commands you ran,
and evidence of anti-forensic history evasion.
"""

import os
import re
from typing import List, Dict, Optional
from pathlib import Path


# Patterns for secrets typed on command line
SECRET_COMMAND_PATTERNS = [
    (r'(?:^|\s)(?:mysql|psql|mongo)\s+.*-p\s*\S+', "Database password on command line"),
    (r'(?:curl|wget|http)\s+.*(?:token|key|auth|password|Bearer)\s*[=:]\s*\S+', "API credential in HTTP request"),
    (r'(?:export|set)\s+(?:.*(?:PASSWORD|SECRET|TOKEN|KEY|API_KEY))\s*=', "Secret exported to environment"),
    (r'echo\s+.*(?:password|secret|token|key)\s*[|>]', "Secret echoed/piped"),
    (r'sshpass\s+-p', "SSH password on command line"),
    (r'(?:curl|wget)\s+.*-u\s+\S+:\S+', "HTTP basic auth credentials"),
    (r'htpasswd\s+.*-b\s+', "htpasswd with password argument"),
    (r'openssl\s+.*-pass\s+pass:', "OpenSSL password on command line"),
    (r'gpg\s+.*--passphrase\s+', "GPG passphrase on command line"),
    (r'ansible.*--ask-pass|ansible.*-k\s', "Ansible password prompt"),
    (r'(?:aws|gcloud|az)\s+.*(?:secret|key|token)', "Cloud CLI with possible credentials"),
]

# Dangerous commands
DANGEROUS_PATTERNS = [
    (r'rm\s+(?:-[rf]{1,3}\s+)?/(?:\s|$)', "Recursive delete from root", "CRITICAL"),
    (r'rm\s+-rf\s+/\*', "Delete everything", "CRITICAL"),
    (r'dd\s+.*of=/dev/sd', "Direct disk write with dd", "HIGH"),
    (r'mkfs\s+', "Filesystem format command", "HIGH"),
    (r'chmod\s+(?:-R\s+)?(?:777|666)\s+/', "Dangerous permission change", "HIGH"),
    (r'chmod\s+(?:4|2)?\d{3}\s+/usr/|chmod\s+\+s\s+', "SUID/SGID modification", "CRITICAL"),
    (r'chown\s+-R\s+.*/', "Recursive ownership change on system path", "HIGH"),
    (r'>\s*/etc/(?:passwd|shadow|sudoers)', "Overwriting critical system file", "CRITICAL"),
    (r'(?:python|perl|bash|sh)\s+-c\s+.*(?:exec|eval|system)', "Dynamic code execution", "MEDIUM"),
    (r'nc\s+-(?:l|e)|ncat\s+-(?:l|e)', "Netcat listener/execute", "HIGH"),
    (r'(?:curl|wget)\s+.*\|\s*(?:bash|sh|python)', "Pipe-to-shell execution", "HIGH"),
    (r'iptables\s+-F|iptables\s+--flush', "Firewall flush", "HIGH"),
    (r'systemctl\s+(?:disable|mask)\s+(?:firewalld|ufw|iptables)', "Firewall disabled", "HIGH"),
    (r'history\s+-c|history\s+--clear', "History cleared", "MEDIUM"),
]

# History evasion indicators
EVASION_PATTERNS = [
    (r'unset\s+HIST', "HISTFILE/HISTSIZE unset — history evasion"),
    (r'export\s+HISTFILE\s*=\s*/dev/null', "History redirected to /dev/null"),
    (r'export\s+HISTSIZE\s*=\s*0', "History size set to 0"),
    (r'export\s+HISTFILESIZE\s*=\s*0', "History file size set to 0"),
    (r'set\s+\+o\s+history', "History recording disabled"),
    (r'kill\s+-9\s+\$\$', "Self-kill — possible evasion"),
    (r'shred\s+.*history', "History file shredded"),
    (r'truncate\s+.*history', "History file truncated"),
    (r'ln\s+-sf?\s+/dev/null.*history', "History symlinked to /dev/null"),
]


def _find_history_files() -> List[Dict]:
    """Find all shell history files on the system."""
    history_files = []
    history_names = [
        ".bash_history", ".zsh_history", ".sh_history",
        ".history", ".python_history", ".node_repl_history",
        ".psql_history", ".mysql_history", ".sqlite_history",
        ".lesshst", ".viminfo",
    ]

    # Check current user
    home = os.path.expanduser("~")
    for hname in history_names:
        hpath = os.path.join(home, hname)
        if os.path.exists(hpath):
            try:
                size = os.path.getsize(hpath)
                history_files.append({
                    "path": hpath,
                    "name": hname,
                    "size": size,
                    "user": os.environ.get("USER", "?"),
                })
            except OSError:
                pass

    # Check other home directories
    try:
        for entry in os.scandir("/home"):
            if entry.is_dir():
                for hname in history_names:
                    hpath = os.path.join(entry.path, hname)
                    if os.path.exists(hpath):
                        try:
                            size = os.path.getsize(hpath)
                            history_files.append({
                                "path": hpath,
                                "name": hname,
                                "size": size,
                                "user": entry.name,
                            })
                        except (OSError, PermissionError):
                            pass
    except (PermissionError, FileNotFoundError):
        pass

    # Root history
    for hname in history_names:
        hpath = os.path.join("/root", hname)
        if os.path.exists(hpath):
            try:
                size = os.path.getsize(hpath)
                history_files.append({
                    "path": hpath,
                    "name": hname,
                    "size": size,
                    "user": "root",
                })
            except (OSError, PermissionError):
                pass

    return history_files


def audit_history(history_file: Optional[str] = None,
                  max_lines: int = 10000) -> Dict:
    """Audit a shell history file for secrets and dangerous commands."""
    result = {
        "file": history_file,
        "lines_scanned": 0,
        "secrets": [],
        "dangerous": [],
        "evasion": [],
    }

    if not history_file:
        # Auto-detect
        for hfile in [os.path.expanduser("~/.bash_history"),
                      os.path.expanduser("~/.zsh_history")]:
            if os.path.exists(hfile):
                history_file = hfile
                break

    if not history_file or not os.path.exists(history_file):
        result["error"] = "No history file found"
        return result

    result["file"] = history_file

    try:
        with open(history_file, 'r', errors='replace') as f:
            lines = f.readlines()
    except PermissionError:
        result["error"] = "Permission denied"
        return result

    # Scan lines (most recent first, limited)
    scan_lines = lines[-max_lines:] if len(lines) > max_lines else lines
    result["lines_scanned"] = len(scan_lines)
    result["total_lines"] = len(lines)

    for line_num, line in enumerate(scan_lines, 1):
        line = line.strip()
        if not line:
            continue

        # Strip zsh timestamp prefix if present
        if line.startswith(': ') and ';' in line[:20]:
            line = line.split(';', 1)[1] if ';' in line else line

        # Check for secrets
        for pattern, description in SECRET_COMMAND_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                # Mask any obvious passwords
                masked = _mask_secrets(line)
                result["secrets"].append({
                    "line_num": line_num,
                    "command": masked[:120],
                    "type": description,
                    "severity": "HIGH",
                    "emoji": "🔑",
                })
                break

        # Check for dangerous commands
        for pattern, description, severity in DANGEROUS_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                result["dangerous"].append({
                    "line_num": line_num,
                    "command": line[:120],
                    "type": description,
                    "severity": severity,
                    "emoji": "💣" if severity == "CRITICAL" else "⚠️",
                })
                break

        # Check for evasion
        for pattern, description in EVASION_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                result["evasion"].append({
                    "line_num": line_num,
                    "command": line[:120],
                    "type": description,
                    "severity": "HIGH",
                    "emoji": "🕵️",
                })
                break

    return result


def detect_history_evasion() -> List[Dict]:
    """Detect active history evasion on the system."""
    findings = []

    # Check environment
    histfile = os.environ.get("HISTFILE", "")
    histsize = os.environ.get("HISTSIZE", "")
    histfilesize = os.environ.get("HISTFILESIZE", "")

    if histfile == "/dev/null" or histfile == "":
        findings.append({
            "type": "HISTFILE_DEVNULL",
            "emoji": "🕵️",
            "severity": "HIGH",
            "detail": f"HISTFILE={histfile or '(empty)'} — history not being saved",
        })

    if histsize == "0":
        findings.append({
            "type": "HISTSIZE_ZERO",
            "emoji": "🕵️",
            "severity": "HIGH",
            "detail": "HISTSIZE=0 — in-memory history disabled",
        })

    if histfilesize == "0":
        findings.append({
            "type": "HISTFILESIZE_ZERO",
            "emoji": "🕵️",
            "severity": "HIGH",
            "detail": "HISTFILESIZE=0 — history file truncated on exit",
        })

    # Check if history file is a symlink to /dev/null
    for hfile in [os.path.expanduser("~/.bash_history"),
                  os.path.expanduser("~/.zsh_history")]:
        if os.path.islink(hfile):
            target = os.readlink(hfile)
            if target == "/dev/null":
                findings.append({
                    "type": "HISTORY_SYMLINK_NULL",
                    "emoji": "🔴",
                    "severity": "CRITICAL",
                    "detail": f"{hfile} is symlinked to /dev/null",
                })

        # Check if history file is empty but should have content
        if os.path.exists(hfile) and not os.path.islink(hfile):
            try:
                size = os.path.getsize(hfile)
                if size == 0:
                    findings.append({
                        "type": "EMPTY_HISTORY",
                        "emoji": "⚠️",
                        "severity": "MEDIUM",
                        "detail": f"{hfile} exists but is empty — recently cleared?",
                    })
            except OSError:
                pass

    return findings


def full_imp_scan() -> Dict:
    """Full imp scan — audit all history files and check evasion."""
    history_files = _find_history_files()
    audits = []
    for hf in history_files:
        if hf["name"] in (".bash_history", ".zsh_history", ".sh_history", ".history"):
            audit = audit_history(hf["path"])
            audits.append(audit)

    return {
        "history_files": history_files,
        "audits": audits,
        "evasion": detect_history_evasion(),
    }


def _mask_secrets(command: str) -> str:
    """Mask obvious passwords/tokens in a command."""
    # Mask -p password arguments
    masked = re.sub(r'(-p\s*)\S+', r'\1****', command)
    # Mask key=value secrets
    masked = re.sub(r'((?:password|secret|token|key|auth)\s*[=:]\s*)\S+',
                    r'\1****', masked, flags=re.IGNORECASE)
    # Mask basic auth
    masked = re.sub(r'(-u\s+\S+:)\S+', r'\1****', masked)
    return masked
