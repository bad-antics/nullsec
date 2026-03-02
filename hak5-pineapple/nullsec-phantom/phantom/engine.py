"""
Phantom Engine — Crafts ghost network packets and analyzes spectral traffic.
Creates decoy traffic patterns, phantom listeners, and network mirages.
"""

import socket
import struct
import hashlib
import os
import time
import random
from typing import List, Dict, Optional


def craft_phantom_packet(dst_ip: str = "127.0.0.1", dst_port: int = 0,
                         payload: str = "", protocol: str = "tcp") -> Dict:
    """
    Craft a phantom packet — describes what would be sent without sending.
    Returns packet anatomy for analysis/education.
    """
    if not payload:
        payload = f"👻 PHANTOM #{random.randint(1000, 9999)} — {time.time()}"

    payload_bytes = payload.encode('utf-8')
    src_port = random.randint(49152, 65535)

    # Build packet anatomy
    packet = {
        "layer2": {
            "type": "Ethernet",
            "src_mac": _random_mac(),
            "dst_mac": _random_mac(),
            "ethertype": "0x0800",
        },
        "layer3": {
            "type": "IPv4",
            "version": 4,
            "header_length": 20,
            "ttl": random.choice([64, 128, 255]),
            "protocol": 6 if protocol == "tcp" else 17,
            "src_ip": _random_ip(),
            "dst_ip": dst_ip,
            "checksum": f"0x{random.randint(0, 65535):04x}",
        },
        "layer4": {
            "type": protocol.upper(),
            "src_port": src_port,
            "dst_port": dst_port or random.randint(1, 65535),
            "flags": _random_tcp_flags() if protocol == "tcp" else None,
            "seq": random.randint(0, 2**32 - 1),
            "ack": random.randint(0, 2**32 - 1),
        },
        "payload": {
            "data": payload,
            "size": len(payload_bytes),
            "hex": payload_bytes.hex(),
            "entropy": _calc_entropy(payload_bytes),
        },
        "phantom_id": hashlib.md5(f"{time.time()}{random.random()}".encode()).hexdigest()[:12],
    }

    return packet


def generate_traffic_pattern(pattern: str = "heartbeat",
                            count: int = 10) -> List[Dict]:
    """Generate a sequence of phantom packets following a traffic pattern."""
    packets = []

    if pattern == "heartbeat":
        # Regular interval beacon
        for i in range(count):
            pkt = craft_phantom_packet(
                dst_port=443,
                payload=f"💓 beat {i + 1}/{count}",
            )
            pkt["timing"] = {"delay_ms": 1000, "jitter_ms": random.randint(0, 50)}
            packets.append(pkt)

    elif pattern == "exfil":
        # Data exfiltration simulation — increasing payload sizes
        for i in range(count):
            size = 64 * (2 ** i)
            pkt = craft_phantom_packet(
                dst_port=53,  # DNS tunneling
                payload=f"📤 chunk_{i}: {'x' * min(size, 200)}",
            )
            pkt["timing"] = {"delay_ms": random.randint(100, 5000)}
            packets.append(pkt)

    elif pattern == "scan":
        # Port scan pattern
        ports = random.sample(range(1, 1024), min(count, 100))
        for port in ports[:count]:
            pkt = craft_phantom_packet(
                dst_port=port,
                payload="",
                protocol="tcp",
            )
            pkt["layer4"]["flags"] = "SYN"
            pkt["timing"] = {"delay_ms": random.randint(1, 100)}
            packets.append(pkt)

    elif pattern == "ghost":
        # Random chaotic traffic — the poltergeist pattern
        for i in range(count):
            pkt = craft_phantom_packet(
                dst_ip=_random_ip(),
                dst_port=random.randint(1, 65535),
                payload=os.urandom(random.randint(1, 100)).hex(),
                protocol=random.choice(["tcp", "udp"]),
            )
            pkt["timing"] = {"delay_ms": random.randint(0, 10000)}
            packets.append(pkt)

    return packets


def scan_open_ports(target: str = "127.0.0.1",
                    ports: Optional[List[int]] = None,
                    timeout: float = 0.5) -> List[Dict]:
    """Scan ports and report which ones have phantom listeners."""
    if ports is None:
        ports = [21, 22, 23, 25, 53, 80, 110, 143, 443, 993, 995,
                 3306, 5432, 6379, 8080, 8443, 9090, 27017]

    results = []
    for port in ports:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            result = sock.connect_ex((target, port))
            status = "ALIVE" if result == 0 else "SILENT"
            sock.close()
        except Exception:
            status = "ERROR"

        emoji = "👻" if status == "ALIVE" else "💀" if status == "SILENT" else "⚠️"
        results.append({
            "port": port,
            "status": status,
            "emoji": emoji,
            "service": _guess_service(port),
        })

    return results


def network_ghost_map() -> Dict:
    """Map the local network neighborhood — find all the ghosts."""
    result = {
        "hostname": socket.gethostname(),
        "interfaces": [],
        "connections": [],
    }

    # Get network interfaces
    try:
        import subprocess
        out = subprocess.run(["ip", "addr"], capture_output=True, text=True, timeout=5)
        if out.returncode == 0:
            for line in out.stdout.split("\n"):
                line = line.strip()
                if "inet " in line:
                    parts = line.split()
                    result["interfaces"].append({
                        "addr": parts[1],
                        "scope": parts[-1] if len(parts) > 1 else "unknown",
                    })
    except Exception:
        pass

    # Get active connections
    try:
        import subprocess
        out = subprocess.run(["ss", "-tuln"], capture_output=True, text=True, timeout=5)
        if out.returncode == 0:
            for line in out.stdout.strip().split("\n")[1:]:
                parts = line.split()
                if len(parts) >= 5:
                    result["connections"].append({
                        "type": parts[0],
                        "state": parts[1],
                        "local": parts[4],
                    })
    except Exception:
        pass

    return result


def _random_mac() -> str:
    return ':'.join(f'{random.randint(0, 255):02x}' for _ in range(6))

def _random_ip() -> str:
    return '.'.join(str(random.randint(1, 254)) for _ in range(4))

def _random_tcp_flags() -> str:
    flags = ["SYN", "ACK", "FIN", "RST", "PSH", "URG", "SYN-ACK"]
    return random.choice(flags)

def _calc_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    freq = {}
    for b in data:
        freq[b] = freq.get(b, 0) + 1
    import math
    entropy = 0.0
    for count in freq.values():
        p = count / len(data)
        entropy -= p * math.log2(p)
    return round(entropy, 2)

def _guess_service(port: int) -> str:
    services = {
        21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
        80: "HTTP", 110: "POP3", 143: "IMAP", 443: "HTTPS",
        993: "IMAPS", 995: "POP3S", 3306: "MySQL", 5432: "PostgreSQL",
        6379: "Redis", 8080: "HTTP-ALT", 8443: "HTTPS-ALT",
        9090: "Prometheus", 27017: "MongoDB",
    }
    return services.get(port, "unknown")
