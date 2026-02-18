# NullSec Pineapple Suite 🍍

<p align="center">
  <img src="https://img.shields.io/badge/Payloads-141-green" alt="Payloads">
  <img src="https://img.shields.io/badge/Platform-WiFi%20Pineapple%20Pager-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Version-3.0-orange" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
  <img src="https://img.shields.io/badge/Author-bad--antics-red" alt="Author">
  <img src="https://img.shields.io/badge/Mesh-batman--adv-purple" alt="Mesh">
  <img src="https://img.shields.io/badge/Cluster-Distributed-cyan" alt="Cluster">
</p>

**The ultimate payload collection for Hak5 WiFi Pineapple Pager** — 141 professional payloads, distributed mesh cluster computing, batman-adv mesh networking, automated deployment, and enterprise-grade tooling.

## ✨ Features

- 🎯 **141 Payloads** — The largest WiFi Pineapple payload suite ever built
- 🕸️ **Mesh Networking** — batman-adv mesh with auto-peering and WireGuard encryption
- 🖥️ **Cluster Computing** — Distributed compute across 90+ cores for hash cracking and scanning
- ⚡ **Auto Deploy** — One-command deployment to Pineapple and cluster nodes
- 📊 **Health Dashboard** — Real-time monitoring of all cluster nodes
- 🔧 **Asset Inventory** — Automated network discovery and tracking
- 💾 **Backup System** — Encrypted backups of loot, configs, and payloads
- 🎭 **Unique Names** — Memorable payload names (SPECTER, BANSHEE, WRAITH, REAPER...)
- 📦 **One-Click Install** — Automated installer handles everything

## 📦 Installation

### Quick Install

```bash
git clone https://github.com/bad-antics/nullsec.git
cd nullsec/hak5-pineapple

# Deploy to WiFi Pineapple Pager
./nullsec-deploy.sh pineapple

# Or manual install via SSH
scp -r nullsec-suite/* root@172.16.52.1:/root/payloads/user/nullsec/
ssh root@172.16.52.1 "chmod +x /root/payloads/user/nullsec/*/payload.sh"
```

### Full Setup (with mesh + cluster)

```bash
# 1. Install suite
./install.sh --full

# 2. Set up mesh network
./nullsec-mesh-setup.sh

# 3. Configure cluster nodes
./nullsec-cluster.sh setup

# 4. Deploy tools to cluster
./nullsec-deploy.sh cluster-tools
```

### Installer Options

```bash
sh install.sh --full        # Full installation
sh install.sh --payloads    # Payloads only
sh install.sh --deps        # Dependencies only
sh install.sh --verify      # Verify installation
sh install.sh --uninstall   # Remove everything
```

## 🎭 Complete Payload Catalog (141)

### 🔥 Attack (20)
| Payload | Description |
|---------|-------------|
| **AuthFlood** | Authentication flood using aireplay-ng |
| **Banshee** | Aggressive deauthentication attack |
| **BeaconSpam** | Flood area with fake WiFi networks |
| **BotSwarm** | Multi-device coordinated attack swarm via mesh |
| **CaptivePortal** | Custom captive portal for credential harvesting |
| **ChannelJammer** | Disrupt WiFi across channels |
| **CoffeeShopAttack** | Rogue AP for public WiFi credentials |
| **DNSHijack** | Redirect DNS queries to capture portals |
| **EvilTwin** | Clone target network and capture credentials |
| **FloodGate** | Multi-vector DoS (deauth + beacon + auth) |
| **HotspotHijack** | Target mobile hotspots |
| **MassDeauth** | Simultaneous deauth on all networks |
| **PacketReplay** | Capture and replay WiFi packets |
| **Poltergeist** | Unpredictable WiFi disruption |
| **ProbeAttack** | Exploit probe requests to lure clients |
| **Siren** | Advanced captive portal with 8+ lure themes |
| **TargetedDeauth** | Precision deauth attacks |
| **WiFiConfuser** | Fake networks + deauth chaos |
| **WifiJammer** | Continuous WiFi disruption |
| **WPSBruteforce** | WPS PIN brute force with Pixie Dust |

