"""
Color palette extraction from hash bytes.
Maps 4 bytes into a harmonious color scheme.
"""

from dataclasses import dataclass
from typing import List, Tuple
import colorsys


@dataclass
class Palette:
    """A color palette derived from hash bytes."""
    primary: str       # Main accent color
    secondary: str     # Secondary accent
    tertiary: str      # Third accent
    background: str    # Background color
    foreground: str    # Text/line color
    glow: str          # Glow/highlight color
    hue: float         # Base hue (0-360)
    saturation: float  # Base saturation (0-1)

    def as_list(self) -> List[str]:
        return [self.primary, self.secondary, self.tertiary,
                self.background, self.foreground, self.glow]


def _hsl_to_hex(h: float, s: float, l: float) -> str:
    """Convert HSL (h=0-360, s=0-1, l=0-1) to hex color."""
    h_norm = h / 360.0
    r, g, b = colorsys.hls_to_rgb(h_norm, l, s)
    return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"


def extract_palette(four_bytes: bytes) -> Palette:
    """
    Extract a harmonious color palette from 4 bytes.

    Byte 0: Base hue (0-360)
    Byte 1: Saturation (0.3-1.0)
    Byte 2: Harmony type (complementary, triadic, analogous, split-comp)
    Byte 3: Lightness bias
    """
    base_hue = (four_bytes[0] / 255.0) * 360.0
    saturation = 0.3 + (four_bytes[1] / 255.0) * 0.7
    harmony = four_bytes[2] % 4
    lightness_bias = 0.4 + (four_bytes[3] / 255.0) * 0.3  # 0.4-0.7

    # Generate harmony colors
    if harmony == 0:
        # Complementary
        hue2 = (base_hue + 180) % 360
        hue3 = (base_hue + 90) % 360
    elif harmony == 1:
        # Triadic
        hue2 = (base_hue + 120) % 360
        hue3 = (base_hue + 240) % 360
    elif harmony == 2:
        # Analogous
        hue2 = (base_hue + 30) % 360
        hue3 = (base_hue + 60) % 360
    else:
        # Split-complementary
        hue2 = (base_hue + 150) % 360
        hue3 = (base_hue + 210) % 360

    primary = _hsl_to_hex(base_hue, saturation, lightness_bias)
    secondary = _hsl_to_hex(hue2, saturation * 0.8, lightness_bias)
    tertiary = _hsl_to_hex(hue3, saturation * 0.6, lightness_bias + 0.1)
    background = _hsl_to_hex(base_hue, 0.1, 0.08)
    foreground = _hsl_to_hex(base_hue, 0.15, 0.85)
    glow = _hsl_to_hex(base_hue, 1.0, 0.65)

    return Palette(
        primary=primary,
        secondary=secondary,
        tertiary=tertiary,
        background=background,
        foreground=foreground,
        glow=glow,
        hue=base_hue,
        saturation=saturation,
    )
