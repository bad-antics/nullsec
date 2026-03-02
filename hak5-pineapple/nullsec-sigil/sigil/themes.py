"""
Theme definitions for sigil rendering.
"""

from dataclasses import dataclass, field
from typing import Optional
from .palette import Palette, _hsl_to_hex


@dataclass
class Theme:
    """A rendering theme that can override palette colors."""
    name: str
    override_palette: bool = False
    bg_primary: str = "#0a0a0f"
    bg_secondary: str = "#12121a"
    base_hue_range: Optional[tuple] = None  # (min, max) — None = use hash
    saturation_range: tuple = (0.5, 1.0)
    lightness_range: tuple = (0.4, 0.7)
    glow_enabled: bool = True

    def generate_palette(self, four_bytes: bytes) -> Palette:
        """Generate a theme-constrained palette from hash bytes."""
        if self.base_hue_range:
            hmin, hmax = self.base_hue_range
            base_hue = hmin + (four_bytes[0] / 255.0) * (hmax - hmin)
        else:
            base_hue = (four_bytes[0] / 255.0) * 360.0

        smin, smax = self.saturation_range
        saturation = smin + (four_bytes[1] / 255.0) * (smax - smin)

        lmin, lmax = self.lightness_range
        lightness = lmin + (four_bytes[3] / 255.0) * (lmax - lmin)

        harmony = four_bytes[2] % 4
        if harmony == 0:
            hue2 = (base_hue + 180) % 360
            hue3 = (base_hue + 90) % 360
        elif harmony == 1:
            hue2 = (base_hue + 120) % 360
            hue3 = (base_hue + 240) % 360
        elif harmony == 2:
            hue2 = (base_hue + 30) % 360
            hue3 = (base_hue + 60) % 360
        else:
            hue2 = (base_hue + 150) % 360
            hue3 = (base_hue + 210) % 360

        return Palette(
            primary=_hsl_to_hex(base_hue, saturation, lightness),
            secondary=_hsl_to_hex(hue2, saturation * 0.8, lightness),
            tertiary=_hsl_to_hex(hue3, saturation * 0.6, lightness + 0.1),
            background=self.bg_primary,
            foreground=_hsl_to_hex(base_hue, 0.15, 0.85),
            glow=_hsl_to_hex(base_hue, 1.0, 0.65),
            hue=base_hue,
            saturation=saturation,
        )


THEMES = {
    "dark": Theme(
        name="dark",
        bg_primary="#0a0a0f",
        bg_secondary="#12121a",
    ),
    "light": Theme(
        name="light",
        bg_primary="#f5f5f0",
        bg_secondary="#e8e8e0",
        lightness_range=(0.3, 0.5),
    ),
    "neon": Theme(
        name="neon",
        override_palette=True,
        bg_primary="#0a0010",
        bg_secondary="#150020",
        saturation_range=(0.8, 1.0),
        lightness_range=(0.5, 0.7),
        glow_enabled=True,
    ),
    "mono": Theme(
        name="mono",
        override_palette=True,
        bg_primary="#111111",
        bg_secondary="#1a1a1a",
        saturation_range=(0.0, 0.05),
        lightness_range=(0.4, 0.8),
        glow_enabled=False,
    ),
    "fire": Theme(
        name="fire",
        override_palette=True,
        bg_primary="#0f0500",
        bg_secondary="#1a0800",
        base_hue_range=(0, 60),
        saturation_range=(0.7, 1.0),
        lightness_range=(0.4, 0.6),
    ),
    "ice": Theme(
        name="ice",
        override_palette=True,
        bg_primary="#000510",
        bg_secondary="#000a18",
        base_hue_range=(180, 240),
        saturation_range=(0.5, 0.9),
        lightness_range=(0.45, 0.7),
    ),
    "matrix": Theme(
        name="matrix",
        override_palette=True,
        bg_primary="#000800",
        bg_secondary="#001200",
        base_hue_range=(110, 140),
        saturation_range=(0.7, 1.0),
        lightness_range=(0.35, 0.6),
        glow_enabled=True,
    ),
}