### 🔍 Recon (21)
| Payload | Description |
|---------|-------------|
| **5GHzHunter** | 5GHz band scanner with DFS channel detection |
| **AIRecon** | AI-powered recon using Ollama LLM analysis |
| **BLERecon** | Bluetooth Low Energy device fingerprinting |
| **BluetoothScanner** | BT/BLE device discovery |
| **ClientTracker** | Track specific devices across networks |
| **CredSniffer** | Passive credential sniffing |
| **DarkRecon** | OSINT + service enumeration + vuln fingerprinting |
| **DeviceFingerprint** | Identify devices from MAC and probes |
| **DroneHunter** | Detect and identify nearby drones |
| **HiddenNetFinder** | Discover cloaked SSIDs |
| **InfraMap** | Infrastructure topology mapping |
| **IoTScanner** | IoT device discovery and fingerprinting |
| **NetworkMapper** | Full network mapping |
| **PasspointScanner** | Hotspot 2.0 and enterprise WiFi scanning |
| **QuickScan** | Fast 30-second WiFi scan |
| **SignalTracker** | Signal strength tracking for source location |
| **SocialMapper** | Map device relationships and patterns |
| **SpectrumAnalyzer** | WiFi spectrum analysis and channel mapping |
| **VendorHunt** | Find devices by manufacturer |
| **WaveRider** | Track devices across channels |
| **WiFi6Scanner** | 802.11ax/WiFi 6 network analyzer |

### 📥 Capture (14)
| Payload | Description |
|---------|-------------|
| **ARPSpoof** | ARP poisoning for MITM |
| **CredHarvester** | Multi-protocol credential harvesting |
| **DeepPacket** | Deep packet inspection with protocol analysis |
| **DNSSiphon** | DNS query interception and browsing analysis |
| **HandshakeHunter** | Targeted WPA handshake capture |
| **MITMProxy** | Transparent HTTP/HTTPS proxy |
| **PacketSniffer** | Protocol-aware packet capture |
| **PMKIDCapture** | Clientless PMKID hash capture |
| **Reaper** | Automated WPA handshake + PMKID harvester |
| **RogueCert** | SSL/TLS certificate attack framework |
| **SessionHijack** | Active session hijacking with injection |
| **SSLStrip** | SSL stripping (HTTPS → HTTP downgrade) |
| **TokenThief** | Session token interception and replay |
| **WPSScanner** | WPS vulnerability scanning |

### 🔓 Cracking (6)
| Payload | Description |
|---------|-------------|
| **BruteHydra** | Distributed multi-protocol brute force |
| **HashCrack** | GPU-accelerated distributed hash cracking |
| **MeshCracker** | Distributed WPA cracking via SSH mesh |
| **PasswordSpray** | Distributed password spraying with lockout evasion |
| **VaultBreaker** | Password vault and credential store extraction |
| **WPACracker** | Onboard wordlist-based WPA cracking |

### 🎣 Social Engineering (4)
| Payload | Description |
|---------|-------------|
| **FakeUpdate** | Captive portal disguised as software update |
| **NullSecDeface** | Hacker-style deface page with credential capture |
| **PhishForge** | Automated phishing portal generator |
| **PortalMaster** | All-in-one portal launcher (15+ templates) |

### 📤 Exfiltration (6)
| Payload | Description |
|---------|-------------|
| **CloudExfil** | Exfiltrate loot to cloud storage |
| **DataVacuum** | Extract interesting data from network traffic |
| **DNSExfil** | Data exfil via DNS tunneling |
| **Exfiltrator** | Multi-channel exfil (DNS, ICMP, HTTP, stego) |
| **LootSync** | Sync captured loot to USB storage |
| **StealthExfil** | Covert multi-channel exfiltration toolkit |

### 🛡️ Defense (8)
| Payload | Description |
|---------|-------------|
| **BandwidthAlert** | Bandwidth usage monitoring and alerts |
| **ClientAlert** | New client connection alerts |
| **DeauthAlert** | Deauth frame detection and alerting |
| **GeoFenceAlert** | GPS-based geofence monitoring |
| **HandshakeAlert** | WPA handshake capture alerting |
| **Honeypot** | Decoy AP logging connection attempts |
| **IntrusionAlert** | IDS for port scans, ARP spoofing, etc. |
| **RogueAPAlert** | Evil twin and rogue AP detection |

