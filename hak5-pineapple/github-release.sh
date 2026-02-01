#!/bin/bash
#####################################################
# NullSec Pineapple Suite - GitHub Release Script
# Automates repo creation and push to GitHub
#####################################################
# Author: bad-antics / NullSec Team
# Version: 1.0
#####################################################

set -e

# Configuration
GITHUB_USER="bad-antics"
RELEASE_DIR="/home/antics/nullsec/hak5-pineapple/github-release"
PAYLOADS_DIR="/home/antics/nullsec/hak5-pineapple/payloads"
THEME_DIR="/home/antics/nullsec/hak5-pineapple/themes"
LIB_DIR="/home/antics/nullsec/hak5-pineapple/lib"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

banner() {
    echo -e "${PURPLE}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║     _   _       _ _ ____                                  ║"
    echo "  ║    | \ | |_   _| | / ___|  ___  ___                       ║"
    echo "  ║    |  \| | | | | | \___ \ / _ \/ __|                      ║"
    echo "  ║    | |\  | |_| | | |___) |  __/ (__                       ║"
    echo "  ║    |_| \_|\__,_|_|_|____/ \___|\___|                      ║"
    echo "  ║                                                           ║"
    echo "  ║         GitHub Release Automation Script                  ║"
    echo "  ║                   Version ${VERSION}                           ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

# Get payload category
get_category() {
    local payload="$1"
    case "$payload" in
        DeauthStorm|MassDeauth|TargetedDeauth|AuthFlood|ChannelJammer|WifiJammer|KarmaAttack|EvilTwin|HotspotHijack|DNSHijack|Banshee|Siren)
            echo "attack" ;;
        QuickScan|StealthRecon|ProbeHunter|DeviceFingerprint|VendorHunt|NetworkMapper|ClientTracker|SignalTracker|IoTScanner|DroneHunter|WiFiAudit|SocialMapper)
            echo "recon" ;;
        NullSecPortal|FakeUpdate|CoffeeShopAttack|PortalMaster|NullSecDeface)
            echo "social" ;;
        HandshakeHunter|PMKIDCapture|WPACracker|CredSniffer|USBCredStealer|PacketReplay)
            echo "capture" ;;
        BeaconSpam|RickRoll|SSIDPranks|WiFiConfuser|NetParasite)
            echo "pranks" ;;
        GhostNetwork|Phantom|Specter|Wraith|Mimic|Poltergeist|Honeypot)
            echo "stealth" ;;
        AutoPwn|ZeroClick|TimeBomb|Reaper)
            echo "automation" ;;
        *)
            echo "utility" ;;
    esac
}

