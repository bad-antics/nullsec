"""
Ghoul Engine — Shared Library Injection Detector.
Ghouls feed on the dead — and injected .so files feed on your processes.
Scans /proc/*/maps for suspicious libraries, detects LD_PRELOAD injection,
and audits library search paths for hijacking opportunities.
"""

import os
import re
import stat
from typing import List, Dict, Optional
from pathlib import Path
from collections import defaultdict


# Trusted library directories
TRUSTED_LIB_DIRS = {
    "/lib", "/lib64", "/lib/x86_64-linux-gnu", "/lib/aarch64-linux-gnu",
    "/usr/lib", "/usr/lib64", "/usr/lib/x86_64-linux-gnu",
    "/usr/local/lib", "/usr/local/lib64",
    "/usr/lib/x86_64-linux-gnu/libfakeroot",
}


def scan_loaded_libraries(pid: Optional[int] = None) -> List[Dict]:
    """
    Scan loaded shared libraries across processes for suspicious entries.
    If pid is given, scan only that process. Otherwise scan all accessible.
    """
    findings = []
    pids = [pid] if pid else _get_all_pids()

    for p in pids:
        maps_path = f"/proc/{p}/maps"
        try:
            with open(maps_path, 'r') as f:
                maps_data = f.read()
        except (PermissionError, FileNotFoundError):
            continue

        proc_name = _get_proc_name(p)
        seen_libs = set()

        for line in maps_data.split('\n'):
            if not line or '.so' not in line:
                continue

            parts = line.split()
            if len(parts) < 6:
                continue

            lib_path = parts[-1]
            if lib_path in seen_libs:
                continue
            seen_libs.add(lib_path)

            perms = parts[1]
            lib_dir = os.path.dirname(lib_path)

            # Check for suspicious library paths
            suspicious = False
            reasons = []

            # Library from /tmp, /dev/shm, /var/tmp, or home directory
            if any(lib_path.startswith(p) for p in ("/tmp/", "/dev/shm/", "/var/tmp/")):
                suspicious = True
                reasons.append("Loaded from world-writable directory")

            # Library from unusual location (not in trusted dirs)
            elif lib_dir not in TRUSTED_LIB_DIRS and not lib_dir.startswith("/snap/"):
                if ".so" in os.path.basename(lib_path):
                    # Only flag actual .so files, not memory-mapped regular files
                    if not lib_path.startswith(("/proc/", "/sys/")):
                        reasons.append(f"Non-standard library path: {lib_dir}")

            # Deleted library (still loaded in memory)
            if "(deleted)" in lib_path:
                suspicious = True
                reasons.append("Library deleted but still loaded — ghost injection")

            # Check if library is writable by non-root
            try:
                lib_stat = os.stat(lib_path.replace(" (deleted)", ""))
                if lib_stat.st_mode & stat.S_IWOTH:
                    suspicious = True
                    reasons.append("Library is WORLD-WRITABLE")
                elif lib_stat.st_mode & stat.S_IWGRP:
                    reasons.append("Library is group-writable")
            except (FileNotFoundError, OSError):
                if "(deleted)" not in lib_path:
                    reasons.append("Library file no longer exists")

            if suspicious or reasons:
                findings.append({
                    "pid": p,
                    "process": proc_name,
                    "library": lib_path,
                    "directory": lib_dir,
                    "permissions": perms,
                    "reasons": reasons,
                    "severity": "CRITICAL" if suspicious else "MEDIUM",
                    "emoji": "👹" if suspicious else "🔍",
                })

    return findings


