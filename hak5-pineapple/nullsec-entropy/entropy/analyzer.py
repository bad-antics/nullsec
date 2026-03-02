"""
Core entropy analysis engine.
Shannon entropy, byte distribution, and anomaly detection.
"""

import math
import os
from collections import Counter
from dataclasses import dataclass, field
from typing import List, Optional, Tuple


@dataclass
class EntropyResult:
    """Result of entropy analysis on a file or data block."""
    filepath: Optional[str]
    size: int
    entropy: float                    # Shannon entropy (0-8)
    classification: str               # human-readable classification
    threat_level: str                 # clean, suspicious, anomalous
    byte_distribution: List[int]      # 256-element frequency list
    chi_square: float                 # chi-square uniformity test
    unique_bytes: int                 # count of distinct byte values
    most_common: List[Tuple[int, int]]  # top 10 most common bytes
    least_common: List[Tuple[int, int]] # top 10 least common bytes
    anomalies: List[str]              # detected anomalies
    sections: List["SectionEntropy"] = field(default_factory=list)


@dataclass
class SectionEntropy:
    """Entropy of a section/chunk within a file."""
    offset: int
    size: int
    entropy: float
    classification: str
    flag: str = ""  # warning flag


def _shannon_entropy(data: bytes) -> float:
    """Calculate Shannon entropy of a byte sequence (0-8 bits)."""
    if not data:
        return 0.0

    freq = Counter(data)
    length = len(data)
    entropy = 0.0

    for count in freq.values():
        p = count / length
        if p > 0:
            entropy -= p * math.log2(p)

    return entropy


def _chi_square(data: bytes) -> float:
    """Chi-square test for uniform byte distribution."""
    freq = Counter(data)
    expected = len(data) / 256.0

    chi_sq = 0.0
    for byte_val in range(256):
        observed = freq.get(byte_val, 0)
        chi_sq += (observed - expected) ** 2 / expected if expected > 0 else 0

    return chi_sq


def _classify_entropy(entropy: float) -> str:
    """Classify entropy value into human-readable category."""
    if entropy < 1.0:
        return "null/repetitive"
    elif entropy < 3.5:
        return "structured text"
    elif entropy < 5.0:
        return "natural language"
    elif entropy < 6.5:
        return "mixed binary"
    elif entropy < 7.5:
        return "compressed"
    elif entropy < 7.99:
        return "encrypted/packed"
    else:
        return "true random"


def _detect_anomalies(data: bytes, entropy: float, chi_sq: float,
                      unique: int) -> List[str]:
    """Detect anomalies in the byte distribution."""
    anomalies = []

    # Very high entropy in a small file is suspicious
    if len(data) < 1024 and entropy > 7.5:
        anomalies.append("High entropy in small file — possible embedded ciphertext")

    # Encrypted data should have near-uniform distribution
    if entropy > 7.8 and chi_sq < 300:
        anomalies.append("Near-perfect uniformity — likely AES/ChaCha encrypted")

    # Low unique byte count with high entropy suggests XOR cipher
    if entropy > 5.0 and unique < 64:
        anomalies.append(f"Only {unique}/256 unique bytes with high entropy — possible XOR cipher")

    # Null byte dominance in non-empty file
    freq = Counter(data)
    null_ratio = freq.get(0, 0) / len(data) if data else 0
    if null_ratio > 0.3 and entropy > 2.0:
        anomalies.append(f"Excessive null bytes ({null_ratio:.0%}) — possible sparse data or padding")

    # Base64 signature (limited character set with moderate entropy)
    b64_chars = set(range(43, 123))  # rough Base64 character range
    b64_count = sum(freq.get(b, 0) for b in b64_chars)
    if len(data) > 100 and b64_count / len(data) > 0.95 and 4.0 < entropy < 6.5:
        anomalies.append("Character set consistent with Base64 encoding")

    # Repeating patterns (low entropy sections in high-entropy file)
    if entropy < 1.0 and len(data) > 100:
        anomalies.append("Extremely low entropy — file is repetitive or mostly empty")

    return anomalies


