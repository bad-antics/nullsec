#!/usr/bin/env python3
"""
NullSec Ford SYNC Boot Splash Generator
========================================
Generates custom boot splash screens and animation frames
for Ford SYNC 2 (MyFord Touch) and SYNC 3 head units.

Target: 2015 F-250 Lariat (SYNC 2 stock, SYNC 3 upgrade path)

Resolutions:
  SYNC 2: 800x384 (resistive 8" screen)
  SYNC 3: 800x480 (capacitive 8" screen)

Output:
  output/sync2/  - SYNC 2 boot splash + animation frames
  output/sync3/  - SYNC 3 boot splash + animation frames
  output/usb/    - Ready-to-flash USB structure

Author: bad-antics / NullSec
"""

import math
import os
import random
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ── Color Palette ─────────────────────────────────────────────────────
BLACK = (0, 0, 0)
DARK_BG = (8, 8, 12)
NULLSEC_GREEN = (0, 255, 65)
NULLSEC_GREEN_DIM = (0, 180, 45)
NULLSEC_GREEN_GLOW = (0, 255, 65, 80)
DARK_GREEN = (0, 60, 20)
MATRIX_GREEN = (0, 200, 50)
CYAN = (0, 220, 255)
CYAN_DIM = (0, 120, 160)
RED = (255, 40, 40)
AMBER = (255, 176, 0)
WHITE = (255, 255, 255)
GREY = (80, 80, 80)
DARK_GREY = (30, 30, 35)

# ── Font Helpers ──────────────────────────────────────────────────────
def get_font(size, bold=False):
    """Try to load a good monospace font, fall back gracefully."""
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/ubuntu/UbuntuMono-Bold.ttf",
        "/usr/share/fonts/truetype/ubuntu/UbuntuMono-Regular.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    ]
    if bold:
        font_paths = [p for p in font_paths if "Bold" in p] + font_paths
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                continue
    return ImageFont.load_default()


def get_sans_font(size, bold=False):
    """Try to load a sans-serif font for cleaner titles."""
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-Bold.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-Regular.ttf",
    ]
    if bold:
        font_paths = [p for p in font_paths if "Bold" in p] + font_paths
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                continue
    return get_font(size, bold)


# ── Drawing Primitives ───────────────────────────────────────────────

def draw_scanlines(draw, width, height, opacity=15):
    """Draw CRT-style horizontal scanlines."""
    for y in range(0, height, 3):
        draw.line([(0, y), (width, y)], fill=(0, 0, 0, opacity), width=1)


def draw_vignette(img):
    """Apply a dark vignette effect around the edges."""
    w, h = img.size
    vignette = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    # Gradient darkness from edges
    for i in range(60):
        alpha = int(180 * (1 - i / 60) ** 2)
        vdraw.rectangle([i, i, w - i - 1, h - i - 1], outline=(0, 0, 0, alpha))
    img.paste(Image.alpha_composite(img.convert("RGBA"), vignette).convert("RGB"))


def draw_grid(draw, width, height, spacing=40, color=(0, 30, 10)):
    """Draw a subtle background grid."""
    for x in range(0, width, spacing):
        draw.line([(x, 0), (x, height)], fill=color, width=1)
    for y in range(0, height, spacing):
        draw.line([(0, y), (width, y)], fill=color, width=1)


