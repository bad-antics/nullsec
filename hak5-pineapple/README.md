# NullSec Pineapple Suite 🍍

<p align="center">
  <img src="https://img.shields.io/badge/Payloads-58-green" alt="Payloads">
  <img src="https://img.shields.io/badge/Platform-WiFi%20Pineapple%20Pager-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Version-2.0-orange" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
  <img src="https://img.shields.io/badge/Author-bad--antics-red" alt="Author">
</p>

**The ultimate payload collection for Hak5 WiFi Pineapple Pager** - 58 professional payloads with unique themed names, auto target scanning, and consistent branding.

## ✨ Features

- 🎯 **Auto Target Scanning** - Scan networks and select targets with intuitive UI
- 🎭 **Unique Themed Names** - Memorable payload names (SPECTER, BANSHEE, WRAITH...)
- ⚡ **Performance Optimized** - Boot optimization and fast scan modes
- 📊 **Organized Loot** - All captures organized by payload
- 🔧 **Shared Libraries** - Reusable scanner and utility modules
- 📦 **One-Click Install** - Automated installer handles all dependencies

## 📦 Installation

### Quick Install (Recommended)

Connect your WiFi Pineapple Pager via USB and run:

```bash
# Clone the repository
git clone https://github.com/bad-antics/nullsec-pineapple-suite.git
cd nullsec-pineapple-suite

# Transfer installer to device
scp -r . root@172.16.52.1:/tmp/nullsec-install/

# SSH into device and run installer
ssh root@172.16.52.1
cd /tmp/nullsec-install
sh install.sh --full
```

### Installer Options

```bash
# Full installation (recommended)
sh install.sh --full

# Install payloads only (if dependencies already installed)
sh install.sh --payloads

# Install dependencies only
sh install.sh --deps

# Verify installation
sh install.sh --verify

# Uninstall
sh install.sh --uninstall
```

### Interactive Mode

Run `sh install.sh` without arguments for an interactive menu.

## 🔧 Dependencies

The installer automatically installs these tools from OpenWrt repositories:

| Tool | Package | Purpose |
|------|---------|---------|
| iwconfig | wireless-tools | Interface configuration |
| airodump-ng | aircrack-ng | Network scanning |
| aireplay-ng | aircrack-ng | Deauth/injection attacks |
| airmon-ng | aircrack-ng | Monitor mode |
| aircrack-ng | aircrack-ng | WPA cracking |
| hcxdumptool | hcxdumptool | PMKID capture |
| python3 | python3-light | Python payloads |
| php | php8-cli | Portal payloads |

### Offline Installation

If your Pineapple doesn't have internet access:

1. Download packages on your computer:
```bash
# Run from the repo directory
./download-packages.sh
```

2. Transfer to device:
```bash
scp -r packages/ root@172.16.52.1:/mmc/packages/
scp install.sh root@172.16.52.1:/tmp/
scp -r nullsec-suite/ root@172.16.52.1:/tmp/
```

3. Run installer on device:
```bash
ssh root@172.16.52.1
cd /tmp
sh install.sh --full
```

## 🎭 Featured Payloads

| Payload | Description |
|---------|-------------|
| **SPECTER** | Ghost-mode passive reconnaissance - zero transmission footprint |
| **BANSHEE** | Multi-vector chaos attack (deauth + beacons + auth storms) |
| **WRAITH** | Persistent target tracking across channels |
| **POLTERGEIST** | Wireless haunting - random disconnects and ghost SSIDs |
| **REAPER** | Full WPA/WPA2 handshake + PMKID harvester |
| **SIREN** | Advanced captive portal with 8 lure themes |
| **PHANTOM** | MITM packet sniffing and credential capture |
| **MIMIC** | MAC cloning and vendor spoofing |

## 📚 Complete Payload List (58)

### 🔥 Attack (20)
| Payload | Description |
|---------|-------------|
| AuthFlood | Authentication flood attack |
| AutoPwn | Automated attack chain |
| Banshee | Aggressive deauth attack |
| ChannelJammer | Multi-channel WiFi disruption |
| DeauthStorm | Mass deauthentication |
| DNSHijack | DNS redirect attacks |
| EvilTwin | Rogue AP clone |
| HandshakeHunter | WPA handshake capture |
| KarmaAttack | PineAP KARMA mode |
| MassDeauth | Area-wide deauth |
| Poltergeist | Random WiFi chaos |
| Reaper | WPA hash harvester |
| TargetedDeauth | Precision deauth attacks |
| WifiJammer | Continuous WiFi jamming |
| ZeroClick | Zero-interaction attacks |

