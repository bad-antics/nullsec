```
    ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗
    ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝
    ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     
    ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     
    ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗
    ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝
                    OFFENSIVE SECURITY FRAMEWORK
```

# NULLSEC Linux

**Advanced Penetration Testing & Red Team Operations Framework**

*A custom ParrotSec-based distribution for offensive security operations*

[![Version](https://img.shields.io/badge/version-4.2.0-red.svg)](https://github.com/bad-antics/nullsec-linux)
[![Platform](https://img.shields.io/badge/platform-ParrotSec%20|%20Kali-blue.svg)](https://parrotsec.org)
[![Modules](https://img.shields.io/badge/modules-150+-purple.svg)](docs/MODULES.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 🎯 Overview

NULLSEC is a comprehensive offensive security operations platform featuring:

- **150+ Custom Attack Modules** across 12 categories
- **Full Metasploit Framework Integration**
- **AI-Powered Security Assistant** (NullSec AI v3)
- **Interactive TUI Launcher** with search and filtering
- **Dual Operation Modes** - TEST (safe demos) + LIVE (real attacks)
- **Custom ISO Builder** for deployment

## 🚀 Quick Start

\`\`\`bash
# Launch framework console
./nullsec

# Launch TUI interface
python3 nullsec-launcher.py

# Launch AI assistant
python3 nullsec-ai.py

# Build custom ISO
./build-iso.sh
\`\`\`

## 📦 Module Categories

| Category | Count | Description |
|----------|-------|-------------|
| Network | 25+ | Scanning, pivoting, tunneling, MITM |
| Web | 20+ | XSS, SQLi, SSRF, API attacks |
| Wireless | 15+ | WiFi, Bluetooth, RF, RFID |
| Malware | 15+ | Payloads, evasion, persistence |
| Cloud | 12+ | AWS, Azure, GCP, Kubernetes |
| ICS/SCADA | 10+ | PLC, Modbus, industrial systems |
| Mobile | 8+ | Android, iOS exploitation |
| Social | 8+ | Phishing, vishing, pretexting |
| Active Directory | 8+ | Kerberos, Golden Ticket, DCSync |
| Cryptography | 6+ | Breaking crypto, key extraction |
| IoT | 10+ | Cameras, smart devices, firmware |
| Evasion | 12+ | AV/EDR bypass, anti-forensics |

## 🔧 Features

### Framework Console
\`\`\`
nullsec> use network/port-scanner
nullsec (port-scanner)> set TARGET 192.168.1.0/24
nullsec (port-scanner)> run
\`\`\`

### TUI Launcher
- Category browsing with vim-style navigation
- Real-time search filtering
- Module favorites and history
- Detailed module info panels

### AI Assistant
- Natural language security queries
- Automatic tool recommendations
- Attack chain suggestions
- CVE lookups and analysis

### Metasploit Integration
- Direct MSF console access
- Payload generation wizard
- Multi-handler setup
- Session management

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [FRAMEWORK.md](FRAMEWORK.md) | Core framework documentation |
| [MODULE_DEVELOPMENT_GUIDE.md](MODULE_DEVELOPMENT_GUIDE.md) | Creating custom modules |
| [NULLSEC_AI_V3_GUIDE.md](NULLSEC_AI_V3_GUIDE.md) | AI assistant usage |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Installation & deployment |
| [ISO_BUILD_INSTRUCTIONS.txt](ISO_BUILD_INSTRUCTIONS.txt) | Custom ISO creation |

## 🖥️ System Requirements

- **OS:** ParrotSec Linux 5.x+ / Kali Linux 2023+
- **RAM:** 4GB minimum, 8GB recommended
- **Disk:** 40GB+ for full installation
- **Network:** Wireless card for WiFi attacks (optional)

## 📁 Project Structure

\`\`\`
nullsec/
├── nullsec                 # Main framework launcher
├── nullsec-launcher.py     # TUI interface
├── nullsec-ai.py          # AI assistant
├── app.py                 # Web dashboard
├── nullsecurity/          # 150+ attack modules
│   ├── network/
│   ├── web/
│   ├── wireless/
│   └── ...
├── resources/             # Wordlists, payloads
├── utils/                 # Helper scripts
└── static/               # Web assets
\`\`\`

## ⚠️ Legal Disclaimer

**FOR AUTHORIZED SECURITY TESTING ONLY**

This framework is designed for legal penetration testing and security research. Unauthorized access to computer systems is illegal. Only use on systems you own or have explicit written permission to test.

The developers assume no liability for misuse of this software.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (\`git checkout -b feature/new-module\`)
3. Commit changes (\`git commit -am 'Add new module'\`)
4. Push to branch (\`git push origin feature/new-module\`)
5. Open Pull Request

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>bad-antics development</strong><br>
  <a href="https://github.com/bad-antics">github.com/bad-antics</a>
</p>
