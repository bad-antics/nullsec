"""
nullsec-sigil — Visual Hash Fingerprinting
Turn any hash into unique geometric SVG art.
"""

__version__ = "1.0.0"
__author__ = "bad-antics"

from .core import Sigil
from .palette import Palette
from .renderer import render_svg, render_ascii
from .themes import THEMES

__all__ = ["Sigil", "Palette", "render_svg", "render_ascii", "THEMES"]
