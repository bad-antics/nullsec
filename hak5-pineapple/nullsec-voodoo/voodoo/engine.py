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


def curse_scan(pid: int) -> List[Dict]:
    """
    Scan process memory for corruption curses — heap spray, stack smash,
    use-after-free markers, canary deaths, and other memory dark arts.
    This is NOT string extraction (MemHunter does that) — this looks
    for structural corruption signatures.
    """
    curses = []
    regions = read_memory_map(pid)
    readable_regions = [r for r in regions if 'r' in r['permissions']]

    # Corruption signatures to hunt
    CORRUPTION_SIGS = {
        b"\x41\x41\x41\x41\x41\x41\x41\x41": ("🔴 HEAP_SPRAY", "Repeated 0x41 (AAAA) — classic heap spray"),
        b"\x42\x42\x42\x42\x42\x42\x42\x42": ("🔴 BUFFER_FILL", "Repeated 0x42 (BBBB) — buffer overflow marker"),
        b"\x43\x43\x43\x43\x43\x43\x43\x43": ("🟡 PADDING_FILL", "Repeated 0x43 (CCCC) — overflow padding"),
        b"\xde\xad\xbe\xef": ("🔴 DEADBEEF", "Magic debug marker — freed/uninitialized memory"),
        b"\xfe\xed\xfa\xce": ("🟡 FEEDFACE", "Mach-O magic or debug marker"),
        b"\xba\xad\xf0\x0d": ("🔴 BAADF00D", "Windows HeapAlloc marker — uninitialized heap"),
        b"\xab\xab\xab\xab": ("🟡 ABABABAB", "Guard bytes — heap guard page fill"),
        b"\xfd\xfd\xfd\xfd": ("🟡 FDFDFDFD", "No-mans-land guard — buffer overrun sentinel"),
        b"\xcd\xcd\xcd\xcd": ("🟡 CDCDCDCD", "Uninitialized heap — debug mode fill"),
        b"\xcc\xcc\xcc\xcc": ("🔴 INT3_SLED", "INT3 breakpoint sled — debugger or shellcode"),
        b"\x90\x90\x90\x90\x90\x90\x90\x90": ("🔴 NOP_SLED", "NOP sled — classic shellcode landing zone"),
    }

    # Stack canary death signatures (common sentinel values after overwrite)
    CANARY_DEATH = [
        (b"\x00\x00\x00\x00\x00\x00\x00\x00", "NULL canary — stack smash with null bytes"),
    ]

    try:
        with open(f"/proc/{pid}/mem", 'rb') as mem:
            for region in readable_regions[:30]:
                start_hex = region['address'].split('-')[0]
                start = int(start_hex, 16)
                size = min(region['size'], 512 * 1024)  # 512KB cap

                try:
                    mem.seek(start)
                    data = mem.read(size)
                except (OSError, ValueError):
                    continue

                # Scan for corruption signatures
                for sig, (curse_type, detail) in CORRUPTION_SIGS.items():
                    offset = data.find(sig)
                    while offset != -1:
                        # Count consecutive occurrences (indicates spray vs incidental)
                        run_length = 0
                        check_pos = offset
                        while check_pos + len(sig) <= len(data) and data[check_pos:check_pos+len(sig)] == sig:
                            run_length += 1
                            check_pos += len(sig)

                        if run_length >= 2:  # At least 2 consecutive = suspicious
                            severity = "CRITICAL" if run_length >= 8 else "HIGH" if run_length >= 4 else "MEDIUM"
                            curses.append({
                                "type": curse_type,
                                "detail": f"{detail} (×{run_length} consecutive)",
                                "address": f"0x{start + offset:016x}",
                                "region": region['type'],
                                "region_addr": region['address'],
                                "severity": severity,
                                "run_length": run_length,
                            })
                        offset = data.find(sig, offset + len(sig) * max(1, run_length))

                # Check for entropy anomalies in heap/stack (uniform fill = suspicious)
                if region['type'] in ('HEAP', 'STACK', 'ANONYMOUS') and len(data) > 256:
                    for chunk_off in range(0, len(data) - 256, 4096):
                        chunk = data[chunk_off:chunk_off + 256]
                        unique_bytes = len(set(chunk))
                        if unique_bytes <= 3 and len(chunk) == 256:
                            curses.append({
                                "type": "🟠 MONOTONE_FILL",
                                "detail": f"Suspiciously uniform memory ({unique_bytes} unique bytes in 256B block)",
                                "address": f"0x{start + chunk_off:016x}",
                                "region": region['type'],
                                "region_addr": region['address'],
                                "severity": "MEDIUM",
                                "run_length": 1,
                            })

    except (PermissionError, FileNotFoundError):
        pass

    return curses


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
