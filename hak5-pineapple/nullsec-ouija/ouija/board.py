"""
Ouija Board — File carving and recovery from raw disk/memory.
Summons the spirits of deleted files using magic byte signatures.
"""

import os
import struct
from typing import List, Dict, Optional, BinaryIO

# File signatures — the "spirits" we can summon
SPIRITS = {
    "JPEG": {"header": b"\xff\xd8\xff", "footer": b"\xff\xd9", "ext": ".jpg", "emoji": "🖼️"},
    "PNG":  {"header": b"\x89PNG\r\n\x1a\n", "footer": b"IEND", "ext": ".png", "emoji": "🖼️"},
    "PDF":  {"header": b"%PDF", "footer": b"%%EOF", "ext": ".pdf", "emoji": "📄"},
    "ZIP":  {"header": b"PK\x03\x04", "footer": b"PK\x05\x06", "ext": ".zip", "emoji": "📦"},
    "GIF":  {"header": b"GIF8", "footer": b"\x00\x3b", "ext": ".gif", "emoji": "🎞️"},
    "ELF":  {"header": b"\x7fELF", "footer": None, "ext": ".elf", "emoji": "👻"},
    "GZIP": {"header": b"\x1f\x8b", "footer": None, "ext": ".gz", "emoji": "📦"},
    "BZ2":  {"header": b"BZ", "footer": None, "ext": ".bz2", "emoji": "📦"},
    "RAR":  {"header": b"Rar!", "footer": None, "ext": ".rar", "emoji": "📦"},
    "7Z":   {"header": b"7z\xbc\xaf\x27\x1c", "footer": None, "ext": ".7z", "emoji": "📦"},
    "SQLITE": {"header": b"SQLite format 3", "footer": None, "ext": ".db", "emoji": "🗄️"},
    "TAR":    {"header": b"ustar", "footer": None, "ext": ".tar", "emoji": "📦"},
    "PEM_KEY": {"header": b"-----BEGIN", "footer": b"-----END", "ext": ".pem", "emoji": "🔑"},
    "SSH_KEY": {"header": b"ssh-rsa", "footer": None, "ext": ".pub", "emoji": "🔑"},
}

# Entropy of the dead — strings commonly found in deleted file remnants
DEATH_STRINGS = [
    b"password", b"secret", b"private", b"BEGIN RSA",
    b"Authorization:", b"Bearer ", b"api_key", b"token",
    b"SELECT ", b"INSERT ", b"DELETE FROM", b"DROP TABLE",
]


def summon_spirits(source_path: str, output_dir: str,
                   max_size: int = 10 * 1024 * 1024,
                   chunk_size: int = 512) -> List[Dict]:
    """
    Carve files from a raw source (disk image, memory dump, or any binary).
    Each recovered file is a "spirit" summoned from the dead.
    """
    os.makedirs(output_dir, exist_ok=True)
    spirits_found = []
    file_size = os.path.getsize(source_path)

    with open(source_path, 'rb') as f:
        offset = 0
        while offset < file_size:
            f.seek(offset)
            header_bytes = f.read(32)

            if not header_bytes:
                break

            for spirit_name, spirit in SPIRITS.items():
                sig = spirit["header"]
                if header_bytes[:len(sig)] == sig:
                    # Found a spirit! Try to determine its boundaries
                    f.seek(offset)
                    data = f.read(max_size)

                    end_offset = len(data)
                    if spirit["footer"]:
                        footer_pos = data.find(spirit["footer"], len(sig))
                        if footer_pos != -1:
                            end_offset = footer_pos + len(spirit["footer"])

                    spirit_data = data[:end_offset]
                    spirit_id = len(spirits_found)
                    out_file = os.path.join(output_dir,
                        f"spirit_{spirit_id:04d}_{spirit_name.lower()}{spirit['ext']}")

                    with open(out_file, 'wb') as out:
                        out.write(spirit_data)

                    spirits_found.append({
                        "id": spirit_id,
                        "type": spirit_name,
                        "emoji": spirit["emoji"],
                        "offset": offset,
                        "size": len(spirit_data),
                        "output": out_file,
                        "hex_offset": f"0x{offset:08x}",
                    })

                    offset += end_offset
                    break
            else:
                offset += chunk_size

    return spirits_found


def seance_scan(filepath: str, chunk_size: int = 4096) -> Dict:
    """
    Perform a séance on a file — look for ghostly remnants of deleted data.
    Searches for death strings, magic bytes, and residual data.
    """
    results = {
        "filepath": filepath,
        "size": os.path.getsize(filepath),
        "spirits": [],
        "death_echoes": [],
        "magic_remnants": [],
    }

    with open(filepath, 'rb') as f:
        data = f.read()

    # Look for death strings
    for death_str in DEATH_STRINGS:
        pos = 0
        while True:
            pos = data.find(death_str, pos)
            if pos == -1:
                break
            context = data[max(0, pos - 20):pos + len(death_str) + 20]
            results["death_echoes"].append({
                "string": death_str.decode('utf-8', errors='replace'),
                "offset": f"0x{pos:08x}",
                "context": context.decode('utf-8', errors='replace'),
            })
            pos += 1

    # Look for magic byte signatures
    for spirit_name, spirit in SPIRITS.items():
        sig = spirit["header"]
        pos = 0
        while True:
            pos = data.find(sig, pos)
            if pos == -1:
                break
            results["magic_remnants"].append({
                "type": spirit_name,
                "emoji": spirit["emoji"],
                "offset": f"0x{pos:08x}",
            })
            pos += 1

    results["verdict"] = _divine_verdict(results)
    return results


def read_tombstone(filepath: str, offset: int, length: int = 256) -> Dict:
    """Read raw bytes from a specific offset — peek into the grave."""
    with open(filepath, 'rb') as f:
        f.seek(offset)
        data = f.read(length)

    # Format as hex dump with ASCII
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        hex_part = ' '.join(f'{b:02x}' for b in chunk)
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '·' for b in chunk)
        lines.append(f"  {offset + i:08x}  {hex_part:<48}  |{ascii_part}|")

    return {
        "offset": f"0x{offset:08x}",
        "length": len(data),
        "hex_dump": "\n".join(lines),
        "raw_printable": data.decode('utf-8', errors='replace'),
    }


def _divine_verdict(results: Dict) -> str:
    """Generate a creepy verdict based on findings."""
    echoes = len(results["death_echoes"])
    remnants = len(results["magic_remnants"])

    if echoes > 10 and remnants > 5:
        return "💀 THIS PLACE IS CURSED. Secrets and spirits everywhere."
    elif echoes > 5:
        return "👁️ The dead are whispering... sensitive data detected."
    elif remnants > 3:
        return "👻 Ghostly file remnants linger in the void."
    elif echoes > 0 or remnants > 0:
        return "🕯️ Faint echoes from beyond... something was here."
    else:
        return "🌑 The void is empty. The dead rest peacefully... for now."
