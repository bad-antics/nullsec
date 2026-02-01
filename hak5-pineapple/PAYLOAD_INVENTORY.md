# NullSec Pineapple Pager - Complete Payload Inventory

## 📊 Summary

**Total Payloads: 38**
**Author: bad-antics**
**Platform: Hak5 WiFi Pineapple Pager (480x222 screen)**

---

## 🎯 Attack Payloads (13)

| # | Payload | Description | Status |
|---|---------|-------------|--------|
| 1 | **AutoPwn** | Automated attack chain - scan, deauth, capture, crack | ✅ Deployed |
| 2 | **AutoPwnTest** | Safe testing version of AutoPwn | ✅ Deployed |
| 3 | **DeauthStorm** | Massive deauthentication flood attack | ✅ Deployed |
| 4 | **KarmaAttack** | Respond to all probe requests | ✅ Deployed |
| 5 | **PMKIDCapture** | PMKID hash capture for WPA cracking | ✅ Deployed |
| 6 | **TargetedDeauth** | Precision deauth against specific targets | ✅ Deployed |
| 7 | **EvilTwin** | Create rogue AP clone of target | ✅ Deployed |
| 8 | **HandshakeHunter** | WPA handshake capture | ✅ Deployed |
| 9 | **ChannelJammer** | Channel-specific disruption | ✅ Deployed |
| 10 | **AuthFlood** | Authentication flood attack | ✅ Deployed |
| 11 | **HotspotHijack** | Public hotspot takeover | ✅ Deployed |
| 12 | **MassDeauth** | Simultaneous attack on ALL networks | ✅ Deployed |
| 13 | **WifiJammer** | Full spectrum WiFi disruption | ✅ Deployed |

---

## 🔍 Recon Payloads (11)

| # | Payload | Description | Status |
|---|---------|-------------|--------|
| 1 | **ProbeHunter** | Capture probe requests and device history | ✅ Deployed |
| 2 | **WiFiAudit** | Comprehensive WiFi security audit | ✅ Deployed |
| 3 | **QuickScan** | Fast 10-second network survey | ✅ Deployed |
| 4 | **NetworkMapper** | Map network topology and relationships | ✅ Deployed |
| 5 | **ClientTracker** | Track client devices and movements | ✅ Deployed |
| 6 | **StealthRecon** | Passive-only reconnaissance | ✅ Deployed |
| 7 | **DeviceFingerprint** | Identify devices by signatures | ✅ Deployed |
| 8 | **SignalTracker** | Locate devices via signal strength | ✅ Deployed |
| 9 | **VendorHunt** | Find devices by manufacturer (Apple, Samsung, etc.) | ✅ Deployed |
| 10 | **DroneHunter** | Detect and identify nearby drones | ✅ Deployed |
| 11 | **IoTScanner** | Discover smart home/IoT devices | ✅ Deployed |

---

## 🎭 Social Engineering Payloads (5)

| # | Payload | Description | Status |
|---|---------|-------------|--------|
| 1 | **NullSecPortal** | NullSec branded captive portal | ✅ Deployed |
| 2 | **FakeUpdate** | Fake software update credential capture | ✅ Deployed |
| 3 | **CoffeeShopAttack** | Public WiFi credential harvesting | ✅ Deployed |
| 4 | **PortalMaster** | 40+ brand portal templates | ✅ Deployed |
| 5 | **NullSecDeface** | Hacker-style deface portal w/ matrix rain | ✅ Deployed |

---

## 📡 Capture Payloads (3)

| # | Payload | Description | Status |
|---|---------|-------------|--------|
| 1 | **CredSniffer** | Passive/active credential capture | ✅ Deployed |
| 2 | **WPACracker** | Onboard WPA password cracking | ✅ Deployed |
| 3 | **DNSHijack** | DNS interception and redirect | ✅ Deployed |

---

## 🔧 Utility Payloads (1)

| # | Payload | Description | Status |
|---|---------|-------------|--------|
| 1 | **RangeExtender** | WiFi repeater/hotspot with spoofed SSID | ✅ Deployed |

---

## 😈 Prank Payloads (5)

