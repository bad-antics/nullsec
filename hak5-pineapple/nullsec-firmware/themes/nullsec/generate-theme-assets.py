#!/usr/bin/env python3
"""
NullSec Theme Asset Generator
Creates all custom graphics for the NullSec Pineapple Pager theme

Author: bad-antics / NullSec
Credits: Built for Hak5 WiFi Pineapple Pager

Screen Resolution: 480x222 pixels
Color Depth: 8-bit colormap PNG
"""

import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Installing Pillow...")
    os.system("pip install Pillow")
    from PIL import Image, ImageDraw, ImageFont, ImageFilter

import random
import math

# Screen dimensions
SCREEN_WIDTH = 480
SCREEN_HEIGHT = 222

# NullSec color palette
COLORS = {
    'black': (0, 0, 0),
    'dark_bg': (10, 10, 15),
    'dark_red': (100, 0, 0),
    'red': (200, 0, 0),
    'bright_red': (255, 0, 0),
    'red_glow': (255, 50, 50),
    'dark_gray': (30, 30, 35),
    'gray': (60, 60, 70),
    'light_gray': (120, 120, 130),
    'green': (0, 255, 65),
    'matrix_green': (57, 255, 20),
    'cyan': (0, 255, 200),
    'white': (255, 255, 255),
    'yellow': (255, 200, 0),
    'orange': (255, 100, 0),
}

# Base output directory
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(OUTPUT_DIR, 'assets')

def ensure_dir(path):
    """Create directory if it doesn't exist"""
    os.makedirs(path, exist_ok=True)

def draw_scanlines(draw, width, height, color=(30, 30, 30), spacing=3, alpha=50):
    """Draw CRT-style scanlines"""
    for y in range(0, height, spacing):
        draw.line([(0, y), (width, y)], fill=(*color, alpha))

def draw_grid(draw, width, height, color=(40, 0, 0), spacing=20):
    """Draw subtle grid pattern"""
    for x in range(0, width, spacing):
        draw.line([(x, 0), (x, height)], fill=color)
    for y in range(0, height, spacing):
        draw.line([(0, y), (width, y)], fill=color)

def draw_matrix_rain(draw, width, height, density=0.1):
    """Draw matrix-style rain effect"""
    chars = "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 8)
    except:
        font = ImageFont.load_default()
    
    for x in range(0, width, 12):
        if random.random() < density:
            y_start = random.randint(0, height)
            for i in range(random.randint(3, 10)):
                y = y_start + i * 10
                if y < height:
                    char = random.choice(chars)
                    alpha = 255 - (i * 25)
                    green = max(50, 255 - (i * 30))
                    draw.text((x, y), char, fill=(0, green, 20), font=font)

