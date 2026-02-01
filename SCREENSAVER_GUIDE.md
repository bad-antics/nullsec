# 🎨 NullSec Linux - Custom Screensaver

## AI-Generated Matrix-Style Visual Display

```
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄
▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
```

---

## 📋 Overview

The NullSec Linux custom screensaver is an AI-generated, Matrix-inspired visual display that activates when your system is idle. It features:

- **Matrix Rain Effect** - Falling green characters
- **NullSec ASCII Logo** - Centered with pulsing glow effect
- **Hex Data Streams** - Floating hexadecimal values
- **Binary Particles** - Rising 0s and 1s
- **Scan Line** - Horizontal scanning effect
- **Status Messages** - Rotating system information
- **Live Clock** - Real-time display in corner

---

## 🚀 Installation

### Quick Install
```bash
cd ~/nullsec
bash install-screensaver.sh
```

### Manual Install
```bash
# Make executable
chmod +x ~/nullsec/nullsec-screensaver.py

# Install dependencies
sudo apt-get install python3-pyqt5 xprintidle

# Test run
python3 ~/nullsec/nullsec-screensaver.py
```

---

## 🎯 Features

### Visual Effects

#### 1. Matrix Rain
- 100 columns of falling characters
- Variable speed and length
- Fade-out trail effect
- Random character generation
- Green phosphor color scheme

#### 2. NullSec Logo Display
- ASCII art centered on screen
- Pulsing glow animation (180-255 alpha)
- Multi-layer shadow effect
- Neon green highlighting

#### 3. Hexadecimal Streams
- Random hex values floating down
- Cyan color with fade
- Variable speeds
- 8-character hex strings

#### 4. Binary Particles
- Rising binary digits (0 and 1)
- Pink/magenta coloring
- Gravity-defying animation
- Fade-out effect

#### 5. Scan Line
- Horizontal line sweeping screen
- Cyan glow effect
- Continuous loop
- CRT monitor simulation

#### 6. System Information
- Top-left: OS name and codename
- Top-right: Live time and date
- Bottom-left: Framework version
- Bottom-right: Exit instructions
- Center: Rotating status messages

### Status Messages
The screensaver cycles through:
- "SYSTEM IDLE - MONITORING..."
- "NULLSEC LINUX 1.0 (VOID)"
- "185 ATTACK MODULES LOADED"
- "12 AI MODELS ACTIVE"
- "SECURITY PROTOCOLS ENGAGED"
- "OFFENSIVE MODE: STANDBY"
- "FRAMEWORK v2.0 READY"
- "PENETRATION TESTING OS"
- "VOID CODENAME ACTIVE"
- "NULLSEC AI ONLINE"
- "NO THREATS DETECTED"
- "ALL SYSTEMS OPERATIONAL"

---

## ⚙️ Configuration

### Automatic Activation

The screensaver is configured to launch automatically after **10 minutes** of inactivity.

**Idle Timer:** 600,000 milliseconds (10 minutes)

To change the idle time, edit `~/.config/nullsec-idle-watcher.sh`:
```bash
IDLE_TIME=600000  # Change this value (in milliseconds)
```

**Time Conversions:**
- 5 minutes = 300000
- 10 minutes = 600000 (default)
- 15 minutes = 900000
- 30 minutes = 1800000

### Manual Configuration

#### Disable Auto-Launch
```bash
# Stop the idle watcher
pkill -f nullsec-idle-watcher

# Remove from autostart
rm ~/.config/autostart/nullsec-screensaver-watcher.desktop
```

#### Re-enable Auto-Launch
```bash
# Start watcher manually
~/.config/nullsec-idle-watcher.sh &

# Or reboot to use autostart
```

---

## 🎮 Usage

### Launch Manually
```bash
# From anywhere
python3 ~/nullsec/nullsec-screensaver.py

# Or if in nullsec directory
python3 nullsec-screensaver.py
```

