"""
Spectral steganography engine.
Embeds text into audio frequency bands so it appears in spectrograms.
"""

import math
import struct
import wave
import os
from typing import List, Optional

# Simple 5x7 dot-matrix font for spectrogram rendering
FONT = {
    'A': ["01110","10001","10001","11111","10001","10001","10001"],
    'B': ["11110","10001","10001","11110","10001","10001","11110"],
    'C': ["01110","10001","10000","10000","10000","10001","01110"],
    'D': ["11100","10010","10001","10001","10001","10010","11100"],
    'E': ["11111","10000","10000","11110","10000","10000","11111"],
    'F': ["11111","10000","10000","11110","10000","10000","10000"],
    'G': ["01110","10001","10000","10111","10001","10001","01110"],
    'H': ["10001","10001","10001","11111","10001","10001","10001"],
    'I': ["01110","00100","00100","00100","00100","00100","01110"],
    'J': ["00111","00010","00010","00010","00010","10010","01100"],
    'K': ["10001","10010","10100","11000","10100","10010","10001"],
    'L': ["10000","10000","10000","10000","10000","10000","11111"],
    'M': ["10001","11011","10101","10101","10001","10001","10001"],
    'N': ["10001","11001","10101","10011","10001","10001","10001"],
    'O': ["01110","10001","10001","10001","10001","10001","01110"],
    'P': ["11110","10001","10001","11110","10000","10000","10000"],
    'Q': ["01110","10001","10001","10001","10101","10010","01101"],
    'R': ["11110","10001","10001","11110","10100","10010","10001"],
    'S': ["01111","10000","10000","01110","00001","00001","11110"],
    'T': ["11111","00100","00100","00100","00100","00100","00100"],
    'U': ["10001","10001","10001","10001","10001","10001","01110"],
    'V': ["10001","10001","10001","10001","01010","01010","00100"],
    'W': ["10001","10001","10001","10101","10101","10101","01010"],
    'X': ["10001","10001","01010","00100","01010","10001","10001"],
    'Y': ["10001","10001","01010","00100","00100","00100","00100"],
    'Z': ["11111","00001","00010","00100","01000","10000","11111"],
    ' ': ["00000","00000","00000","00000","00000","00000","00000"],
    '0': ["01110","10011","10101","10101","10101","11001","01110"],
    '1': ["00100","01100","00100","00100","00100","00100","01110"],
}


def _text_to_bitmap(text: str) -> List[List[int]]:
    """Convert text to a 2D bitmap grid using dot-matrix font."""
    text = text.upper()
    rows = [[] for _ in range(7)]

    for char in text:
        glyph = FONT.get(char, FONT[' '])
        for r in range(7):
            for bit in glyph[r]:
                rows[r].append(int(bit))
            rows[r].append(0)  # spacing

    return rows


def generate_whisper(message: str, output_path: str,
                     duration: float = 5.0, sample_rate: int = 44100,
                     base_freq: float = 2000.0, freq_step: float = 200.0,
                     noise_level: float = 0.02) -> dict:
    """
    Generate a WAV file with a message hidden in the spectrogram.

    The message appears as bright frequency bands when viewed in a
    spectrogram viewer.
    """
    bitmap = _text_to_bitmap(message)
    num_samples = int(sample_rate * duration)
    cols = len(bitmap[0]) if bitmap else 1
    samples_per_col = num_samples // cols

    audio = []

    for sample_idx in range(num_samples):
        col_idx = min(sample_idx // samples_per_col, cols - 1)
        value = 0.0

        # Add noise floor (the "static")
        import random
        value += random.gauss(0, noise_level)

        # Add frequency bands for active pixels
        t = sample_idx / sample_rate
        for row_idx, row in enumerate(bitmap):
            if col_idx < len(row) and row[col_idx]:
                freq = base_freq + (len(bitmap) - row_idx) * freq_step
                amplitude = 0.15
                value += amplitude * math.sin(2 * math.pi * freq * t)

        # Clamp
        value = max(-1.0, min(1.0, value))
        audio.append(int(value * 32767))

    # Write WAV
    with wave.open(output_path, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(struct.pack(f'<{len(audio)}h', *audio))

    return {
        "output": output_path,
        "message": message,
        "duration": duration,
        "sample_rate": sample_rate,
        "freq_range": f"{base_freq:.0f}-{base_freq + len(bitmap) * freq_step:.0f} Hz",
        "bitmap_size": f"{cols}x{len(bitmap)}",
    }


def render_spectrogram(filepath: str, width: int = 80, height: int = 20) -> str:
    """Render a simple ASCII spectrogram of a WAV file."""
    with wave.open(filepath, 'r') as wav:
        n_frames = wav.getnframes()
        sample_rate = wav.getframerate()
        raw = wav.readframes(n_frames)
        samples = struct.unpack(f'<{n_frames}h', raw)

    # Simple FFT-based spectrogram
    chunk_size = n_frames // width
    spectrum = []

    for col in range(width):
        start = col * chunk_size
        chunk = samples[start:start + chunk_size]
        if not chunk:
            spectrum.append([0] * height)
            continue

        # Compute power at frequency bands
        freqs = []
        for band in range(height):
            freq = 500 + band * 300
            power = 0.0
            for i, s in enumerate(chunk[:min(len(chunk), 2048)]):
                t = i / sample_rate
                power += abs(s * math.sin(2 * math.pi * freq * t))
            freqs.append(power / len(chunk))

        spectrum.append(freqs)

    # Normalize
    max_power = max(max(col) for col in spectrum) or 1
    chars = " ░▒▓█"

    lines = []
    for row in range(height - 1, -1, -1):
        line = ""
        for col in range(width):
            val = spectrum[col][row] / max_power
            idx = min(int(val * (len(chars) - 1)), len(chars) - 1)
            line += chars[idx]
        lines.append(line)

    return "\n".join(lines)


def detect_whisper(filepath: str) -> dict:
    """Analyze a WAV file for potential spectrogram steganography."""
    with wave.open(filepath, 'r') as wav:
        n_frames = wav.getnframes()
        sample_rate = wav.getframerate()
        raw = wav.readframes(n_frames)
        samples = struct.unpack(f'<{n_frames}h', raw)

    # Check for unusual frequency band energy patterns
    chunk_size = min(4096, n_frames)
    band_energies = {}

    for band_freq in range(500, 8000, 100):
        energy = 0.0
        for i in range(chunk_size):
            t = i / sample_rate
            energy += abs(samples[i] * math.sin(2 * math.pi * band_freq * t))
        band_energies[band_freq] = energy / chunk_size

    # Look for discrete frequency bands with high energy (stego indicator)
    values = list(band_energies.values())
    avg_energy = sum(values) / len(values) if values else 0
    hot_bands = [f for f, e in band_energies.items() if e > avg_energy * 2]

    likelihood = min(len(hot_bands) / 10.0, 1.0) if hot_bands else 0.0

    return {
        "filepath": filepath,
        "likelihood": likelihood,
        "hot_bands": len(hot_bands),
        "total_bands": len(band_energies),
        "suspicious": likelihood > 0.3,
        "verdict": "👁️ Voices detected in the static..." if likelihood > 0.3
                   else "🔇 The silence is... genuine. For now.",
    }
