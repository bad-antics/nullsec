#!/usr/bin/env python3
"""NullSec Screensaver v3 - Optimized for software rendering"""
import tkinter as tk
import random
import signal
import sys
import math
import socket

def die(*a):
    try: root.destroy()
    except: pass
    sys.exit(0)

signal.signal(signal.SIGTERM, die)
signal.signal(signal.SIGINT, die)
signal.signal(signal.SIGHUP, die)

root = tk.Tk()
root.attributes('-fullscreen', True)
root.configure(bg='black', cursor='none')
root.overrideredirect(True)

W = root.winfo_screenwidth()
H = root.winfo_screenheight()

canvas = tk.Canvas(root, width=W, height=H, bg='black', highlightthickness=0)
canvas.pack()

def on_key(e): die()
def on_click(e): die()
mouse_start = [None, None]
def on_motion(e):
    if mouse_start[0] is None:
        mouse_start[0] = e.x; mouse_start[1] = e.y; return
    if abs(e.x - mouse_start[0]) > 5 or abs(e.y - mouse_start[1]) > 5: die()

root.bind('<Any-KeyPress>', on_key)
root.bind('<Any-Button>', on_click)
root.bind('<Motion>', on_motion)

FONT = 18; SPACING = 40; COLS = W // SPACING; TRAIL = 7; FPS_MS = 150
drops = [random.randint(-20, 0) for _ in range(COLS)]
HEX = "0123456789ABCDEF"
GREENS = [f'#00{max(30, 255 - i * 35):02X}00' for i in range(TRAIL)]

rain = []
for c in range(COLS):
    col = []
    for t in range(TRAIL):
        item = canvas.create_text(c * SPACING, -100, text='0',
            fill=GREENS[t], font=('Courier', FONT - 2), anchor='nw', state='hidden')
        col.append(item)
    rain.append(col)

cx, cy = W // 2, H // 2
NODE = socket.gethostname().upper()
LOGO = [
    "╔═══════════════════════════════╗",
    "║     ███╗   ██╗███████╗        ║",
    "║     ████╗  ██║██╔════╝        ║",
    "║     ██╔██╗ ██║███████╗        ║",
    "║     ██║╚██╗██║╚════██║        ║",
    "║     ██║ ╚████║███████║        ║",
    "║     ╚═╝  ╚═══╝╚══════╝        ║",
    "║  AUTONOMOUS SECURITY CLUSTER  ║",
    "╚═══════════════════════════════╝",
]
bg_r = canvas.create_rectangle(cx-260, cy-100, cx+260, cy+110, fill='black', outline='#003300', width=2)
logo_items = []
for i, line in enumerate(LOGO):
    item = canvas.create_text(cx, cy - 72 + i * 18, text=line,
        fill='#00BB00', font=('Courier', 11, 'bold'), anchor='center')
    logo_items.append(item)
node_txt = canvas.create_text(cx, cy + 100, text=f"NODE: {NODE} \u2022 NULLSEC MESH",
    fill='#004400', font=('Courier', 10), anchor='center')
cursor_txt = canvas.create_text(cx + 160, cy + 100, text='\u2588',
    fill='#006600', font=('Courier', 10), anchor='center')

frame = [0]; pulse = [0]
def animate():
    f = frame[0]; frame[0] += 1
    for c in range(COLS):
        drops[c] += 1; hy = drops[c] * FONT
        if hy > H + TRAIL * FONT:
            drops[c] = random.randint(-15, -1)
            for item in rain[c]: canvas.itemconfigure(item, state='hidden')
            continue
        x = c * SPACING
        for t in range(TRAIL):
            y = hy - t * FONT; item = rain[c][t]
            if 0 <= y < H:
                canvas.coords(item, x, y)
                if t == 0:
                    canvas.itemconfigure(item, fill='#FFFFFF', text=random.choice(HEX), state='normal')
                else:
                    if random.random() > 0.6: canvas.itemconfigure(item, text=random.choice(HEX))
                    canvas.itemconfigure(item, fill=GREENS[t], state='normal')
            else:
                canvas.itemconfigure(item, state='hidden')
    if f % 10 == 0:
        pulse[0] = (pulse[0] + 1) % 20
        g = 140 + int(50 * math.sin(pulse[0] * 0.314)); color = f'#00{g:02X}00'
        for item in logo_items: canvas.itemconfigure(item, fill=color)
        canvas.itemconfigure(bg_r, outline=f'#00{g // 3:02X}00')
    canvas.itemconfigure(cursor_txt, state='normal' if f % 14 < 7 else 'hidden')
    canvas.tag_raise(bg_r)
    for item in logo_items: canvas.tag_raise(item)
    canvas.tag_raise(node_txt); canvas.tag_raise(cursor_txt)
    root.after(FPS_MS, animate)

root.focus_force(); root.after(50, animate); root.mainloop()
