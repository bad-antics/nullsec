#!/usr/bin/env python3
"""
N01D Start Menu - Complete Application Launcher
Dynamically loads ALL applications from .desktop files
Single-instance: only one menu window at a time
"""

import customtkinter as ctk
import subprocess
import os
import sys
import fcntl
import signal
from pathlib import Path
from PIL import Image
import configparser
import re

# Single instance lock file
LOCK_FILE = '/tmp/n01d-start-menu.lock'
PID_FILE = '/tmp/n01d-start-menu.pid'

def check_single_instance():
    """Ensure only one instance runs. If already running, bring it to focus."""
    global lock_fp
    
    # Check if another instance is running
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, 'r') as f:
                old_pid = int(f.read().strip())
            # Check if process is still running
            os.kill(old_pid, 0)  # This will raise OSError if not running
            # Process exists, send signal to bring to front or toggle
            os.kill(old_pid, signal.SIGUSR1)
            print(f"Menu already running (PID {old_pid}), toggling window.")
            sys.exit(0)
        except (OSError, ValueError, FileNotFoundError):
            # Process not running, clean up stale files
            pass
    
    # Try to acquire lock
    try:
        lock_fp = open(LOCK_FILE, 'w')
        fcntl.flock(lock_fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Write PID
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        return True
    except IOError:
        print("Another instance is already running.")
        sys.exit(0)

def cleanup_lock():
    """Clean up lock files on exit."""
    try:
        if os.path.exists(LOCK_FILE):
            os.remove(LOCK_FILE)
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    except:
        pass

# N01D Theme colors
COLORS = {
    'bg_dark': '#0a0a0f',
    'bg_mid': '#0d1117',
    'bg_light': '#161b22',
    'bg_hover': '#1c2128',
    'accent': '#00ff9f',
    'accent_dim': '#00cc7f',
    'text': '#e6edf3',
    'text_dim': '#7d8590',
    'border': '#30363d',
    'red': '#ff4757',
    'yellow': '#ffd93d',
    'blue': '#4da6ff',
    'purple': '#a855f7',
    'orange': '#ff8c42',
    'cyan': '#00d4ff',
    'pink': '#ff6b9d',
}

# Icon search paths - comprehensive search including all common locations
ICON_PATHS = [
    # Flat-Remix-Green-Dark (current theme)
    '/usr/share/icons/Flat-Remix-Green-Dark/apps/scalable',
    '/usr/share/icons/Flat-Remix-Green-Dark/apps/symbolic',
    '/usr/share/icons/Flat-Remix-Green-Dark/apps/64',
    '/usr/share/icons/Flat-Remix-Green-Dark/apps/48',
    # Nullsec theme
    '/usr/share/icons/nullsec',
    '/usr/share/icons/nullsec/48x48',
    '/usr/share/icons/nullsec/64x64',
    # Breeze (fallback theme)
    '/usr/share/icons/breeze-dark/apps/48',
    '/usr/share/icons/breeze-dark/apps/22',
    '/usr/share/icons/breeze/apps/48',
    # Papirus (popular theme)
    '/usr/share/icons/Papirus-Dark/48x48/apps',
    '/usr/share/icons/Papirus/48x48/apps',
    # Hicolor (standard fallback)
    '/usr/share/icons/hicolor/scalable/apps',
    '/usr/share/icons/hicolor/128x128/apps',
    '/usr/share/icons/hicolor/64x64/apps',
    '/usr/share/icons/hicolor/48x48/apps',
    '/usr/share/icons/hicolor/32x32/apps',
    '/usr/share/icons/hicolor/24x24/apps',
    '/usr/share/icons/hicolor/256x256/apps',
    # Gnome & Adwaita
    '/usr/share/icons/Adwaita/scalable/apps',
    '/usr/share/icons/Adwaita/48x48/apps',
    '/usr/share/icons/gnome/48x48/apps',
    '/usr/share/icons/gnome/scalable/apps',
    # Pixmaps
    '/usr/share/pixmaps',
    # Local icons
    '/home/antics/nullsec/static',
    '/home/antics/nullsec/static/nullsec-branding',
]

# Desktop file locations
DESKTOP_PATHS = [
    '/usr/share/applications',
    os.path.expanduser('~/.local/share/applications'),
]

# Icon cache for faster lookups
_icon_cache = {}

def find_icon_gtk(name, size=48):
    """Use GTK to find icon (most reliable method)"""
    try:
        import gi
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gtk
        theme = Gtk.IconTheme.get_default()
        icon_info = theme.lookup_icon(name, size, Gtk.IconLookupFlags.USE_BUILTIN)
        if icon_info:
            return icon_info.get_filename()
    except:
        pass
    return None

def find_icon(name, size=24):
    """Find an icon file by name with caching"""
    if not name:
        return None
    
    # Check cache first
    if name in _icon_cache:
        return _icon_cache[name]
    
    # Check if it's already a full path
    if name.startswith('/') and os.path.exists(name):
        _icon_cache[name] = name
        return name
    
    # Try GTK icon lookup first (most reliable)
    gtk_path = find_icon_gtk(name, 48)
    if gtk_path and os.path.exists(gtk_path):
        _icon_cache[name] = gtk_path
        return gtk_path
    
    # Search for icon in all paths
    search_names = [name, f'{name}.svg', f'{name}.png', f'{name}.xpm']
    for path in ICON_PATHS:
        if not os.path.exists(path):
            continue
        for sname in search_names:
            full = Path(path) / sname
            if full.exists():
                _icon_cache[name] = str(full)
                return str(full)
    
    # Try to find by partial match (e.g., "firefox" matches "firefox-esr")
    for path in ICON_PATHS:
        if not os.path.exists(path):
            continue
        try:
            for f in os.listdir(path):
                if name.lower() in f.lower():
                    full = Path(path) / f
                    _icon_cache[name] = str(full)
                    return str(full)
        except:
            pass
    
    _icon_cache[name] = None
    return None

def load_icon(path, size=(18, 18)):
    """Load and resize an icon (supports PNG, SVG, etc.)"""
    try:
        if not path or not Path(path).exists():
            return None
        
        # Handle SVG files
        if path.lower().endswith('.svg'):
            try:
                import cairosvg
                import io
                # Convert SVG to PNG in memory
                png_data = cairosvg.svg2png(url=path, output_width=size[0]*2, output_height=size[1]*2)
                img = Image.open(io.BytesIO(png_data))
            except ImportError:
                # Fallback: try to open SVG directly (some PIL versions support it)
                try:
                    img = Image.open(path)
                except:
                    return None
        else:
            img = Image.open(path)
        
        # Convert to RGBA if needed
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        img = img.resize(size, Image.Resampling.LANCZOS)
        return ctk.CTkImage(light_image=img, dark_image=img, size=size)
    except Exception as e:
        pass
    return None

def parse_desktop_file(filepath):
    """Parse a .desktop file and return app info"""
    try:
        config = configparser.ConfigParser(interpolation=None)
        config.read(filepath, encoding='utf-8')
        
        if 'Desktop Entry' not in config:
            return None
        
        entry = config['Desktop Entry']
        
        # Skip if NoDisplay or Hidden
        if entry.get('NoDisplay', 'false').lower() == 'true':
            return None
        if entry.get('Hidden', 'false').lower() == 'true':
            return None
        
        # Get basic info
        name = entry.get('Name', os.path.basename(filepath).replace('.desktop', ''))
        exec_cmd = entry.get('Exec', '')
        icon = entry.get('Icon', '')
        comment = entry.get('Comment', '')
        categories = entry.get('Categories', '')
        
        # Clean up exec command (remove %f, %u, etc.)
        exec_cmd = re.sub(r'%[fFuUdDnNickvm]', '', exec_cmd).strip()
        
        if not exec_cmd:
            return None
        
        return {
            'name': name,
            'cmd': exec_cmd,
            'icon': icon,
            'desc': comment[:50] if comment else '',
            'categories': categories,
            'file': filepath,
        }
    except:
        return None

# Cache file for faster startup
CACHE_FILE = '/tmp/n01d-apps-cache.json'
CACHE_MAX_AGE = 300  # 5 minutes

def load_all_applications():
    """Load all applications from .desktop files with caching"""
    import json
    import time
    
    # Try to load from cache
    try:
        if os.path.exists(CACHE_FILE):
            cache_age = time.time() - os.path.getmtime(CACHE_FILE)
            if cache_age < CACHE_MAX_AGE:
                with open(CACHE_FILE, 'r') as f:
                    cached = json.load(f)
                    print(f"Loaded {len(cached)} apps from cache")
                    return cached
    except:
        pass
    
    apps = {}
    
    for desktop_path in DESKTOP_PATHS:
        if not os.path.exists(desktop_path):
            continue
        
        for filename in os.listdir(desktop_path):
            if not filename.endswith('.desktop'):
                continue
            
            filepath = os.path.join(desktop_path, filename)
            app = parse_desktop_file(filepath)
            
            if app:
                # Use name as key to avoid duplicates
                key = app['name'].lower()
                if key not in apps:
                    apps[key] = app
    
    app_list = list(apps.values())
    
    # Save to cache
    try:
        with open(CACHE_FILE, 'w') as f:
            json.dump(app_list, f)
    except:
        pass
    
    return app_list

def categorize_apps(apps):
    """Organize apps into categories"""
    categories = {
        'nullsec': {'name': '☠️ NullSec Tools', 'color': COLORS['accent'], 'apps': [], 'expanded': False},
        'wireless': {'name': '📡 Wireless & WiFi', 'color': COLORS['cyan'], 'apps': [], 'expanded': False},
        'web': {'name': '🌐 Web & Recon', 'color': COLORS['blue'], 'apps': [], 'expanded': False},
        'exploit': {'name': '💣 Exploitation', 'color': COLORS['red'], 'apps': [], 'expanded': False},
        'password': {'name': '🔑 Passwords & Crypto', 'color': COLORS['yellow'], 'apps': [], 'expanded': False},
        'forensics': {'name': '🔍 Forensics & Recovery', 'color': COLORS['purple'], 'apps': [], 'expanded': False},
        'network': {'name': '🔌 Network Tools', 'color': COLORS['orange'], 'apps': [], 'expanded': False},
        'sniffing': {'name': '👁️ Sniffing & Spoofing', 'color': COLORS['pink'], 'apps': [], 'expanded': False},
        'dev': {'name': '💻 Development', 'color': COLORS['blue'], 'apps': [], 'expanded': False},
        'media': {'name': '🎬 Media & Graphics', 'color': COLORS['orange'], 'apps': [], 'expanded': False},
        'internet': {'name': '🌍 Internet', 'color': COLORS['cyan'], 'apps': [], 'expanded': False},
        'office': {'name': '📄 Office & Documents', 'color': COLORS['pink'], 'apps': [], 'expanded': False},
        'system': {'name': '⚙️ System & Utilities', 'color': COLORS['text_dim'], 'apps': [], 'expanded': False},
        'settings': {'name': '🔧 Settings', 'color': COLORS['purple'], 'apps': [], 'expanded': False},
        'other': {'name': '📦 Other', 'color': COLORS['text_dim'], 'apps': [], 'expanded': False},
    }
    
    # Keywords for categorization
    wireless_kw = ['air', 'wifi', 'wlan', 'wireless', 'bluetooth', 'kismet', 'fern', 'reaver', 'bully', 'wifite', 'cowpatty', 'wash']
    web_kw = ['web', 'http', 'burp', 'zap', 'nikto', 'dirb', 'gobuster', 'wfuzz', 'sqlmap', 'xss', 'whatweb', 'wafw00f', 'skipfish', 'w3af', 'commix', 'dirbuster', 'dirsearch']
    exploit_kw = ['metasploit', 'msf', 'armitage', 'exploit', 'payload', 'backdoor', 'beef', 'meterpreter', 'shellcode', 'unicorn', 'venom', 'starkiller', 'sliver', 'cobalt']
    password_kw = ['hash', 'crack', 'john', 'hydra', 'pass', 'brute', 'wordlist', 'cewl', 'crunch', 'ophcrack', 'chntpw', 'mimikatz', 'secretsdump']
    forensics_kw = ['forensic', 'autopsy', 'sleuth', 'binwalk', 'volatility', 'dd', 'ewf', 'foremost', 'scalpel', 'bulk_extractor', 'photorec', 'testdisk', 'guymager']
    network_kw = ['nmap', 'netcat', 'nc', 'socat', 'arp', 'ping', 'trace', 'masscan', 'zenmap', 'enum', 'dns', 'snmp', 'smb', 'ldap', 'rpc', 'netdiscover']
    sniffing_kw = ['wireshark', 'tcpdump', 'ettercap', 'bettercap', 'sniff', 'spoof', 'mitm', 'dsniff', 'arpspoof', 'macchanger', 'responder']
    dev_kw = ['code', 'codium', 'vim', 'geany', 'git', 'python', 'terminal', 'debug', 'compiler', 'ide']
    media_kw = ['vlc', 'gimp', 'audacity', 'obs', 'video', 'audio', 'image', 'photo', 'media', 'player', 'brasero', 'cheese']
    internet_kw = ['firefox', 'chromium', 'browser', 'discord', 'telegram', 'mail', 'torrent', 'transmission', 'anydesk', 'teamviewer', 'remmina']
    office_kw = ['libre', 'office', 'writer', 'calc', 'impress', 'draw', 'pdf', 'document', 'atril', 'evince']
    settings_kw = ['settings', 'preferences', 'control', 'config', 'appearance', 'display', 'network-manager', 'bluetooth-manager', 'power', 'sound', 'keyboard', 'mouse']
    
    for app in apps:
        name_lower = app['name'].lower()
        file_lower = app.get('file', '').lower()
        cat_lower = app.get('categories', '').lower()
        
        # Check if it's a NullSec tool
        if 'nullsec' in file_lower or 'nullsec' in name_lower:
            # Further categorize NullSec tools
            if any(kw in name_lower for kw in wireless_kw):
                categories['wireless']['apps'].append(app)
            elif any(kw in name_lower for kw in web_kw):
                categories['web']['apps'].append(app)
            elif any(kw in name_lower for kw in exploit_kw):
                categories['exploit']['apps'].append(app)
            elif any(kw in name_lower for kw in password_kw):
                categories['password']['apps'].append(app)
            elif any(kw in name_lower for kw in forensics_kw):
                categories['forensics']['apps'].append(app)
            elif any(kw in name_lower for kw in network_kw):
                categories['network']['apps'].append(app)
            elif any(kw in name_lower for kw in sniffing_kw):
                categories['sniffing']['apps'].append(app)
            else:
                categories['nullsec']['apps'].append(app)
        elif any(kw in name_lower for kw in wireless_kw):
            categories['wireless']['apps'].append(app)
        elif any(kw in name_lower for kw in web_kw):
            categories['web']['apps'].append(app)
        elif any(kw in name_lower for kw in exploit_kw):
            categories['exploit']['apps'].append(app)
        elif any(kw in name_lower for kw in password_kw):
            categories['password']['apps'].append(app)
        elif any(kw in name_lower for kw in forensics_kw):
            categories['forensics']['apps'].append(app)
        elif any(kw in name_lower for kw in network_kw):
            categories['network']['apps'].append(app)
        elif any(kw in name_lower for kw in sniffing_kw):
            categories['sniffing']['apps'].append(app)
        elif any(kw in name_lower or kw in cat_lower for kw in dev_kw):
            categories['dev']['apps'].append(app)
        elif any(kw in name_lower or kw in cat_lower for kw in media_kw):
            categories['media']['apps'].append(app)
        elif any(kw in name_lower or kw in cat_lower for kw in internet_kw):
            categories['internet']['apps'].append(app)
        elif any(kw in name_lower or kw in cat_lower for kw in office_kw):
            categories['office']['apps'].append(app)
        elif any(kw in name_lower or kw in cat_lower for kw in settings_kw):
            categories['settings']['apps'].append(app)
        elif 'system' in cat_lower or 'utility' in cat_lower:
            categories['system']['apps'].append(app)
        else:
            categories['other']['apps'].append(app)
    
    # Sort apps in each category and filter empty categories
    result = {}
    for key, cat in categories.items():
        cat['apps'].sort(key=lambda x: x['name'].lower())
        if cat['apps']:  # Only include categories with apps
            result[key] = cat
    
    return result


class AppItem(ctk.CTkFrame):
    """Application item widget"""
    
    def __init__(self, parent, app_data, menu_root=None, **kwargs):
        super().__init__(parent, fg_color='transparent', height=28, **kwargs)
        self.app_data = app_data
        self.menu_root = menu_root
        self.pack_propagate(False)
        
        self.inner = ctk.CTkFrame(self, fg_color='transparent', corner_radius=4)
        self.inner.pack(fill='both', expand=True, padx=1, pady=0)
        
        for w in [self, self.inner]:
            w.bind('<Enter>', self._hover)
            w.bind('<Leave>', self._leave)
            w.bind('<Button-1>', self._click)
        
        # Icon
        icon_path = find_icon(app_data.get('icon', ''))
        icon = load_icon(icon_path, (16, 16))
        
        self.icon_lbl = ctk.CTkLabel(self.inner, text='' if icon else '•', image=icon,
            font=('JetBrains Mono', 8), text_color=COLORS['accent'], width=20)
        self.icon_lbl.pack(side='left', padx=(4, 2))
        self.icon_lbl.bind('<Button-1>', self._click)
        
        # Name
        self.name_lbl = ctk.CTkLabel(self.inner, text=app_data['name'][:35],
            font=('JetBrains Mono', 9), text_color=COLORS['text'], anchor='w')
        self.name_lbl.pack(side='left', padx=(2, 4), fill='x', expand=True)
        self.name_lbl.bind('<Button-1>', self._click)
    
    def _hover(self, e):
        self.inner.configure(fg_color=COLORS['bg_hover'])
    
    def _leave(self, e):
        self.inner.configure(fg_color='transparent')
    
    def _click(self, e):
        try:
            subprocess.Popen(self.app_data['cmd'], shell=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            # Hide menu after launching app (don't destroy - keeps it fast)
            if self.menu_root:
                self.menu_root.after(50, self.menu_root.withdraw)
        except:
            pass


class CategoryHeader(ctk.CTkFrame):
    """Category header with expand/collapse"""
    
    def __init__(self, parent, key, data, toggle_cb, **kwargs):
        super().__init__(parent, fg_color='transparent', height=30, **kwargs)
        self.pack_propagate(False)
        self.key = key
        self.data = data
        self.toggle_cb = toggle_cb
        self.expanded = data.get('expanded', False)
        
        self.inner = ctk.CTkFrame(self, fg_color=COLORS['bg_light'], corner_radius=5,
            border_width=1, border_color=COLORS['border'])
        self.inner.pack(fill='both', expand=True, padx=1, pady=1)
        
        for w in [self, self.inner]:
            w.bind('<Button-1>', self._toggle)
            w.bind('<Enter>', self._hover)
            w.bind('<Leave>', self._leave)
        
        # Arrow
        self.arrow = ctk.CTkLabel(self.inner, text='▼' if self.expanded else '▶',
            font=('JetBrains Mono', 8), text_color=data['color'], width=14)
        self.arrow.pack(side='left', padx=(6, 2))
        self.arrow.bind('<Button-1>', self._toggle)
        
        # Name
        self.name_lbl = ctk.CTkLabel(self.inner, text=data['name'],
            font=('JetBrains Mono', 10, 'bold'), text_color=COLORS['text'], anchor='w')
        self.name_lbl.pack(side='left', fill='x', expand=True, padx=2)
        self.name_lbl.bind('<Button-1>', self._toggle)
        
        # Count
        self.count = ctk.CTkLabel(self.inner, text=str(len(data['apps'])),
            font=('JetBrains Mono', 8), text_color=COLORS['bg_dark'],
            fg_color=data['color'], corner_radius=6, width=22, height=14)
        self.count.pack(side='right', padx=6)
        self.count.bind('<Button-1>', self._toggle)
    
    def _toggle(self, e=None):
        self.expanded = not self.expanded
        self.arrow.configure(text='▼' if self.expanded else '▶')
        self.toggle_cb(self.key, self.expanded)
    
    def _hover(self, e):
        self.inner.configure(border_color=self.data['color'])
    
    def _leave(self, e):
        self.inner.configure(border_color=COLORS['border'])


class N01DStartMenu(ctk.CTk):
    """Main start menu"""
    
    def __init__(self):
        super().__init__()
        
        self.title('N01D Start Menu')
        self.geometry('520x750')
        self.configure(fg_color=COLORS['bg_dark'])
        self.resizable(True, True)
        self.minsize(400, 500)
        
        self.cat_frames = {}
        self.cat_headers = {}
        self.all_apps = []
        
        # Load all applications
        print("Loading applications...")
        all_apps = load_all_applications()
        self.categories = categorize_apps(all_apps)
        
        # Count total
        self.total_apps = sum(len(c['apps']) for c in self.categories.values())
        print(f"Loaded {self.total_apps} applications in {len(self.categories)} categories")
        
        # Set icon
        try:
            icon_path = Path('/home/antics/nullsec/static/skull.png')
            if icon_path.exists():
                img = Image.open(icon_path)
                self.iconphoto(True, ctk.CTkImage(light_image=img, dark_image=img, size=(64, 64)))
        except:
            pass
        
        self._build_ui()
        
        # Mouse wheel scrolling
        self.bind_all('<Button-4>', lambda e: self.scroll._parent_canvas.yview_scroll(-3, 'units'))
        self.bind_all('<Button-5>', lambda e: self.scroll._parent_canvas.yview_scroll(3, 'units'))
        self.bind_all('<MouseWheel>', lambda e: self.scroll._parent_canvas.yview_scroll(int(-1*(e.delta/120)), 'units'))
        
        # Auto-close when clicking outside the menu window
        self.bind('<FocusOut>', self._on_focus_out)
        
    def _on_focus_out(self, event):
        """Close menu when focus is lost (clicked outside)"""
        # Small delay to allow for internal widget focus changes
        self.after(150, self._check_focus)
    
    def _check_focus(self):
        """Check if focus is still within our window - hide instead of destroy"""
        try:
            focused = self.focus_get()
            if focused is None:
                self.withdraw()  # Hide instead of destroy for instant re-open
        except:
            pass
    
    def _build_ui(self):
        # Header
        header = ctk.CTkFrame(self, fg_color=COLORS['bg_light'], height=42, corner_radius=0)
        header.pack(fill='x')
        header.pack_propagate(False)
        
        # Logo
        title_frame = ctk.CTkFrame(header, fg_color='transparent')
        title_frame.pack(side='left', padx=10, pady=6)
        
        logo_path = find_icon('skull')
        logo = load_icon(logo_path, (22, 22))
        
        ctk.CTkLabel(title_frame, text='' if logo else '☠', image=logo,
            font=('JetBrains Mono', 16), text_color=COLORS['accent']).pack(side='left', padx=(0, 5))
        ctk.CTkLabel(title_frame, text='N01D',
            font=('JetBrains Mono', 14, 'bold'), text_color=COLORS['accent']).pack(side='left')
        
        # Search
        self.search = ctk.CTkEntry(header, placeholder_text='🔍 Search...',
            font=('JetBrains Mono', 9), fg_color=COLORS['bg_mid'],
            border_color=COLORS['border'], text_color=COLORS['text'], width=180, height=26)
        self.search.pack(side='right', padx=10)
        self.search.bind('<KeyRelease>', self._search)
        
        # Scrollable content
        self.scroll = ctk.CTkScrollableFrame(self, fg_color=COLORS['bg_dark'],
            scrollbar_button_color=COLORS['accent_dim'], scrollbar_button_hover_color=COLORS['accent'])
        self.scroll.pack(fill='both', expand=True, padx=4, pady=4)
        
        # Build categories
        for key, data in self.categories.items():
            self._build_category(key, data)
        
        # Footer
        footer = ctk.CTkFrame(self, fg_color=COLORS['bg_light'], height=36, corner_radius=0)
        footer.pack(fill='x', side='bottom')
        footer.pack_propagate(False)
        
        # Quick actions
        actions = [('⏻', 'mate-session-save --shutdown-dialog'), ('🔒', 'mate-screensaver-command -l'),
                   ('📁', 'caja'), ('🖥️', 'mate-terminal'), ('⚙️', 'mate-control-center')]
        
        for icon, cmd in actions:
            ctk.CTkButton(footer, text=icon, font=('Segoe UI Emoji', 11),
                fg_color='transparent', hover_color=COLORS['bg_hover'],
                text_color=COLORS['text'], width=32, height=28,
                command=lambda c=cmd: subprocess.Popen(c, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            ).pack(side='left', padx=2, pady=4)
        
        ctk.CTkLabel(footer, text=f'{len(self.categories)} categories • {self.total_apps} apps',
            font=('JetBrains Mono', 8), text_color=COLORS['text_dim']).pack(side='right', padx=10)
        
        self.bind('<Escape>', lambda e: self.destroy())
        self.bind('<Control-q>', lambda e: self.destroy())
    
    def _build_category(self, key, data):
        container = ctk.CTkFrame(self.scroll, fg_color='transparent')
        container.pack(fill='x', pady=1)
        
        header = CategoryHeader(container, key, data, self._toggle)
        header.pack(fill='x')
        self.cat_headers[key] = header
        
        apps_frame = ctk.CTkFrame(container, fg_color='transparent')
        self.cat_frames[key] = apps_frame
        
        for app in data['apps']:
            AppItem(apps_frame, app, menu_root=self).pack(fill='x', padx=(12, 0))
        
        if data.get('expanded', False):
            apps_frame.pack(fill='x', pady=(0, 2))
    
    def _toggle(self, key, expanded):
        frame = self.cat_frames.get(key)
        if frame:
            if expanded:
                frame.pack(fill='x', pady=(0, 2))
            else:
                frame.pack_forget()
    
    def _search(self, e):
        query = self.search.get().lower().strip()
        
        for key, data in self.categories.items():
            header = self.cat_headers.get(key)
            frame = self.cat_frames.get(key)
            
            if not query:
                if not data.get('expanded', False):
                    frame.pack_forget()
                    if header:
                        header.expanded = False
                        header.arrow.configure(text='▶')
                continue
            
            match = any(query in app['name'].lower() or query in app.get('desc', '').lower() 
                       for app in data['apps'])
            
            if match:
                frame.pack(fill='x', pady=(0, 2))
                if header:
                    header.expanded = True
                    header.arrow.configure(text='▼')
            else:
                frame.pack_forget()


def main():
    # Check for background mode (start hidden)
    start_hidden = '--background' in sys.argv or '-b' in sys.argv
    
    # Check single instance before creating window
    check_single_instance()
    
    ctk.set_appearance_mode('dark')
    ctk.set_default_color_theme('dark-blue')
    
    app = N01DStartMenu()
    
    # Signal handler to toggle window visibility
    def toggle_window(signum, frame):
        if app.winfo_viewable():
            app.withdraw()  # Hide
        else:
            app.deiconify()  # Show
            app.lift()  # Bring to front
            app.focus_force()
    
    signal.signal(signal.SIGUSR1, toggle_window)
    
    # Clean up on exit
    import atexit
    atexit.register(cleanup_lock)
    
    # Start hidden if background mode
    if start_hidden:
        app.withdraw()
        print("N01D Start Menu running in background. Use SIGUSR1 to toggle visibility.")
    
    app.mainloop()


if __name__ == '__main__':
    main()