def draw_hex_pattern(draw, width, height, color=(40, 0, 0)):
    """Draw hexagonal pattern background"""
    size = 15
    for row in range(0, height + size, int(size * 1.5)):
        offset = (row // int(size * 1.5)) % 2 * (size * 0.866)
        for col in range(int(-size), width + size, int(size * 1.732)):
            x = col + offset
            y = row
            points = []
            for i in range(6):
                angle = math.pi / 3 * i
                px = x + size * 0.5 * math.cos(angle)
                py = y + size * 0.5 * math.sin(angle)
                points.append((px, py))
            draw.polygon(points, outline=color)

def draw_nullsec_logo(draw, x, y, size=40, color=COLORS['red']):
    """Draw stylized NullSec logo"""
    # Draw skull-like icon with crosshairs
    # Circle head
    draw.ellipse([x, y, x + size, y + size], outline=color, width=2)
    # Eyes (Xs)
    eye_size = size // 6
    ex1, ey = x + size//4, y + size//3
    ex2 = x + 3*size//4 - eye_size
    draw.line([(ex1, ey), (ex1+eye_size, ey+eye_size)], fill=color, width=2)
    draw.line([(ex1+eye_size, ey), (ex1, ey+eye_size)], fill=color, width=2)
    draw.line([(ex2, ey), (ex2+eye_size, ey+eye_size)], fill=color, width=2)
    draw.line([(ex2+eye_size, ey), (ex2, ey+eye_size)], fill=color, width=2)
    # Crosshair
    cx, cy = x + size//2, y + size//2
    draw.line([(cx - size//2 - 5, cy), (cx - size//3, cy)], fill=color, width=2)
    draw.line([(cx + size//3, cy), (cx + size//2 + 5, cy)], fill=color, width=2)
    draw.line([(cx, cy - size//2 - 5), (cx, cy - size//3)], fill=color, width=2)
    draw.line([(cx, cy + size//3), (cx, cy + size//2 + 5)], fill=color, width=2)

def create_boot_animation_frames():
    """Create custom NullSec boot animation frames"""
    print("Creating boot animation frames...")
    boot_dir = os.path.join(ASSETS_DIR, 'boot_animation')
    ensure_dir(boot_dir)
    
    try:
        font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 36)
        font_med = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 14)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
    except:
        font_large = ImageFont.load_default()
        font_med = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Frame 1: Initial boot with logo appearing
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (20, 0, 0), 30)
    
    # NullSec text fading in
    text = "NULLSEC"
    draw.text((SCREEN_WIDTH//2 - 80, SCREEN_HEIGHT//2 - 30), text, fill=COLORS['dark_red'], font=font_large)
    draw.text((20, SCREEN_HEIGHT - 30), "INITIALIZING SYSTEM...", fill=COLORS['red'], font=font_small)
    draw.text((20, 20), "[bad-antics]", fill=COLORS['dark_gray'], font=font_small)
    
    img.save(os.path.join(boot_dir, 'init-1.png'), 'PNG')
    
    # Frame 2: Logo bright with system checks
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (30, 0, 0), 30)
    draw_hex_pattern(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (20, 0, 0))
    
    draw.text((SCREEN_WIDTH//2 - 80, SCREEN_HEIGHT//2 - 40), "NULLSEC", fill=COLORS['red'], font=font_large)
    draw.text((SCREEN_WIDTH//2 - 60, SCREEN_HEIGHT//2 + 10), "SECURITY", fill=COLORS['dark_red'], font=font_med)
    
    # Boot messages
    boot_msgs = [
        "[OK] Loading kernel modules",
        "[OK] Network interface ready", 
        "[OK] WiFi chipset initialized",
    ]
    y = 20
    for msg in boot_msgs:
        draw.text((20, y), msg, fill=COLORS['green'], font=font_small)
        y += 15
    
    draw.text((20, SCREEN_HEIGHT - 30), "LOADING PAYLOADS...", fill=COLORS['yellow'], font=font_small)
    img.save(os.path.join(boot_dir, 'init-2.png'), 'PNG')
    
    # Frame 3: Matrix effect with full logo
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_matrix_rain(draw, SCREEN_WIDTH, SCREEN_HEIGHT, 0.15)
    
    # Logo box
    box_x, box_y = SCREEN_WIDTH//2 - 100, SCREEN_HEIGHT//2 - 50
    draw.rectangle([box_x, box_y, box_x + 200, box_y + 80], outline=COLORS['red'], width=2)
    draw.text((box_x + 20, box_y + 15), "NULLSEC", fill=COLORS['bright_red'], font=font_large)
    draw.text((box_x + 45, box_y + 55), "PAGER ARMED", fill=COLORS['red'], font=font_med)
    
    draw.text((20, SCREEN_HEIGHT - 30), "SYSTEM ARMED // READY", fill=COLORS['green'], font=font_small)
    draw.text((SCREEN_WIDTH - 150, SCREEN_HEIGHT - 30), "bad-antics//nullsec", fill=COLORS['dark_gray'], font=font_small)
    img.save(os.path.join(boot_dir, 'init-3.png'), 'PNG')
    
    # Frame 4: Final ready state
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['dark_bg'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (25, 0, 0), 25)
    draw_scanlines(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (40, 0, 0), 4, 30)
    
    # Centered logo with glow effect
    draw.text((SCREEN_WIDTH//2 - 85, SCREEN_HEIGHT//2 - 35), "NULLSEC", fill=COLORS['red_glow'], font=font_large)
    draw.text((SCREEN_WIDTH//2 - 55, SCREEN_HEIGHT//2 + 15), "[ READY ]", fill=COLORS['green'], font=font_med)
    
    # Corner decorations
    draw.line([(10, 10), (50, 10)], fill=COLORS['red'], width=2)
    draw.line([(10, 10), (10, 50)], fill=COLORS['red'], width=2)
    draw.line([(SCREEN_WIDTH - 50, 10), (SCREEN_WIDTH - 10, 10)], fill=COLORS['red'], width=2)
    draw.line([(SCREEN_WIDTH - 10, 10), (SCREEN_WIDTH - 10, 50)], fill=COLORS['red'], width=2)
    draw.line([(10, SCREEN_HEIGHT - 50), (10, SCREEN_HEIGHT - 10)], fill=COLORS['red'], width=2)
    draw.line([(10, SCREEN_HEIGHT - 10), (50, SCREEN_HEIGHT - 10)], fill=COLORS['red'], width=2)
    draw.line([(SCREEN_WIDTH - 10, SCREEN_HEIGHT - 50), (SCREEN_WIDTH - 10, SCREEN_HEIGHT - 10)], fill=COLORS['red'], width=2)
    draw.line([(SCREEN_WIDTH - 50, SCREEN_HEIGHT - 10), (SCREEN_WIDTH - 10, SCREEN_HEIGHT - 10)], fill=COLORS['red'], width=2)
    
    img.save(os.path.join(boot_dir, 'init-4.png'), 'PNG')
    print("  Created 4 boot animation frames")

def create_dashboard_bg():
    """Create custom NullSec dashboard background with prominent logo"""
    print("Creating dashboard background...")
    dash_dir = os.path.join(ASSETS_DIR, 'dashboard')
    ensure_dir(dash_dir)
    
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    
    # Draw grid pattern
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (20, 5, 5), 20)
    
    # Draw hexagonal overlay
    draw_hex_pattern(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (30, 0, 0))
    
    # Add scanlines
    draw_scanlines(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (40, 0, 0), 3, 25)
    
    # === PROMINENT NULLSEC LOGO IN CENTER ===
    center_x, center_y = SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2
    logo_size = 100
    
    # Outer targeting circle
    draw.ellipse([center_x - logo_size//2, center_y - logo_size//2, 
                  center_x + logo_size//2, center_y + logo_size//2], 
                 outline=(50, 0, 0), width=3)
    draw.ellipse([center_x - logo_size//2 + 10, center_y - logo_size//2 + 10, 
                  center_x + logo_size//2 - 10, center_y + logo_size//2 - 10], 
                 outline=(35, 0, 0), width=2)
    
    # Crosshair lines
    draw.line([(center_x - logo_size//2 - 20, center_y), (center_x - logo_size//2 + 15, center_y)], 
              fill=(45, 0, 0), width=3)
    draw.line([(center_x + logo_size//2 - 15, center_y), (center_x + logo_size//2 + 20, center_y)], 
              fill=(45, 0, 0), width=3)
    draw.line([(center_x, center_y - logo_size//2 - 20), (center_x, center_y - logo_size//2 + 15)], 
              fill=(45, 0, 0), width=3)
    draw.line([(center_x, center_y + logo_size//2 - 15), (center_x, center_y + logo_size//2 + 20)], 
              fill=(45, 0, 0), width=3)
    
    # Stylized "N" in center
    n_size = 35
    n_left = center_x - n_size//2
    n_right = center_x + n_size//2
    n_top = center_y - n_size//2
    n_bottom = center_y + n_size//2
    
    # Draw the N
    draw.line([(n_left, n_bottom), (n_left, n_top)], fill=(60, 0, 0), width=4)
    draw.line([(n_left, n_top), (n_right, n_bottom)], fill=(60, 0, 0), width=4)
    draw.line([(n_right, n_top), (n_right, n_bottom)], fill=(60, 0, 0), width=4)
    
    # Corner brackets around logo
    bracket_len = 20
    bracket_color = (55, 0, 0)
    bx1, by1 = center_x - logo_size//2 - 5, center_y - logo_size//2 - 5
    bx2, by2 = center_x + logo_size//2 + 5, center_y + logo_size//2 + 5
    # Top-left
    draw.line([(bx1, by1), (bx1, by1+bracket_len)], fill=bracket_color, width=2)
    draw.line([(bx1, by1), (bx1+bracket_len, by1)], fill=bracket_color, width=2)
    # Top-right
    draw.line([(bx2, by1), (bx2, by1+bracket_len)], fill=bracket_color, width=2)
    draw.line([(bx2, by1), (bx2-bracket_len, by1)], fill=bracket_color, width=2)
    # Bottom-left
    draw.line([(bx1, by2), (bx1, by2-bracket_len)], fill=bracket_color, width=2)
    draw.line([(bx1, by2), (bx1+bracket_len, by2)], fill=bracket_color, width=2)
    # Bottom-right
    draw.line([(bx2, by2), (bx2, by2-bracket_len)], fill=bracket_color, width=2)
    draw.line([(bx2, by2), (bx2-bracket_len, by2)], fill=bracket_color, width=2)
    
    # Top bar
    draw.rectangle([0, 0, SCREEN_WIDTH, 25], fill=(20, 0, 0))
    draw.line([(0, 25), (SCREEN_WIDTH, 25)], fill=COLORS['red'], width=2)
    
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 14)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
    except:
        font = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Header text
    draw.text((10, 5), "NULLSEC", fill=COLORS['red'], font=font)
    draw.text((SCREEN_WIDTH - 100, 7), "bad-antics", fill=COLORS['dark_gray'], font=font_small)
    
    # Bottom status bar area
    draw.rectangle([0, SCREEN_HEIGHT - 30, SCREEN_WIDTH, SCREEN_HEIGHT], fill=(15, 0, 0))
    draw.line([(0, SCREEN_HEIGHT - 30), (SCREEN_WIDTH, SCREEN_HEIGHT - 30)], fill=COLORS['dark_red'], width=1)
    
    # Corner brackets
    bracket_color = COLORS['red']
    # Top left
    draw.line([(5, 30), (5, 50)], fill=bracket_color, width=2)
    draw.line([(5, 30), (25, 30)], fill=bracket_color, width=2)
    # Top right  
    draw.line([(SCREEN_WIDTH - 5, 30), (SCREEN_WIDTH - 5, 50)], fill=bracket_color, width=2)
    draw.line([(SCREEN_WIDTH - 25, 30), (SCREEN_WIDTH - 5, 30)], fill=bracket_color, width=2)
    
    # Add subtle logo watermark
    draw.text((SCREEN_WIDTH//2 - 40, SCREEN_HEIGHT//2 - 10), "N U L L", fill=(25, 0, 0), font=font)
    
    img.save(os.path.join(dash_dir, 'nullsec_bg.png'), 'PNG')
    print("  Created nullsec_bg.png")

def create_dashboard_icons():
    """Create custom dashboard menu icons"""
    print("Creating dashboard icons...")
    dash_dir = os.path.join(ASSETS_DIR, 'dashboard')
    ensure_dir(dash_dir)
    
    # Icon size: match wargames theme sizes (icons are ~33x29)
    icon_size = 33
    
    icons = {
        'alerts': create_alerts_icon,
        'payloads': create_payloads_icon,
        'recon': create_recon_icon,
        'pineap': create_pineap_icon,
        'settings': create_settings_icon,
        'nullsec_tools': create_nullsec_tools_icon,
    }
    
    for name, create_func in icons.items():
        img = create_func(icon_size)
        img.save(os.path.join(dash_dir, f'{name}.png'), 'PNG')
        print(f"  Created {name}.png")
    
    # Create item_bg at proper size (63x62 like wargames)
    img = create_item_bg(63, 62)
    img.save(os.path.join(dash_dir, 'item_bg.png'), 'PNG')
    print("  Created item_bg.png (63x62)")
    
    # Create highlight at proper size (71x72 like wargames)
    img = create_highlight(71, 72)
    img.save(os.path.join(dash_dir, 'highlight.png'), 'PNG')
    print("  Created highlight.png (71x72)")
    
    # Create NullSec logo watermark for background
    create_nullsec_logo_watermark(dash_dir)

def create_alerts_icon(size):
    """Alert icon - warning triangle with exclamation"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Triangle warning
    points = [(size//2, 2), (size-2, size-4), (2, size-4)]
    draw.polygon(points, outline=COLORS['red'], fill=None)
    draw.polygon(points, outline=COLORS['red'])
    
    # Exclamation mark
    draw.line([(size//2, 8), (size//2, size-14)], fill=COLORS['red'], width=2)
    draw.ellipse([size//2-2, size-12, size//2+2, size-8], fill=COLORS['red'])
    
    return img

def create_payloads_icon(size):
    """Payloads icon - bomb/explosive"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Bomb body (circle)
    draw.ellipse([4, 8, size-4, size-2], outline=COLORS['red'], width=2)
    
    # Fuse
    draw.line([(size//2, 8), (size//2, 2)], fill=COLORS['red'], width=2)
    draw.arc([size//2-4, -2, size//2+6, 8], 0, 180, fill=COLORS['orange'], width=2)
    
    # Spark
    draw.ellipse([size//2+2, 0, size//2+6, 4], fill=COLORS['yellow'])
    
    return img

def create_recon_icon(size):
    """Recon icon - radar/scan"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Radar circles
    center = size // 2
    draw.arc([4, 4, size-4, size-4], 0, 360, fill=COLORS['red'], width=1)
    draw.arc([8, 8, size-8, size-8], 0, 360, fill=COLORS['red'], width=1)
    draw.arc([12, 12, size-12, size-12], 0, 360, fill=COLORS['red'], width=1)
    
    # Sweep line
    draw.line([(center, center), (size-4, 4)], fill=COLORS['bright_red'], width=2)
    
    # Center dot
    draw.ellipse([center-2, center-2, center+2, center+2], fill=COLORS['red'])
    
    return img

def create_pineap_icon(size):
    """PineAP icon - pineapple with wifi"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # WiFi arcs (top)
    draw.arc([size//4, -2, 3*size//4, size//3], 200, 340, fill=COLORS['red'], width=2)
    draw.arc([size//3, 2, 2*size//3, size//4], 200, 340, fill=COLORS['red'], width=2)
    
    # Pineapple body (diamond/oval shape)
    points = [
        (size//2, size//3),
        (size-6, size//2),
        (size//2, size-2),
        (6, size//2)
    ]
    draw.polygon(points, outline=COLORS['red'], fill=None)
    
    # Cross pattern on body
    draw.line([(size//3, size//2), (2*size//3, size//2)], fill=COLORS['dark_red'])
    draw.line([(size//2, size//3 + 4), (size//2, size - 6)], fill=COLORS['dark_red'])
    
    return img

def create_settings_icon(size):
    """Settings icon - gear"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    outer_r = size // 2 - 2
    inner_r = size // 4
    teeth = 8
    
    # Draw gear teeth
    for i in range(teeth):
        angle = (2 * math.pi * i) / teeth
        x1 = center + outer_r * math.cos(angle)
        y1 = center + outer_r * math.sin(angle)
        draw.ellipse([x1-3, y1-3, x1+3, y1+3], fill=COLORS['red'])
    
    # Outer circle
    draw.ellipse([center-inner_r-4, center-inner_r-4, center+inner_r+4, center+inner_r+4], 
                 outline=COLORS['red'], width=2)
    
    # Inner circle (hole)
    draw.ellipse([center-inner_r+2, center-inner_r+2, center+inner_r-2, center+inner_r-2],
                 outline=COLORS['red'], width=2)
    
    return img

def create_item_bg(width=63, height=62):
    """Menu item background box - matches wargames 63x62"""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Dark background with red border
    draw.rectangle([2, 2, width-2, height-2], fill=(25, 5, 5, 220), outline=COLORS['dark_red'])
    # Inner glow line
    draw.rectangle([4, 4, width-4, height-4], outline=(40, 0, 0, 150))
    
    return img

def create_highlight(width=71, height=72):
    """Selection highlight glow - matches wargames 71x72"""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Outer glowing border
    for i in range(4):
        alpha = 180 - i * 35
        draw.rectangle([i, i, width-i-1, height-i-1], outline=(255, 0, 0, alpha))
    
    # Inner bright glow
    draw.rectangle([4, 4, width-5, height-5], outline=COLORS['bright_red'], width=2)
    
    return img

def create_nullsec_tools_icon(size=32):
    """NullSec tools icon - skull with crosshair targeting reticle"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # Outer targeting circle
    draw.ellipse([2, 2, size-2, size-2], outline=COLORS['red'], width=2)
    
    # Crosshair lines
    draw.line([(0, center), (size//4, center)], fill=COLORS['red'], width=2)
    draw.line([(3*size//4, center), (size, center)], fill=COLORS['red'], width=2)
    draw.line([(center, 0), (center, size//4)], fill=COLORS['red'], width=2)
    draw.line([(center, 3*size//4), (center, size)], fill=COLORS['red'], width=2)
    
    # Inner skull-like design - stylized "N"
    draw.line([(size//3, size//3+2), (size//3, 2*size//3-2)], fill=COLORS['bright_red'], width=2)
    draw.line([(size//3, size//3+2), (2*size//3, 2*size//3-2)], fill=COLORS['bright_red'], width=2)
    draw.line([(2*size//3, size//3+2), (2*size//3, 2*size//3-2)], fill=COLORS['bright_red'], width=2)
    
    # Corner accent dots
    draw.ellipse([4, 4, 8, 8], fill=COLORS['bright_red'])
    draw.ellipse([size-8, 4, size-4, 8], fill=COLORS['bright_red'])
    draw.ellipse([4, size-8, 8, size-4], fill=COLORS['bright_red'])
    draw.ellipse([size-8, size-8, size-4, size-4], fill=COLORS['bright_red'])
    
    return img

def create_nullsec_logo_watermark(output_dir):
    """Create large NullSec logo watermark for dashboard background - more vibrant and wider"""
    print("  Creating NullSec logo watermark...")
    
    # Create a wider logo watermark (160x120 for better visibility)
    logo_width = 160
    logo_height = 120
    img = Image.new('RGBA', (logo_width, logo_height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center_x = logo_width // 2
    center_y = logo_height // 2
    
    # Outer targeting ellipse (wider) - MORE VIBRANT red
    draw.ellipse([10, 5, logo_width-10, logo_height-5], outline=(120, 0, 0, 200), width=3)
    draw.ellipse([20, 15, logo_width-20, logo_height-15], outline=(80, 0, 0, 160), width=2)
    
    # Crosshair lines extending beyond ellipse - BRIGHTER
    line_color = (100, 0, 0, 180)
    draw.line([(0, center_y), (30, center_y)], fill=line_color, width=4)
    draw.line([(logo_width-30, center_y), (logo_width, center_y)], fill=line_color, width=4)
    draw.line([(center_x, 0), (center_x, 25)], fill=line_color, width=4)
    draw.line([(center_x, logo_height-25), (center_x, logo_height)], fill=line_color, width=4)
    
    # Stylized "N" in center - BOLDER and MORE VISIBLE
    n_padding_x = 45
    n_padding_y = 30
    n_top = n_padding_y
    n_bottom = logo_height - n_padding_y
    n_left = n_padding_x
    n_right = logo_width - n_padding_x
    
    n_color = (140, 0, 0, 220)
    # Left vertical of N
    draw.line([(n_left, n_bottom), (n_left, n_top)], fill=n_color, width=5)
    # Diagonal of N  
    draw.line([(n_left, n_top), (n_right, n_bottom)], fill=n_color, width=5)
    # Right vertical of N
    draw.line([(n_right, n_top), (n_right, n_bottom)], fill=n_color, width=5)
    
    # Corner brackets - BRIGHTER
    bracket_len = 20
    bracket_color = (110, 0, 0, 200)
    # Top-left
    draw.line([(5, 5), (5, 5+bracket_len)], fill=bracket_color, width=3)
    draw.line([(5, 5), (5+bracket_len, 5)], fill=bracket_color, width=3)
    # Top-right
    draw.line([(logo_width-5, 5), (logo_width-5, 5+bracket_len)], fill=bracket_color, width=3)
    draw.line([(logo_width-5, 5), (logo_width-5-bracket_len, 5)], fill=bracket_color, width=3)
    # Bottom-left
    draw.line([(5, logo_height-5), (5, logo_height-5-bracket_len)], fill=bracket_color, width=3)
    draw.line([(5, logo_height-5), (5+bracket_len, logo_height-5)], fill=bracket_color, width=3)
    # Bottom-right
    draw.line([(logo_width-5, logo_height-5), (logo_width-5, logo_height-5-bracket_len)], fill=bracket_color, width=3)
    draw.line([(logo_width-5, logo_height-5), (logo_width-5-bracket_len, logo_height-5)], fill=bracket_color, width=3)
    
    # Small accent dots at crosshair ends
    dot_color = (160, 0, 0, 255)
    draw.ellipse([center_x-3, 2, center_x+3, 8], fill=dot_color)
    draw.ellipse([center_x-3, logo_height-8, center_x+3, logo_height-2], fill=dot_color)
    draw.ellipse([2, center_y-3, 8, center_y+3], fill=dot_color)
    draw.ellipse([logo_width-8, center_y-3, logo_width-2, center_y+3], fill=dot_color)
    
    img.save(os.path.join(output_dir, 'nullsec_logo.png'), 'PNG')
    print(f"  Created nullsec_logo.png ({logo_width}x{logo_height} vibrant watermark)")

def create_spinner_frames():
    """Create custom spinner/loading animation"""
    print("Creating spinner frames...")
    spinner_dir = os.path.join(ASSETS_DIR, 'spinner')
    ensure_dir(spinner_dir)
    
    # Spinner size from theme: 220x156
    width, height = 220, 156
    
    for i in range(4):
        img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        cx, cy = width // 2, height // 2
        radius = 40
        
        # Draw rotating segments
        segments = 8
        for j in range(segments):
            angle = (2 * math.pi * j / segments) + (i * math.pi / 4)
            
            # Calculate segment brightness based on position
            brightness = ((j - i * 2) % segments) / segments
            red_val = int(100 + brightness * 155)
            
            x1 = cx + (radius - 15) * math.cos(angle)
            y1 = cy + (radius - 15) * math.sin(angle)
            x2 = cx + radius * math.cos(angle)
            y2 = cy + radius * math.sin(angle)
            
            draw.line([(x1, y1), (x2, y2)], fill=(red_val, 0, 0), width=4)
        
        # Center dot
        draw.ellipse([cx-5, cy-5, cx+5, cy+5], fill=COLORS['red'])
        
        # Add "LOADING" text
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 12)
        except:
            font = ImageFont.load_default()
        
        loading_dots = "." * ((i % 3) + 1)
        draw.text((cx - 35, cy + 50), f"LOADING{loading_dots}", fill=COLORS['red'], font=font)
        
        img.save(os.path.join(spinner_dir, f'spinner{i+1}.png'), 'PNG')
    
    print("  Created 4 spinner frames")

def create_dialog_backgrounds():
    """Create dialog/popup backgrounds"""
    print("Creating dialog backgrounds...")
    
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
    except:
        font = ImageFont.load_default()
    
    # Main alert dialog - 480x222 (full screen)
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (20, 0, 0), 25)
    draw_scanlines(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (30, 0, 0), 3, 20)
    
    # Border
    draw.rectangle([5, 5, SCREEN_WIDTH-5, SCREEN_HEIGHT-5], outline=COLORS['red'], width=2)
    draw.rectangle([8, 8, SCREEN_WIDTH-8, SCREEN_HEIGHT-8], outline=COLORS['dark_red'], width=1)
    
    # Header bar
    draw.rectangle([10, 10, SCREEN_WIDTH-10, 35], fill=(30, 0, 0))
    draw.line([(10, 35), (SCREEN_WIDTH-10, 35)], fill=COLORS['red'], width=1)
    
    img.save(os.path.join(ASSETS_DIR, 'alert_dialog_bg_term.png'), 'PNG')
    print("  Created alert_dialog_bg_term.png")
    
    # Blue variant (info)
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (0, 10, 30), 25)
    draw.rectangle([5, 5, SCREEN_WIDTH-5, SCREEN_HEIGHT-5], outline=COLORS['cyan'], width=2)
    draw.rectangle([10, 10, SCREEN_WIDTH-10, 35], fill=(0, 20, 40))
    img.save(os.path.join(ASSETS_DIR, 'alert_dialog_bg_term_blue.png'), 'PNG')
    print("  Created alert_dialog_bg_term_blue.png")
    
    # Error variant
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), (10, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (40, 0, 0), 25)
    draw.rectangle([5, 5, SCREEN_WIDTH-5, SCREEN_HEIGHT-5], outline=COLORS['bright_red'], width=3)
    draw.rectangle([10, 10, SCREEN_WIDTH-10, 35], fill=(50, 0, 0))
    draw.text((15, 15), "! ERROR", fill=COLORS['bright_red'], font=font)
    img.save(os.path.join(ASSETS_DIR, 'alert_dialog_bg_term_error.png'), 'PNG')
    print("  Created alert_dialog_bg_term_error.png")
    
    # Warning variant
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), (10, 8, 0))
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (30, 25, 0), 25)
    draw.rectangle([5, 5, SCREEN_WIDTH-5, SCREEN_HEIGHT-5], outline=COLORS['yellow'], width=2)
    draw.rectangle([10, 10, SCREEN_WIDTH-10, 35], fill=(40, 30, 0))
    draw.text((15, 15), "⚠ WARNING", fill=COLORS['yellow'], font=font)
    img.save(os.path.join(ASSETS_DIR, 'alert_dialog_bg_term_warning.png'), 'PNG')
    print("  Created alert_dialog_bg_term_warning.png")

def create_confirmation_dialog():
    """Create confirmation dialog background"""
    print("Creating confirmation dialog...")
    confirm_dir = os.path.join(ASSETS_DIR, 'confirmation_dialog')
    ensure_dir(confirm_dir)
    
    # Background - smaller dialog
    width, height = 400, 180
    img = Image.new('RGB', (width, height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    
    draw_grid(draw, width, height, (25, 0, 0), 20)
    draw.rectangle([2, 2, width-2, height-2], outline=COLORS['red'], width=2)
    draw.rectangle([0, 0, width, 30], fill=(30, 0, 0))
    draw.line([(0, 30), (width, 30)], fill=COLORS['red'], width=1)
    
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 12)
    except:
        font = ImageFont.load_default()
    
    draw.text((10, 8), "CONFIRM ACTION", fill=COLORS['red'], font=font)
    
    img.save(os.path.join(ASSETS_DIR, 'confirmation_dialog_bg_term.png'), 'PNG')
    print("  Created confirmation_dialog_bg_term.png")

def create_status_bar_elements():
    """Create status bar icons and elements"""
    print("Creating status bar elements...")
    status_dir = os.path.join(ASSETS_DIR, 'statusbar')
    ensure_dir(status_dir)
    
    # Battery icons at various levels
    battery_levels = [
        ('battery_100', 1.0, COLORS['green']),
        ('battery_75', 0.75, COLORS['green']),
        ('battery_50', 0.50, COLORS['yellow']),
        ('battery_25', 0.25, COLORS['orange']),
        ('battery_10', 0.10, COLORS['red']),
        ('battery_charging', 1.0, COLORS['cyan']),
    ]
    
    for name, level, color in battery_levels:
        img = Image.new('RGBA', (24, 12), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Battery outline
        draw.rectangle([0, 0, 20, 11], outline=color)
        draw.rectangle([21, 3, 23, 8], fill=color)
        
        # Fill level
        fill_width = int(18 * level)
        if fill_width > 0:
            draw.rectangle([2, 2, 2 + fill_width, 9], fill=color)
        
        img.save(os.path.join(status_dir, f'{name}.png'), 'PNG')
    
    # WiFi signal icons
    for strength in range(5):
        img = Image.new('RGBA', (16, 12), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        for i in range(4):
            bar_height = (i + 1) * 3
            color = COLORS['red'] if i < strength else COLORS['dark_gray']
            draw.rectangle([i * 4, 12 - bar_height, i * 4 + 2, 11], fill=color)
        
        img.save(os.path.join(status_dir, f'wifi_{strength}.png'), 'PNG')
    
    print("  Created status bar elements")

def create_misc_assets():
    """Create miscellaneous UI assets"""
    print("Creating miscellaneous assets...")
    
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
    except:
        font = ImageFont.load_default()
    
    # Lock screen
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (15, 0, 0), 30)
    
    # Lock icon (padlock)
    cx, cy = SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 20
    draw.arc([cx-20, cy-30, cx+20, cy], 0, 180, fill=COLORS['red'], width=4)
    draw.rectangle([cx-25, cy-5, cx+25, cy+35], outline=COLORS['red'], width=2)
    draw.ellipse([cx-5, cy+10, cx+5, cy+20], fill=COLORS['red'])
    
    draw.text((SCREEN_WIDTH//2 - 40, SCREEN_HEIGHT - 40), "LOCKED", fill=COLORS['red'], font=font)
    img.save(os.path.join(ASSETS_DIR, 'lock_screen.png'), 'PNG')
    
    # Buttons locked screen
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_scanlines(draw, SCREEN_WIDTH, SCREEN_HEIGHT, (20, 0, 0), 3, 20)
    draw.text((SCREEN_WIDTH//2 - 60, SCREEN_HEIGHT//2), "BUTTONS LOCKED", fill=COLORS['red'], font=font)
    img.save(os.path.join(ASSETS_DIR, 'buttons_locked.png'), 'PNG')
    
    # Low battery alert
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), (10, 5, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([10, 10, SCREEN_WIDTH-10, SCREEN_HEIGHT-10], outline=COLORS['orange'], width=2)
    draw.text((SCREEN_WIDTH//2 - 50, SCREEN_HEIGHT//2 - 20), "LOW BATTERY", fill=COLORS['orange'], font=font)
    draw.text((SCREEN_WIDTH//2 - 60, SCREEN_HEIGHT//2 + 10), "CHARGE REQUIRED", fill=COLORS['yellow'], font=font)
    img.save(os.path.join(ASSETS_DIR, 'low_battery_alert.png'), 'PNG')
    
    # Critical battery alert
    img = Image.new('RGB', (SCREEN_WIDTH, SCREEN_HEIGHT), (20, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([5, 5, SCREEN_WIDTH-5, SCREEN_HEIGHT-5], outline=COLORS['bright_red'], width=3)
    draw.text((SCREEN_WIDTH//2 - 70, SCREEN_HEIGHT//2 - 20), "CRITICAL BATTERY", fill=COLORS['bright_red'], font=font)
    draw.text((SCREEN_WIDTH//2 - 80, SCREEN_HEIGHT//2 + 10), "SHUTTING DOWN...", fill=COLORS['red'], font=font)
    img.save(os.path.join(ASSETS_DIR, 'critical_battery_alert.png'), 'PNG')
    
    # Small UI icons
    icons_small = {
        'arrow_up': [(8, 2), (2, 10), (14, 10)],
        'arrow_down': [(8, 10), (2, 2), (14, 2)],
        'up': [(8, 2), (2, 10), (14, 10)],
        'down': [(8, 10), (2, 2), (14, 2)],
    }
    
    for name, points in icons_small.items():
        img = Image.new('RGBA', (16, 12), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.polygon(points, fill=COLORS['red'])
        img.save(os.path.join(ASSETS_DIR, f'{name}.png'), 'PNG')
    
    print("  Created misc assets")

def create_keyboard_assets():
    """Create custom NullSec keyboard UI assets"""
    print("Creating keyboard assets...")
    kb_dir = os.path.join(ASSETS_DIR, 'keyboard')
    ensure_dir(kb_dir)
    
    try:
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 14)
        font_tiny = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
    except:
        font_small = ImageFont.load_default()
        font_tiny = ImageFont.load_default()
    
    # Full keyboard layout dimensions: 480x222 (full screen)
    kb_width, kb_height = SCREEN_WIDTH, SCREEN_HEIGHT
    
    # === LOWERCASE KEYBOARD LAYOUT ===
    img = Image.new('RGB', (kb_width, kb_height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    
    # Background pattern
    draw_grid(draw, kb_width, kb_height, (20, 0, 0), 30)
    draw_scanlines(draw, kb_width, kb_height, (25, 0, 0), 4, 15)
    
    # Top bar with input area
    draw.rectangle([0, 0, kb_width, 50], fill=(15, 5, 5))
    draw.line([(0, 50), (kb_width, 50)], fill=COLORS['red'], width=2)
    draw.text((10, 5), "INPUT:", fill=COLORS['red'], font=font_tiny)
    
    # Input field area
    draw.rectangle([10, 20, kb_width-10, 45], outline=COLORS['dark_red'], fill=(20, 10, 10))
    
    # Key rows - starting at y=55
    row_height = 31
    key_width = 47
    start_y = 59
    
    # Draw key grid pattern (10 keys per row, 5 rows)
    rows = [
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
        ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
        ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '⌫'],
        ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.'],
        ['#', '-', "'", '____SPACE____', '', '', '', '/', '?', '✓']
    ]
    
    for row_idx, row in enumerate(rows):
        y = start_y + row_idx * row_height
        for key_idx, key in enumerate(row):
            if key == '' or key.startswith('____'):
                continue
            x = 7 + key_idx * key_width
            
            # Key background
            if key == '____SPACE____':
                # Spacebar spans 4 keys
                draw.rectangle([x, y, x + key_width * 4 - 2, y + 26], outline=COLORS['dark_red'], fill=(25, 10, 10))
                draw.text((x + 60, y + 6), "SPACE", fill=COLORS['gray'], font=font_tiny)
            else:
                draw.rectangle([x, y, x + 43, y + 26], outline=COLORS['dark_red'], fill=(25, 10, 10))
                # Key label
                label = key
                if key == '⌫':
                    label = '←'
                elif key == '⇧':
                    label = '⇧'
                elif key == '✓':
                    label = 'OK'
                elif key == '#':
                    label = '!#'
                draw.text((x + 15, y + 5), label, fill=COLORS['gray'], font=font_small)
    
    # Corner brackets
    draw.line([(3, 55), (3, 75)], fill=COLORS['red'], width=2)
    draw.line([(3, 55), (23, 55)], fill=COLORS['red'], width=2)
    draw.line([(kb_width-3, 55), (kb_width-3, 75)], fill=COLORS['red'], width=2)
    draw.line([(kb_width-23, 55), (kb_width-3, 55)], fill=COLORS['red'], width=2)
    
    img.save(os.path.join(kb_dir, 'keyboard_layout_lower.png'), 'PNG')
    print("  Created keyboard_layout_lower.png")
    
    # === UPPERCASE KEYBOARD LAYOUT ===
    img = Image.new('RGB', (kb_width, kb_height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, kb_width, kb_height, (20, 0, 0), 30)
    draw_scanlines(draw, kb_width, kb_height, (25, 0, 0), 4, 15)
    draw.rectangle([0, 0, kb_width, 50], fill=(15, 5, 5))
    draw.line([(0, 50), (kb_width, 50)], fill=COLORS['red'], width=2)
    draw.text((10, 5), "INPUT:", fill=COLORS['red'], font=font_tiny)
    draw.rectangle([10, 20, kb_width-10, 45], outline=COLORS['dark_red'], fill=(20, 10, 10))
    
    rows_upper = [
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
        ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
        ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', '⌫'],
        ['⇧', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.'],
        ['#', '-', "'", '____SPACE____', '', '', '', '/', '?', '✓']
    ]
    
    for row_idx, row in enumerate(rows_upper):
        y = start_y + row_idx * row_height
        for key_idx, key in enumerate(row):
            if key == '' or key.startswith('____'):
                continue
            x = 7 + key_idx * key_width
            if key == '____SPACE____':
                draw.rectangle([x, y, x + key_width * 4 - 2, y + 26], outline=COLORS['dark_red'], fill=(25, 10, 10))
                draw.text((x + 60, y + 6), "SPACE", fill=COLORS['gray'], font=font_tiny)
            else:
                draw.rectangle([x, y, x + 43, y + 26], outline=COLORS['dark_red'], fill=(25, 10, 10))
                label = key
                if key == '⌫':
                    label = '←'
                elif key == '⇧':
                    label = '⇩'  # Indicate caps is ON
                elif key == '✓':
                    label = 'OK'
                elif key == '#':
                    label = '!#'
                draw.text((x + 15, y + 5), label, fill=COLORS['gray'], font=font_small)
    
    draw.line([(3, 55), (3, 75)], fill=COLORS['red'], width=2)
    draw.line([(3, 55), (23, 55)], fill=COLORS['red'], width=2)
    draw.line([(kb_width-3, 55), (kb_width-3, 75)], fill=COLORS['red'], width=2)
    draw.line([(kb_width-23, 55), (kb_width-3, 55)], fill=COLORS['red'], width=2)
    
    img.save(os.path.join(kb_dir, 'keyboard_layout_upper.png'), 'PNG')
    print("  Created keyboard_layout_upper.png")
    
    # === SYMBOLS KEYBOARD LAYOUT ===
    img = Image.new('RGB', (kb_width, kb_height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, kb_width, kb_height, (20, 0, 0), 30)
    draw_scanlines(draw, kb_width, kb_height, (25, 0, 0), 4, 15)
    draw.rectangle([0, 0, kb_width, 50], fill=(15, 5, 5))
    draw.line([(0, 50), (kb_width, 50)], fill=COLORS['bright_red'], width=2)
    draw.text((10, 5), "SYMBOLS:", fill=COLORS['bright_red'], font=font_tiny)
    draw.rectangle([10, 20, kb_width-10, 45], outline=COLORS['red'], fill=(25, 10, 10))
    
    rows_symbols = [
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
        ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')'],
        ['~', '<', '>', '+', '=', ':', ';', '[', ']', '⌫'],
        ['⇧', '_', '"', '`', '{', '}', '|', '\\', ',', '.'],
        ['abc', '-', "'", '____SPACE____', '', '', '', '/', '?', '✓']
    ]
    
    for row_idx, row in enumerate(rows_symbols):
        y = start_y + row_idx * row_height
        for key_idx, key in enumerate(row):
            if key == '' or key.startswith('____'):
                continue
            x = 7 + key_idx * key_width
            if key == '____SPACE____':
                draw.rectangle([x, y, x + key_width * 4 - 2, y + 26], outline=COLORS['red'], fill=(30, 15, 15))
                draw.text((x + 60, y + 6), "SPACE", fill=COLORS['red'], font=font_tiny)
            else:
                fill_color = (30, 15, 15) if key in ['abc', '⇧', '⌫', '✓'] else (25, 10, 10)
                draw.rectangle([x, y, x + 43, y + 26], outline=COLORS['red'], fill=fill_color)
                label = key
                if key == '⌫':
                    label = '←'
                elif key == '⇧':
                    label = '⇧'
                elif key == '✓':
                    label = 'OK'
                elif key == 'abc':
                    label = 'abc'
                draw.text((x + 12, y + 5), label, fill=COLORS['red'], font=font_small)
    
    draw.line([(3, 55), (3, 75)], fill=COLORS['bright_red'], width=2)
    draw.line([(3, 55), (23, 55)], fill=COLORS['bright_red'], width=2)
    draw.line([(kb_width-3, 55), (kb_width-3, 75)], fill=COLORS['bright_red'], width=2)
    draw.line([(kb_width-23, 55), (kb_width-3, 55)], fill=COLORS['bright_red'], width=2)
    
    img.save(os.path.join(kb_dir, 'keyboard_layout_symbols.png'), 'PNG')
    print("  Created keyboard_layout_symbols.png")
    
    # === HEX KEYBOARD LAYOUT ===
    img = Image.new('RGB', (kb_width, kb_height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, kb_width, kb_height, (0, 20, 10), 30)
    draw.rectangle([0, 0, kb_width, 50], fill=(5, 15, 10))
    draw.line([(0, 50), (kb_width, 50)], fill=COLORS['green'], width=2)
    draw.text((10, 5), "HEX INPUT:", fill=COLORS['green'], font=font_tiny)
    draw.rectangle([10, 20, kb_width-10, 45], outline=COLORS['green'], fill=(10, 20, 15))
    
    hex_key_width = 77
    hex_rows = [
        ['0', '1', '2', '3', '4', 'OK'],
        ['5', '6', '7', '8', '9', '⌫'],
        ['A', 'B', 'C', 'D', 'E', 'F']
    ]
    
    for row_idx, row in enumerate(hex_rows):
        y = 57 + row_idx * 56
        for key_idx, key in enumerate(row):
            x = 11 + key_idx * hex_key_width
            draw.rectangle([x, y, x + 70, y + 48], outline=COLORS['green'], fill=(10, 25, 15))
            label = '←' if key == '⌫' else key
            draw.text((x + 25, y + 15), label, fill=COLORS['green'], font=font_small)
    
    img.save(os.path.join(kb_dir, 'keyboard_layout_hex.png'), 'PNG')
    print("  Created keyboard_layout_hex.png")
    
    # === IP KEYBOARD LAYOUT ===
    img = Image.new('RGB', (kb_width, kb_height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, kb_width, kb_height, (0, 15, 30), 30)
    draw.rectangle([0, 0, kb_width, 50], fill=(5, 10, 20))
    draw.line([(0, 50), (kb_width, 50)], fill=COLORS['cyan'], width=2)
    draw.text((10, 5), "IP ADDRESS:", fill=COLORS['cyan'], font=font_tiny)
    draw.rectangle([10, 20, kb_width-10, 45], outline=COLORS['cyan'], fill=(10, 15, 25))
    
    ip_key_width = 77
    ip_rows = [
        ['0', '1', '2', '3', 'OK'],
        ['/', '4', '5', '6', '⌫'],
        ['.', '7', '8', '9', '']
    ]
    
    for row_idx, row in enumerate(ip_rows):
        y = 57 + row_idx * 56
        for key_idx, key in enumerate(row):
            if key == '':
                continue
            x = 51 + key_idx * ip_key_width
            draw.rectangle([x, y, x + 70, y + 48], outline=COLORS['cyan'], fill=(10, 20, 30))
            label = '←' if key == '⌫' else key
            draw.text((x + 25, y + 15), label, fill=COLORS['cyan'], font=font_small)
    
    img.save(os.path.join(kb_dir, 'keyboard_layout_ip.png'), 'PNG')
    print("  Created keyboard_layout_ip.png")
    
    # === NUMERIC KEYBOARD LAYOUT ===
    img = Image.new('RGB', (kb_width, kb_height), COLORS['black'])
    draw = ImageDraw.Draw(img)
    draw_grid(draw, kb_width, kb_height, (20, 15, 0), 30)
    draw.rectangle([0, 0, kb_width, 50], fill=(15, 12, 5))
    draw.line([(0, 50), (kb_width, 50)], fill=COLORS['yellow'], width=2)
    draw.text((10, 5), "NUMBER:", fill=COLORS['yellow'], font=font_tiny)
    draw.rectangle([10, 20, kb_width-10, 45], outline=COLORS['yellow'], fill=(20, 18, 10))
    
    # Centered numpad
    num_key_width = 47
    num_rows = [
        ['7', '8', '9'],
        ['4', '5', '6'],
        ['1', '2', '3'],
        ['OK', '0', '⌫']
    ]
    
    start_x = 172
    for row_idx, row in enumerate(num_rows):
        y = 59 + row_idx * 31
        for key_idx, key in enumerate(row):
            x = start_x + key_idx * num_key_width
            draw.rectangle([x, y, x + 43, y + 26], outline=COLORS['yellow'], fill=(25, 20, 10))
            label = '←' if key == '⌫' else key
            draw.text((x + 15, y + 5), label, fill=COLORS['yellow'], font=font_small)
    
    img.save(os.path.join(kb_dir, 'keyboard_layout_numeric.png'), 'PNG')
    print("  Created keyboard_layout_numeric.png")
    
    # === KEY HIGHLIGHT BACKGROUNDS ===
    # Standard key highlight (selected)
    img = Image.new('RGBA', (43, 26), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 42, 25], fill=(80, 0, 0, 200), outline=COLORS['bright_red'])
    draw.rectangle([1, 1, 41, 24], outline=(255, 50, 50, 150))
    img.save(os.path.join(kb_dir, '_key-bg.png'), 'PNG')
    print("  Created _key-bg.png")
    
    # Hex key highlight
    img = Image.new('RGBA', (70, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 69, 47], fill=(0, 60, 30, 200), outline=COLORS['green'])
    draw.rectangle([1, 1, 68, 46], outline=(50, 255, 100, 150))
    img.save(os.path.join(kb_dir, '_hex-bg.png'), 'PNG')
    print("  Created _hex-bg.png")
    
    # Spacebar highlight (4x width)
    img = Image.new('RGBA', (186, 26), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 185, 25], fill=(80, 0, 0, 200), outline=COLORS['bright_red'])
    draw.rectangle([1, 1, 184, 24], outline=(255, 50, 50, 150))
    img.save(os.path.join(kb_dir, '_spacebar-4x.png'), 'PNG')
    print("  Created _spacebar-4x.png")
    
    print("  Keyboard assets complete!")

def create_all_assets():
    """Generate all theme assets"""
    print("\n" + "="*60)
    print("NullSec Theme Asset Generator")
    print("="*60)
    print(f"Output directory: {ASSETS_DIR}")
    print()
    
    ensure_dir(ASSETS_DIR)
    
    create_boot_animation_frames()
    create_dashboard_bg()
    create_dashboard_icons()
    create_spinner_frames()
    create_dialog_backgrounds()
    create_confirmation_dialog()
    create_status_bar_elements()
    create_misc_assets()
    create_keyboard_assets()
    
    print("\n" + "="*60)
    print("Asset generation complete!")
    print("="*60)

if __name__ == "__main__":
    create_all_assets()
