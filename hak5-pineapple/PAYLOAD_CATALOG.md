# NullSec Payload Catalog v3.0

> Complete reference for all 141 payloads in the NullSec Pineapple Suite.
> Each payload includes `payload.sh` and `info.json` in its directory.

## Quick Stats

| Metric | Value |
|--------|-------|
| **Total Payloads** | 141 |
| **Categories** | 16 |
| **Platform** | WiFi Pineapple Pager |
| **Author** | bad-antics |
| **Version** | 3.0.0 |

## Categories

| Category | Count | Description |
|----------|-------|-------------|
| 🔥 Attack | 20 | Active WiFi attacks, deauth, rogue APs |
| 🔍 Recon | 21 | Passive and active reconnaissance |
| 📥 Capture | 14 | Packet capture, MITM, credential theft |
| 🔓 Cracking | 6 | Password and hash cracking |
| 🎣 Social Engineering | 4 | Phishing, fake portals, lures |
| 📤 Exfiltration | 6 | Covert data extraction |
| 🛡️ Defense | 8 | IDS, alerts, honeypots |
| 🕵️ Stealth | 12 | Covert operations, persistence, C2 |
| 📋 Compliance | 4 | Auditing, reporting, validation |
| 🔧 Utility | 8 | System tools and management |
| 📡 SIGINT | 2 | Signal intelligence |
| 🔑 WPA3 | 1 | WPA3-specific attacks |
| 🏢 Enterprise | 1 | Enterprise network attacks |
| 🤖 Automation | 1 | Automated attack chains |
| 🎮 Simulation | 1 | Red team simulation |
| 😈 Pranks | 6 | Fun/prank payloads |
| 🌐 General | 17 | Multi-purpose and advanced |

## Payload Directory

### Attack Payloads (20)

| # | Payload | Lines | Description |
|---|---------|-------|-------------|
| 1 | AuthFlood | ~80 | Authentication flood using aireplay-ng |
| 2 | Banshee | ~150 | Aggressive multi-target deauthentication |
| 3 | BeaconSpam | ~90 | Flood area with hundreds of fake APs |
| 4 | BotSwarm | ~200 | Coordinated multi-device swarm attacks via mesh |
| 5 | CaptivePortal | ~180 | Custom captive portal credential harvesting |
| 6 | ChannelJammer | ~100 | Multi-channel WiFi disruption |
| 7 | CoffeeShopAttack | ~150 | Rogue AP mimicking public WiFi |
| 8 | DNSHijack | ~120 | DNS redirect to capture portals |
| 9 | EvilTwin | ~200 | Perfect AP clone with credential capture |
| 10 | FloodGate | ~180 | Combined deauth + beacon + auth flood |
| 11 | HotspotHijack | ~120 | Target mobile hotspot users |
| 12 | MassDeauth | ~100 | Area-wide simultaneous deauth |
| 13 | PacketReplay | ~130 | WiFi packet capture and replay |
| 14 | Poltergeist | ~140 | Random unpredictable WiFi chaos |
| 15 | ProbeAttack | ~110 | Probe request exploitation |
| 16 | Siren | ~250 | 8-theme advanced lure portal |
| 17 | TargetedDeauth | ~90 | Single-target precision deauth |
| 18 | WiFiConfuser | ~100 | Fake networks + deauth combo |
| 19 | WifiJammer | ~80 | Continuous WiFi disruption |
| 20 | WPSBruteforce | ~160 | WPS PIN brute force with Pixie Dust |

### Recon Payloads (21)

