"""
Gremlin Engine — Filesystem anomaly detector and chaos tester.
Finds files that shouldn't exist, detects filesystem tampering,
and can generate decoy filesystems for honeypots.
"""

import os
import stat
import hashlib
import random
import string
import time
from pathlib import Path
from typing import List, Dict, Optional


# Files that should NOT exist on a clean system
CURSED_LOCATIONS = [
    "/tmp/.X11-unix/../.hidden",
    "/dev/shm/.secret",
    "/var/tmp/.cache_backdoor",
    "/tmp/.ICE-unix/../.payload",
    "~/.ssh/authorized_keys2",
    "~/.bashrc.bak",
    "/etc/cron.d/.hidden_job",
]

# Suspicious file patterns
GREMLIN_PATTERNS = {
    "HIDDEN_EXECUTABLE": {"pattern": r"^\.", "check": lambda p: os.access(p, os.X_OK) and os.path.isfile(p)},
    "WORLD_WRITABLE": {"check": lambda p: bool(os.stat(p).st_mode & stat.S_IWOTH)},
    "SETUID": {"check": lambda p: bool(os.stat(p).st_mode & stat.S_ISUID)},
    "SETGID": {"check": lambda p: bool(os.stat(p).st_mode & stat.S_ISGID)},
    "STICKY": {"check": lambda p: bool(os.stat(p).st_mode & stat.S_ISVTX) and os.path.isfile(p)},
}


def detect_anomalies(dirpath: str, recursive: bool = True) -> List[Dict]:
    """Detect filesystem anomalies — files that shouldn't be there."""
    anomalies = []
    path = Path(dirpath)
    pattern = "**/*" if recursive else "*"

    for fpath in path.glob(pattern):
        fname = fpath.name
        fstr = str(fpath)

        try:
            fstat = fpath.stat()
        except (PermissionError, OSError):
            continue

        file_anomalies = []

        # Check for hidden executables
        if fname.startswith('.') and fpath.is_file():
            try:
                if os.access(fstr, os.X_OK):
                    file_anomalies.append({
                        "type": "HIDDEN_EXECUTABLE",
                        "emoji": "👻",
                        "detail": f"Hidden executable: {fname}",
                        "severity": "HIGH",
                    })
            except (PermissionError, OSError):
                pass

        # World-writable files
        try:
            if fstat.st_mode & stat.S_IWOTH and fpath.is_file():
                file_anomalies.append({
                    "type": "WORLD_WRITABLE",
                    "emoji": "🌍",
                    "detail": f"World-writable file: anyone can modify",
                    "severity": "MEDIUM",
                })
        except (PermissionError, OSError):
            pass

        # SUID/SGID binaries
        try:
            if fstat.st_mode & stat.S_ISUID:
                file_anomalies.append({
                    "type": "SETUID",
                    "emoji": "⚡",
                    "detail": f"SUID bit set — runs as file owner",
                    "severity": "HIGH",
                })
            if fstat.st_mode & stat.S_ISGID:
                file_anomalies.append({
                    "type": "SETGID",
                    "emoji": "⚡",
                    "detail": f"SGID bit set — runs as group",
                    "severity": "MEDIUM",
                })
        except (PermissionError, OSError):
            pass

        # Suspicious file sizes
        if fpath.is_file():
            if fstat.st_size == 0:
                file_anomalies.append({
                    "type": "EMPTY_VESSEL",
                    "emoji": "🕳️",
                    "detail": "Empty file — potential placeholder or breadcrumb",
                    "severity": "LOW",
                })

        # Files with no extension in unexpected places
        if fpath.is_file() and '.' not in fname and not fname.startswith('.'):
            try:
                with open(fstr, 'rb') as f:
                    header = f.read(4)
                if header == b'\x7fELF':
                    file_anomalies.append({
                        "type": "UNMARKED_BINARY",
                        "emoji": "💀",
                        "detail": "ELF binary without extension — trying to hide?",
                        "severity": "HIGH",
                    })
            except (PermissionError, OSError):
                pass

        # Symlink pointing outside directory
        if fpath.is_symlink():
            try:
                target = os.readlink(fstr)
                if not os.path.exists(target):
                    file_anomalies.append({
                        "type": "BROKEN_LINK",
                        "emoji": "🔗",
                        "detail": f"Broken symlink → {target}",
                        "severity": "LOW",
                    })
                elif target.startswith('/') and not target.startswith(dirpath):
                    file_anomalies.append({
                        "type": "ESCAPE_LINK",
                        "emoji": "🚪",
                        "detail": f"Symlink escapes to {target}",
                        "severity": "MEDIUM",
                    })
            except (PermissionError, OSError):
                pass

        if file_anomalies:
            anomalies.append({
                "path": fstr,
                "name": fname,
                "size": fstat.st_size,
                "mode": oct(fstat.st_mode)[-4:],
                "anomalies": file_anomalies,
            })

    return anomalies