def detect_preload_injection() -> List[Dict]:
    """Detect LD_PRELOAD injection across all processes."""
    findings = []

    for pid in _get_all_pids():
        env_path = f"/proc/{pid}/environ"
        try:
            with open(env_path, 'rb') as f:
                env_data = f.read()
        except (PermissionError, FileNotFoundError):
            continue

        # Environment variables are null-separated
        env_vars = env_data.split(b'\x00')
        proc_name = _get_proc_name(pid)

        for var in env_vars:
            try:
                var_str = var.decode('utf-8', errors='replace')
            except Exception:
                continue

            if var_str.startswith("LD_PRELOAD="):
                preload_value = var_str[11:]
                libs = [l.strip() for l in preload_value.split(":") if l.strip()]

                for lib in libs:
                    lib_exists = os.path.exists(lib)
                    findings.append({
                        "pid": pid,
                        "process": proc_name,
                        "preloaded_lib": lib,
                        "lib_exists": lib_exists,
                        "severity": "CRITICAL",
                        "emoji": "💉",
                        "detail": f"LD_PRELOAD injection: {lib}" + (" (MISSING!)" if not lib_exists else ""),
                    })

            elif var_str.startswith("LD_AUDIT="):
                audit_value = var_str[9:]
                findings.append({
                    "pid": pid,
                    "process": proc_name,
                    "preloaded_lib": audit_value,
                    "severity": "CRITICAL",
                    "emoji": "💉",
                    "detail": f"LD_AUDIT injection: {audit_value}",
                })

            elif var_str.startswith("LD_LIBRARY_PATH="):
                ld_path = var_str[16:]
                for d in ld_path.split(":"):
                    d = d.strip()
                    if d and os.path.exists(d):
                        try:
                            st = os.stat(d)
                            if st.st_mode & stat.S_IWOTH:
                                findings.append({
                                    "pid": pid,
                                    "process": proc_name,
                                    "preloaded_lib": d,
                                    "severity": "HIGH",
                                    "emoji": "🔓",
                                    "detail": f"LD_LIBRARY_PATH includes world-writable dir: {d}",
                                })
                        except OSError:
                            pass

    return findings


def audit_library_paths() -> List[Dict]:
    """Audit system library search paths for hijacking opportunities."""
    findings = []

    # Check /etc/ld.so.conf and includes
    ld_conf_paths = ["/etc/ld.so.conf"]
    conf_dir = "/etc/ld.so.conf.d"
    if os.path.isdir(conf_dir):
        try:
            for f in os.listdir(conf_dir):
                if f.endswith('.conf'):
                    ld_conf_paths.append(os.path.join(conf_dir, f))
        except PermissionError:
            pass

    all_lib_dirs = set()
    for conf_path in ld_conf_paths:
        try:
            with open(conf_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and not line.startswith('include'):
                        all_lib_dirs.add(line)
        except (PermissionError, FileNotFoundError):
            pass

    # Check each directory
    for lib_dir in sorted(all_lib_dirs):
        if not os.path.exists(lib_dir):
            findings.append({
                "path": lib_dir,
                "severity": "LOW",
                "emoji": "👻",
                "detail": f"Configured lib path doesn't exist: {lib_dir}",
            })
            continue

        try:
            st = os.stat(lib_dir)
            if st.st_mode & stat.S_IWOTH:
                findings.append({
                    "path": lib_dir,
                    "severity": "CRITICAL",
                    "emoji": "🔓",
                    "detail": f"World-writable library path: {lib_dir}",
                })
            if st.st_uid != 0:
                findings.append({
                    "path": lib_dir,
                    "severity": "HIGH",
                    "emoji": "👤",
                    "detail": f"Library path not owned by root (UID {st.st_uid}): {lib_dir}",
                })
        except OSError:
            pass

    # Check ld.so.cache freshness
    cache_path = "/etc/ld.so.cache"
    if os.path.exists(cache_path):
        try:
            cache_mtime = os.path.getmtime(cache_path)
            age_days = (import_time() - cache_mtime) / 86400
            if age_days > 90:
                findings.append({
                    "path": cache_path,
                    "severity": "LOW",
                    "emoji": "🕰️",
                    "detail": f"ld.so.cache is {int(age_days)} days old — may be stale",
                })
        except OSError:
            pass

    return findings


def full_ghoul_scan() -> Dict:
    """Complete ghoul scan — all library injection checks."""
    return {
        "loaded_libraries": scan_loaded_libraries(),
        "preload_injection": detect_preload_injection(),
        "library_paths": audit_library_paths(),
    }


def _get_all_pids() -> List[int]:
    """Get all accessible PIDs."""
    pids = []
    try:
        for entry in os.listdir("/proc"):
            if entry.isdigit():
                pids.append(int(entry))
    except PermissionError:
        pass
    return pids


def _get_proc_name(pid: int) -> str:
    """Get process name."""
    try:
        with open(f"/proc/{pid}/comm", 'r') as f:
            return f.read().strip()
    except (PermissionError, FileNotFoundError):
        return "?"


def import_time():
    """Get current time."""
    import time
    return time.time()