| # | Payload | Lines | Description |
|---|---------|-------|-------------|
| 1 | 5GHzHunter | ~170 | 5GHz band DFS channel scanner |
| 2 | AIRecon | ~200 | Ollama LLM-powered intelligence analysis |
| 3 | BLERecon | ~160 | BLE device fingerprinting and GATT enum |
| 4 | BluetoothScanner | ~120 | BT/BLE discovery |
| 5 | ClientTracker | ~110 | Cross-network device tracking |
| 6 | CredSniffer | ~100 | Passive credential sniffing |
| 7 | DarkRecon | ~250 | OSINT + vuln fingerprinting |
| 8 | DeviceFingerprint | ~100 | MAC-based device identification |
| 9 | DroneHunter | ~130 | Drone detection via WiFi patterns |
| 10 | HiddenNetFinder | ~90 | Cloaked SSID discovery |
| 11 | InfraMap | ~200 | Network infrastructure topology mapping |
| 12 | IoTScanner | ~120 | IoT device discovery |
| 13 | NetworkMapper | ~100 | Full network mapping |
| 14 | PasspointScanner | ~130 | Hotspot 2.0 scanning |
| 15 | QuickScan | ~60 | Fast 30-second WiFi scan |
| 16 | SignalTracker | ~110 | Signal strength source location |
| 17 | SocialMapper | ~150 | Device relationship mapping |
| 18 | SpectrumAnalyzer | ~160 | WiFi spectrum analysis |
| 19 | VendorHunt | ~90 | Manufacturer-based device search |
| 20 | WaveRider | ~100 | Cross-channel device tracking |
| 21 | WiFi6Scanner | ~140 | 802.11ax WiFi 6/6E analyzer |

### Capture Payloads (14)

| # | Payload | Lines | Description |
|---|---------|-------|-------------|
| 1 | ARPSpoof | ~130 | ARP poisoning MITM |
| 2 | CredHarvester | ~180 | Multi-protocol credential harvest |
| 3 | DeepPacket | ~200 | DPI with protocol analysis |
| 4 | DNSSiphon | ~120 | DNS browsing pattern analysis |
| 5 | HandshakeHunter | ~150 | Targeted WPA handshake capture |
| 6 | MITMProxy | ~180 | HTTP/HTTPS transparent proxy |
| 7 | PacketSniffer | ~160 | Protocol-aware capture |
| 8 | PMKIDCapture | ~100 | Clientless PMKID hash capture |
| 9 | Reaper | ~180 | WPA handshake + PMKID harvester |
| 10 | RogueCert | ~260 | SSL/TLS certificate attacks |
| 11 | SessionHijack | ~200 | Active session hijacking |
| 12 | SSLStrip | ~120 | HTTPS downgrade attack |
| 13 | TokenThief | ~150 | Session token interception |
| 14 | WPSScanner | ~100 | WPS vulnerability scanning |

### Stealth Payloads (12)

| # | Payload | Lines | Description |
|---|---------|-------|-------------|
| 1 | C2Beacon | ~200 | HTTP/HTTPS C2 check-in |
| 2 | CloudC2Relay | ~280 | Cloud relay (SSH/WG/HTTP) |
| 3 | GhostNetwork | ~150 | Hidden covert network |
| 4 | LogWiper | ~100 | Secure log wiping |
| 5 | Mimic | ~80 | MAC address cloning |
| 6 | NetGhost | ~250 | IDS/NAC bypass |
| 7 | NetworkPivot | ~210 | Multi-hop traversal |
| 8 | PagerLink | ~120 | Remote Pager UI tunnel |
| 9 | StealthRecon | ~100 | Zero-footprint recon |
| 10 | TrafficMask | ~130 | Traffic disguise |
| 11 | TunnelRat | ~140 | Persistent reverse SSH |
| 12 | VPNConnect | ~110 | Anonymous VPN ops |

## Loot Directories

All payloads save output to `/mmc/nullsec/<payload_name>/`:

```
/mmc/nullsec/
├── specter/         # Specter recon data
├── reaper/          # Captured handshakes
├── banshee/         # Attack logs
├── siren/           # Portal credentials
├── ...              # (one per payload)
```

## Payload Template

Create new payloads following this template:

```bash
#!/bin/bash
# Title: My Payload
# Author: bad-antics
# Description: What it does
# Category: nullsec/category

LOOT_DIR="/mmc/nullsec/mypayload"
mkdir -p "$LOOT_DIR"

PROMPT "PAYLOAD NAME

Description here.

Press OK to start."

# Your code here

PROMPT "Results here.
Loot: $LOOT_DIR"
```

Each payload must also include `info.json`:
```json
{
    "name": "MyPayload",
    "title": "My Payload - Short Description",
    "description": "Full description of what the payload does",
    "author": "bad-antics",
    "version": "1.0.0",
    "category": "recon",
    "platform": "pineapple-pager",
    "firmware": ">=2.0"
}
```

---

*NullSec Pineapple Suite v3.0 — 141 Payloads — Developed by bad-antics*