| # | Payload | Description | Status |
|---|---------|-------------|--------|
| 1 | **SSIDPranks** | Broadcast funny/inappropriate SSIDs | ✅ Deployed |
| 2 | **BeaconSpam** | Flood area with fake networks | ✅ Deployed |
| 3 | **RickRoll** | RickRoll captive portal | ✅ Deployed |
| 4 | **WiFiConfuser** | Confusing duplicate network names | ✅ Deployed |
| 5 | **NetParasite** | Bandwidth consumption attack | ✅ Deployed |

---

## 🎨 Portal Templates (40+)

### Social Media
- Facebook, Instagram, Twitter/X, LinkedIn, TikTok, Snapchat

### Corporate
- Microsoft 365, Google Workspace, Salesforce, Slack, Zoom, Cisco

### ISP/Carrier
- Xfinity, AT&T, Verizon, T-Mobile, Spectrum, Cox

### Entertainment
- Netflix, Spotify, Disney+, Amazon, HBO Max, YouTube

### Financial
- PayPal, Bank of America, Chase, Wells Fargo, Venmo, Cash App

### Technical
- Apple ID, Steam, GitHub, AWS, Azure, Cloudflare

### NullSec Specials
- Deface (Matrix Rain), Ransomware, Police, Breach, Update, Survey

---

## 🌟 Feature Highlights

### RangeExtender Payload
- Connect to source WiFi or phone hotspot
- Broadcast spoofed AP with internet passthrough
- Option to clone nearby SSID
- Preset popular SSIDs (xfinitywifi, attwifi, etc.)
- WPA2 or Open security options

### NullSecDeface Portal
- Matrix rain canvas animation
- Glitch text effects
- Animated fake statistics
- Skull ASCII art
- bad-antics credits
- Login credential capture

### PortalMaster Payload
- 40+ brand-accurate templates
- Dynamic color schemes
- Credential logging
- Auto HTTPS redirect

---

## 📁 Directory Structure on Device

```
/root/payloads/user/nullsec/
├── AuthFlood/payload.sh
├── AutoPwn/payload.sh
├── AutoPwnTest/payload.sh
├── BeaconSpam/payload.sh
├── ChannelJammer/payload.sh
├── ClientTracker/payload.sh
├── CoffeeShopAttack/payload.sh
├── CredSniffer/payload.sh
├── DNSHijack/payload.sh
├── DeauthStorm/payload.sh
├── DeviceFingerprint/payload.sh
├── DroneHunter/payload.sh
├── EvilTwin/payload.sh
├── FakeUpdate/payload.sh
├── HandshakeHunter/payload.sh
├── HotspotHijack/payload.sh
├── IoTScanner/payload.sh
├── KarmaAttack/payload.sh
├── MassDeauth/payload.sh
├── NetParasite/payload.sh
├── NetworkMapper/payload.sh
├── NullSecDeface/payload.sh
├── NullSecPortal/payload.sh
├── PMKIDCapture/payload.sh
├── PortalMaster/payload.sh
├── ProbeHunter/payload.sh
├── QuickScan/payload.sh
├── RangeExtender/payload.sh
├── RickRoll/payload.sh
├── SSIDPranks/payload.sh
├── SignalTracker/payload.sh
├── StealthRecon/payload.sh
├── TargetedDeauth/payload.sh
├── VendorHunt/payload.sh
├── WPACracker/payload.sh
├── WiFiAudit/payload.sh
├── WiFiConfuser/payload.sh
└── WifiJammer/payload.sh
```

---

## 🔧 Loot Directories

```
/mmc/nullsec/
├── handshakes/     # WPA captures
├── pmkid/          # PMKID hashes
├── probes/         # Probe requests
├── creds/          # Captured credentials
├── vendor_hunt/    # Vendor search results
├── drones/         # Drone detection logs
├── iot/            # IoT scan results
└── portals/        # Portal HTML files
```

---

## ✅ All Payloads Use Pager DuckyScript

- `PROMPT` - Full-screen prompts
- `NUMBER_PICKER` - Numeric input
- `TEXT_PICKER` - Text input
- `MAC_PICKER` - MAC address input
- `CONFIRMATION_DIALOG` - Yes/No confirmations
- `ERROR_DIALOG` - Error messages
- `SPINNER_START/STOP` - Progress indication
- `LOG` - Status messages
- `ALERT` - Important notifications

---

## 📝 Author Credits

**Created by:** bad-antics  
**Project:** NullSec WiFi Pineapple Suite  
**Platform:** Hak5 WiFi Pineapple Pager  

---

*Last Updated: Session Complete - 38 Payloads Deployed*
