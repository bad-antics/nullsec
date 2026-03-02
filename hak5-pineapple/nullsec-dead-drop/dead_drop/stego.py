"""
LSB Steganography engine for dead-drop.
Embeds and extracts encrypted data in PNG pixel channels.
"""

import struct
import hashlib
import math
import os
from dataclasses import dataclass
from typing import Optional, List

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

from .crypto import encrypt_message, decrypt_message

# Magic bytes to identify dead-drop payloads
MAGIC = b"\xDE\xAD\xD0\x0F"
HEADER_SIZE = 4 + 4 + 16  # magic(4) + length(4) + checksum(16) = 24 bytes


def _check_pil():
    if not HAS_PIL:
        raise RuntimeError("dead-drop requires Pillow: pip install Pillow")


def _data_to_bits(data: bytes) -> List[int]:
    """Convert bytes to a list of bits."""
    bits = []
    for byte in data:
        for i in range(7, -1, -1):
            bits.append((byte >> i) & 1)
    return bits


def _bits_to_data(bits: List[int]) -> bytes:
    """Convert a list of bits back to bytes."""
    result = bytearray()
    for i in range(0, len(bits), 8):
        byte = 0
        for j in range(8):
            if i + j < len(bits):
                byte = (byte << 1) | bits[i + j]
            else:
                byte = byte << 1
        result.append(byte)
    return bytes(result)


@dataclass
class Capacity:
    """Image capacity information."""
    width: int
    height: int
    channels: int
    total_pixels: int
    usable_bits: int
    bytes: int
    human: str


@dataclass
class Detection:
    """Steganography detection result."""
    likelihood: float  # 0.0 to 1.0
    has_magic: bool
    indicators: List[str]
    lsb_chi_square: float


def capacity(image_path: str) -> Capacity:
    """Calculate how much data can be hidden in an image."""
    _check_pil()
    img = Image.open(image_path)
    w, h = img.size
    channels = len(img.getbands())

    # We use 1 bit per channel per pixel, minus header
    total_pixels = w * h
    usable_bits = total_pixels * channels - (HEADER_SIZE * 8)
    usable_bytes = usable_bits // 8

    if usable_bytes < 1024:
        human = f"{usable_bytes} bytes"
    elif usable_bytes < 1024 * 1024:
        human = f"{usable_bytes / 1024:.1f} KB"
    else:
        human = f"{usable_bytes / (1024 * 1024):.1f} MB"

    return Capacity(
        width=w, height=h, channels=channels,
        total_pixels=total_pixels, usable_bits=usable_bits,
        bytes=usable_bytes, human=human
    )


def hide(image_path: str, output_path: str,
         message: Optional[str] = None,
         payload_path: Optional[str] = None,
         key: str = "") -> dict:
    """
    Hide a message or file inside a PNG image.

    Args:
        image_path: Path to carrier image
        output_path: Path to write stego image
        message: Text message to hide
        payload_path: File to hide (alternative to message)
        key: Encryption passphrase

    Returns:
        dict with metadata about the operation
    """
    _check_pil()

    if message:
        plaintext = message.encode("utf-8")
    elif payload_path:
        with open(payload_path, "rb") as f:
            plaintext = f.read()
    else:
        raise ValueError("Provide either message or payload_path")

    # Encrypt
    encrypted = encrypt_message(plaintext, key)

    # Build header
    checksum = hashlib.md5(encrypted).digest()
    header = MAGIC + struct.pack("<I", len(encrypted)) + checksum
    payload = header + encrypted

    # Check capacity
    img = Image.open(image_path).convert("RGBA")
    w, h = img.size
    max_bits = w * h * 4  # RGBA = 4 channels

    payload_bits = _data_to_bits(payload)
    if len(payload_bits) > max_bits:
        raise ValueError(
            f"Payload too large ({len(payload)} bytes). "
            f"Image can hold {max_bits // 8} bytes max."
        )

    # Embed bits into LSBs
    pixels = list(img.getdata())
    bit_idx = 0

    new_pixels = []
    for pixel in pixels:
        new_pixel = list(pixel)
        for c in range(4):  # RGBA
            if bit_idx < len(payload_bits):
                # Clear LSB and set to payload bit
                new_pixel[c] = (new_pixel[c] & 0xFE) | payload_bits[bit_idx]
                bit_idx += 1
        new_pixels.append(tuple(new_pixel))

    # Create output image
    stego = Image.new("RGBA", (w, h))
    stego.putdata(new_pixels)
    stego.save(output_path, "PNG")

    return {
        "original_size": len(plaintext),
        "encrypted_size": len(encrypted),
        "total_embedded": len(payload),
        "capacity_used": f"{len(payload_bits) / max_bits * 100:.1f}%",
        "image_size": f"{w}x{h}",
        "output": output_path,
    }