### 🕵️ Stealth (12)
| Payload | Description |
|---------|-------------|
| **C2Beacon** | Command & control with periodic check-in |
| **CloudC2Relay** | Cloud relay for remote management |
| **GhostNetwork** | Hidden covert network creation |
| **LogWiper** | Secure operation log wiping |
| **Mimic** | MAC address cloning |
| **NetGhost** | Invisible network presence (bypass IDS/NAC) |
| **NetworkPivot** | Multi-hop network traversal |
| **PagerLink** | SSH tunnel for remote Pager UI |
| **StealthRecon** | Completely passive WiFi recon |
| **TrafficMask** | Disguise Pineapple traffic as normal device |
| **TunnelRat** | Persistent reverse SSH tunnel |
| **VPNConnect** | VPN connection for anonymous operations |

### 📋 Compliance (4)
| Payload | Description |
|---------|-------------|
| **IsoBreaker** | Client/AP isolation bypass testing |
| **PenReport** | Automated pentest report generator |
| **SegmentShark** | Network segmentation and VLAN validator |
| **SupplyChainAudit** | Supply chain risk and firmware version audit |

### 🔧 Utility (8)
| Payload | Description |
|---------|-------------|
| **FirewallManager** | Manage iptables from Pager UI |
| **MACChanger** | Interface MAC address changer |
| **PackageManager** | Manage opkg packages from Pager UI |
| **RangeExtender** | WiFi range extension and signal boost |
| **ScheduleTask** | Schedule payloads via cron |
| **SpeedTest** | Internet speed testing |
| **SystemInfo** | Comprehensive system information display |
| **TimeBomb** | Delayed payload execution |

### 📡 SIGINT (2)
| Payload | Description |
|---------|-------------|
| **RFJammerDetect** | RF jamming source detection and analysis |
| **SignalHound** | RF signal intelligence across spectrum |

### 🔑 WPA3 / Enterprise / Automation / Simulation (4)
| Payload | Description |
|---------|-------------|
| **SAEProbe** | WPA3-SAE transition mode downgrade analyzer |
| **EnterpriseReaper** | WPA Enterprise EAP credential harvester |
| **ZeroClick** | Automated scan, identify, and capture |
| **APTSimulator** | Advanced Persistent Threat simulation |

### 😈 Pranks (6)
| Payload | Description |
|---------|-------------|
| **NetParasite** | Bandwidth hog to slow target network |
| **NumberCracker** | Hacking-themed number guessing game |
| **PagerPong** | Text-based pong on Pager display |
| **RickRoll** | Open AP that rickrolls everyone |
| **SSIDPranks** | Broadcast funny WiFi names |
| **WarGames** | WOPR-style hacking simulation |

### 🌐 General / Advanced (17)
| Payload | Description |
|---------|-------------|
| **AirGap** | Air-gapped network bridging |
| **AutoPwn** | Automated WiFi attack chain |
| **AutoPwn_Test** | Safe test mode (no deauth) |
| **BlueBorne** | Bluetooth vulnerability scanner |
| **BootOptimizer** | Performance tuning |
| **CaptiveClone** | Captive portal page cloning |
| **DeauthStorm** | Mass deauthentication |
| **KarmaAttack** | KARMA rogue AP |
| **NullSecConfig** | Suite configuration manager |
| **NullSecPortal** | NullSec-branded captive portal |
| **Phantom** | MITM packet sniffing |
| **ProbeHunter** | Passive probe request collection |
| **ProtocolFuzzer** | Network protocol fuzzing |
| **Specter** | Ghost-mode passive recon |
| **WiFiAudit** | Comprehensive WiFi security assessment |
| **WordlistManager** | Wordlist deployment |
| **Wraith** | Persistent target tracking |

## 🕸️ Mesh Networking

The suite includes a full batman-adv mesh networking system:

```bash
./nullsec-mesh-setup.sh          # Set up mesh
./nullsec-join-mesh.bat          # Windows join
./nullsec-join-mesh.ps1          # PowerShell join
```

**Features:**
- batman-adv layer 2 mesh routing
- WireGuard encrypted links
- Auto-peering and node discovery
- Cross-platform (Linux, Windows, macOS)
- Bridge to LAN for full network access

## 🖥️ Cluster Computing

Distribute workloads across all mesh-connected nodes:

