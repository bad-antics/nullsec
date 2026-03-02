"""
Djinn Engine — Container Escape Surface Analyzer.
The djinn is trapped in a bottle — but always looking for a way out.
Analyzes container isolation: Docker socket, capabilities, namespaces,
mounted host paths, and privilege escalation surfaces.
"""

import os
import re
import subprocess
from typing import List, Dict, Optional
from pathlib import Path


def detect_container() -> Dict:
    """Detect if we're running inside a container and what kind."""
    result = {
        "in_container": False,
        "container_type": None,
        "container_id": None,
        "indicators": [],
    }

    # Check /.dockerenv
    if os.path.exists("/.dockerenv"):
        result["in_container"] = True
        result["container_type"] = "Docker"
        result["indicators"].append("/.dockerenv exists")

    # Check /run/.containerenv (Podman)
    if os.path.exists("/run/.containerenv"):
        result["in_container"] = True
        result["container_type"] = result.get("container_type") or "Podman"
        result["indicators"].append("/run/.containerenv exists")

    # Check cgroup for container ID
    try:
        with open("/proc/1/cgroup", 'r') as f:
            cgroup = f.read()
        if "docker" in cgroup:
            result["in_container"] = True
            result["container_type"] = result["container_type"] or "Docker"
            result["indicators"].append("Docker found in cgroup")
            # Extract container ID
            match = re.search(r'docker[/-]([a-f0-9]{64})', cgroup)
            if match:
                result["container_id"] = match.group(1)[:12]
        elif "kubepods" in cgroup or "k8s" in cgroup:
            result["in_container"] = True
            result["container_type"] = "Kubernetes"
            result["indicators"].append("Kubernetes pod detected in cgroup")
        elif "lxc" in cgroup:
            result["in_container"] = True
            result["container_type"] = "LXC"
            result["indicators"].append("LXC container detected in cgroup")
    except (FileNotFoundError, PermissionError):
        pass

    # Check for container-specific environment
    for env_var in ("KUBERNETES_SERVICE_HOST", "KUBERNETES_PORT"):
        if os.environ.get(env_var):
            result["in_container"] = True
            result["container_type"] = "Kubernetes"
            result["indicators"].append(f"{env_var} set")

    # Check PID 1 name
    try:
        with open("/proc/1/comm", 'r') as f:
            init = f.read().strip()
        if init not in ("systemd", "init", "launchd"):
            result["indicators"].append(f"PID 1 is '{init}' (not init/systemd)")
    except (FileNotFoundError, PermissionError):
        pass

    return result


