# NULLSEC Desktop

▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
█  Armitage-Style Attack Framework GUI for NULLSEC        █
█                 [ bad-antics development ]               █
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

## Overview

NULLSEC Desktop is a graphical user interface for the NULLSEC attack framework,
inspired by Armitage (the Metasploit GUI). It provides:

- 🌐 **Network Topology Visualization** - Visual map of targets and connections
- 💀 **Attack Module Browser** - 77+ attack modules organized by category
- 📋 **Target Management** - Add, scan, and track multiple targets
- 🔗 **Session Management** - Track active shells and connections
- 📡 **Shodan Integration** - Import targets from Shodan searches
- 🖥️ **Console Output** - Real-time attack feedback

## Installation

```bash
# The launcher will auto-install dependencies if needed
./launcher.sh
```

### Dependencies

- Python 3.8+
- GTK 3.0 (PyGObject)
- python3-gi
- python3-gi-cairo
- gir1.2-gtk-3.0

Install with:
```bash
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

## Usage

### Launch

```bash
# From terminal
./launcher.sh

# Or use the desktop shortcut
# Applications → Security → NULLSEC Desktop
```

### Quick Start

1. **Add Targets** - Enter IP, hostname, or CIDR range in the target bar
2. **Browse Modules** - Expand categories in the left panel
3. **Double-click Module** - Launches in terminal with target info
4. **Right-click Target** - Context menu with attack options
5. **View Console** - Monitor attack output in real-time

### Module Categories

| Category | Icon | Examples |
|----------|------|----------|
| Network | 🌐 | Port Scanner, DNS Poison, WiFi Deauth |
| Web | 🕸️ | SQL Injection, XSS, Web Exploit |
| Exploit | 💥 | Zero-Day, RCE, Webshell |
| Credential | 🔑 | Pass-the-Hash, Kerberoast, Golden Ticket |
| Social | 🎭 | Phishing, Vishing, Social Engineering |
| Persistence | 🔒 | RAT Deploy, C2 Server, Worm |
| Evasion | 👻 | Steganography, Proxy Chain, Evidence Destroy |
| Physical | 🔧 | BadUSB, RFID Clone, RF Jammer |
| Industrial | 🏭 | SCADA Exploit, PLC Attack, Power Grid |
| Cloud | ☁️ | Cloud Attack, Container Exploit |
| Mobile | 📱 | Mobile Attack, SS7, IMSI Catcher |
| AI | 🤖 | AI Attack, Model Extraction |

### Target States

- ❓ **Unknown** - Not yet scanned
- 🟢 **Alive** - Responds to probes
- 💀 **Compromised** - Session established

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+N | Add new target |
| Ctrl+S | Quick scan |
| Ctrl+I | Import targets |
| Ctrl+E | Export targets |
| F5 | Refresh view |
| Esc | Clear selection |

## Configuration

Edit `config.json` to customize:

```json
{
    "theme": "dark",
    "shodan_api_key": "YOUR_KEY",
    "default_terminal": "x-terminal-emulator",
    "auto_scan_on_add": false
}
```

## Integration with NULLSEC Framework

NULLSEC Desktop automatically:
- Loads targets from `.shodan_target` file
- Saves selected targets for modules to read
- Logs all activity to `logs/` directory
- Shares target data between attack modules

## Architecture

```
nullsec-desktop/
├── nullsec_desktop.py   # Main GTK application
├── launcher.sh          # Startup script
├── config.json          # Configuration
├── nullsec-desktop.desktop  # Desktop entry
└── README.md            # This file
```

## Screenshots

[Network View]
- Visual topology with targets as nodes
- Color-coded by status
- Click to select, right-click for menu

[Module Browser]
- Expandable categories
- 77+ attack modules
- Double-click to launch

[Console]
- Real-time output
- Color-coded messages
- Timestamp logging

## Future Features

- [ ] Metasploit RPC integration
- [ ] Nmap integration for scanning
- [ ] Built-in shell/terminal
- [ ] Attack workflow automation
- [ ] Report generation
- [ ] Target notes and annotations
- [ ] Multiple workspaces
- [ ] Plugin system

## Credits

Developed by **bad-antics** for the NULLSEC framework.

╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
