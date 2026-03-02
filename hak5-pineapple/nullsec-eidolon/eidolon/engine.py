"""
Eidolon Engine — Crafts ghost network packets and analyzes spectral traffic.
Creates decoy traffic patterns, eidolon listeners, and network mirages.
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
        # Random chaotic traffic — the wraith pattern
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


def decode_packet(hex_data: str) -> Dict:
    """
    Decode a raw hex packet string into human-readable layers.
    This is a hex packet dissector — NOT a port scanner (we already have 3).
    Takes raw hex (e.g. from tcpdump -xx, wireshark copy-as-hex) and
    rips it apart into Ethernet/IP/TCP/UDP layers.
    """
    try:
        raw = bytes.fromhex(hex_data.replace(" ", "").replace(":", "").replace("\n", ""))
    except ValueError:
        return {"error": "Invalid hex data", "raw_length": 0}

    result = {
        "raw_length": len(raw),
        "raw_hex": raw.hex(),
        "layers": [],
        "anomalies": [],
    }

    offset = 0

    # Layer 2 — Ethernet (14 bytes min)
    if len(raw) >= 14:
        dst_mac = ':'.join(f'{b:02x}' for b in raw[0:6])
        src_mac = ':'.join(f'{b:02x}' for b in raw[6:12])
        ethertype = struct.unpack("!H", raw[12:14])[0]

        eth_type_name = {
            0x0800: "IPv4", 0x86DD: "IPv6", 0x0806: "ARP",
            0x8100: "802.1Q VLAN", 0x88A8: "802.1ad QinQ",
        }.get(ethertype, f"Unknown (0x{ethertype:04x})")

        layer2 = {
            "name": "Ethernet",
            "emoji": "🔌",
            "dst_mac": dst_mac,
            "src_mac": src_mac,
            "ethertype": f"0x{ethertype:04x}",
            "ethertype_name": eth_type_name,
        }

        # Check for broadcast/multicast
        if dst_mac == "ff:ff:ff:ff:ff:ff":
            layer2["note"] = "BROADCAST"
        elif int(dst_mac.split(":")[0], 16) & 1:
            layer2["note"] = "MULTICAST"

        result["layers"].append(layer2)
        offset = 14

        # Layer 3 — IPv4
        if ethertype == 0x0800 and len(raw) >= offset + 20:
            version_ihl = raw[offset]
            version = (version_ihl >> 4) & 0xF
            ihl = (version_ihl & 0xF) * 4
            total_length = struct.unpack("!H", raw[offset+2:offset+4])[0]
            identification = struct.unpack("!H", raw[offset+4:offset+6])[0]
            flags_frag = struct.unpack("!H", raw[offset+6:offset+8])[0]
            flags = (flags_frag >> 13) & 0x7
            frag_offset = flags_frag & 0x1FFF
            ttl = raw[offset+8]
            protocol = raw[offset+9]
            checksum = struct.unpack("!H", raw[offset+10:offset+12])[0]
            src_ip = socket.inet_ntoa(raw[offset+12:offset+16])
            dst_ip = socket.inet_ntoa(raw[offset+16:offset+20])

            proto_name = {1: "ICMP", 6: "TCP", 17: "UDP", 47: "GRE", 50: "ESP"}.get(
                protocol, f"Proto-{protocol}")

            flag_strs = []
            if flags & 0x2: flag_strs.append("DF")
            if flags & 0x1: flag_strs.append("MF")

            layer3 = {
                "name": "IPv4",
                "emoji": "🌐",
                "version": version,
                "header_length": ihl,
                "total_length": total_length,
                "identification": f"0x{identification:04x}",
                "flags": ' '.join(flag_strs) or "none",
                "fragment_offset": frag_offset,
                "ttl": ttl,
                "protocol": proto_name,
                "protocol_num": protocol,
                "checksum": f"0x{checksum:04x}",
                "src_ip": src_ip,
                "dst_ip": dst_ip,
            }

            # TTL anomaly checks
            if ttl == 1:
                result["anomalies"].append("⚠️ TTL=1 — traceroute or about to expire")
            elif ttl > 200:
                result["anomalies"].append(f"🔍 Unusual TTL={ttl} (common: 64/128)")

            if version != 4:
                result["anomalies"].append(f"⚠️ Version={version} in IPv4 ethertype")

            result["layers"].append(layer3)
            offset += ihl

            # Layer 4 — TCP
            if protocol == 6 and len(raw) >= offset + 20:
                src_port = struct.unpack("!H", raw[offset:offset+2])[0]
                dst_port = struct.unpack("!H", raw[offset+2:offset+4])[0]
                seq = struct.unpack("!I", raw[offset+4:offset+8])[0]
                ack = struct.unpack("!I", raw[offset+8:offset+12])[0]
                data_offset = ((raw[offset+12] >> 4) & 0xF) * 4
                tcp_flags = raw[offset+13]

                flag_names = []
                if tcp_flags & 0x01: flag_names.append("FIN")
                if tcp_flags & 0x02: flag_names.append("SYN")
                if tcp_flags & 0x04: flag_names.append("RST")
                if tcp_flags & 0x08: flag_names.append("PSH")
                if tcp_flags & 0x10: flag_names.append("ACK")
                if tcp_flags & 0x20: flag_names.append("URG")

                window = struct.unpack("!H", raw[offset+14:offset+16])[0]
                tcp_checksum = struct.unpack("!H", raw[offset+16:offset+18])[0]

                layer4 = {
                    "name": "TCP",
                    "emoji": "🔗",
                    "src_port": src_port,
                    "dst_port": dst_port,
                    "src_service": _guess_service(src_port),
                    "dst_service": _guess_service(dst_port),
                    "seq": seq,
                    "ack": ack,
                    "data_offset": data_offset,
                    "flags": ' '.join(flag_names) or "none",
                    "flags_raw": f"0x{tcp_flags:02x}",
                    "window": window,
                    "checksum": f"0x{tcp_checksum:04x}",
                }

                # Christmas tree scan detection
                if tcp_flags == 0x29:  # FIN+PSH+URG
                    result["anomalies"].append("🎄 XMAS scan detected (FIN+PSH+URG)")
                if tcp_flags == 0x00:
                    result["anomalies"].append("👻 NULL scan detected (no flags)")
                if tcp_flags == 0x01:
                    result["anomalies"].append("🔍 FIN scan detected (only FIN)")

                result["layers"].append(layer4)
                payload_start = offset + data_offset
                if payload_start < len(raw):
                    payload_data = raw[payload_start:]
                    result["payload"] = {
                        "size": len(payload_data),
                        "hex": payload_data[:64].hex(),
                        "printable": ''.join(chr(b) if 32 <= b < 127 else '.' for b in payload_data[:64]),
                        "entropy": _calc_entropy(payload_data),
                    }

            # Layer 4 — UDP
            elif protocol == 17 and len(raw) >= offset + 8:
                src_port = struct.unpack("!H", raw[offset:offset+2])[0]
                dst_port = struct.unpack("!H", raw[offset+2:offset+4])[0]
                udp_length = struct.unpack("!H", raw[offset+4:offset+6])[0]
                udp_checksum = struct.unpack("!H", raw[offset+6:offset+8])[0]

                layer4 = {
                    "name": "UDP",
                    "emoji": "📡",
                    "src_port": src_port,
                    "dst_port": dst_port,
                    "src_service": _guess_service(src_port),
                    "dst_service": _guess_service(dst_port),
                    "length": udp_length,
                    "checksum": f"0x{udp_checksum:04x}",
                }
                result["layers"].append(layer4)

                payload_start = offset + 8
                if payload_start < len(raw):
                    payload_data = raw[payload_start:]
                    result["payload"] = {
                        "size": len(payload_data),
                        "hex": payload_data[:64].hex(),
                        "printable": ''.join(chr(b) if 32 <= b < 127 else '.' for b in payload_data[:64]),
                        "entropy": _calc_entropy(payload_data),
                    }

    if not result["layers"]:
        # Raw dump if we can't parse
        result["layers"].append({
            "name": "RAW",
            "emoji": "📦",
            "hex": raw[:128].hex(),
            "printable": ''.join(chr(b) if 32 <= b < 127 else '.' for b in raw[:128]),
        })

    return result


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