# Get payload description
get_description() {
    local payload="$1"
    case "$payload" in
        AuthFlood) echo "Authentication flood attack to overwhelm access points" ;;
        AutoPwn) echo "Automated WiFi attack chain for quick exploitation" ;;
        Banshee) echo "Audio-based disruption and alert payload" ;;
        BeaconSpam) echo "Flood the airwaves with fake access point beacons" ;;
        BootOptimizer) echo "Optimize Pineapple boot time and performance" ;;
        ChannelJammer) echo "Jam specific WiFi channels to disrupt communications" ;;
        ClientTracker) echo "Track and monitor wireless client devices" ;;
        CoffeeShopAttack) echo "Public WiFi credential harvesting attack" ;;
        CredSniffer) echo "Capture credentials from network traffic" ;;
        DNSHijack) echo "DNS interception and redirection attack" ;;
        DeauthStorm) echo "Massive deauthentication flood attack" ;;
        DeviceFingerprint) echo "Identify and fingerprint wireless devices" ;;
        DroneHunter) echo "Detect and identify drone WiFi signatures" ;;
        EvilTwin) echo "Clone legitimate APs to intercept traffic" ;;
        FakeUpdate) echo "Fake software update captive portal" ;;
        GhostNetwork) echo "Create invisible covert C2 network with null SSID" ;;
        HandshakeHunter) echo "Capture WPA/WPA2 handshakes for cracking" ;;
        Honeypot) echo "Deploy decoy AP to detect and log attackers" ;;
        HotspotHijack) echo "Take over existing hotspot connections" ;;
        IoTScanner) echo "Discover and identify IoT devices" ;;
        KarmaAttack) echo "Respond to all probe requests for mass interception" ;;
        MassDeauth) echo "Simultaneous deauth against multiple networks" ;;
        Mimic) echo "Impersonate legitimate access points" ;;
        NetParasite) echo "Consume bandwidth as network parasite" ;;
        NetworkMapper) echo "Map network topology and device relationships" ;;
        NullSecConfig) echo "Configure NullSec suite settings" ;;
        NullSecDeface) echo "Hacker-themed captive portal deface" ;;
        NullSecPortal) echo "NullSec branded captive portal" ;;
        PMKIDCapture) echo "Clientless PMKID capture attack" ;;
        PacketReplay) echo "Capture and replay network packets" ;;
        Phantom) echo "Ghost access point operations" ;;
        Poltergeist) echo "Unpredictable interference patterns" ;;
        PortalMaster) echo "40+ brand captive portal templates" ;;
        ProbeHunter) echo "Collect and analyze probe requests" ;;
        QuickScan) echo "Fast network discovery and enumeration" ;;
        RangeExtender) echo "Extend WiFi range as repeater" ;;
        Reaper) echo "Cleanup and remove attack traces" ;;
        RickRoll) echo "Classic RickRoll network prank" ;;
        SSIDPranks) echo "Broadcast humorous fake SSIDs" ;;
        SignalTracker) echo "Track device location via signal strength" ;;
        Siren) echo "Alert and notification payload" ;;
        SocialMapper) echo "Map social connections via probe analysis" ;;
        Specter) echo "Invisible presence operations" ;;
        StealthRecon) echo "Passive reconnaissance without detection" ;;
        TargetedDeauth) echo "Precision deauth against specific targets" ;;
        TimeBomb) echo "Schedule payloads for delayed execution" ;;
        USBCredStealer) echo "USB-based credential theft" ;;
        VendorHunt) echo "Find devices by manufacturer/vendor" ;;
        WPACracker) echo "Onboard WPA password cracking" ;;
        WaveRider) echo "Channel-hopping target pursuit and tracking" ;;
        WiFiAudit) echo "Comprehensive WiFi security audit" ;;
        WiFiConfuser) echo "Confusing SSID spam attack" ;;
        WifiJammer) echo "Full spectrum WiFi disruption" ;;
        WordlistManager) echo "Manage wordlists for password attacks" ;;
        Wraith) echo "Stealth operation mode" ;;
        ZeroClick) echo "Fully automated attack chain: scan-identify-exploit" ;;
        *) echo "NullSec payload for WiFi Pineapple" ;;
    esac
}

# Create release directory structure
setup_release_dir() {
    log "Setting up release directory structure..."
    
    rm -rf "$RELEASE_DIR"
    mkdir -p "$RELEASE_DIR"/{master-suite,individual-payloads}
    mkdir -p "$RELEASE_DIR/master-suite/nullsec-pineapple-suite"/{payloads/{attack,recon,social,capture,utility,pranks,stealth,automation},theme,lib,docs,tools,assets}
}

# Generate LICENSE file
generate_license() {
    local output_dir="$1"
    cat > "$output_dir/LICENSE" << 'EOF'
MIT License

Copyright (c) 2026 bad-antics / NullSec

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

DISCLAIMER: This software is intended for educational and authorized security
testing purposes only. Unauthorized access to computer systems is illegal.
EOF
}