def audit_escape_surface() -> List[Dict]:
    """Audit container escape vectors — the djinn's escape routes."""
    findings = []

    # Docker socket access
    docker_sockets = ["/var/run/docker.sock", "/run/docker.sock"]
    for sock_path in docker_sockets:
        if os.path.exists(sock_path):
            writable = os.access(sock_path, os.W_OK)
            findings.append({
                "vector": "DOCKER_SOCKET",
                "emoji": "🔴" if writable else "🟡",
                "severity": "CRITICAL" if writable else "HIGH",
                "detail": f"Docker socket accessible: {sock_path}" +
                         (" (WRITABLE — full escape!)" if writable else " (read-only)"),
                "exploitable": writable,
            })

    # Privileged mode check
    try:
        with open("/proc/1/status", 'r') as f:
            status = f.read()
        cap_match = re.search(r'CapEff:\s+([0-9a-f]+)', status)
        if cap_match:
            cap_eff = int(cap_match.group(1), 16)
            # 0x3fffffffff = all capabilities
            if cap_eff >= 0x3fffffffff:
                findings.append({
                    "vector": "PRIVILEGED_MODE",
                    "emoji": "🔴",
                    "severity": "CRITICAL",
                    "detail": "Container running in PRIVILEGED mode — full capability set",
                    "exploitable": True,
                })
    except (FileNotFoundError, PermissionError):
        pass

    # Sensitive host mounts
    sensitive_mounts = {
        "/": "Host root filesystem",
        "/etc": "Host /etc",
        "/root": "Host root home",
        "/var/run": "Host runtime dir",
        "/proc/sysrq-trigger": "SysRq trigger",
        "/sys/fs/cgroup": "Cgroup filesystem",
        "/dev": "Host devices",
    }

    try:
        with open("/proc/mounts", 'r') as f:
            mounts = f.read()
        for mount_line in mounts.split('\n'):
            parts = mount_line.split()
            if len(parts) >= 2:
                mount_point = parts[1]
                for sensitive_path, desc in sensitive_mounts.items():
                    if mount_point == sensitive_path and parts[0] not in ("proc", "sysfs", "tmpfs", "cgroup"):
                        findings.append({
                            "vector": "SENSITIVE_MOUNT",
                            "emoji": "⚠️",
                            "severity": "HIGH",
                            "detail": f"Sensitive mount: {parts[0]} → {mount_point} ({desc})",
                            "exploitable": True,
                        })
    except (FileNotFoundError, PermissionError):
        pass

    # Check for host PID namespace
    try:
        # If we can see host processes, we might be in host PID namespace
        pid_count = len([p for p in os.listdir("/proc") if p.isdigit()])
        if pid_count > 100:
            findings.append({
                "vector": "HOST_PID_NS",
                "emoji": "🟡",
                "severity": "MEDIUM",
                "detail": f"Can see {pid_count} processes — possibly sharing host PID namespace",
            })
    except PermissionError:
        pass

    # Check for host network namespace
    try:
        result = subprocess.run(
            ["ip", "link", "show"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            interfaces = [l for l in result.stdout.split('\n') if ': ' in l and 'lo' not in l]
            if len(interfaces) > 3:
                findings.append({
                    "vector": "HOST_NET_NS",
                    "emoji": "🟡",
                    "severity": "MEDIUM",
                    "detail": f"Multiple network interfaces ({len(interfaces)}) — possibly host network",
                })
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return findings


def check_capabilities() -> Dict:
    """Check Linux capabilities of the current process."""
    result = {
        "effective": [],
        "permitted": [],
        "bounding": [],
        "dangerous": [],
    }

    # Capability names
    CAP_NAMES = {
        0: "CAP_CHOWN", 1: "CAP_DAC_OVERRIDE", 2: "CAP_DAC_READ_SEARCH",
        3: "CAP_FOWNER", 4: "CAP_FSETID", 5: "CAP_KILL",
        6: "CAP_SETGID", 7: "CAP_SETUID", 8: "CAP_SETPCAP",
        9: "CAP_LINUX_IMMUTABLE", 10: "CAP_NET_BIND_SERVICE",
        11: "CAP_NET_BROADCAST", 12: "CAP_NET_ADMIN", 13: "CAP_NET_RAW",
        14: "CAP_IPC_LOCK", 15: "CAP_IPC_OWNER", 16: "CAP_SYS_MODULE",
        17: "CAP_SYS_RAWIO", 18: "CAP_SYS_CHROOT", 19: "CAP_SYS_PTRACE",
        20: "CAP_SYS_PACCT", 21: "CAP_SYS_ADMIN", 22: "CAP_SYS_BOOT",
        23: "CAP_SYS_NICE", 24: "CAP_SYS_RESOURCE", 25: "CAP_SYS_TIME",
        26: "CAP_SYS_TTY_CONFIG", 27: "CAP_MKNOD", 28: "CAP_LEASE",
        29: "CAP_AUDIT_WRITE", 30: "CAP_AUDIT_CONTROL", 31: "CAP_SETFCAP",
    }

    DANGEROUS_CAPS = {
        "CAP_SYS_ADMIN", "CAP_SYS_PTRACE", "CAP_SYS_MODULE",
        "CAP_DAC_OVERRIDE", "CAP_DAC_READ_SEARCH", "CAP_NET_ADMIN",
        "CAP_NET_RAW", "CAP_SYS_RAWIO", "CAP_SETUID", "CAP_SETGID",
    }

    try:
        with open("/proc/self/status", 'r') as f:
            status = f.read()

        for cap_type, cap_key in [("effective", "CapEff"),
                                   ("permitted", "CapPrm"),
                                   ("bounding", "CapBnd")]:
            match = re.search(rf'{cap_key}:\s+([0-9a-f]+)', status)
            if match:
                cap_val = int(match.group(1), 16)
                caps = []
                for bit, name in CAP_NAMES.items():
                    if cap_val & (1 << bit):
                        caps.append(name)
                        if name in DANGEROUS_CAPS and cap_type == "effective":
                            result["dangerous"].append({
                                "cap": name,
                                "bit": bit,
                                "type": cap_type,
                                "severity": "CRITICAL" if name == "CAP_SYS_ADMIN" else "HIGH",
                            })
                result[cap_type] = caps

    except (FileNotFoundError, PermissionError):
        pass

    return result


def check_namespaces() -> Dict:
    """Check namespace isolation."""
    result = {"namespaces": [], "shared_with_host": []}

    NS_TYPES = ["cgroup", "ipc", "mnt", "net", "pid", "user", "uts"]
    pid1_ns = {}
    self_ns = {}

    for ns in NS_TYPES:
        try:
            pid1_link = os.readlink(f"/proc/1/ns/{ns}")
            pid1_ns[ns] = pid1_link
        except (FileNotFoundError, PermissionError):
            pass
        try:
            self_link = os.readlink(f"/proc/self/ns/{ns}")
            self_ns[ns] = self_link
        except (FileNotFoundError, PermissionError):
            pass

    for ns in NS_TYPES:
        if ns in self_ns:
            shared = pid1_ns.get(ns) == self_ns.get(ns)
            result["namespaces"].append({
                "type": ns,
                "id": self_ns[ns],
                "shared_with_init": shared,
            })

    return result


def full_djinn_scan() -> Dict:
    """Full djinn scan — complete container security assessment."""
    return {
        "container": detect_container(),
        "escape_surface": audit_escape_surface(),
        "capabilities": check_capabilities(),
        "namespaces": check_namespaces(),
    }
