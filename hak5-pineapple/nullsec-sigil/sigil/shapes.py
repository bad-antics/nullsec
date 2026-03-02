"""
SVG shape primitives for sigil rendering.
Each shape is a dataclass that can render itself as SVG elements.
"""

import math
from dataclasses import dataclass
from typing import List, Tuple


def _polygon_points(cx: float, cy: float, radius: float,
                    sides: int, rotation: float = 0) -> List[Tuple[float, float]]:
    """Generate polygon vertex coordinates."""
    points = []
    for i in range(sides):
        angle = math.radians(rotation + (360.0 / sides) * i - 90)
        x = cx + radius * math.cos(angle)
        y = cy + radius * math.sin(angle)
        points.append((x, y))
    return points


def _points_str(points: List[Tuple[float, float]]) -> str:
    """Convert points to SVG points attribute string."""
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in points)


@dataclass
class Ring:
    """Outer ring shape."""
    sides: int
    rotation: float
    stroke_width: float

    def render(self, cx: float, cy: float, radius: float,
               color: str, opacity: float = 0.8) -> str:
        if self.sides <= 2:
            # Circle
            return (f'<circle cx="{cx}" cy="{cy}" r="{radius}" '
                    f'fill="none" stroke="{color}" stroke-width="{self.stroke_width}" '
                    f'opacity="{opacity}" />')
        points = _polygon_points(cx, cy, radius, self.sides, self.rotation)
        return (f'<polygon points="{_points_str(points)}" '
                f'fill="none" stroke="{color}" stroke-width="{self.stroke_width}" '
                f'opacity="{opacity}" />')


@dataclass
class Mandala:
    """Inner mandala / flower pattern."""
    petals: int
    symmetry: int
    radius_ratio: float  # relative to canvas

    def render(self, cx: float, cy: float, canvas_size: float,
               color: str, secondary: str) -> str:
        elements = []
        radius = canvas_size * self.radius_ratio
        petal_len = radius * 0.6

        for layer in range(self.symmetry):
            layer_radius = radius * (1 - layer * 0.15)
            layer_opacity = 0.7 - layer * 0.1
            offset = layer * (180.0 / self.petals)

            for i in range(self.petals):
                angle = math.radians(offset + (360.0 / self.petals) * i)
                x1 = cx + layer_radius * 0.2 * math.cos(angle)
                y1 = cy + layer_radius * 0.2 * math.sin(angle)
                x2 = cx + layer_radius * math.cos(angle)
                y2 = cy + layer_radius * math.sin(angle)

                # Petal as an elliptical arc
                c = color if layer % 2 == 0 else secondary
                ctrl_angle = angle + math.pi / (self.petals * 2)
                ctrl_x = cx + petal_len * 0.7 * math.cos(ctrl_angle)
                ctrl_y = cy + petal_len * 0.7 * math.sin(ctrl_angle)

                elements.append(
                    f'<line x1="{x1:.2f}" y1="{y1:.2f}" '
                    f'x2="{x2:.2f}" y2="{y2:.2f}" '
                    f'stroke="{c}" stroke-width="1.5" '
                    f'opacity="{layer_opacity:.2f}" />'
                )

                # Petal tip dot
                dot_r = 2.0 + layer * 0.5
                elements.append(
                    f'<circle cx="{x2:.2f}" cy="{y2:.2f}" r="{dot_r}" '
                    f'fill="{c}" opacity="{layer_opacity:.2f}" />'
                )

        return "\n    ".join(elements)


@dataclass
class CoreGlyph:
    """Central polygon glyph."""
    sides: int
    fill_style: str

    def render(self, cx: float, cy: float, radius: float,
               color: str, bg_color: str) -> str:
        points = _polygon_points(cx, cy, radius, self.sides)
        pts = _points_str(points)

        if self.fill_style == "solid":
            return (f'<polygon points="{pts}" fill="{color}" '
                    f'opacity="0.6" stroke="{color}" stroke-width="1" />')
        elif self.fill_style == "hollow":
            return (f'<polygon points="{pts}" fill="none" '
                    f'stroke="{color}" stroke-width="2" opacity="0.8" />')
        elif self.fill_style == "gradient":
            grad_id = f"glyph_grad_{self.sides}"
            grad = (f'<defs><radialGradient id="{grad_id}">'
                    f'<stop offset="0%" stop-color="{color}" stop-opacity="0.8" />'
                    f'<stop offset="100%" stop-color="{bg_color}" stop-opacity="0.1" />'
                    f'</radialGradient></defs>')
            poly = (f'<polygon points="{pts}" fill="url(#{grad_id})" '
                    f'stroke="{color}" stroke-width="1" />')
            return f"{grad}\n    {poly}"
        elif self.fill_style == "hatched":
            hatch_id = f"hatch_{self.sides}"
            pattern = (
                f'<defs><pattern id="{hatch_id}" patternUnits="userSpaceOnUse" '
                f'width="6" height="6" patternTransform="rotate(45)">'
                f'<line x1="0" y1="0" x2="0" y2="6" stroke="{color}" '
                f'stroke-width="1" opacity="0.5" />'
                f'</pattern></defs>')
            poly = (f'<polygon points="{pts}" fill="url(#{hatch_id})" '
                    f'stroke="{color}" stroke-width="1.5" />')
            return f"{pattern}\n    {poly}"
        else:
            # dotted fill — just outline with dots at vertices
            elements = [f'<polygon points="{pts}" fill="none" '
                        f'stroke="{color}" stroke-width="1" opacity="0.7" />']
            for px, py in points:
                elements.append(f'<circle cx="{px:.2f}" cy="{py:.2f}" r="3" '
                                f'fill="{color}" opacity="0.8" />')
            return "\n    ".join(elements)