# Generate README for individual payload
generate_payload_readme() {
    local payload="$1"
    local output_dir="$2"
    local category=$(get_category "$payload")
    local description=$(get_description "$payload")
    local payload_lower=$(echo "$payload" | tr '[:upper:]' '[:lower:]')
    
    cat > "$output_dir/README.md" << EOF
# NullSec Payload: ${payload}

<p align="center">
  <img src="https://raw.githubusercontent.com/${GITHUB_USER}/nullsec-pineapple-suite/main/assets/banner.png" alt="NullSec Banner" width="600">
</p>

<p align="center">
  <a href="#installation"><img src="https://img.shields.io/badge/Platform-WiFi%20Pineapple%20Pager-purple"></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-green"></a>
  <a href="https://github.com/${GITHUB_USER}"><img src="https://img.shields.io/badge/Author-bad--antics-cyan"></a>
  <img src="https://img.shields.io/badge/Category-${category}-blue">
</p>

## 📝 Description

${description}

## ✨ Features

- Fully compatible with WiFi Pineapple Pager
- NullSec library integration
- Detailed logging to \`/root/loot/${payload_lower}/\`
- Clean exit handling
- Targeted payload support (use from Recon)

## 📋 Requirements

- WiFi Pineapple Pager
- NullSec libraries (\`nullsec-lib.sh\`, \`nullsec-scanner.sh\`)

## 🚀 Installation

### Quick Install
\`\`\`bash
ssh root@172.16.52.1
mkdir -p /root/payloads/user/nullsec/${payload}
wget -O /root/payloads/user/nullsec/${payload}/payload.sh \\
  https://raw.githubusercontent.com/${GITHUB_USER}/nullsec-payload-${payload_lower}/main/payload.sh
chmod +x /root/payloads/user/nullsec/${payload}/payload.sh
\`\`\`

### Via NullSec Suite
\`\`\`bash
git clone https://github.com/${GITHUB_USER}/nullsec-pineapple-suite
cd nullsec-pineapple-suite
./install.sh
\`\`\`

## 📖 Usage

### From Pineapple UI
1. **Payloads** → **User** → **nullsec** → **${payload}**
2. Click **Run**

### As Targeted Payload
1. **Recon** → Start scan → Select target
2. **Payloads** → **NullSec-${payload}**

### Command Line
\`\`\`bash
/root/payloads/user/nullsec/${payload}/payload.sh [options]
\`\`\`

## ⚠️ Disclaimer

For **authorized penetration testing only**. Unauthorized access is illegal.

## 🔗 Part of NullSec Collection

[NullSec WiFi Pineapple Suite](https://github.com/${GITHUB_USER}/nullsec-pineapple-suite) - 58+ payloads

## 📄 License

MIT License - [LICENSE](LICENSE)

---
<p align="center"><b>NullSec</b> - <i>Hacking the planet, one pineapple at a time</i> 🍍</p>
EOF
}

# Create individual payload repos
create_individual_repos() {
    log "Creating individual payload repositories with READMEs..."
    
    local count=0
    for payload_file in "$PAYLOADS_DIR"/*_payload.sh; do
        [ -f "$payload_file" ] || continue
        
        local filename=$(basename "$payload_file")
        local payload="${filename%_payload.sh}"
        
        # Skip test payloads
        [[ "$payload" == *"Test"* ]] && continue
        
        local payload_lower=$(echo "$payload" | tr '[:upper:]' '[:lower:]')
        local repo_dir="$RELEASE_DIR/individual-payloads/nullsec-payload-${payload_lower}"
        
        mkdir -p "$repo_dir"
        
        # Copy payload
        cp "$payload_file" "$repo_dir/payload.sh"
        chmod +x "$repo_dir/payload.sh"
        
        # Generate README
        generate_payload_readme "$payload" "$repo_dir"
        
        # Generate LICENSE
        generate_license "$repo_dir"
        
        # Create .gitignore
        cat > "$repo_dir/.gitignore" << 'EOF'
*.log
*.pcap
*.cap
*.csv
.DS_Store
EOF
        
        count=$((count + 1))
        info "Created: nullsec-payload-${payload_lower}"
    done
    
    log "Created $count individual payload repositories"
}

# Create master suite
create_master_suite() {
    log "Creating master suite repository..."
    
    local suite_dir="$RELEASE_DIR/master-suite/nullsec-pineapple-suite"
    
    # Copy all payloads organized by category
    for payload_file in "$PAYLOADS_DIR"/*_payload.sh; do
        [ -f "$payload_file" ] || continue
        
        local filename=$(basename "$payload_file")
        local payload="${filename%_payload.sh}"
        [[ "$payload" == *"Test"* ]] && continue
        
        local category=$(get_category "$payload")
        
        mkdir -p "$suite_dir/payloads/$category/$payload"
        cp "$payload_file" "$suite_dir/payloads/$category/$payload/payload.sh"
        chmod +x "$suite_dir/payloads/$category/$payload/payload.sh"
    done
    
    # Copy libraries
    if [ -d "$LIB_DIR" ]; then
        cp "$LIB_DIR"/*.sh "$suite_dir/lib/" 2>/dev/null || true
    fi
    
    # Copy theme
    if [ -d "$THEME_DIR/nullsec" ]; then
        cp -r "$THEME_DIR/nullsec"/* "$suite_dir/theme/" 2>/dev/null || true
    fi
    
    # Generate main README
    generate_master_readme "$suite_dir"
    
    # Generate LICENSE
    generate_license "$suite_dir"
    
    # Create install script
    create_install_script "$suite_dir"
    
    # Create .gitignore
    cat > "$suite_dir/.gitignore" << 'EOF'
*.log
*.pcap
*.cap
.DS_Store
EOF
    
    log "Master suite created!"
}

# Generate master suite README
generate_master_readme() {
    local suite_dir="$1"
    
    cat > "$suite_dir/README.md" << 'READMEEOF'
<p align="center">
  <img src="assets/banner.png" alt="NullSec Pineapple Suite" width="800">
</p>

<h1 align="center">🍍 NullSec Pineapple Suite</h1>

<p align="center">
  <b>The Ultimate WiFi Pineapple Pager Payload Collection</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Payloads-58+-purple">
  <img src="https://img.shields.io/badge/Platform-Pineapple%20Pager-orange">
  <img src="https://img.shields.io/badge/License-MIT-green">
  <img src="https://img.shields.io/badge/Author-bad--antics-cyan">
</p>

---

## 🎯 Overview

NullSec Pineapple Suite is a comprehensive collection of **58+ professional payloads** for the Hak5 WiFi Pineapple Pager. From reconnaissance to exploitation, this suite covers every aspect of WiFi security testing.

## ✨ Features

- 🔥 **58+ Battle-Tested Payloads**
- 🎯 **Targeted Payload Support** - Auto-inject target parameters
- 🎨 **Custom NullSec Theme**
- 📚 **Core Libraries**
- 🔄 **One-Click Install**

---

## 📦 Payload Categories

| Category | Count | Description |
|----------|-------|-------------|
| ⚔️ **Attack** | 12 | Deauth, jamming, evil twin, DNS hijack |
| 🔍 **Recon** | 12 | Scanning, fingerprinting, tracking |
| 🔐 **Capture** | 6 | Handshakes, PMKID, credentials |
| 🎭 **Social** | 5 | Captive portals, phishing |
| 👻 **Stealth** | 7 | Ghost networks, honeypots |
| 🤖 **Automation** | 4 | Auto-pwn, scheduled attacks |
| 🎪 **Pranks** | 5 | Beacon spam, RickRoll |
| 🔧 **Utility** | 7 | Config, optimization |

### Highlight Payloads

| Payload | Description |
|---------|-------------|
| **ZeroClick** | Fully automated: scan → identify → exploit |
| **GhostNetwork** | Invisible C2 with null SSID |
| **TimeBomb** | Schedule attacks for later |
| **SocialMapper** | Map device social connections |
| **Honeypot** | Decoy AP with attacker logging |
| **WaveRider** | Channel-hopping target pursuit |

---

## 🚀 Installation

### One-Click Install
```bash
git clone https://github.com/bad-antics/nullsec-pineapple-suite
cd nullsec-pineapple-suite
./install.sh
```

### Manual Install
```bash
ssh root@172.16.52.1
git clone https://github.com/bad-antics/nullsec-pineapple-suite /tmp/ns
cp -r /tmp/ns/payloads/*/* /root/payloads/user/nullsec/
cp /tmp/ns/lib/* /root/payloads/library/
```

---

## 📖 Usage

### Standard Payloads
**Dashboard** → **Payloads** → **User** → **nullsec** → Select & Run

### Targeted Payloads (Recommended)
1. **Recon** → Scan → Select AP/Client
2. **Payloads** → **NullSec-{Name}**
3. Target info auto-injected!

---

## 📁 Structure

```
nullsec-pineapple-suite/
├── payloads/
│   ├── attack/       # Deauth, jamming, evil twin
│   ├── recon/        # Scanning, tracking
│   ├── capture/      # Handshakes, creds
│   ├── social/       # Portals, phishing
│   ├── stealth/      # Ghost, honeypot
│   ├── automation/   # Auto-pwn, scheduled
│   ├── pranks/       # Fun stuff
│   └── utility/      # Config, tools
├── lib/              # Core libraries
├── theme/            # NullSec theme
└── install.sh
```

---

## ⚠️ Legal Disclaimer

**For authorized penetration testing ONLY.**

- ❌ Do NOT use without permission
- ❌ Unauthorized access is ILLEGAL
- ✅ Get written authorization first
- ✅ Use in controlled environments

---

## 👤 Author

**bad-antics** - [GitHub](https://github.com/bad-antics)

## 📄 License

MIT License - See [LICENSE](LICENSE)

---

<p align="center">
  <b>NullSec</b> - <i>Hacking the planet, one pineapple at a time</i> 🍍
</p>
READMEEOF
}

# Create install script
create_install_script() {
    local suite_dir="$1"
    
    cat > "$suite_dir/install.sh" << 'INSTALLEOF'
#!/bin/bash
#####################################################
# NullSec Pineapple Suite - Installer
#####################################################

PINEAPPLE_IP="${1:-172.16.52.1}"

echo "╔═══════════════════════════════════════════════╗"
echo "║     NullSec Pineapple Suite Installer         ║"
echo "╚═══════════════════════════════════════════════╝"

echo "[*] Checking connection to $PINEAPPLE_IP..."
if ! ping -c 1 "$PINEAPPLE_IP" &>/dev/null; then
    echo "[!] Cannot reach Pineapple. Connect via USB first."
    exit 1
fi
echo "[+] Connected!"

echo "[*] Installing payloads..."
for category in payloads/*/; do
    for payload in "$category"*/; do
        [ -d "$payload" ] || continue
        name=$(basename "$payload")
        echo "    → $name"
        ssh root@"$PINEAPPLE_IP" "mkdir -p /root/payloads/user/nullsec/$name" 2>/dev/null
        scp -q "$payload/payload.sh" root@"$PINEAPPLE_IP":/root/payloads/user/nullsec/"$name"/ 2>/dev/null
    done
done

echo "[*] Installing libraries..."
scp -q lib/*.sh root@"$PINEAPPLE_IP":/root/payloads/library/ 2>/dev/null

echo "[*] Installing theme..."
ssh root@"$PINEAPPLE_IP" "mkdir -p /mmc/root/themes/nullsec" 2>/dev/null
scp -qr theme/* root@"$PINEAPPLE_IP":/mmc/root/themes/nullsec/ 2>/dev/null

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║          Installation Complete! 🍍            ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "Payloads: Dashboard → Payloads → User → nullsec"
echo "Theme:    Dashboard → Settings → Theme → nullsec"
INSTALLEOF
    chmod +x "$suite_dir/install.sh"
}

# Push to GitHub
push_to_github() {
    echo ""
    log "GitHub Release Ready!"
    echo ""
    info "Release directory: $RELEASE_DIR"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PUSH MASTER SUITE TO GITHUB${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  cd $RELEASE_DIR/master-suite/nullsec-pineapple-suite"
    echo "  git init"
    echo "  git add ."
    echo "  git commit -m '🍍 NullSec Pineapple Suite v${VERSION}'"
    echo "  gh repo create nullsec-pineapple-suite --public --source=. --push"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PUSH INDIVIDUAL PAYLOADS (OPTIONAL)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  cd $RELEASE_DIR/individual-payloads"
    echo "  for repo in nullsec-payload-*; do"
    echo "    cd \$repo && git init && git add . && git commit -m 'Initial release'"
    echo "    gh repo create \$repo --public --source=. --push"
    echo "    cd .."
    echo "  done"
    echo ""
    
    read -p "Push master suite to GitHub now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$RELEASE_DIR/master-suite/nullsec-pineapple-suite"
        git init
        git add .
        git commit -m "🍍 NullSec Pineapple Suite v${VERSION} - 58+ WiFi Pineapple Pager Payloads"
        
        if command -v gh &>/dev/null; then
            gh repo create nullsec-pineapple-suite --public \
                --description "58+ WiFi Pineapple Pager payloads for penetration testing" \
                --source=. --push
            log "✓ Master suite pushed to GitHub!"
            echo ""
            echo -e "${GREEN}https://github.com/${GITHUB_USER}/nullsec-pineapple-suite${NC}"
        else
            warn "GitHub CLI not installed. Run manually:"
            echo "  git remote add origin git@github.com:${GITHUB_USER}/nullsec-pineapple-suite.git"
            echo "  git branch -M main"
            echo "  git push -u origin main"
        fi
    fi
}

# Main
main() {
    banner
    
    echo "This will create:"
    echo "  • Master suite repository (all 58 payloads)"
    echo "  • Individual payload repositories (58 repos)"
    echo "  • README files for every payload"
    echo ""
    
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && exit 0
    
    setup_release_dir
    create_individual_repos
    create_master_suite
    push_to_github
    
    echo ""
    log "GitHub release preparation complete!"
    info "Master suite: $RELEASE_DIR/master-suite/nullsec-pineapple-suite/"
    info "Individual:   $RELEASE_DIR/individual-payloads/"
}

main "$@"