def analyze_bytes(data: bytes, filepath: Optional[str] = None) -> EntropyResult:
    """Analyze entropy of raw bytes."""
    if not data:
        return EntropyResult(
            filepath=filepath, size=0, entropy=0.0,
            classification="empty", threat_level="clean",
            byte_distribution=[0] * 256, chi_square=0.0,
            unique_bytes=0, most_common=[], least_common=[],
            anomalies=["File is empty"]
        )

    entropy = _shannon_entropy(data)
    chi_sq = _chi_square(data)
    freq = Counter(data)
    unique = len(freq)

    # Build 256-element distribution
    distribution = [freq.get(i, 0) for i in range(256)]

    # Most/least common
    most_common = freq.most_common(10)
    least_common = freq.most_common()[:-11:-1] if len(freq) >= 10 else freq.most_common()[::-1]

    classification = _classify_entropy(entropy)
    anomalies = _detect_anomalies(data, entropy, chi_sq, unique)

    # Threat assessment
    if anomalies:
        threat_level = "anomalous" if entropy > 7.5 else "suspicious"
    else:
        threat_level = "clean"

    return EntropyResult(
        filepath=filepath,
        size=len(data),
        entropy=entropy,
        classification=classification,
        threat_level=threat_level,
        byte_distribution=distribution,
        chi_square=chi_sq,
        unique_bytes=unique,
        most_common=most_common,
        least_common=least_common,
        anomalies=anomalies,
    )


def analyze_file(filepath: str, chunk_size: int = 0) -> EntropyResult:
    """Analyze entropy of a file."""
    with open(filepath, "rb") as f:
        data = f.read()

    result = analyze_bytes(data, filepath=filepath)

    # Section analysis
    if chunk_size > 0 and len(data) > chunk_size:
        sections = []
        for offset in range(0, len(data), chunk_size):
            chunk = data[offset:offset + chunk_size]
            ent = _shannon_entropy(chunk)
            cls = _classify_entropy(ent)
            flag = ""
            if ent > 7.5:
                flag = "⚠ HIGH"
            elif ent < 0.5 and len(chunk) > 64:
                flag = "⚠ LOW"
            sections.append(SectionEntropy(
                offset=offset, size=len(chunk),
                entropy=ent, classification=cls, flag=flag
            ))
        result.sections = sections

    return result


def entropy_map(filepath: str, chunk_size: int = 4096) -> List[SectionEntropy]:
    """Generate a section-by-section entropy map of a file."""
    with open(filepath, "rb") as f:
        data = f.read()

    sections = []
    for offset in range(0, len(data), chunk_size):
        chunk = data[offset:offset + chunk_size]
        ent = _shannon_entropy(chunk)
        cls = _classify_entropy(ent)
        flag = ""
        if ent > 7.5:
            flag = "⚠ PACKED"
        elif ent > 7.0:
            flag = "compressed"
        elif ent < 0.5:
            flag = "padding"
        sections.append(SectionEntropy(
            offset=offset, size=len(chunk),
            entropy=ent, classification=cls, flag=flag
        ))

    return sections


def classify_file(filepath: str) -> dict:
    """Classify a file based on its entropy signature."""
    result = analyze_file(filepath)

    # Try to detect file type mismatches
    _, ext = os.path.splitext(filepath)
    ext = ext.lower()

    expected_ranges = {
        ".txt": (1.0, 5.5), ".py": (2.0, 5.5), ".js": (2.0, 5.5),
        ".html": (2.0, 5.5), ".json": (2.0, 6.0), ".xml": (2.0, 5.5),
        ".zip": (7.0, 8.0), ".gz": (7.0, 8.0), ".xz": (7.5, 8.0),
        ".png": (6.0, 8.0), ".jpg": (7.0, 8.0), ".gif": (5.0, 8.0),
        ".exe": (4.0, 7.5), ".dll": (4.0, 7.5), ".so": (4.0, 7.5),
        ".pdf": (5.0, 8.0), ".doc": (5.0, 8.0),
    }

    mismatch = False
    expected = expected_ranges.get(ext)
    if expected:
        low, high = expected
        if result.entropy < low or result.entropy > high:
            mismatch = True

    return {
        "filepath": filepath,
        "extension": ext,
        "entropy": round(result.entropy, 4),
        "classification": result.classification,
        "threat_level": result.threat_level,
        "size": result.size,
        "unique_bytes": result.unique_bytes,
        "extension_mismatch": mismatch,
        "anomalies": result.anomalies,
    }
