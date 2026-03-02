"""
nullsec-dead-drop — Steganographic Message Hiding
Hide encrypted messages inside PNG images using LSB encoding.
"""

__version__ = "1.0.0"
__author__ = "bad-antics"

from .stego import hide, extract, detect, capacity
from .crypto import encrypt_message, decrypt_message

__all__ = ["hide", "extract", "detect", "capacity",
           "encrypt_message", "decrypt_message"]