```bash
./nullsec-cluster.sh setup                     # Configure nodes
./nullsec-cluster.sh status                    # Show cluster status
./nullsec-cluster.sh run "command"             # Run on all nodes
./nullsec-cluster-health.sh                    # Health dashboard
./nullsec-cluster-health.sh --watch            # Live monitoring
./nullsec-cluster.sh hashcrack capture.hccapx  # Distributed cracking
```

## 🚀 Toolkit

| Tool | Description |
|------|-------------|
| `nullsec-cluster.sh` | Distributed compute cluster management |
| `nullsec-cluster-health.sh` | Real-time cluster health dashboard |
| `nullsec-mesh-setup.sh` | batman-adv mesh networking setup |
| `nullsec-connect.sh` | WiFi Pineapple connection manager |
| `nullsec-deploy.sh` | Automated payload and tool deployment |
| `nullsec-inventory.sh` | Network asset discovery and inventory |
| `nullsec-backup.sh` | Encrypted backup system |
| `nullsec-watchdog.sh` | Service watchdog and keepalive |
| `nullsec-pxe-server.sh` | PXE boot server for network installs |
| `hak5-toolkit.sh` | All-in-one Hak5 toolkit |
| `install.sh` | Full suite installer |
| `build-firmware.sh` | Custom firmware builder |

## 📁 Directory Structure

```
hak5-pineapple/
├── nullsec-suite/           # 141 payloads (payload.sh + info.json)
├── pager-payloads/          # Advanced category-organized payloads
│   ├── bypass/              # Portal and WPA3 bypass
│   ├── enterprise/          # Enterprise network attacks
│   ├── exfil/               # Data exfiltration
│   ├── forensics/           # Evidence collection
│   ├── implant/             # Wireless implants
│   ├── mesh/                # Mesh network tools
│   ├── persist/             # Persistence mechanisms
│   ├── recon/               # Reconnaissance
│   ├── sigint/              # Signal intelligence
│   └── wifi/                # WiFi-specific attacks
├── nullsec-firmware/        # Custom firmware builds
├── lib/                     # Shared libraries
├── docs/                    # Documentation
├── themes/                  # UI themes
└── modules/                 # Extension modules
```

## 🔧 Dependencies

Auto-installed by the installer:

| Tool | Package | Purpose |
|------|---------|---------|
| aircrack-ng | aircrack-ng | WiFi cracking suite |
| hcxdumptool | hcxdumptool | PMKID capture |
| nmap | nmap | Network scanning |
| tcpdump | tcpdump | Packet capture |
| python3 | python3-light | Python payloads |
| php | php8-cli | Portal payloads |
| openssl | openssl-util | Certificate tools |

## 🛠️ Troubleshooting

<details>
<summary>Payloads not appearing?</summary>

```bash
sh install.sh --verify
chmod +x /root/payloads/user/nullsec/*/payload.sh
```
</details>

<details>
<summary>Monitor mode issues?</summary>

```bash
airmon-ng check kill
airmon-ng start wlan1
```
</details>

<details>
<summary>Mesh not connecting?</summary>

```bash
./nullsec-mesh-setup.sh status
batctl o    # Check mesh peers
```
</details>

<details>
<summary>Cluster node unreachable?</summary>

```bash
./nullsec-cluster-health.sh -n hostname
ssh -v user@ip
```
</details>

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/new-payload`)
3. Follow the payload template (see [CONTRIBUTING.md](CONTRIBUTING.md))
4. Include `info.json` with your payload
5. Test on WiFi Pineapple Pager hardware
6. Submit a pull request

## 📜 License

MIT License — See [LICENSE](LICENSE)

## ⚠️ Disclaimer

This toolkit is for **authorized security testing only**. The author is not responsible for misuse. Always obtain proper authorization before testing.

**Legal uses:**
- Penetration testing with written authorization
- Security assessments on your own networks
- Educational research in controlled environments
- Red team engagements with proper scope

## 🙏 Credits

**Developed by: bad-antics**

- Hak5 for the WiFi Pineapple platform
- The security research community
- OpenWrt project
- batman-adv mesh networking project

---

<p align="center">
<b>NullSec Pineapple Suite v3.0</b><br>
<i>141 Payloads • Mesh Cluster • Distributed Computing • Auto-Deploy</i><br>
<i>Developed by: bad-antics</i>
</p>