### Exit Screensaver
- Press **any key**
- **Move mouse**
- **Click mouse**

### Test Idle Detection
```bash
# Check current idle time (in milliseconds)
xprintidle

# Watch idle time
watch -n 1 xprintidle
```

### View Running Watcher
```bash
# Check if watcher is running
ps aux | grep nullsec-idle-watcher

# View logs
tail -f ~/.xsession-errors
```

---

## 🛠️ Customization

### Change Colors

Edit `nullsec-screensaver.py`:

**Matrix Rain Color:**
```python
# Line ~144 - Change from green
color = QColor(0, 255, 70, alpha)  # (R, G, B, Alpha)
# To blue for example:
color = QColor(70, 70, 255, alpha)
```

**Logo Color:**
```python
# Line ~184 - Change logo color
painter.setPen(QColor(0, 255, 100, self.logo_alpha))
# To red for example:
painter.setPen(QColor(255, 50, 50, self.logo_alpha))
```

**Hex Stream Color:**
```python
# Line ~155
painter.setPen(QColor(0, 255, 255, alpha))  # Cyan
# Change to purple:
painter.setPen(QColor(255, 0, 255, alpha))
```

### Add Custom Messages

Edit the `messages` list in `nullsec-screensaver.py`:
```python
self.messages = [
    "SYSTEM IDLE - MONITORING...",
    "YOUR CUSTOM MESSAGE HERE",
    "ANOTHER CUSTOM MESSAGE",
    # ... add more messages
]
```

### Adjust Animation Speed

```python
# Line ~78 - Timer interval (milliseconds)
self.timer.start(50)  # 20 FPS (default)
# Faster:
self.timer.start(30)  # ~33 FPS
# Slower:
self.timer.start(100)  # 10 FPS
```

### Change Matrix Characters

```python
# Line ~22 - Character set
self.chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%^&*()_+-=[]{}|;:,.<>?/~`"
# Change to only binary:
self.chars = "01"
# Or custom symbols:
self.chars = "☠⚡⚠✓✗◆◇●○"
```

---

## 🐛 Troubleshooting

### Screensaver Won't Launch

**Check Python and PyQt5:**
```bash
python3 --version
python3 -c "import PyQt5; print('PyQt5 OK')"
```

**Install PyQt5 if missing:**
```bash
sudo apt-get install python3-pyqt5
```

### Idle Detection Not Working

**Check xprintidle:**
```bash
which xprintidle
xprintidle  # Should show current idle time
```

**Install if missing:**
```bash
sudo apt-get install xprintidle
```

### Watcher Not Starting

**Check if running:**
```bash
ps aux | grep nullsec-idle-watcher
```

**Start manually:**
```bash
~/.config/nullsec-idle-watcher.sh &
```

**Check autostart:**
```bash
ls ~/.config/autostart/nullsec-screensaver-watcher.desktop
```

### Black Screen / Nothing Displays

**Test in window mode:**
Edit `nullsec-screensaver.py`, comment out line ~74:
```python
# self.showFullScreen()
self.show()  # Use this instead for testing
```

**Check display server:**
```bash
echo $DISPLAY  # Should show :0 or similar
```

### Screensaver Won't Exit

**Force kill:**
```bash
pkill -f nullsec-screensaver
```

**Or:**
```bash
killall python3
```

---

## 📊 Performance

### System Requirements
- **CPU:** Minimal (< 5% on modern systems)
- **RAM:** ~50MB
- **GPU:** Software rendering (no GPU required)
- **Display:** Any resolution (auto-scales)

### Optimization Tips

**Reduce CPU usage:**
- Decrease FPS (increase timer interval)
- Reduce number of drops/particles
- Disable some effects

**Example low-performance mode:**
```python
# Fewer columns
self.columns = 50  # Instead of 100

# Slower refresh
self.timer.start(100)  # Instead of 50