@dataclass
class ParticleField:
    """Scattered dots around the sigil."""
    count: int
    spread: float
    opacity: float

    def render(self, cx: float, cy: float, canvas_size: float,
               color: str, hash_bytes: bytes) -> str:
        elements = []
        max_r = canvas_size * self.spread * 0.45

        for i in range(self.count):
            # Deterministic positioning from hash
            b1 = hash_bytes[i % 32]
            b2 = hash_bytes[(i + 7) % 32]
            angle = (b1 / 255.0) * 2 * math.pi + (i * 0.618033988749895 * 2 * math.pi)
            dist = (b2 / 255.0) * max_r * 0.4 + max_r * 0.5
            x = cx + dist * math.cos(angle)
            y = cy + dist * math.sin(angle)
            r = 1.0 + (b1 % 4) * 0.5
            op = self.opacity * (0.5 + (b2 / 255.0) * 0.5)

            elements.append(
                f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.1f}" '
                f'fill="{color}" opacity="{op:.2f}" />'
            )

        return "\n    ".join(elements)


@dataclass
class ConnectingArcs:
    """Curved lines connecting elements."""
    count: int
    curvature: float

    def render(self, cx: float, cy: float, radius: float,
               color: str, hash_bytes: bytes) -> str:
        elements = []

        for i in range(self.count):
            b1 = hash_bytes[(i * 3) % 32]
            b2 = hash_bytes[(i * 3 + 1) % 32]
            b3 = hash_bytes[(i * 3 + 2) % 32]

            angle1 = (b1 / 255.0) * 2 * math.pi
            angle2 = (b2 / 255.0) * 2 * math.pi
            r1 = radius * (0.3 + (b3 / 255.0) * 0.6)
            r2 = radius * (0.4 + (b1 / 255.0) * 0.5)

            x1 = cx + r1 * math.cos(angle1)
            y1 = cy + r1 * math.sin(angle1)
            x2 = cx + r2 * math.cos(angle2)
            y2 = cy + r2 * math.sin(angle2)

            sweep = 1 if b3 % 2 == 0 else 0
            arc_r = radius * self.curvature * 1.5

            elements.append(
                f'<path d="M {x1:.2f},{y1:.2f} A {arc_r:.2f},{arc_r:.2f} 0 0 {sweep} '
                f'{x2:.2f},{y2:.2f}" fill="none" stroke="{color}" '
                f'stroke-width="0.8" opacity="0.4" />'
            )

        return "\n    ".join(elements)


@dataclass
class BorderRunes:
    """Tick marks around the border encoding the hash prefix."""
    tick_count: int

    def render(self, cx: float, cy: float, radius: float,
               color: str, hash_hex: str) -> str:
        elements = []
        inner_r = radius - 8
        outer_r = radius - 2

        for i in range(self.tick_count):
            angle = math.radians((360.0 / self.tick_count) * i - 90)

            # Vary tick length based on hash character
            char_idx = i % len(hash_hex)
            char_val = int(hash_hex[char_idx], 16)
            tick_inner = inner_r - (char_val / 15.0) * 6

            x1 = cx + tick_inner * math.cos(angle)
            y1 = cy + tick_inner * math.sin(angle)
            x2 = cx + outer_r * math.cos(angle)
            y2 = cy + outer_r * math.sin(angle)

            op = 0.3 + (char_val / 15.0) * 0.5
            sw = 0.5 + (char_val / 15.0) * 1.5

            elements.append(
                f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
                f'stroke="{color}" stroke-width="{sw:.1f}" opacity="{op:.2f}" />'
            )

        return "\n    ".join(elements)


@dataclass
class Background:
    """Gradient background."""
    angle: float
    darkness: float

    def render(self, size: float, color1: str, color2: str) -> str:
        rad = math.radians(self.angle)
        x1 = 50 + 50 * math.cos(rad)
        y1 = 50 + 50 * math.sin(rad)
        x2 = 50 - 50 * math.cos(rad)
        y2 = 50 - 50 * math.sin(rad)

        return (
            f'<defs><linearGradient id="bg_grad" '
            f'x1="{x1:.1f}%" y1="{y1:.1f}%" x2="{x2:.1f}%" y2="{y2:.1f}%">'
            f'<stop offset="0%" stop-color="{color1}" />'
            f'<stop offset="100%" stop-color="{color2}" />'
            f'</linearGradient></defs>'
            f'<rect width="{size}" height="{size}" fill="url(#bg_grad)" />'
        )