### 🔍 Recon (15)
| Payload | Description |
|---------|-------------|
| ClientTracker | Track connected clients |
| DeviceFingerprint | Device identification |
| DroneHunter | Detect drones |
| GhostNetwork | Hidden network detection |
| IoTScanner | Find IoT devices |
| NetworkMapper | Network topology mapping |
| PMKIDCapture | PMKID hash capture |
| ProbeHunter | Capture probe requests |
| QuickScan | Fast network scan |
| SignalTracker | Signal strength tracking |
| Specter | Ghost passive recon |
| StealthRecon | Low-profile scanning |
| VendorHunt | Device vendor identification |
| WaveRider | Signal analysis |
| WiFiAudit | Security assessment |
| Wraith | Persistent tracking |

### 🎣 Social Engineering (8)
| Payload | Description |
|---------|-------------|
| CoffeeShopAttack | Cafe-themed portal |
| FakeUpdate | Software update lure |
| Honeypot | Honeypot AP deployment |
| HotspotHijack | Hijack hotspot users |
| NullSecPortal | Basic captive portal |
| PortalMaster | Multi-template portals |
| RickRoll | YouTube redirect prank |
| Siren | 8-theme lure portals |

### 📥 Capture (5)
| Payload | Description |
|---------|-------------|
| CredSniffer | Credential harvest |
| PacketReplay | Packet capture/replay |
| Phantom | MITM sniffing |
| USBCredStealer | USB harvesting |
| WPACracker | Hash cracking setup |

### 🛠️ Utility (6)
| Payload | Description |
|---------|-------------|
| BootOptimizer | Performance tuning |
| Mimic | MAC spoofing |
| NullSecConfig | Suite settings |
| RangeExtender | Signal boosting |
| TimeBomb | Delayed execution |
| WordlistManager | Wordlist deployment |

### 😈 Pranks (4)
| Payload | Description |
|---------|-------------|
| BeaconSpam | Fake AP flooding |
| NetParasite | Persistent prank SSIDs |
| SSIDPranks | Funny network names |
| WiFiConfuser | Confusing network names |

## 📁 Directory Structure

After installation:

```
/root/payloads/user/nullsec/     # Payloads
├── Specter/
│   ├── payload.sh
│   └── info.json
├── Banshee/
├── ... (58 payloads)
│
/mmc/nullsec/
├── lib/                          # Shared libraries
│   ├── nullsec-lib.sh
│   └── nullsec-scanner.sh
├── loot/                         # Captured data
│   ├── handshakes/
│   ├── pmkid/
│   └── credentials/
└── logs/                         # Payload logs

/root/nullsec/logs/               # Session logs
```

## 🔧 Quick Reference

After installation, these aliases are available:

```bash
payloads    # Go to payload directory
loot        # Go to loot directory
monitor     # Start monitor mode (airmon-ng start wlan0)
scan        # Start network scan (airodump-ng wlan0mon)
```

## ⚙️ Configuration

Run **NullSecConfig** payload to customize:
- Quick Dismiss (LEFT/RIGHT clears prompts)
- Performance Mode (faster execution)
- Scan Duration (5-60 seconds)
- Auto Cleanup

Run **BootOptimizer** payload for:
- Faster boot times
- Memory optimization
- WiFi fast mode

## 🛠️ Troubleshooting

### Payloads not appearing?
```bash
# Verify installation
sh install.sh --verify

# Check permissions
chmod +x /root/payloads/user/nullsec/*/payload.sh
```

### Missing tools?
```bash
# Reinstall dependencies
sh install.sh --deps
```

### Interface issues?
```bash
# Restart wireless
wifi down && wifi up

# Or reboot
reboot
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Follow payload naming conventions
4. Include bad-antics credits
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for payload development guidelines.

## 📜 License

MIT License - See [LICENSE](LICENSE) file

## ⚠️ Disclaimer

This toolkit is for **authorized security testing only**. The author is not responsible for misuse. Always obtain proper authorization before testing.

**Legal uses include:**
- Penetration testing with written authorization
- Security assessments on your own networks
- Educational research in controlled environments

## 🙏 Credits

**Developed by: bad-antics**

Special thanks to:
- Hak5 for the WiFi Pineapple platform
- The security research community
- OpenWrt project for package repositories

---

<p align="center">
<b>NullSec Pineapple Suite v2.0</b><br>
<i>58 Payloads • Auto-Install • Fully Documented</i><br>
<i>Developed by: bad-antics</i>
</p>
