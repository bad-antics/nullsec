"""
Core sigil generation engine.
Converts SHA-256 hash bytes into deterministic geometric parameters.
"""

import hashlib
import math
from dataclasses import dataclass, field
from typing import List, Tuple, Optional

from .palette import Palette, extract_palette
from .shapes import (
    Ring, Mandala, CoreGlyph, ParticleField,
    ConnectingArcs, BorderRunes, Background
)
from .themes import THEMES, Theme
from .renderer import render_svg, render_ascii


@dataclass
class SigilParams:
    """Geometric parameters extracted from hash bytes."""
    ring_sides: int = 0
    ring_rotation: float = 0.0
    ring_stroke: float = 2.0
    mandala_petals: int = 6
    mandala_symmetry: int = 2
    mandala_radius: float = 0.3
    glyph_sides: int = 3
    glyph_fill: str = "solid"
    particle_count: int = 20
    particle_spread: float = 0.8
    particle_opacity: float = 0.6
    arc_count: int = 4
    arc_curvature: float = 0.5
    bg_angle: float = 0.0
    bg_darkness: float = 0.9
    rune_ticks: int = 32
    palette: Optional[Palette] = None


def _bytes_to_params(hash_bytes: bytes) -> SigilParams:
    """Extract geometric parameters from 32 hash bytes."""
    p = SigilParams()

    # Bytes 0-3: Outer ring
    p.ring_sides = (hash_bytes[0] % 8) + 3  # 3-10 sides (0 = circle)
    p.ring_rotation = (hash_bytes[1] / 255.0) * 360.0
    p.ring_stroke = 1.0 + (hash_bytes[2] / 255.0) * 4.0
    # byte 3 reserved

    # Bytes 4-7: Inner mandala
    p.mandala_petals = (hash_bytes[4] % 12) + 3  # 3-14 petals
    p.mandala_symmetry = (hash_bytes[5] % 6) + 1  # 1-6 symmetry
    p.mandala_radius = 0.15 + (hash_bytes[6] / 255.0) * 0.35
    # byte 7 reserved

    # Bytes 8-11: Core glyph
    p.glyph_sides = (hash_bytes[8] % 6) + 3  # 3-8 sides
    fills = ["solid", "hatched", "dotted", "gradient", "hollow"]
    p.glyph_fill = fills[hash_bytes[9] % len(fills)]
    # bytes 10-11 reserved

    # Bytes 12-15: Color palette
    p.palette = extract_palette(hash_bytes[12:16])

    # Bytes 16-19: Particle field
    p.particle_count = (hash_bytes[16] % 40) + 5  # 5-44 particles
    p.particle_spread = 0.3 + (hash_bytes[17] / 255.0) * 0.7
    p.particle_opacity = 0.2 + (hash_bytes[18] / 255.0) * 0.6

    # Bytes 20-23: Connecting arcs
    p.arc_count = (hash_bytes[20] % 8) + 2  # 2-9 arcs
    p.arc_curvature = (hash_bytes[21] / 255.0)

    # Bytes 24-27: Background
    p.bg_angle = (hash_bytes[24] / 255.0) * 360.0
    p.bg_darkness = 0.7 + (hash_bytes[25] / 255.0) * 0.25

    # Bytes 28-31: Border runes
    p.rune_ticks = (hash_bytes[28] % 48) + 16  # 16-63 ticks

    return p


class Sigil:
    """
    Generate a deterministic visual sigil from any input.

    Usage:
        s = Sigil("hello world")
        print(s.svg)
        s.save("hello.svg")
    """

    def __init__(self, data: str, size: int = 512, theme: str = "dark"):
        self._data = data
        self._size = size
        self._theme_name = theme
        self._hash = hashlib.sha256(data.encode("utf-8")).hexdigest()
        self._hash_bytes = bytes.fromhex(self._hash)
        self._params = _bytes_to_params(self._hash_bytes)
        self._theme = THEMES.get(theme, THEMES["dark"])

        # Override palette colors with theme if needed
        if self._theme.override_palette:
            self._params.palette = self._theme.generate_palette(self._hash_bytes[12:16])

    @classmethod
    def from_file(cls, filepath: str, size: int = 512, theme: str = "dark") -> "Sigil":
        """Generate sigil from file contents."""
        sha = hashlib.sha256()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha.update(chunk)
        instance = cls.__new__(cls)
        instance._data = f"file:{filepath}"
        instance._size = size
        instance._theme_name = theme
        instance._hash = sha.hexdigest()
        instance._hash_bytes = bytes.fromhex(instance._hash)
        instance._params = _bytes_to_params(instance._hash_bytes)
        instance._theme = THEMES.get(theme, THEMES["dark"])
        if instance._theme.override_palette:
            instance._params.palette = instance._theme.generate_palette(instance._hash_bytes[12:16])
        return instance

    @classmethod
    def from_bytes(cls, raw: bytes, size: int = 512, theme: str = "dark") -> "Sigil":
        """Generate sigil from raw bytes."""
        instance = cls.__new__(cls)
        instance._data = f"bytes:{len(raw)}"
        instance._size = size
        instance._theme_name = theme
        instance._hash = hashlib.sha256(raw).hexdigest()
        instance._hash_bytes = bytes.fromhex(instance._hash)
        instance._params = _bytes_to_params(instance._hash_bytes)
        instance._theme = THEMES.get(theme, THEMES["dark"])
        if instance._theme.override_palette:
            instance._params.palette = instance._theme.generate_palette(instance._hash_bytes[12:16])
        return instance

    @property
    def hash(self) -> str:
        return self._hash

    @property
    def palette(self) -> Palette:
        return self._params.palette

    @property
    def params(self) -> SigilParams:
        return self._params

    @property
    def svg(self) -> str:
        """Render sigil as SVG string."""
        return render_svg(self._params, self._theme, self._size, self._hash)

    @property
    def ascii(self) -> str:
        """Render sigil as ASCII art."""
        return render_ascii(self._params, self._hash)

    def save(self, path: str) -> None:
        """Save sigil to file. Format detected from extension."""
        if path.endswith(".png"):
            try:
                import cairosvg
                cairosvg.svg2png(bytestring=self.svg.encode(), write_to=path,
                                 output_width=self._size, output_height=self._size)
            except ImportError:
                raise RuntimeError("PNG output requires cairosvg: pip install cairosvg")
        elif path.endswith(".txt"):
            with open(path, "w") as f:
                f.write(self.ascii)
        else:
            with open(path, "w") as f:
                f.write(self.svg)

    def __repr__(self) -> str:
        return f"Sigil(hash={self._hash[:16]}…, theme={self._theme_name})"


def compare(input_a: str, input_b: str) -> dict:
    """Compare two sigils and return similarity metrics."""
    hash_a = hashlib.sha256(input_a.encode()).hexdigest()
    hash_b = hashlib.sha256(input_b.encode()).hexdigest()

    # Hamming distance on hex chars
    distance = sum(a != b for a, b in zip(hash_a, hash_b))
    identical = hash_a == hash_b

    return {
        "identical": identical,
        "distance": distance,
        "max_distance": 64,
        "similarity": 1.0 - (distance / 64.0),
        "hash_a": hash_a,
        "hash_b": hash_b,
    }
