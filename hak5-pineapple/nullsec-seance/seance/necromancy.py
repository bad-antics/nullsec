"""
Séance Engine — Resurrect dead connections and commune with ghost traffic.
Analyzes connection history, DNS caches, ARP tables, and network tombstones.
"""

import os
import subprocess
import time
import socket
import hashlib
from typing import List, Dict, Optional
from pathlib import Path


def resurrect_connections() -> List[Dict]:
    """Query the system for dead/closed connections — ghost traffic."""
    ghosts = []

    # Check /proc/net/tcp for TIME_WAIT and CLOSE_WAIT states
    try:
        with open("/proc/net/tcp", 'r') as f:
            lines = f.readlines()[1:]  # Skip header

        states = {
            "01": "ESTABLISHED", "02": "SYN_SENT", "03": "SYN_RECV",
            "04": "FIN_WAIT1", "05": "FIN_WAIT2", "06": "TIME_WAIT",
            "07": "CLOSE", "08": "CLOSE_WAIT", "09": "LAST_ACK",
            "0A": "LISTEN", "0B": "CLOSING",
        }

        ghost_states = {"06", "07", "08", "09", "0B"}  # The dead/dying states

        for line in lines:
            parts = line.strip().split()
            if len(parts) < 4:
                continue

            state = parts[3]
            if state in ghost_states:
                local = _decode_addr(parts[1])
                remote = _decode_addr(parts[2])
                ghosts.append({
                    "local": local,
                    "remote": remote,
                    "state": states.get(state, state),
                    "emoji": "💀" if state in {"07", "09"} else "👻",
                    "type": "tcp",
                })
    except (PermissionError, FileNotFoundError):
        pass

    return ghosts


def dns_graveyard() -> List[Dict]:
    """Dig through DNS caches and resolution history."""
    graves = []

    # Check /etc/hosts for manually pinned entries
    try:
        with open("/etc/hosts", 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    parts = line.split()
                    if len(parts) >= 2:
                        graves.append({
                            "type": "TOMBSTONE",
                            "ip": parts[0],
                            "names": parts[1:],
                            "source": "/etc/hosts",
                            "emoji": "⚰️",
                        })
    except FileNotFoundError:
        pass

    # Check resolv.conf for configured nameservers
    try:
        with open("/etc/resolv.conf", 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith("nameserver"):
                    ns = line.split()[1]
                    graves.append({
                        "type": "NECROMANCER",
                        "ip": ns,
                        "names": ["(DNS resolver)"],
                        "source": "/etc/resolv.conf",
                        "emoji": "🧙",
                    })
    except FileNotFoundError:
        pass

    return graves


def arp_spirits() -> List[Dict]:
    """Read the ARP table — MAC addresses of nearby spirits."""
    spirits = []

    try:
        with open("/proc/net/arp", 'r') as f:
            lines = f.readlines()[1:]

        for line in lines:
            parts = line.split()
            if len(parts) >= 6:
                mac = parts[3]
                ip = parts[0]
                device = parts[5]

                # Detect suspicious entries
                anomalies = []
                if mac == "00:00:00:00:00:00":
                    anomalies.append("INVISIBLE — zero MAC address")
                if mac == "ff:ff:ff:ff:ff:ff":
                    anomalies.append("BROADCAST — screaming at everyone")

                spirits.append({
                    "ip": ip,
                    "mac": mac,
                    "device": device,
                    "anomalies": anomalies,
                    "emoji": "👤" if not anomalies else "⚠️",
                    "fingerprint": hashlib.md5(mac.encode()).hexdigest()[:8],
                })
    except (PermissionError, FileNotFoundError):
        pass

    return spirits


def commune_with_port(host: str, port: int, timeout: float = 3.0) -> Dict:
    """
    Attempt to commune with a specific port — what spirit answers?
    Sends various probes and records the response.
    """
    result = {
        "host": host,
        "port": port,
        "alive": False,
        "banner": None,
        "response": None,
        "spirit_type": "UNKNOWN",
    }

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        result["alive"] = True

        # Try to grab banner
        try:
            sock.send(b"\r\n")
            banner = sock.recv(1024)
            result["banner"] = banner.decode('utf-8', errors='replace').strip()[:200]
        except socket.timeout:
            pass

        # Try HTTP probe
        if not result["banner"]:
            try:
                sock.close()
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(timeout)
                sock.connect((host, port))
                sock.send(b"GET / HTTP/1.0\r\nHost: localhost\r\n\r\n")
                resp = sock.recv(2048)
                result["response"] = resp.decode('utf-8', errors='replace')[:300]
                if b"HTTP/" in resp:
                    result["spirit_type"] = "HTTP_SPIRIT"
            except (socket.timeout, ConnectionResetError):
                pass

        sock.close()

        # Identify the spirit
        if result["banner"]:
            banner_lower = result["banner"].lower()
            if "ssh" in banner_lower:
                result["spirit_type"] = "SSH_DAEMON"
            elif "smtp" in banner_lower:
                result["spirit_type"] = "MAIL_SPIRIT"
            elif "ftp" in banner_lower:
                result["spirit_type"] = "FTP_WRAITH"
            elif "mysql" in banner_lower:
                result["spirit_type"] = "DATABASE_SPECTER"

    except (ConnectionRefusedError, socket.timeout, OSError):
        result["spirit_type"] = "DEPARTED"

    return result


def network_autopsy() -> Dict:
    """Full autopsy of the network — routing table, interfaces, all of it."""
    autopsy = {
        "timestamp": time.time(),
        "routing_table": [],
        "interfaces": [],
        "listening_spirits": [],
    }

    # Routing table
    try:
        with open("/proc/net/route", 'r') as f:
            for line in f.readlines()[1:]:
                parts = line.split()
                if len(parts) >= 8:
                    autopsy["routing_table"].append({
                        "iface": parts[0],
                        "destination": _hex_to_ip(parts[1]),
                        "gateway": _hex_to_ip(parts[2]),
                        "mask": _hex_to_ip(parts[7]),
                    })
    except FileNotFoundError:
        pass

    # Listening ports
    try:
        with open("/proc/net/tcp", 'r') as f:
            for line in f.readlines()[1:]:
                parts = line.strip().split()
                if len(parts) >= 4 and parts[3] == "0A":  # LISTEN state
                    addr = _decode_addr(parts[1])
                    autopsy["listening_spirits"].append({
                        "address": addr,
                        "emoji": "👂",
                    })
    except (PermissionError, FileNotFoundError):
        pass

    return autopsy


def _decode_addr(hex_addr: str) -> str:
    """Decode /proc/net/tcp hex address to ip:port."""
    try:
        ip_hex, port_hex = hex_addr.split(':')
        ip_int = int(ip_hex, 16)
        ip = f"{ip_int & 0xff}.{(ip_int >> 8) & 0xff}.{(ip_int >> 16) & 0xff}.{(ip_int >> 24) & 0xff}"
        port = int(port_hex, 16)
        return f"{ip}:{port}"
    except (ValueError, IndexError):
        return hex_addr


def _hex_to_ip(hex_ip: str) -> str:
    """Convert hex IP from /proc/net/route to dotted decimal."""
    try:
        ip_int = int(hex_ip, 16)
        return f"{ip_int & 0xff}.{(ip_int >> 8) & 0xff}.{(ip_int >> 16) & 0xff}.{(ip_int >> 24) & 0xff}"
    except ValueError:
        return hex_ip
