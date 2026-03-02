"""
Shade Engine — File Permission Anomaly Hunter.
Shades lurk in the darkness of file permissions — finding
world-writable configs, orphaned files, dangerous capabilities,
SGID binaries, and permission anomalies that shouldn't exist.
"""

import os
import stat
import subprocess
import pwd
import grp
from typing import List, Dict, Optional
from pathlib import Path


# Critical config files that should have strict permissions
CRITICAL_CONFIGS = {
    "/etc/passwd": {"max_mode": 0o644, "owner": 0},
    "/etc/shadow": {"max_mode": 0o640, "owner": 0},
    "/etc/sudoers": {"max_mode": 0o440, "owner": 0},
    "/etc/ssh/sshd_config": {"max_mode": 0o644, "owner": 0},
    "/etc/crontab": {"max_mode": 0o644, "owner": 0},
    "/etc/hosts": {"max_mode": 0o644, "owner": 0},
    "/etc/fstab": {"max_mode": 0o644, "owner": 0},
    "/etc/gshadow": {"max_mode": 0o640, "owner": 0},
}


def scan_world_writable(directories: Optional[List[str]] = None,
                        max_results: int = 200) -> List[Dict]:
    """Find world-writable files in sensitive directories."""
    if directories is None:
        directories = ["/etc", "/usr", "/var", "/opt", "/boot"]

    findings = []
    count = 0

    for directory in directories:
        if not os.path.exists(directory):
            continue
        try:
            for root, dirs, files in os.walk(directory):
                # Skip proc-like filesystems
                if root.startswith(("/proc", "/sys", "/dev")):
                    continue
                for fname in files:
                    if count >= max_results:
                        return findings
                    fpath = os.path.join(root, fname)
                    try:
                        st = os.lstat(fpath)
                        if stat.S_ISREG(st.st_mode) and st.st_mode & stat.S_IWOTH:
                            count += 1
                            findings.append({
                                "path": fpath,
                                "mode": oct(st.st_mode)[-4:],
                                "owner_uid": st.st_uid,
                                "owner": _uid_to_name(st.st_uid),
                                "size": st.st_size,
                                "severity": "CRITICAL" if fpath.startswith("/etc") else "HIGH",
                                "emoji": "🔓",
                                "detail": f"World-writable: {fpath} ({oct(st.st_mode)[-4:]})",
                            })
                    except (OSError, PermissionError):
                        pass
        except PermissionError:
            pass

    return findings


def find_orphaned_files(directories: Optional[List[str]] = None,
                        max_results: int = 100) -> List[Dict]:
    """Find files with UIDs/GIDs that don't map to any user/group."""
    if directories is None:
        directories = ["/home", "/tmp", "/var/tmp", "/opt"]

    # Build sets of valid UIDs and GIDs
    valid_uids = set()
    valid_gids = set()
    try:
        for p in pwd.getpwall():
            valid_uids.add(p.pw_uid)
    except Exception:
        pass
    try:
        for g in grp.getgrall():
            valid_gids.add(g.gr_gid)
    except Exception:
        pass

    findings = []
    count = 0

    for directory in directories:
        if not os.path.exists(directory):
            continue
        try:
            for root, dirs, files in os.walk(directory):
                for fname in files + dirs:
                    if count >= max_results:
                        return findings
                    fpath = os.path.join(root, fname)
                    try:
                        st = os.lstat(fpath)
                        orphan_reasons = []
                        if st.st_uid not in valid_uids:
                            orphan_reasons.append(f"UID {st.st_uid} has no user")
                        if st.st_gid not in valid_gids:
                            orphan_reasons.append(f"GID {st.st_gid} has no group")
                        if orphan_reasons:
                            count += 1
                            findings.append({
                                "path": fpath,
                                "uid": st.st_uid,
                                "gid": st.st_gid,
                                "reasons": orphan_reasons,
                                "severity": "MEDIUM",
                                "emoji": "👻",
                                "detail": f"Orphaned: {fpath} — {', '.join(orphan_reasons)}",
                            })
                    except (OSError, PermissionError):
                        pass
        except PermissionError:
            pass

    return findings


