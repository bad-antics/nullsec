"""
Voodoo Engine — Stick pins in process memory.
Reads /proc/PID/maps and /proc/PID/mem for live memory analysis,
finds strings, patterns, and cursed data in running processes.
"""

import os
import re
import struct
import hashlib
from typing import List, Dict, Optional


def read_memory_map(pid: int) -> List[Dict]:
    """Read the memory map of a process — see all its memory regions."""
    regions = []

    try:
        with open(f"/proc/{pid}/maps", 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 1:
                    addr_range = parts[0]
                    perms = parts[1] if len(parts) > 1 else "????"
                    path = parts[-1] if len(parts) >= 6 else "[anonymous]"

                    start_hex, end_hex = addr_range.split('-')
                    size = int(end_hex, 16) - int(start_hex, 16)

                    # Classify the region
                    region_type = "UNKNOWN"
                    if "[stack]" in line:
                        region_type = "STACK"
                    elif "[heap]" in line:
                        region_type = "HEAP"
                    elif "[vdso]" in line:
                        region_type = "VDSO"
                    elif ".so" in line:
                        region_type = "SHARED_LIB"
                    elif path.startswith("/"):
                        region_type = "FILE_BACKED"
                    else:
                        region_type = "ANONYMOUS"

                    # Security assessment
                    cursed = []
                    if 'w' in perms and 'x' in perms:
                        cursed.append("🔥 WX — writable AND executable!")
                    if region_type == "ANONYMOUS" and 'x' in perms:
                        cursed.append("💀 Anonymous executable memory — shellcode?")

                    regions.append({
                        "address": addr_range,
                        "size": size,
                        "size_human": _human_size(size),
                        "permissions": perms,
                        "type": region_type,
                        "path": path,
                        "cursed": cursed,
                        "emoji": _region_emoji(region_type),
                    })
    except (PermissionError, FileNotFoundError, ProcessLookupError):
        pass

    return regions


def stick_pin(pid: int, address: int, length: int = 256) -> Dict:
    """
    Stick a voodoo pin into a specific memory address.
    Read raw bytes from process memory.
    """
    result = {
        "pid": pid,
        "address": f"0x{address:016x}",
        "length": length,
        "success": False,
    }

    try:
        with open(f"/proc/{pid}/mem", 'rb') as mem:
            mem.seek(address)
            data = mem.read(length)
            result["success"] = True
            result["hex_dump"] = _hex_dump(data, address)
            result["strings"] = _extract_strings(data)
            result["entropy"] = _calc_entropy(data)

            # Look for interesting patterns
            result["patterns"] = []
            if b"\x90\x90\x90\x90" in data:
                result["patterns"].append("🦠 NOP sled detected!")
            if b"\xcc" in data:
                result["patterns"].append("🔴 INT3 breakpoint found")
            if b"/bin/sh" in data or b"/bin/bash" in data:
                result["patterns"].append("💀 Shell reference in memory!")
            if b"password" in data.lower() or b"secret" in data.lower():
                result["patterns"].append("🔑 Credential-like string!")

    except (PermissionError, OSError, ValueError) as e:
        result["error"] = str(e)

    return result


def find_strings_in_memory(pid: int, pattern: str = None,
                           min_length: int = 6) -> List[Dict]:
    """Search process memory for strings — extract the souls of data."""
    results = []

    regions = read_memory_map(pid)
    readable_regions = [r for r in regions if 'r' in r['permissions']]

    try:
        with open(f"/proc/{pid}/mem", 'rb') as mem:
            for region in readable_regions[:20]:  # Limit to prevent hanging
                start_hex = region['address'].split('-')[0]
                start = int(start_hex, 16)
                size = min(region['size'], 1024 * 1024)  # Cap at 1MB per region

                try:
                    mem.seek(start)
                    data = mem.read(size)
                except (OSError, ValueError):
                    continue

                strings = _extract_strings(data, min_length)
                for s in strings:
                    if pattern and pattern.lower() not in s.lower():
                        continue
                    results.append({
                        "string": s[:200],
                        "region": region['type'],
                        "address_range": region['address'],
                    })

                if len(results) > 500:
                    break
    except (PermissionError, FileNotFoundError):
        pass

    return results


def create_voodoo_doll(pid: int) -> Dict:
    """
    Create a 'voodoo doll' — a complete process profile showing
    all its memory regions, interesting strings, and cursed areas.
    """
    doll = {
        "pid": pid,
        "exists": os.path.exists(f"/proc/{pid}"),
    }

    if not doll["exists"]:
        doll["verdict"] = "💨 This soul has already departed."
        return doll

    # Get process info
    try:
        with open(f"/proc/{pid}/comm", 'r') as f:
            doll["name"] = f.read().strip()
    except (PermissionError, FileNotFoundError):
        doll["name"] = "???"

    try:
        with open(f"/proc/{pid}/status", 'r') as f:
            status = f.read()
            for line in status.split('\n'):
                if line.startswith('VmRSS:'):
                    doll["memory_rss"] = line.split(':')[1].strip()
                elif line.startswith('Threads:'):
                    doll["threads"] = line.split(':')[1].strip()
                elif line.startswith('Uid:'):
                    doll["uid"] = line.split(':')[1].strip().split()[0]
    except (PermissionError, FileNotFoundError):
        pass

    # Memory map summary
    regions = read_memory_map(pid)
    doll["total_regions"] = len(regions)
    doll["cursed_regions"] = sum(1 for r in regions if r['cursed'])
    doll["total_memory"] = sum(r['size'] for r in regions)
    doll["total_memory_human"] = _human_size(doll["total_memory"])
    doll["region_types"] = {}
    for r in regions:
        t = r['type']
        doll["region_types"][t] = doll["region_types"].get(t, 0) + 1

    # Find cursed regions
    doll["curses"] = []
    for r in regions:
        for curse in r['cursed']:
            doll["curses"].append(f"{r['address']}: {curse}")

    return doll


def _hex_dump(data: bytes, base_addr: int = 0) -> str:
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        hex_part = ' '.join(f'{b:02x}' for b in chunk)
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '·' for b in chunk)
        lines.append(f"  {base_addr + i:016x}  {hex_part:<48}  |{ascii_part}|")
    return "\n".join(lines)


def _extract_strings(data: bytes, min_length: int = 6) -> List[str]:
    pattern = re.compile(rb'[\x20-\x7e]{' + str(min_length).encode() + rb',}')
    return [m.group().decode('ascii') for m in pattern.finditer(data)]


def _calc_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    import math
    freq = {}
    for b in data:
        freq[b] = freq.get(b, 0) + 1
    entropy = 0.0
    for count in freq.values():
        p = count / len(data)
        entropy -= p * math.log2(p)
    return round(entropy, 2)


def _human_size(size: int) -> str:
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"


def _region_emoji(region_type: str) -> str:
    return {
        "STACK": "📚", "HEAP": "🏔️", "SHARED_LIB": "📦",
        "FILE_BACKED": "📁", "ANONYMOUS": "👤", "VDSO": "⚙️",
    }.get(region_type, "❓")