def generate_honeypot(dirpath: str, count: int = 20) -> List[Dict]:
    """Generate a honeypot filesystem with decoy files that look juicy."""
    os.makedirs(dirpath, exist_ok=True)
    decoys = []

    honeypot_files = [
        ("passwords.txt", "admin:password123\nroot:toor\nuser:changeme\n"),
        (".ssh/id_rsa", "-----BEGIN FAKE RSA PRIVATE KEY-----\n" + "A" * 64 + "\n" * 10 + "-----END FAKE RSA PRIVATE KEY-----\n"),
        ("database_backup.sql", "-- HONEYPOT DATABASE\nCREATE TABLE users (id INT, email VARCHAR(255), password VARCHAR(255));\nINSERT INTO users VALUES (1, 'admin@corp.com', 'HONEYPOT_HASH');\n"),
        (".env", "DATABASE_URL=postgresql://admin:HONEYPOT@localhost/production\nSECRET_KEY=FAKE_sk_live_4eC39HqLyjWDarjtT1zdp7dc\nAWS_ACCESS_KEY=AKIAI44QH8DHBHONEYPOT\n"),
        ("bitcoin_wallet.dat", "HONEYPOT WALLET - NOT REAL\n" + os.urandom(256).hex() + "\n"),
        ("vpn_credentials.conf", "# HONEYPOT VPN CONFIG\nremote vpn.corp.internal 1194\nauth-user-pass\n<secret>\nHONEYPOT_USER\nHONEYPOT_PASS\n</secret>\n"),
        ("api_keys.json", '{"stripe": "sk_test_HONEYPOT", "github": "ghp_HONEYPOT", "aws": "AKIA_HONEYPOT"}\n'),
        (".bash_history", "mysql -u root -p'realpassword123'\nssh admin@10.0.0.1\ncurl -H 'Authorization: Bearer HONEYPOT'\n"),
    ]

    for fname, content in honeypot_files[:count]:
        fpath = os.path.join(dirpath, fname)
        os.makedirs(os.path.dirname(fpath), exist_ok=True)
        with open(fpath, 'w') as f:
            f.write(content)

        decoys.append({
            "path": fpath,
            "name": fname,
            "size": len(content),
            "type": "HONEYPOT",
            "emoji": "🍯",
        })

    return decoys


def filesystem_fingerprint(dirpath: str) -> Dict:
    """Generate a fingerprint of a directory — detect future changes."""
    fingerprint = {
        "path": dirpath,
        "timestamp": time.time(),
        "files": {},
    }

    path = Path(dirpath)
    for fpath in path.rglob("*"):
        if fpath.is_file():
            try:
                stat_info = fpath.stat()
                with open(str(fpath), 'rb') as f:
                    file_hash = hashlib.sha256(f.read(65536)).hexdigest()[:16]

                rel = str(fpath.relative_to(dirpath))
                fingerprint["files"][rel] = {
                    "hash": file_hash,
                    "size": stat_info.st_size,
                    "mtime": stat_info.st_mtime,
                    "mode": oct(stat_info.st_mode)[-4:],
                }
            except (PermissionError, OSError):
                pass

    fingerprint["total_files"] = len(fingerprint["files"])
    fingerprint["signature"] = hashlib.sha256(
        str(sorted(fingerprint["files"].items())).encode()
    ).hexdigest()[:32]

    return fingerprint
