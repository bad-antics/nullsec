# NullSec Firmware for WiFi Pineapple Pager

<p align="center">
  <img src="assets/nullsec-logo.png" alt="NullSec Logo" width="200"/>
</p>

## 🔴 Custom Firmware Enhancement Suite

**NullSec Firmware** is a comprehensive enhancement package for the Hak5 WiFi Pineapple Pager, featuring custom payloads, themes, and tools for security professionals.

---

## ⚠️ Disclaimer

This firmware is provided for **authorized security testing and educational purposes only**. Users are responsible for ensuring compliance with all applicable laws and regulations. Unauthorized access to computer systems is illegal.

---

## 🙏 Credits & Attribution

**Built for devices by [Hak5](https://hak5.org)**

This project is an independent community contribution and is not officially affiliated with, endorsed by, or sponsored by Hak5 LLC. The WiFi Pineapple® is a registered trademark of Hak5 LLC.

We extend our gratitude to the Hak5 team for creating amazing security research tools that empower the infosec community.

- **Hak5 Website**: https://hak5.org
- **Hak5 Shop**: https://shop.hak5.org
- **Hak5 Forums**: https://forums.hak5.org
- **Hak5 GitHub**: https://github.com/hak5

---

## ✨ Features

### 🎨 NullSec Theme
- Custom red/black hacker aesthetic
- Custom boot animation
- NullSec color palette
- Custom sound effects & ringtones

### 🚀 Attack Payloads
| Payload | Description |
|---------|-------------|
| `nullsec-autopwn` | Full automated attack chain |
| `nullsec-karma` | Evil twin + captive portal |
| `nullsec-deauth` | Mass deauthentication |
| `nullsec-pmkid` | PMKID hash capture |
| `nullsec-probes` | Probe request harvesting |
| `nullsec-recon` | Comprehensive WiFi recon |

### 🛠️ Utility Tools
| Tool | Description |
|------|-------------|
| `nullsec-sync` | Loot exfiltration (SSH/Discord/Telegram) |
| `nullsec-backup` | Full device backup |
| `wifi-audit` | Enterprise WiFi security audit |
| `net-mapper` | Network topology discovery |
| `cred-harvest` | Multi-protocol credential capture |

### 📡 Community Payloads
Additional payloads contributed by the community for various penetration testing scenarios.

---

## 📦 Installation

### Method 1: Desktop Updater (Recommended)
1. Download the NullSec Firmware Updater
2. Connect your Pineapple Pager via USB or WiFi
3. Click "Install NullSec Firmware"
4. Follow on-screen instructions

### Method 2: Manual Installation
```bash
# Connect to Pineapple
ssh root@172.16.52.1

# Download and run installer
curl -L https://nullsec.dev/pager/install.sh | bash
```

### Method 3: Full Firmware Flash
1. Download `nullsec-pager-firmware-vX.X.bin`
2. Use Hak5 recovery mode to flash
3. Complete setup wizard

---

## 🔧 Building from Source

```bash
# Clone repository
git clone https://github.com/nullsec/pineapple-firmware
cd pineapple-firmware

# Build firmware package
./build-firmware.sh

# Output: dist/nullsec-pager-firmware-vX.X.tar.gz
```

---

## 📁 Directory Structure

```
nullsec-firmware/
├── payloads/           # Attack & utility payloads
│   ├── attacks/        # Offensive payloads
│   ├── recon/          # Reconnaissance tools
│   ├── utils/          # Utility scripts
│   └── community/      # Community contributions
├── themes/             # NullSec theme files
│   └── nullsec/        # Main theme
├── tools/              # Additional tools
├── config/             # Default configurations
├── updater/            # Desktop updater application
└── docs/               # Documentation
```

---

## 🤝 Contributing

We welcome contributions from the security community!

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📜 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

**Note**: This license applies only to NullSec-created content. Hak5 device firmware and software are subject to their own licensing terms.

---

## 🔗 Links

- **NullSec GitHub**: https://github.com/nullsec
- **Documentation**: https://docs.nullsec.dev/pager
- **Twitter**: https://twitter.com/AnonAntics
- **Hak5 Forums Thread**: [Coming Soon]

---

<p align="center">
  <b>Made with ❤️ by the NullSec Team</b><br>
  <i>Powered by Hak5 Hardware</i>
</p>
