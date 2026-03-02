"""
SVG and ASCII renderers for sigils.
"""

from .shapes import (
    Ring, Mandala, CoreGlyph, ParticleField,
    ConnectingArcs, BorderRunes, Background
)


def render_svg(params, theme, size: int, hash_hex: str) -> str:
    """Render a full sigil as SVG."""
    cx = size / 2
    cy = size / 2
    palette = params.palette
    hash_bytes = bytes.fromhex(hash_hex)

    # Background
    bg = Background(angle=params.bg_angle, darkness=params.bg_darkness)
    bg_svg = bg.render(size, theme.bg_primary, theme.bg_secondary)

    # Border runes (outermost)
    runes = BorderRunes(tick_count=params.rune_ticks)
    runes_svg = runes.render(cx, cy, size * 0.48, palette.foreground, hash_hex)

    # Outer ring
    ring = Ring(sides=params.ring_sides, rotation=params.ring_rotation,
                stroke_width=params.ring_stroke)
    ring_svg = ring.render(cx, cy, size * 0.42, palette.primary)

    # Connecting arcs
    arcs = ConnectingArcs(count=params.arc_count, curvature=params.arc_curvature)
    arcs_svg = arcs.render(cx, cy, size * 0.38, palette.tertiary, hash_bytes)

    # Particle field
    particles = ParticleField(count=params.particle_count,
                               spread=params.particle_spread,
                               opacity=params.particle_opacity)
    particles_svg = particles.render(cx, cy, size, palette.secondary, hash_bytes)

    # Mandala
    mandala = Mandala(petals=params.mandala_petals,
                      symmetry=params.mandala_symmetry,
                      radius_ratio=params.mandala_radius)
    mandala_svg = mandala.render(cx, cy, size, palette.primary, palette.secondary)

    # Core glyph
    glyph = CoreGlyph(sides=params.glyph_sides, fill_style=params.glyph_fill)
    glyph_svg = glyph.render(cx, cy, size * 0.08, palette.glow, palette.background)

    # Glow filter
    glow_filter = ""
    if theme.glow_enabled:
        glow_filter = (
            '<defs>'
            '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%">'
            '<feGaussianBlur stdDeviation="3" result="blur" />'
            '<feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>'
            '</filter>'
            '</defs>'
        )

    # Hash label
    label_y = size - 12
    label = (f'<text x="{cx}" y="{label_y}" text-anchor="middle" '
             f'font-family="monospace" font-size="9" fill="{palette.foreground}" '
             f'opacity="0.4">{hash_hex[:16]}…{hash_hex[-8:]}</text>')

    # Assemble SVG
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}"
     width="{size}" height="{size}">
  <title>Sigil: {hash_hex[:16]}</title>
  {glow_filter}
  {bg_svg}
  <g filter="{'url(#glow)' if theme.glow_enabled else 'none'}">
    {runes_svg}
    {ring_svg}
    {arcs_svg}
    {particles_svg}
    {mandala_svg}
    {glyph_svg}
  </g>
  {label}
</svg>"""

    return svg


def render_ascii(params, hash_hex: str) -> str:
    """Render a simplified ASCII representation of the sigil."""
    width = 48
    height = 24
    canvas = [[' ' for _ in range(width)] for _ in range(height)]
    cx, cy = width // 2, height // 2

    hash_bytes = bytes.fromhex(hash_hex)

    # Draw ring
    import math
    ring_r = min(cx, cy) - 2
    sides = params.ring_sides
    if sides <= 2:
        # Circle
        for i in range(64):
            angle = (i / 64) * 2 * math.pi
            x = int(cx + ring_r * math.cos(angle) * 1.8)
            y = int(cy + ring_r * math.sin(angle))
            if 0 <= x < width and 0 <= y < height:
                canvas[y][x] = '·'
    else:
        points = []
        for i in range(sides):
            angle = math.radians(params.ring_rotation + (360.0 / sides) * i - 90)
            x = cx + ring_r * math.cos(angle) * 1.8
            y = cy + ring_r * math.sin(angle)
            points.append((x, y))
        for i in range(len(points)):
            x1, y1 = points[i]
            x2, y2 = points[(i + 1) % len(points)]
            steps = max(abs(int(x2 - x1)), abs(int(y2 - y1)), 1)
            for s in range(steps + 1):
                t = s / steps
                x = int(x1 + (x2 - x1) * t)
                y = int(y1 + (y2 - y1) * t)
                if 0 <= x < width and 0 <= y < height:
                    canvas[y][x] = '+'

    # Draw mandala spokes
    for i in range(params.mandala_petals):
        angle = (2 * math.pi / params.mandala_petals) * i
        for d in range(2, int(ring_r * 0.6)):
            x = int(cx + d * math.cos(angle) * 1.8)
            y = int(cy + d * math.sin(angle))
            if 0 <= x < width and 0 <= y < height:
                canvas[y][x] = '─' if abs(math.cos(angle)) > 0.7 else '│'

    # Core glyph
    glyphs = ['△', '◇', '⬠', '⬡', '◯', '☆']
    canvas[cy][cx] = glyphs[params.glyph_sides % len(glyphs)]

    # Build output
    border = '╔' + '═' * width + '╗'
    bottom = '╚' + '═' * width + '╝'

    lines = [border]
    for row in canvas:
        lines.append('║' + ''.join(row) + '║')
    lines.append(bottom)
    lines.append(f"  {hash_hex[:32]}")
    lines.append(f"  {hash_hex[32:]}")

    return '\n'.join(lines)