def audit_capabilities(directories: Optional[List[str]] = None) -> List[Dict]:
    """Find files with Linux capabilities set (privilege escalation surface)."""
    if directories is None:
        directories = ["/usr/bin", "/usr/sbin", "/usr/local/bin", "/bin", "/sbin"]

    findings = []

    # Dangerous capabilities
    DANGEROUS_CAPS = {
        "cap_sys_admin", "cap_sys_ptrace", "cap_sys_module",
        "cap_dac_override", "cap_dac_read_search", "cap_setuid",
        "cap_setgid", "cap_net_raw", "cap_net_admin", "cap_sys_rawio",
    }

    for directory in directories:
        if not os.path.exists(directory):
            continue
        try:
            result = subprocess.run(
                ["getcap", "-r", directory],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if not line or '=' not in line:
                        continue
                    parts = line.rsplit(' ', 1)
                    if len(parts) == 2:
                        fpath = parts[0].strip()
                        caps = parts[1].strip()
                        cap_names = set(re.findall(r'cap_\w+', caps.lower())) if 'cap_' in caps.lower() else set()
                        dangerous = cap_names & DANGEROUS_CAPS

                        severity = "HIGH" if dangerous else "MEDIUM"
                        findings.append({
                            "path": fpath,
                            "capabilities": caps,
                            "dangerous_caps": list(dangerous),
                            "severity": severity,
                            "emoji": "⚡" if dangerous else "🔍",
                            "detail": f"{fpath}: {caps}",
                        })
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    import re
    return findings


def check_config_perms() -> List[Dict]:
    """Check permissions on critical configuration files."""
    findings = []

    for config_path, expected in CRITICAL_CONFIGS.items():
        if not os.path.exists(config_path):
            continue
        try:
            st = os.stat(config_path)
            mode = stat.S_IMODE(st.st_mode)
            max_mode = expected["max_mode"]

            # Check if permissions are too open
            if mode & ~max_mode:
                findings.append({
                    "path": config_path,
                    "current_mode": oct(mode),
                    "expected_max": oct(max_mode),
                    "severity": "HIGH" if config_path in ("/etc/shadow", "/etc/sudoers") else "MEDIUM",
                    "emoji": "🔓",
                    "detail": f"{config_path}: mode {oct(mode)} (expected max {oct(max_mode)})",
                })

            # Check ownership
            if st.st_uid != expected["owner"]:
                findings.append({
                    "path": config_path,
                    "owner": _uid_to_name(st.st_uid),
                    "expected_owner": _uid_to_name(expected["owner"]),
                    "severity": "CRITICAL",
                    "emoji": "👤",
                    "detail": f"{config_path}: owned by {_uid_to_name(st.st_uid)} (expected {_uid_to_name(expected['owner'])})",
                })
        except (OSError, PermissionError):
            pass

    return findings


def find_sgid_binaries(directories: Optional[List[str]] = None) -> List[Dict]:
    """Find SGID binaries — group privilege escalation surface."""
    if directories is None:
        directories = ["/usr/bin", "/usr/sbin", "/usr/local/bin", "/bin", "/sbin"]

    findings = []
    for directory in directories:
        if not os.path.exists(directory):
            continue
        try:
            for entry in os.scandir(directory):
                try:
                    if entry.is_file() and entry.stat().st_mode & stat.S_ISGID:
                        st = entry.stat()
                        findings.append({
                            "path": entry.path,
                            "mode": oct(stat.S_IMODE(st.st_mode)),
                            "group": _gid_to_name(st.st_gid),
                            "severity": "MEDIUM",
                            "emoji": "🔑",
                            "detail": f"SGID: {entry.path} (group: {_gid_to_name(st.st_gid)})",
                        })
                except (OSError, PermissionError):
                    pass
        except PermissionError:
            pass

    return findings


def full_shade_scan() -> Dict:
    """Full shade scan — all permission anomaly checks."""
    return {
        "world_writable": scan_world_writable(),
        "orphaned": find_orphaned_files(),
        "capabilities": audit_capabilities(),
        "config_perms": check_config_perms(),
        "sgid_binaries": find_sgid_binaries(),
    }


def _uid_to_name(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)

def _gid_to_name(gid: int) -> str:
    try:
        return grp.getgrgid(gid).gr_name
    except KeyError:
        return str(gid)
