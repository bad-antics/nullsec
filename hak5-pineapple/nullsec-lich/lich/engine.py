"""
Lich Engine — Kernel Module & Rootkit Surface Scanner.
The lich commands the undead kernel — finds hidden modules,
checks taint flags, and scans for rootkit indicators.
"""

import os
import re
import subprocess
from typing import List, Dict, Optional
from pathlib import Path


# Known suspicious module names (common rootkits)
SUSPICIOUS_MODULES = {
    "diamorphine", "reptile", "bdvl", "azazel", "jynx", "jynx2",
    "vlany", "brootus", "suterusu", "adore-ng", "knark", "mood-nt",
    "rkloader", "override", "necurs", "phalanx", "kbeast", "enyelkm",
    "heroin", "suckit", "shv4", "shv5", "ark", "rkit",
}


def list_modules() -> List[Dict]:
    """List all loaded kernel modules with metadata."""
    modules = []

    try:
        with open("/proc/modules", 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 6:
                    name = parts[0]
                    size = int(parts[1])
                    used_count = int(parts[2])
                    used_by = parts[3].strip(',').split(',') if parts[3] != '-' else []
                    state = parts[4]  # Live, Loading, Unloading
                    address = parts[5] if len(parts) > 5 else "unknown"

                    suspicious = name.lower() in SUSPICIOUS_MODULES
                    out_of_tree = _check_out_of_tree(name)

                    modules.append({
                        "name": name,
                        "size": size,
                        "size_human": _human_size(size),
                        "used_count": used_count,
                        "used_by": [u for u in used_by if u],
                        "state": state,
                        "address": address,
                        "suspicious": suspicious,
                        "out_of_tree": out_of_tree,
                    })
    except (PermissionError, FileNotFoundError):
        pass

    return modules


def detect_hidden_modules() -> List[Dict]:
    """Detect potentially hidden kernel modules."""
    findings = []

    # Method 1: Compare /proc/modules with /sys/module
    proc_modules = set()
    sys_modules = set()

    try:
        with open("/proc/modules", 'r') as f:
            for line in f:
                proc_modules.add(line.split()[0])
    except (PermissionError, FileNotFoundError):
        pass

    sys_module_path = "/sys/module"
    if os.path.exists(sys_module_path):
        try:
            for entry in os.listdir(sys_module_path):
                # Only count entries that have a "sections" or "parameters" dir
                # (built-in params show up here too)
                if os.path.isdir(os.path.join(sys_module_path, entry)):
                    sys_modules.add(entry)
        except PermissionError:
            pass

    # Modules in /sys/module but not in /proc/modules could be hidden or built-in
    # Built-in modules appear in /sys/module but NOT /proc/modules (this is normal)
    # But we can check if they have a refcnt file (loadable modules have this)
    for mod in sys_modules - proc_modules:
        refcnt_path = os.path.join(sys_module_path, mod, "refcnt")
        if os.path.exists(refcnt_path):
            # Has refcnt but not in /proc/modules — potentially hidden
            findings.append({
                "module": mod,
                "type": "HIDDEN_FROM_PROC",
                "emoji": "👻",
                "severity": "CRITICAL",
                "detail": f"Module '{mod}' has refcnt in /sys/module but not listed in /proc/modules",
            })

    # Modules in /proc/modules but not in /sys/module
    for mod in proc_modules - sys_modules:
        findings.append({
            "module": mod,
            "type": "HIDDEN_FROM_SYS",
            "emoji": "🔍",
            "severity": "HIGH",
            "detail": f"Module '{mod}' in /proc/modules but not in /sys/module",
        })

    return findings


def check_kernel_taint() -> Dict:
    """Check kernel taint flags — indicators of non-standard modules."""
    result = {
        "tainted": False,
        "taint_value": 0,
        "flags": [],
    }

    TAINT_FLAGS = {
        0: ("P", "Proprietary module loaded"),
        1: ("F", "Module force-loaded"),
        2: ("S", "Kernel running on out-of-spec system"),
        3: ("R", "Module force-unloaded"),
        4: ("M", "Machine check exception occurred"),
        5: ("B", "Bad page referenced"),
        6: ("U", "User requested taint"),
        7: ("D", "Kernel died recently (OOPS or BUG)"),
        8: ("A", "ACPI table overridden"),
        9: ("W", "Warning issued"),
        10: ("C", "Module from staging tree"),
        11: ("I", "Platform firmware bug workaround"),
        12: ("O", "Out-of-tree module loaded"),
        13: ("E", "Unsigned module loaded"),
        14: ("L", "Soft lockup occurred"),
        15: ("K", "Kernel live-patched"),
        16: ("X", "Auxiliary taint (distro-specific)"),
        17: ("T", "Built with struct randomization plugin"),
    }

    try:
        with open("/proc/sys/kernel/tainted", 'r') as f:
            taint_value = int(f.read().strip())
        result["taint_value"] = taint_value
        result["tainted"] = taint_value != 0

        for bit, (flag, description) in TAINT_FLAGS.items():
            if taint_value & (1 << bit):
                severity = "CRITICAL" if flag in ("F", "R", "E") else \
                          "HIGH" if flag in ("O", "D") else "MEDIUM"
                result["flags"].append({
                    "flag": flag,
                    "bit": bit,
                    "description": description,
                    "severity": severity,
                })

    except (PermissionError, FileNotFoundError, ValueError):
        pass

    return result


def rootkit_indicators() -> List[Dict]:
    """Scan for common rootkit indicators."""
    findings = []

    # Check for suspicious /dev entries
    suspicious_devs = [
        "/dev/hdz0", "/dev/xdta", "/dev/.rd", "/dev/.bak",
        "/dev/.pizda", "/dev/ptyxx", "/dev/lkm",
    ]
    for dev in suspicious_devs:
        if os.path.exists(dev):
            findings.append({
                "type": "SUSPICIOUS_DEV",
                "emoji": "🔴",
                "severity": "CRITICAL",
                "detail": f"Suspicious device node: {dev} (rootkit indicator)",
            })

    # Check for hidden directories in /
    try:
        for entry in os.listdir("/"):
            if entry.startswith('.') and entry not in ('.', '..'):
                full = os.path.join("/", entry)
                if os.path.isdir(full):
                    findings.append({
                        "type": "HIDDEN_ROOT_DIR",
                        "emoji": "⚠️",
                        "severity": "HIGH",
                        "detail": f"Hidden directory in /: {full}",
                    })
    except PermissionError:
        pass

    # Check kernel version consistency
    try:
        with open("/proc/version", 'r') as f:
            proc_version = f.read().strip()
        uname_result = subprocess.run(["uname", "-r"], capture_output=True, text=True, timeout=5)
        if uname_result.returncode == 0:
            uname_version = uname_result.stdout.strip()
            if uname_version not in proc_version:
                findings.append({
                    "type": "VERSION_MISMATCH",
                    "emoji": "🔴",
                    "severity": "CRITICAL",
                    "detail": f"Kernel version mismatch: uname says {uname_version}, "
                             f"/proc/version says different",
                })
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Check for loaded suspicious modules
    modules = list_modules()
    for mod in modules:
        if mod["suspicious"]:
            findings.append({
                "type": "SUSPICIOUS_MODULE",
                "emoji": "☠️",
                "severity": "CRITICAL",
                "detail": f"Known rootkit module loaded: {mod['name']}",
            })
        if mod.get("out_of_tree"):
            findings.append({
                "type": "OOT_MODULE",
                "emoji": "🔍",
                "severity": "MEDIUM",
                "detail": f"Out-of-tree module: {mod['name']} ({mod['size_human']})",
            })

    # Check for syscall table modification indicators
    kallsyms = "/proc/kallsyms"
    if os.path.exists(kallsyms):
        try:
            with open(kallsyms, 'r') as f:
                first_line = f.readline()
            if first_line.startswith("0000000000000000"):
                findings.append({
                    "type": "KALLSYMS_RESTRICTED",
                    "emoji": "🔒",
                    "severity": "INFO",
                    "detail": "kallsyms addresses hidden (kptr_restrict enabled — good)",
                })
        except PermissionError:
            pass

    return findings


def full_lich_scan() -> Dict:
    """Complete lich scan — all kernel security checks."""
    modules = list_modules()
    return {
        "modules": modules,
        "module_count": len(modules),
        "hidden": detect_hidden_modules(),
        "taint": check_kernel_taint(),
        "rootkit_indicators": rootkit_indicators(),
    }


def _check_out_of_tree(module_name: str) -> bool:
    """Check if a module is out-of-tree."""
    taint_path = f"/sys/module/{module_name}/taint"
    if os.path.exists(taint_path):
        try:
            with open(taint_path, 'r') as f:
                taint = f.read().strip()
            return 'O' in taint or 'E' in taint
        except (PermissionError, FileNotFoundError):
            pass
    return False


def _human_size(size: int) -> str:
    for unit in ('B', 'KB', 'MB', 'GB'):
        if size < 1024:
            return f"{size:.0f}{unit}"
        size /= 1024
    return f"{size:.1f}TB"
