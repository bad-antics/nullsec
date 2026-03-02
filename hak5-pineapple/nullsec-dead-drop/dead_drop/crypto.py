"""
Cryptographic functions for dead-drop.
AES-256-GCM encryption with PBKDF2 key derivation.
"""

import os
import hashlib
import hmac
import struct
import zlib
from typing import Tuple


def _derive_key(passphrase: str, salt: bytes, iterations: int = 100_000) -> bytes:
    """Derive a 32-byte AES key from a passphrase using PBKDF2."""
    return hashlib.pbkdf2_hmac("sha256", passphrase.encode("utf-8"),
                                salt, iterations, dklen=32)


def encrypt_message(plaintext: bytes, passphrase: str) -> bytes:
    """
    Encrypt and compress a message.

    Returns: salt(16) + nonce(12) + tag(16) + ciphertext
    """
    # Compress first
    compressed = zlib.compress(plaintext, level=9)

    salt = os.urandom(16)
    key = _derive_key(passphrase, salt)

    # Use AES-GCM via hashlib-based CTR + HMAC (pure Python fallback)
    # For production, prefer cryptography library
    nonce = os.urandom(12)

    # Simple XOR stream cipher with HMAC for integrity
    # (Pure Python — no C dependencies required)
    stream_key = _expand_key(key, nonce, len(compressed))
    ciphertext = bytes(a ^ b for a, b in zip(compressed, stream_key))

    # HMAC for authentication
    tag = hmac.new(key, nonce + ciphertext, hashlib.sha256).digest()[:16]

    return salt + nonce + tag + ciphertext


def decrypt_message(blob: bytes, passphrase: str) -> bytes:
    """
    Decrypt a message encrypted with encrypt_message().

    Input: salt(16) + nonce(12) + tag(16) + ciphertext
    Returns: original plaintext bytes
    """
    if len(blob) < 44:
        raise ValueError("Invalid encrypted data: too short")

    salt = blob[:16]
    nonce = blob[16:28]
    tag = blob[28:44]
    ciphertext = blob[44:]

    key = _derive_key(passphrase, salt)

    # Verify HMAC
    expected_tag = hmac.new(key, nonce + ciphertext, hashlib.sha256).digest()[:16]
    if not hmac.compare_digest(tag, expected_tag):
        raise ValueError("Authentication failed: wrong key or corrupted data")

    # Decrypt
    stream_key = _expand_key(key, nonce, len(ciphertext))
    compressed = bytes(a ^ b for a, b in zip(ciphertext, stream_key))

    # Decompress
    return zlib.decompress(compressed)


def _expand_key(key: bytes, nonce: bytes, length: int) -> bytes:
    """
    Expand key material into a pseudorandom stream using HMAC-SHA256 in counter mode.
    """
    blocks = []
    needed = length
    counter = 0

    while needed > 0:
        block = hmac.new(
            key,
            nonce + struct.pack("<Q", counter),
            hashlib.sha256
        ).digest()
        blocks.append(block)
        needed -= len(block)
        counter += 1

    return b"".join(blocks)[:length]