def extract(image_path: str, key: str = "",
            output_path: Optional[str] = None) -> Optional[str]:
    """
    Extract a hidden message from a stego image.

    Args:
        image_path: Path to stego image
        key: Decryption passphrase
        output_path: If set, write payload to file instead of returning string

    Returns:
        Decoded message string, or None if output_path is set
    """
    _check_pil()

    img = Image.open(image_path).convert("RGBA")
    pixels = list(img.getdata())

    # Extract all LSBs
    all_bits = []
    for pixel in pixels:
        for c in range(4):
            all_bits.append(pixel[c] & 1)

    # Read header
    header_bits = all_bits[:HEADER_SIZE * 8]
    header_bytes = _bits_to_data(header_bits)

    # Verify magic
    if header_bytes[:4] != MAGIC:
        raise ValueError("No dead-drop payload found in this image")

    # Parse length and checksum
    payload_len = struct.unpack("<I", header_bytes[4:8])[0]
    expected_checksum = header_bytes[8:24]

    # Extract payload
    payload_start = HEADER_SIZE * 8
    payload_end = payload_start + payload_len * 8

    if payload_end > len(all_bits):
        raise ValueError("Payload extends beyond image data — corrupted?")

    payload_bits = all_bits[payload_start:payload_end]
    encrypted = _bits_to_data(payload_bits)[:payload_len]

    # Verify checksum
    actual_checksum = hashlib.md5(encrypted).digest()
    if actual_checksum != expected_checksum:
        raise ValueError("Checksum mismatch — image may be corrupted")

    # Decrypt
    plaintext = decrypt_message(encrypted, key)

    if output_path:
        with open(output_path, "wb") as f:
            f.write(plaintext)
        return None

    return plaintext.decode("utf-8")


def detect(image_path: str) -> Detection:
    """
    Analyze an image for signs of steganographic content.
    Does NOT require the encryption key.
    """
    _check_pil()

    img = Image.open(image_path).convert("RGBA")
    pixels = list(img.getdata())
    indicators = []

    # Check for magic bytes
    header_bits = []
    for pixel in pixels[:HEADER_SIZE]:
        for c in range(4):
            header_bits.append(pixel[c] & 1)
    header_bytes = _bits_to_data(header_bits[:HEADER_SIZE * 8])
    has_magic = header_bytes[:4] == MAGIC

    if has_magic:
        indicators.append("Dead-drop magic bytes detected in LSB layer")

    # Chi-square test on LSBs
    # Steganographic images tend to have more uniform LSB distribution
    lsb_counts = [0, 0]
    for pixel in pixels:
        for c in range(4):
            lsb_counts[pixel[c] & 1] += 1

    total = sum(lsb_counts)
    expected = total / 2
    chi_sq = sum((obs - expected) ** 2 / expected for obs in lsb_counts)

    # Natural images typically have chi-square > 10 for LSBs
    # Stego images approach 0
    if chi_sq < 1.0:
        indicators.append(f"LSB distribution suspiciously uniform (χ²={chi_sq:.4f})")

    # Check for LSB plane patterns
    # Sample a stripe of pixels and check for non-random patterns
    w, h = img.size
    stripe_bits = []
    for x in range(min(w, 256)):
        p = pixels[x]
        stripe_bits.append(p[0] & 1)

    # Run length analysis
    runs = 1
    for i in range(1, len(stripe_bits)):
        if stripe_bits[i] != stripe_bits[i - 1]:
            runs += 1
    expected_runs = len(stripe_bits) / 2
    run_ratio = runs / expected_runs if expected_runs > 0 else 1.0

    if run_ratio > 1.3 or run_ratio < 0.7:
        indicators.append(f"Anomalous LSB run-length pattern (ratio={run_ratio:.2f})")

    # Calculate likelihood
    likelihood = 0.0
    if has_magic:
        likelihood = 0.99
    elif chi_sq < 0.5:
        likelihood = 0.8
    elif chi_sq < 2.0:
        likelihood = 0.5
    elif len(indicators) > 0:
        likelihood = 0.3

    return Detection(
        likelihood=likelihood,
        has_magic=has_magic,
        indicators=indicators,
        lsb_chi_square=chi_sq,
    )


def generate_carrier(width: int, height: int, output_path: str) -> str:
    """Generate a clean carrier image with natural-looking noise."""
    _check_pil()
    import random

    img = Image.new("RGBA", (width, height))
    pixels = []

    # Generate a gradient with natural noise
    for y in range(height):
        for x in range(width):
            r = int(30 + (x / width) * 60 + random.gauss(0, 15))
            g = int(20 + (y / height) * 50 + random.gauss(0, 12))
            b = int(40 + ((x + y) / (width + height)) * 80 + random.gauss(0, 18))
            r = max(0, min(255, r))
            g = max(0, min(255, g))
            b = max(0, min(255, b))
            pixels.append((r, g, b, 255))

    img.putdata(pixels)
    img.save(output_path, "PNG")
    return output_path
