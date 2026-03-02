"""
Mothman Engine — Network Interface Promiscuity & ARP Anomaly Detector.
If something is watching the network in the dark, mothman finds it.
Detects NICs in promiscuous mode, ARP table anomalies, duplicate MACs,
gratuitous ARP indicators, and rogue interface configurations.
"""

import os
import re
import subprocess
from typing import List, Dict, Optional
from pathlib import Path
from collections import defaultdict


def detect_promiscuous() -> List[Dict]:
    """Detect network interfaces in promiscuous mode."""
    findings = []

    # Method 1: Check /sys/class/net/*/flags
    net_path = Path("/sys/class/net")
    if net_path.exists():
        for iface_dir in net_path.iterdir():
            iface = iface_dir.name
            flags_path = iface_dir / "flags"
            try:
                flags_hex = flags_path.read_text().strip()
                flags = int(flags_hex, 16)
                # IFF_PROMISC = 0x100
                if flags & 0x100:
                    findings.append({
                        "interface": iface,
                        "emoji": "🔴",
                        "severity": "CRITICAL",
                        "method": "sysfs_flags",
                        "detail": f"Interface '{iface}' is in PROMISCUOUS mode (flags: {flags_hex})",
                        "flags": flags_hex,
                    })
            except (FileNotFoundError, PermissionError, ValueError):
                continue

    # Method 2: Check via ip link (cross-reference)
    try:
        result = subprocess.run(
            ["ip", "-d", "link", "show"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            current_iface = None
            for line in result.stdout.split('\n'):
                iface_match = re.match(r'\d+:\s+(\S+?)[@:]', line)
                if iface_match:
                    current_iface = iface_match.group(1)
                if current_iface and "PROMISC" in line:
                    # Avoid duplicates from method 1
                    existing = {f["interface"] for f in findings}
                    if current_iface not in existing:
                        findings.append({
                            "interface": current_iface,
                            "emoji": "🔴",
                            "severity": "CRITICAL",
                            "method": "ip_link",
                            "detail": f"Interface '{current_iface}' — PROMISC flag via ip link",
                        })
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Method 3: Check /proc/net/dev for unusual byte counts (heuristic)
    try:
        with open("/proc/net/dev", 'r') as f:
            lines = f.readlines()[2:]  # Skip header lines
        for line in lines:
            parts = line.split()
            if len(parts) >= 11:
                iface = parts[0].rstrip(':')
                if iface == "lo":
                    continue
                rx_bytes = int(parts[1])
                tx_bytes = int(parts[9])
                # Huge RX with very low TX = possible passive sniffing
                if rx_bytes > 0 and tx_bytes > 0:
                    ratio = rx_bytes / max(tx_bytes, 1)
                    if ratio > 100 and rx_bytes > 100_000_000:
                        findings.append({
                            "interface": iface,
                            "emoji": "🟡",
                            "severity": "MEDIUM",
                            "method": "traffic_ratio",
                            "detail": f"Interface '{iface}' has {ratio:.0f}:1 RX:TX ratio "
                                     f"({rx_bytes:,} RX / {tx_bytes:,} TX) — passive sniffing?",
                        })
    except (FileNotFoundError, PermissionError):
        pass

    return findings


def audit_arp_cache() -> Dict:
    """Audit the ARP cache for anomalies."""
    result = {
        "entries": [],
        "anomalies": [],
        "duplicate_macs": [],
        "duplicate_ips": [],
    }

    arp_entries = []

    # Parse /proc/net/arp
    try:
        with open("/proc/net/arp", 'r') as f:
            lines = f.readlines()[1:]  # Skip header
        for line in lines:
            parts = line.split()
            if len(parts) >= 6:
                entry = {
                    "ip": parts[0],
                    "hw_type": parts[1],
                    "flags": parts[2],
                    "mac": parts[3],
                    "mask": parts[4],
                    "device": parts[5],
                }
                arp_entries.append(entry)
    except (FileNotFoundError, PermissionError):
        pass

    result["entries"] = arp_entries

    # Check for duplicate MACs (different IPs, same MAC = ARP spoofing)
    mac_to_ips = defaultdict(list)
    ip_to_macs = defaultdict(list)

    for entry in arp_entries:
        mac = entry["mac"]
        ip = entry["ip"]
        if mac != "00:00:00:00:00:00":
            mac_to_ips[mac].append(ip)
            ip_to_macs[ip].append(mac)

    for mac, ips in mac_to_ips.items():
        if len(ips) > 1:
            result["duplicate_macs"].append({
                "mac": mac,
                "ips": ips,
                "emoji": "🔴",
                "severity": "CRITICAL",
                "detail": f"MAC {mac} resolves to {len(ips)} IPs: {', '.join(ips)} — ARP spoofing?",
            })
            result["anomalies"].append({
                "type": "DUPLICATE_MAC",
                "emoji": "🔴",
                "severity": "CRITICAL",
                "detail": f"MAC {mac} → {', '.join(ips)} (possible ARP spoofing)",
            })

    # Duplicate IPs (same IP, multiple MACs = ARP conflict/race)
    for ip, macs in ip_to_macs.items():
        if len(macs) > 1:
            result["duplicate_ips"].append({
                "ip": ip,
                "macs": macs,
                "emoji": "🔴",
                "severity": "CRITICAL",
                "detail": f"IP {ip} has {len(macs)} MACs: {', '.join(macs)} — ARP conflict!",
            })

    # Check for incomplete entries (0x0 flags = unresolved)
    for entry in arp_entries:
        if entry["flags"] == "0x0":
            result["anomalies"].append({
                "type": "INCOMPLETE",
                "emoji": "🟡",
                "severity": "LOW",
                "detail": f"Incomplete ARP entry: {entry['ip']} on {entry['device']}",
            })

    # Check for broadcast MACs in unicast positions
    for entry in arp_entries:
        if entry["mac"] == "ff:ff:ff:ff:ff:ff":
            result["anomalies"].append({
                "type": "BROADCAST_MAC",
                "emoji": "🟡",
                "severity": "MEDIUM",
                "detail": f"Broadcast MAC for unicast IP {entry['ip']} on {entry['device']}",
            })

    return result


def check_interfaces() -> List[Dict]:
    """Inventory all network interfaces with security-relevant info."""
    interfaces = []

    net_path = Path("/sys/class/net")
    if not net_path.exists():
        return interfaces

    for iface_dir in net_path.iterdir():
        iface = iface_dir.name
        info = {"name": iface, "warnings": []}

        # Read basic info
        for prop in ("address", "operstate", "mtu", "type", "speed"):
            prop_path = iface_dir / prop
            try:
                info[prop] = prop_path.read_text().strip()
            except (FileNotFoundError, PermissionError, OSError):
                info[prop] = None

        # Read flags
        try:
            flags_hex = (iface_dir / "flags").read_text().strip()
            flags = int(flags_hex, 16)
            info["flags"] = flags_hex
            info["up"] = bool(flags & 0x1)       # IFF_UP
            info["promisc"] = bool(flags & 0x100) # IFF_PROMISC
            info["noarp"] = bool(flags & 0x80)    # IFF_NOARP

            if info["promisc"]:
                info["warnings"].append("PROMISCUOUS mode active")
            if info["noarp"]:
                info["warnings"].append("ARP disabled (NOARP flag)")
        except (FileNotFoundError, PermissionError, ValueError):
            pass

        # Check for virtual/bridge/tunnel interfaces
        if (iface_dir / "bridge").exists():
            info["type_desc"] = "bridge"
        elif (iface_dir / "brport").exists():
            info["type_desc"] = "bridge port"
        elif (iface_dir / "bonding").exists():
            info["type_desc"] = "bond master"
        elif iface.startswith("veth"):
            info["type_desc"] = "virtual ethernet"
        elif iface.startswith("docker"):
            info["type_desc"] = "docker bridge"
        elif iface.startswith("tun") or iface.startswith("tap"):
            info["type_desc"] = "tunnel/tap"
            info["warnings"].append("Tunnel interface — may be VPN or attack channel")
        elif iface.startswith("wl"):
            info["type_desc"] = "wireless"
        elif iface == "lo":
            info["type_desc"] = "loopback"
        else:
            info["type_desc"] = "ethernet"

        # Check for unusual MAC (locally administered bit)
        mac = info.get("address", "")
        if mac and mac != "00:00:00:00:00:00":
            first_octet = int(mac.split(":")[0], 16) if ":" in mac else 0
            if first_octet & 0x02:
                info["warnings"].append(f"Locally administered MAC ({mac}) — may be spoofed")

        interfaces.append(info)

    return interfaces


def full_mothman_scan() -> Dict:
    """Full mothman scan — complete network anomaly detection."""
    return {
        "promiscuous": detect_promiscuous(),
        "arp_audit": audit_arp_cache(),
        "interfaces": check_interfaces(),
    }