def draw_hex_pattern(draw, width, height):
    """Draw subtle hex characters scattered in background."""
    font = get_font(10)
    random.seed(42)  # Reproducible
    for _ in range(200):
        x = random.randint(0, width)
        y = random.randint(0, height)
        char = random.choice("0123456789ABCDEF")
        alpha = random.randint(15, 40)
        draw.text((x, y), char, fill=(0, alpha + 20, alpha // 2), font=font)


def draw_matrix_rain(draw, width, height, density=0.3, seed=None):
    """Draw Matrix-style falling characters in background."""
    font = get_font(11)
    if seed is not None:
        random.seed(seed)
    chars = "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
    col_spacing = 16
    for col in range(0, width, col_spacing):
        if random.random() > density:
            continue
        stream_len = random.randint(5, height // 14)
        start_y = random.randint(-stream_len * 14, height)
        for i in range(stream_len):
            y = start_y + i * 14
            if y < 0 or y > height:
                continue
            char = random.choice(chars)
            # Head of stream is brightest
            if i == stream_len - 1:
                color = (180, 255, 180)
            elif i >= stream_len - 3:
                color = NULLSEC_GREEN_DIM
            else:
                brightness = max(20, 80 - i * 8)
                color = (0, brightness, brightness // 3)
            draw.text((col, y), char, fill=color, font=font)


def draw_circuit_traces(draw, width, height, seed=42):
    """Draw PCB-style circuit traces."""
    random.seed(seed)
    for _ in range(30):
        x = random.randint(0, width)
        y = random.randint(0, height)
        color = (0, random.randint(30, 60), random.randint(10, 25))
        length = random.randint(30, 200)
        direction = random.choice(["h", "v"])
        if direction == "h":
            draw.line([(x, y), (x + length, y)], fill=color, width=1)
            # Node dot
            draw.ellipse([x + length - 2, y - 2, x + length + 2, y + 2], fill=color)
        else:
            draw.line([(x, y), (x, y + length)], fill=color, width=1)
            draw.ellipse([x - 2, y + length - 2, x + 2, y + length + 2], fill=color)


def draw_nullsec_skull(draw, cx, cy, size, color=NULLSEC_GREEN, glow=True):
    """Draw a stylized NullSec skull logo."""
    s = size
    # Skull outline (rounded rectangle approximation)
    skull_top = cy - s
    skull_bottom = cy + int(s * 0.4)
    skull_left = cx - int(s * 0.7)
    skull_right = cx + int(s * 0.7)
    jaw_bottom = cy + int(s * 0.8)

    # Glow effect
    if glow and s > 10:
        for g in range(8, 0, -1):
            glow_color = (color[0] // 8, color[1] // 8, color[2] // 8)
            draw.rounded_rectangle(
                [skull_left - g, skull_top - g, skull_right + g, skull_bottom + g],
                radius=max(int(s * 0.3), 1),
                outline=glow_color,
                width=2,
            )

    # Main skull shape
    draw.rounded_rectangle(
        [skull_left, skull_top, skull_right, skull_bottom],
        radius=max(int(s * 0.3), 1),
        outline=color,
        width=max(min(3, s // 5), 1),
    )

    # Eye sockets
    eye_size = max(int(s * 0.22), 2)
    eye_y = cy - int(s * 0.3)
    # Left eye
    draw.rounded_rectangle(
        [cx - int(s * 0.4) - eye_size, eye_y - eye_size,
         cx - int(s * 0.4) + eye_size, eye_y + eye_size],
        radius=max(eye_size // 3, 1),
        fill=color,
    )
    # Right eye
    draw.rounded_rectangle(
        [cx + int(s * 0.4) - eye_size, eye_y - eye_size,
         cx + int(s * 0.4) + eye_size, eye_y + eye_size],
        radius=max(eye_size // 3, 1),
        fill=color,
    )
    # Inner eye (dark)
    inner = max(eye_size - 4, 1)
    if inner >= 2:
        draw.rounded_rectangle(
            [cx - int(s * 0.4) - inner, eye_y - inner,
             cx - int(s * 0.4) + inner, eye_y + inner],
            radius=max(inner // 3, 1),
            fill=DARK_BG,
        )
        draw.rounded_rectangle(
            [cx + int(s * 0.4) - inner, eye_y - inner,
             cx + int(s * 0.4) + inner, eye_y + inner],
            radius=max(inner // 3, 1),
            fill=DARK_BG,
        )

    # Nose
    nose_size = max(int(s * 0.08), 2)
    nose_y = cy + int(s * 0.05)
    draw.polygon(
        [(cx, nose_y - nose_size), (cx - nose_size, nose_y + nose_size),
         (cx + nose_size, nose_y + nose_size)],
        fill=DARK_BG,
        outline=color,
    )

    # Jaw / teeth
    jaw_y = cy + int(s * 0.3)
    tooth_w = max(int(s * 0.15), 4)
    num_teeth = 5
    start_x = cx - (num_teeth * tooth_w) // 2
    for i in range(num_teeth):
        tx = start_x + i * tooth_w
        draw.rectangle(
            [tx + 2, jaw_y, tx + tooth_w - 2, jaw_bottom],
            outline=color,
            width=2,
        )

    # Crossbones beneath
    bone_y = jaw_bottom + int(s * 0.15)
    bone_len = int(s * 0.6)
    draw.line(
        [(cx - bone_len, bone_y - 10), (cx + bone_len, bone_y + 10)],
        fill=color, width=3,
    )
    draw.line(
        [(cx - bone_len, bone_y + 10), (cx + bone_len, bone_y - 10)],
        fill=color, width=3,
    )
    # Bone ends
    for bx, by in [(cx - bone_len, bone_y - 10), (cx + bone_len, bone_y + 10),
                    (cx - bone_len, bone_y + 10), (cx + bone_len, bone_y - 10)]:
        draw.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=color)


def draw_f250_silhouette(draw, cx, cy, scale=1.0, color=DARK_GREEN):
    """Draw a simplified F-250 truck silhouette."""
    s = scale
    # Truck body outline points (simplified side view)
    body = [
        (cx - int(180*s), cy + int(20*s)),   # rear bottom
        (cx - int(180*s), cy - int(15*s)),   # rear top
        (cx - int(140*s), cy - int(15*s)),   # bed start
        (cx - int(50*s),  cy - int(15*s)),   # cab rear
        (cx - int(50*s),  cy - int(50*s)),   # cab top rear
        (cx - int(30*s),  cy - int(60*s)),   # roof
        (cx + int(60*s),  cy - int(60*s)),   # windshield top
        (cx + int(100*s), cy - int(30*s)),   # hood
        (cx + int(160*s), cy - int(30*s)),   # front
        (cx + int(180*s), cy - int(20*s)),   # bumper top
        (cx + int(180*s), cy + int(20*s)),   # bumper bottom
    ]
    draw.polygon(body, outline=color, fill=None)
    # Wheels
    wheel_r = int(18 * s)
    # Rear wheel
    draw.ellipse([cx - int(130*s) - wheel_r, cy + int(20*s) - wheel_r,
                  cx - int(130*s) + wheel_r, cy + int(20*s) + wheel_r],
                 outline=color, width=2)
    # Front wheel
    draw.ellipse([cx + int(120*s) - wheel_r, cy + int(20*s) - wheel_r,
                  cx + int(120*s) + wheel_r, cy + int(20*s) + wheel_r],
                 outline=color, width=2)


def draw_progress_bar(draw, x, y, width, height, progress, color=NULLSEC_GREEN, bg=DARK_GREY):
    """Draw a styled progress bar."""
    # Background
    draw.rounded_rectangle([x, y, x + width, y + height], radius=height // 2, fill=bg, outline=GREY)
    # Fill
    fill_w = int((width - 4) * progress)
    if fill_w > 0:
        draw.rounded_rectangle(
            [x + 2, y + 2, x + 2 + fill_w, y + height - 2],
            radius=(height - 4) // 2,
            fill=color,
        )
    # Percentage text
    font = get_font(height - 4)
    pct = f"{int(progress * 100)}%"
    bbox = draw.textbbox((0, 0), pct, font=font)
    tw = bbox[2] - bbox[0]
    draw.text((x + width // 2 - tw // 2, y + 1), pct, fill=WHITE, font=font)


# ── Splash Screen Generators ─────────────────────────────────────────

def generate_main_splash(width, height, label="SYNC"):
    """Generate the primary NullSec boot splash."""
    img = Image.new("RGB", (width, height), DARK_BG)
    draw = ImageDraw.Draw(img)

    # Background layers
    draw_grid(draw, width, height, spacing=50, color=(0, 20, 8))
    draw_circuit_traces(draw, width, height)
    draw_hex_pattern(draw, width, height)

    # NullSec skull logo — centered upper area
    skull_cx = width // 2
    skull_cy = height // 3
    draw_nullsec_skull(draw, skull_cx, skull_cy, size=int(height * 0.22), color=NULLSEC_GREEN)

    # "NULLSEC" title
    title_font = get_sans_font(int(height * 0.12), bold=True)
    title = "NULLSEC"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    title_y = skull_cy + int(height * 0.28)

    # Glow behind title
    for g in range(6, 0, -1):
        glow_col = (0, 40 + g * 5, 10 + g * 2)
        draw.text((skull_cx - tw // 2 - g, title_y), title, fill=glow_col, font=title_font)
        draw.text((skull_cx - tw // 2 + g, title_y), title, fill=glow_col, font=title_font)
    draw.text((skull_cx - tw // 2, title_y), title, fill=NULLSEC_GREEN, font=title_font)

    # Subtitle
    sub_font = get_font(int(height * 0.035))
    subtitle = "F-250 LARIAT  //  SECURITY SYSTEMS ONLINE"
    bbox = draw.textbbox((0, 0), subtitle, font=sub_font)
    sw = bbox[2] - bbox[0]
    sub_y = title_y + int(height * 0.14)
    draw.text((skull_cx - sw // 2, sub_y), subtitle, fill=CYAN_DIM, font=sub_font)

    # Bottom info bar
    info_font = get_font(int(height * 0.028))
    bottom_y = height - int(height * 0.08)
    draw.text((20, bottom_y), f"{label} // NULLSEC OS v2.0", fill=GREY, font=info_font)
    draw.text((width - 250, bottom_y), "bad-antics // 2025", fill=GREY, font=info_font)

    # Decorative lines
    line_y = sub_y + int(height * 0.06)
    line_w = int(width * 0.3)
    draw.line([(skull_cx - line_w, line_y), (skull_cx + line_w, line_y)],
              fill=DARK_GREEN, width=1)
    # Diamond at center of line
    draw.polygon([(skull_cx, line_y - 4), (skull_cx + 4, line_y),
                  (skull_cx, line_y + 4), (skull_cx - 4, line_y)],
                 fill=NULLSEC_GREEN)

    # Truck silhouette (subtle, bottom right)
    draw_f250_silhouette(draw, width - 200, height - 60, scale=0.5, color=(0, 40, 15))

    # Vignette
    draw_vignette(img)

    return img


def generate_matrix_splash(width, height, label="SYNC"):
    """Generate a Matrix-themed boot splash variant."""
    img = Image.new("RGB", (width, height), BLACK)
    draw = ImageDraw.Draw(img)

    # Heavy matrix rain background
    draw_matrix_rain(draw, width, height, density=0.6, seed=42)

    # Dark overlay in center for readability
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    cx, cy = width // 2, height // 2
    for r in range(200, 0, -2):
        alpha = int(200 * (1 - r / 200))
        odraw.ellipse([cx - r * 2, cy - r, cx + r * 2, cy + r],
                      fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)

    # "NULLSEC" in large font
    title_font = get_sans_font(int(height * 0.18), bold=True)
    title = "NULLSEC"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw // 2
    ty = cy - th // 2 - int(height * 0.08)
    draw.text((tx, ty), title, fill=NULLSEC_GREEN, font=title_font)

    # Tagline
    tag_font = get_font(int(height * 0.04))
    tag = "// THERE IS NO SECURITY WITHOUT NULLSEC //"
    bbox = draw.textbbox((0, 0), tag, font=tag_font)
    tgw = bbox[2] - bbox[0]
    draw.text((cx - tgw // 2, ty + th + 15), tag, fill=MATRIX_GREEN, font=tag_font)

    # System info block
    info_font = get_font(int(height * 0.03))
    info_y = ty + th + int(height * 0.15)
    info_lines = [
        f"VEHICLE: 2015 FORD F-250 SUPER DUTY LARIAT",
        f"SYSTEM:  {label} // NULLSEC HARDENED",
        f"STATUS:  ALL SYSTEMS OPERATIONAL",
    ]
    for i, line in enumerate(info_lines):
        color = CYAN_DIM if i == 2 else DARK_GREEN
        draw.text((cx - 220, info_y + i * int(height * 0.045)), line, fill=color, font=info_font)

    draw_vignette(img)
    return img


def generate_hud_splash(width, height, label="SYNC"):
    """Generate a military HUD-style boot splash."""
    img = Image.new("RGB", (width, height), DARK_BG)
    draw = ImageDraw.Draw(img)

    cx, cy = width // 2, height // 2

    # Grid
    draw_grid(draw, width, height, spacing=30, color=(0, 20, 8))

    # Circular HUD elements
    for r in [120, 100, 80]:
        draw.ellipse([cx - r, cy - r - 20, cx + r, cy + r - 20],
                     outline=DARK_GREEN, width=1)

    # Crosshair
    draw.line([(cx - 140, cy - 20), (cx - 50, cy - 20)], fill=NULLSEC_GREEN, width=1)
    draw.line([(cx + 50, cy - 20), (cx + 140, cy - 20)], fill=NULLSEC_GREEN, width=1)
    draw.line([(cx, cy - 160), (cx, cy - 70)], fill=NULLSEC_GREEN, width=1)
    draw.line([(cx, cy + 30), (cx, cy + 120)], fill=NULLSEC_GREEN, width=1)

    # Corner brackets
    blen = 40
    bw = 2
    corners = [
        (30, 30), (width - 30, 30),
        (30, height - 30), (width - 30, height - 30),
    ]
    for i, (bx, by) in enumerate(corners):
        dx = 1 if bx < cx else -1
        dy = 1 if by < cy else -1
        draw.line([(bx, by), (bx + blen * dx, by)], fill=NULLSEC_GREEN, width=bw)
        draw.line([(bx, by), (bx, by + blen * dy)], fill=NULLSEC_GREEN, width=bw)

    # NullSec skull in center
    draw_nullsec_skull(draw, cx, cy - 20, size=int(height * 0.15), color=NULLSEC_GREEN, glow=False)

    # Title below skull
    title_font = get_sans_font(int(height * 0.09), bold=True)
    title = "NULLSEC"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text((cx - tw // 2, cy + int(height * 0.2)), title, fill=NULLSEC_GREEN, font=title_font)

    # HUD data readouts
    hud_font = get_font(int(height * 0.025))
    # Left side
    left_data = [
        "SYS: ONLINE",
        "SEC: ARMED",
        "NET: SECURE",
        "GPS: LOCKED",
    ]
    for i, line in enumerate(left_data):
        draw.text((50, 50 + i * 22), line, fill=NULLSEC_GREEN_DIM, font=hud_font)

    # Right side
    right_data = [
        f"SYNC: {label}",
        "VER: 2.0.0",
        "ENG: 6.7L V8",
        "DRV: 4WD",
    ]
    for i, line in enumerate(right_data):
        bbox = draw.textbbox((0, 0), line, font=hud_font)
        lw = bbox[2] - bbox[0]
        draw.text((width - 50 - lw, 50 + i * 22), line, fill=NULLSEC_GREEN_DIM, font=hud_font)

    # Bottom bar
    draw.rectangle([0, height - 35, width, height], fill=(0, 10, 5))
    draw.line([(0, height - 35), (width, height - 35)], fill=NULLSEC_GREEN, width=1)
    bar_font = get_font(int(height * 0.03))
    draw.text((20, height - 28), "F-250 SUPER DUTY // NULLSEC DEFENSE SYSTEMS", fill=CYAN_DIM, font=bar_font)
    draw.text((width - 200, height - 28), "bad-antics 2025", fill=GREY, font=bar_font)

    draw_vignette(img)
    return img


def generate_boot_animation_frames(width, height, num_frames=30, label="SYNC"):
    """Generate boot animation frame sequence."""
    frames = []

    for f in range(num_frames):
        progress = f / (num_frames - 1)
        img = Image.new("RGB", (width, height), DARK_BG)
        draw = ImageDraw.Draw(img)

        cx, cy = width // 2, height // 2

        # Background - matrix rain with different seeds per frame
        draw_matrix_rain(draw, width, height, density=0.15, seed=f * 7)

        if progress < 0.15:
            # Phase 1: System init text
            font = get_font(int(height * 0.035))
            lines = [
                "[SYS] Initializing NULLSEC OS...",
                "[SYS] Loading security modules...",
                "[SYS] Scanning vehicle systems...",
            ]
            visible = int(progress / 0.15 * len(lines)) + 1
            for i in range(min(visible, len(lines))):
                draw.text((50, 50 + i * 30), lines[i], fill=NULLSEC_GREEN, font=font)
            # Blinking cursor
            if f % 4 < 2:
                cursor_y = 50 + min(visible, len(lines)) * 30
                draw.text((50, cursor_y), "█", fill=NULLSEC_GREEN, font=font)

        elif progress < 0.4:
            # Phase 2: Skull materializes
            sub_prog = (progress - 0.15) / 0.25
            skull_size = int(height * 0.18 * sub_prog)
            if skull_size > 15:
                # Glitch effect during materialization
                offset_x = int(random.gauss(0, 3 * (1 - sub_prog)))
                offset_y = int(random.gauss(0, 2 * (1 - sub_prog)))
                green_val = int(255 * sub_prog)
                skull_color = (0, green_val, green_val // 4)
                draw_nullsec_skull(draw, cx + offset_x, cy - 30 + offset_y,
                                   size=skull_size, color=skull_color, glow=sub_prog > 0.5)

        elif progress < 0.7:
            # Phase 3: Skull + title appears
            draw_nullsec_skull(draw, cx, cy - 30, size=int(height * 0.18), color=NULLSEC_GREEN)
            sub_prog = (progress - 0.4) / 0.3
            title_font = get_sans_font(int(height * 0.1), bold=True)
            title = "NULLSEC"
            bbox = draw.textbbox((0, 0), title, font=title_font)
            tw = bbox[2] - bbox[0]
            title_y = cy + int(height * 0.22)
            # Title slides in with typewriter effect
            visible_chars = int(len(title) * sub_prog) + 1
            partial = title[:visible_chars]
            draw.text((cx - tw // 2, title_y), partial, fill=NULLSEC_GREEN, font=title_font)

        else:
            # Phase 4: Full splash with progress bar
            draw_nullsec_skull(draw, cx, cy - 30, size=int(height * 0.18), color=NULLSEC_GREEN)
            title_font = get_sans_font(int(height * 0.1), bold=True)
            title = "NULLSEC"
            bbox = draw.textbbox((0, 0), title, font=title_font)
            tw = bbox[2] - bbox[0]
            title_y = cy + int(height * 0.22)
            draw.text((cx - tw // 2, title_y), title, fill=NULLSEC_GREEN, font=title_font)

            # Progress bar
            bar_prog = (progress - 0.7) / 0.3
            bar_y = title_y + int(height * 0.12)
            draw_progress_bar(draw, cx - 150, bar_y, 300, 20, bar_prog)

            # Status text
            status_font = get_font(int(height * 0.025))
            statuses = ["Loading drivers...", "Initializing CAN bus...",
                        "Arming security...", "Systems online"]
            status_idx = min(int(bar_prog * len(statuses)), len(statuses) - 1)
            status = statuses[status_idx]
            bbox = draw.textbbox((0, 0), status, font=status_font)
            sw = bbox[2] - bbox[0]
            draw.text((cx - sw // 2, bar_y + 28), status, fill=CYAN_DIM, font=status_font)

        draw_vignette(img)
        frames.append(img)

    return frames


def generate_shutdown_splash(width, height, label="SYNC"):
    """Generate a shutdown/goodbye splash screen."""
    img = Image.new("RGB", (width, height), BLACK)
    draw = ImageDraw.Draw(img)
    cx, cy = width // 2, height // 2

    # Subtle grid
    draw_grid(draw, width, height, spacing=50, color=(0, 12, 5))

    # Skull with red tint (powering down)
    draw_nullsec_skull(draw, cx, cy - 20, size=int(height * 0.18), color=AMBER, glow=True)

    # "SYSTEM SECURED" text
    title_font = get_sans_font(int(height * 0.08), bold=True)
    title = "SYSTEM SECURED"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text((cx - tw // 2, cy + int(height * 0.22)), title, fill=AMBER, font=title_font)

    # Subtitle
    sub_font = get_font(int(height * 0.03))
    sub = "ALL SYSTEMS LOCKED // NULLSEC ARMED"
    bbox = draw.textbbox((0, 0), sub, font=sub_font)
    sw = bbox[2] - bbox[0]
    draw.text((cx - sw // 2, cy + int(height * 0.35)), sub, fill=DARK_GREEN, font=sub_font)

    draw_vignette(img)
    return img


# ── Main Build ────────────────────────────────────────────────────────

def build_all():
    """Generate all splash screens and animations."""
    base_dir = Path(__file__).parent / "output"

    configs = [
        ("sync2", 800, 384, "SYNC 2"),
        ("sync3", 800, 480, "SYNC 3"),
    ]

    for folder, w, h, label in configs:
        out_dir = base_dir / folder
        out_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n{'='*60}")
        print(f"  Generating {label} splash screens ({w}x{h})")
        print(f"{'='*60}")

        # Static splash variants
        print(f"  [1/5] Main splash...")
        img = generate_main_splash(w, h, label)
        img.save(out_dir / "splash_main.png", "PNG")
        img.save(out_dir / "splash_main.bmp", "BMP")
        print(f"        → {out_dir}/splash_main.png")

        print(f"  [2/5] Matrix splash...")
        img = generate_matrix_splash(w, h, label)
        img.save(out_dir / "splash_matrix.png", "PNG")
        img.save(out_dir / "splash_matrix.bmp", "BMP")
        print(f"        → {out_dir}/splash_matrix.png")

        print(f"  [3/5] HUD splash...")
        img = generate_hud_splash(w, h, label)
        img.save(out_dir / "splash_hud.png", "PNG")
        img.save(out_dir / "splash_hud.bmp", "BMP")
        print(f"        → {out_dir}/splash_hud.png")

        print(f"  [4/5] Shutdown splash...")
        img = generate_shutdown_splash(w, h, label)
        img.save(out_dir / "splash_shutdown.png", "PNG")
        img.save(out_dir / "splash_shutdown.bmp", "BMP")
        print(f"        → {out_dir}/splash_shutdown.png")

        # Boot animation frames
        print(f"  [5/5] Boot animation ({30} frames)...")
        anim_dir = out_dir / "boot_animation"
        anim_dir.mkdir(parents=True, exist_ok=True)
        frames = generate_boot_animation_frames(w, h, num_frames=30, label=label)
        for i, frame in enumerate(frames):
            frame.save(anim_dir / f"frame_{i:03d}.png", "PNG")
        # Also save as animated GIF for preview
        frames[0].save(
            out_dir / "boot_animation.gif",
            save_all=True,
            append_images=frames[1:],
            duration=100,
            loop=0,
        )
        print(f"        → {anim_dir}/ ({len(frames)} frames)")
        print(f"        → {out_dir}/boot_animation.gif (preview)")

    # USB flash structure
    print(f"\n{'='*60}")
    print(f"  Building USB flash package")
    print(f"{'='*60}")
    build_usb_package(base_dir)

    print(f"\n{'='*60}")
    print(f"  ✅ ALL DONE!")
    print(f"{'='*60}")
    print(f"\n  Output: {base_dir.resolve()}/")
    print(f"  USB:    {base_dir.resolve()}/usb/")
    print(f"\n  Total files generated:")
    total = sum(1 for _ in base_dir.rglob("*") if _.is_file())
    print(f"    {total} files")


def build_usb_package(base_dir):
    """Build the USB flash drive structure for SYNC installation."""
    usb_dir = base_dir / "usb"

    # SYNC 3 theme structure
    sync3_theme = usb_dir / "sync3_theme" / "SyncMyRide"
    sync3_theme.mkdir(parents=True, exist_ok=True)

    # Copy SYNC 3 splash as the boot image
    import shutil
    sync3_src = base_dir / "sync3"
    if sync3_src.exists():
        shutil.copy2(sync3_src / "splash_main.png", sync3_theme / "splash.png")
        shutil.copy2(sync3_src / "splash_main.png", sync3_theme / "logo.png")

    # SYNC 3 autoinstall.lst (tells SYNC 3 to pick up the theme)
    (usb_dir / "sync3_theme" / "autoinstall.lst").write_text(
        "SyncMyRide/splash.png;/fs/images/splash.png\n"
        "SyncMyRide/logo.png;/fs/images/logo.png\n"
    )

    # Wallpapers USB (works on SYNC 2 & 3 — user selects via Settings > Display)
    wall_dir = usb_dir / "wallpapers"
    wall_dir.mkdir(parents=True, exist_ok=True)
    for variant in ["sync2", "sync3"]:
        src = base_dir / variant
        if src.exists():
            for img_file in src.glob("splash_*.png"):
                # SYNC needs JPG wallpapers
                img = Image.open(img_file)
                jpg_name = img_file.stem.replace("splash_", f"NullSec_{variant}_") + ".jpg"
                img.convert("RGB").save(wall_dir / jpg_name, "JPEG", quality=95)

    # README with install instructions
    readme = usb_dir / "INSTALL_README.txt"
    readme.write_text("""\
╔══════════════════════════════════════════════════════════════╗
║           NULLSEC FORD SYNC BOOT SPLASH INSTALLER           ║
║                  2015 F-250 LARIAT EDITION                   ║
╚══════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════
  METHOD 1: CUSTOM WALLPAPERS (Easy — SYNC 2 & SYNC 3)
═══════════════════════════════════════════════════════════════

  1. Copy the "wallpapers/" folder contents to a USB drive
  2. Plug USB into the truck's USB port
  3. On the SYNC screen: Settings > Display > Wallpaper
  4. Select "Add Wallpaper" and choose from USB
  5. Set as your wallpaper

  Files: wallpapers/*.jpg

═══════════════════════════════════════════════════════════════
  METHOD 2: BOOT SPLASH REPLACEMENT (SYNC 3 Only — Advanced)
═══════════════════════════════════════════════════════════════

  *** REQUIRES SYNC 3 (upgrade from stock SYNC 2) ***

  Option A — Cyanlabs Syn3 Updater:
    1. Download Syn3 Updater from cyanlabs.net
    2. Use it to create a USB update package
    3. Add the splash.png to the custom files section
    4. Flash via USB (truck must be running, takes ~30 min)

  Option B — Manual (requires Forscan):
    1. Copy "sync3_theme/" folder to root of USB drive
    2. Plug USB into truck
    3. SYNC will read autoinstall.lst and replace boot images
    4. Reboot SYNC (hold power + seek right for 10 sec)

  Option C — SSH/Telnet (requires SYNC 3 root access):
    1. Enable developer mode on SYNC 3
    2. SSH into the head unit (default: root@192.168.1.1)
    3. Replace /fs/images/splash.png with custom image
    4. Reboot

═══════════════════════════════════════════════════════════════
  METHOD 3: FORSCAN APIM MODS (SYNC 2 & SYNC 3)
═══════════════════════════════════════════════════════════════

  Required hardware:
    - OBDLink EX adapter ($40 on Amazon)
    - Laptop with Forscan (Windows)

  APIM Module: 7D0 (address for SYNC module)

  Useful As-Built tweaks for 2015 F-250 Lariat:
    7D0-01-01  xx4x xxxx xxxx  → Enable SYNC master reset
    7D0-01-02  xxxx xxxx xx2x  → Nav w/o SD card
    7D0-02-01  xxxx x1xx xxxx  → Enable Siri/Google Eyes-Free
    7D0-02-01  xxxx xx4x xxxx  → HD Radio text

  Always save your STOCK as-built data before changing anything!

═══════════════════════════════════════════════════════════════
  SYNC 2 → SYNC 3 UPGRADE PARTS LIST
═══════════════════════════════════════════════════════════════

  For the full SYNC 3 experience (recommended):

  1. SYNC 3 APIM:  HC3T-14G371-BCF (or similar, 2018+ F-150)
     - eBay/car-part.com: $80-150 used
  2. 8" Screen:     GJ5T-18B955-CB (capacitive touch)
     - eBay: $60-120 used
  3. GPS Antenna:   (if missing) ~$15
  4. USB Media Hub: HC3Z-19A387-B  ~$30
  5. Wiring:        Plug-and-play for 2015 F-250

  Total: ~$200-350 from junkyard parts

  After install, use Forscan to program the new APIM with
  your VIN and correct as-built data for your truck.

═══════════════════════════════════════════════════════════════
  GENERATED BY: NullSec Ford SYNC Splash Generator
  VEHICLE:      2015 Ford F-250 Super Duty Lariat
  AUTHOR:       bad-antics // NullSec
  DATE:         2025
═══════════════════════════════════════════════════════════════
""")

    print(f"  → {usb_dir}/sync3_theme/ (boot splash replacement)")
    print(f"  → {usb_dir}/wallpapers/ (easy wallpaper install)")
    print(f"  → {usb_dir}/INSTALL_README.txt")


if __name__ == "__main__":
    build_all()