# Disable binary particles
# Comment out lines ~117-127
```

---

## 📁 File Locations

```
~/nullsec/
├── nullsec-screensaver.py           # Main screensaver script
├── install-screensaver.sh           # Installation script
└── SCREENSAVER_GUIDE.md            # This guide

~/.config/
├── nullsec-idle-watcher.sh         # Idle detection script
└── autostart/
    └── nullsec-screensaver-watcher.desktop  # Autostart entry

~/.local/share/applications/
└── nullsec-screensaver.desktop     # Desktop entry

~/.config/systemd/user/
└── nullsec-screensaver.service     # Systemd service (optional)
```

---

## 🎨 Technical Details

### Animation Loop
1. Timer triggers every 50ms (20 FPS)
2. Update all animation states
3. Repaint entire screen
4. Handle input events

### Rendering Order (back to front)
1. Black background
2. Matrix rain (green)
3. Hex streams (cyan)
4. Binary particles (pink)
5. Scan line (cyan)
6. NullSec logo (green, center)
7. Status message (cyan, below logo)
8. Corner information (green)

### Color Scheme
- **Primary:** Neon Green (#00FF46) - Matrix rain, logo
- **Secondary:** Cyan (#00FFFF) - Hex streams, messages
- **Accent:** Magenta (#FF0064) - Binary particles
- **Background:** Pure Black (#000000)

### Fonts
- **Logo:** Courier New, 14pt, Bold
- **Messages:** Courier New, 16pt, Bold
- **Matrix:** Courier New, 12pt
- **Info:** Courier New, 10pt

---

## 🔧 Advanced Usage

### Launch on Specific Events

**On system lock:**
```bash
# Add to lock command
mate-screensaver-command --lock && python3 ~/nullsec/nullsec-screensaver.py
```

**On suspend/resume:**
Create systemd service that triggers on resume.

### Integration with MATE Screensaver

**Replace default screensaver:**
```bash
# Disable MATE screensaver graphics
dconf write /org/mate/screensaver/mode "'blank-only'"

# NullSec screensaver will overlay on blank screen
```

### Dual Monitor Support

The screensaver automatically spans all monitors in fullscreen mode.

To show on specific monitor:
```python
# Edit initUI() method
# Get specific screen geometry
screen = QApplication.screens()[0]  # Primary monitor
self.setGeometry(screen.geometry())
```

---

## 🎯 Keyboard Shortcuts

While screensaver is active:
- **Any Key** - Exit screensaver
- **Esc** - Exit screensaver  
- **Mouse Move** - Exit screensaver
- **Mouse Click** - Exit screensaver

---

## 📝 Credits

**Design:** AI-Generated Matrix-Style Interface  
**OS:** NullSec Linux 1.0 (void)  
**Framework:** PyQt5  
**Inspiration:** The Matrix, Cyberpunk aesthetics  
**License:** Part of NullSec Linux distribution  

---

## 🔐 Security Note

This screensaver does **NOT** lock your screen. It's purely visual.

To lock screen automatically:
```bash
# Configure MATE screensaver to lock
dconf write /org/mate/screensaver/lock-enabled true
dconf write /org/mate/screensaver/lock-delay 0
```

Or use a proper screen locker like `xscreensaver` or `light-locker`.

---

## 🚀 Quick Commands

```bash
# Install
bash ~/nullsec/install-screensaver.sh

# Test immediately
python3 ~/nullsec/nullsec-screensaver.py

# Check idle time
xprintidle

# Start watcher manually
~/.config/nullsec-idle-watcher.sh &

# Stop watcher
pkill -f nullsec-idle-watcher

# Force kill screensaver
pkill -f nullsec-screensaver.py

# Reinstall
bash ~/nullsec/install-screensaver.sh
```

---

**NullSec Linux 1.0 (void) - Built for Security Professionals**

*Visual display designed to complement the offensive security workflow*
