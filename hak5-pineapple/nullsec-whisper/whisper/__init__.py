"""nullsec-whisper — Spectral Audio Steganography"""
__version__ = "1.0.0"
__author__ = "bad-antics"
from .spectral import generate_whisper, detect_whisper, render_spectrogram
__all__ = ["generate_whisper", "detect_whisper", "render_spectrogram"]
