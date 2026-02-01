#!/bin/bash
#####################################################
# NullSec Payload README Generator
# Creates documentation for all payloads
#####################################################

SOURCE_DIR="/home/antics/nullsec/hak5-pineapple"
DOCS_DIR="$SOURCE_DIR/payload-docs"
mkdir -p "$DOCS_DIR"

# Payload metadata - name|category|description|features
declare -A PAYLOADS=(
    # Attack Payloads
    ["DeauthStorm"]="attack|Mass deauthentication flood attack|Flood targets with deauth frames,Multi-channel support,Adjustable intensity,Target all or specific clients"
    ["MassDeauth"]="attack|Simultaneous multi-network deauthentication|Attack multiple APs at once,Round-robin targeting,Configurable timing,Stealth options"
    ["TargetedDeauth"]="attack|Precision single-target deauthentication|Surgical strike capability,Minimal collateral,Signal strength tracking,Persistent mode"
    ["EvilTwin"]="attack|Clone and impersonate access points|Perfect AP cloning,Automatic channel matching,HTTPS downgrade,Credential capture"
    ["KarmaAttack"]="attack|Respond to all probe requests|Universal probe response,SSID collection,Client tracking,Automatic association"
    ["AuthFlood"]="attack|Authentication frame flooding|DoS via auth flood,Fake client generation,AP stress testing,Configurable rate"
    ["ChannelJammer"]="attack|Channel-specific disruption|Targeted channel jamming,Interference patterns,Temporary disruption,Auto-recovery"
    ["WifiJammer"]="attack|Full spectrum WiFi interference|All-channel disruption,Maximum impact,Emergency use,Controlled chaos"
    ["DNSHijack"]="attack|DNS interception and spoofing|DNS query capture,Response injection,Domain redirection,Phishing support"
    ["HotspotHijack"]="attack|Public hotspot takeover|Captive portal bypass,Credential theft,Session hijacking,Network pivot"
    ["NetParasite"]="attack|Network parasiting and bandwidth theft|Stealth connection,Bandwidth consumption,Persistent access,Data exfil"
    
    # Recon Payloads
    ["QuickScan"]="recon|Fast network discovery and enumeration|30-second scan,All channels,AP and client detection,Signal mapping"
    ["StealthRecon"]="recon|Passive reconnaissance without transmission|Zero transmission,Probe collection,Traffic analysis,Long-duration"
    ["ProbeHunter"]="recon|Capture and analyze probe requests|SSID history extraction,Device profiling,Location correlation,Travel patterns"
    ["DeviceFingerprint"]="recon|Identify devices by wireless signatures|MAC analysis,Vendor lookup,Device type detection,OS fingerprinting"
    ["NetworkMapper"]="recon|Map network topology and relationships|Visual mapping,AP-client relationships,Channel usage,Coverage analysis"
    ["ClientTracker"]="recon|Track client device movements|Real-time tracking,Signal triangulation,Movement patterns,Dwell time"
    ["SignalTracker"]="recon|Locate devices using signal strength|RSSI analysis,Direction finding,Distance estimation,Movement detection"
    ["VendorHunt"]="recon|Find devices by manufacturer OUI|Vendor filtering,Target specific brands,IoT discovery,Enterprise mapping"
    ["IoTScanner"]="recon|Discover smart devices and IoT|Protocol detection,Vulnerability hints,Default creds check,Device inventory"
    ["DroneHunter"]="recon|Detect and identify drones via WiFi|Drone SSID patterns,Controller detection,Flight tracking,Countermeasures"
    ["SocialMapper"]="recon|Map social connections between devices|Probe correlation,Network history,Relationship graphing,OSINT generation"
    
    # Capture Payloads
    ["HandshakeHunter"]="capture|WPA/WPA2 handshake capture|Targeted capture,Auto-deauth option,Verification,Hash extraction"
    ["PMKIDCapture"]="capture|Clientless PMKID attack for WPA|No client needed,Fast capture,Hash ready,Offline cracking"
    ["WPACracker"]="capture|Onboard password cracking|Dictionary attack,Wordlist support,Progress tracking,Hash management"
    ["CredSniffer"]="capture|Capture credentials from network traffic|HTTP capture,Form extraction,Protocol parsing,Session theft"
    ["USBCredStealer"]="capture|USB-based credential theft|Keyboard emulation,Auto-execute,Exfiltration,Multi-platform"
    ["PacketReplay"]="capture|Capture and replay network packets|Packet recording,Timed replay,ARP replay,IV collection"
    
    # Stealth Payloads
    ["GhostNetwork"]="stealth|Create invisible covert C2 network|Hidden SSID,Null-byte name,Covert channel,Undetectable"
    ["Phantom"]="stealth|Ghost AP operations|Ephemeral AP,Quick spawn,Auto-destruct,Trace removal"
    ["Specter"]="stealth|Stealth AP mode|Low visibility,Reduced beacons,Selective response,Counter-detection"
    ["Wraith"]="stealth|Covert wireless operations|Silent mode,Passive only,Evidence cleanup,Operational security"
    ["WaveRider"]="stealth|Channel-hopping target pursuit|Follow targets,Auto-channel hop,Signal tracking,Attack on find"
    
    # Automation Payloads
    ["ZeroClick"]="automation|Automated full attack chain|Auto-scan,Auto-identify,Auto-exploit,Report generation"
    ["AutoPwn"]="automation|Fully automated WiFi exploitation|One-click attack,Multiple vectors,Result logging,Smart targeting"
    ["TimeBomb"]="automation|Schedule payloads for delayed execution|Timed execution,Delay options,Background daemon,Job management"
    
    # Social Engineering
    ["NullSecPortal"]="social|NullSec branded captive portal|Custom branding,Credential capture,Terms acceptance,Data collection"
    ["FakeUpdate"]="social|Fake software update phishing|OS mimicry,Download fake,Credential prompt,Malware delivery"
    ["PortalMaster"]="social|40+ captive portal templates|Brand spoofing,Multiple industries,Custom templates,Quick deploy"
    ["CoffeeShopAttack"]="social|Public WiFi credential harvesting|Public hotspot clone,Social engineering,Free WiFi bait,Mass capture"
    ["NullSecDeface"]="social|Hacker-style deface portal|Custom message,Brand display,Redirect control,Scare tactics"
    ["Honeypot"]="social|Decoy AP with full logging|Weak password bait,Connection logging,Attack detection,Counter-intel"
    
    # Pranks
    ["BeaconSpam"]="pranks|Flood the air with fake SSIDs|Mass SSID creation,Custom names,Emoji support,Confusion factor"
    ["SSIDPranks"]="pranks|Broadcast funny network names|Humor injection,Custom wordlists,Timed rotation,Safe pranking"
    ["RickRoll"]="pranks|Classic RickRoll via WiFi|Portal redirect,Audio/video,Never give up,Classic meme"
    ["WiFiConfuser"]="pranks|Create confusing network names|Similar names,Typo squatting,Decoy networks,Confusion creation"
    
    # Utility
    ["RangeExtender"]="utility|WiFi range extension and repeating|Signal boost,Network bridging,Seamless roaming,Coverage extension"
    ["WordlistManager"]="utility|Manage wordlists for cracking|Download lists,Combine files,Custom generation,Storage management"
    ["NullSecConfig"]="utility|Configure NullSec suite settings|Preference management,Default targets,Logging options,Theme settings"
    ["BootOptimizer"]="utility|Optimize Pager boot and performance|Service cleanup,Memory optimization,Storage management,Speed boost"
    ["WiFiAudit"]="utility|Comprehensive WiFi security audit|Security scan,Vulnerability check,Compliance report,Risk assessment"
    
    # Additional Payloads
    ["Banshee"]="attack|Audio disruption payload|Sound injection,Speaker targeting,Annoyance factor,Area denial"
    ["Siren"]="attack|Alert and notification payload|Visual alerts,Audio warnings,Status broadcast,Emergency signal"
    ["Poltergeist"]="attack|Ghost interference patterns|Random disruption,Unpredictable timing,Paranoia inducing,Subtle interference"
    ["Mimic"]="attack|AP impersonation attack|Perfect clone,Dynamic adaptation,Trust exploitation,Seamless takeover"
    ["Reaper"]="utility|Cleanup and evidence removal|Log wiping,Trace removal,State reset,Forensic counter"
)

generate_readme() {
    local name="$1"
    local data="${PAYLOADS[$name]}"
    
    if [ -z "$data" ]; then
        echo "No metadata for: $name"
        return
    fi
    
    IFS='|' read -r category description features <<< "$data"
    
    local readme_file="$DOCS_DIR/${name}_README.md"
    
    # Convert features to array
    IFS=',' read -ra feature_array <<< "$features"
    
    cat > "$readme_file" << EOF
<div align="center">

# 🔥 NullSec Payload: ${name}

**${description}**

![Category](https://img.shields.io/badge/category-${category}-blue)
![Platform](https://img.shields.io/badge/platform-WiFi%20Pineapple%20Pager-red)
![Version](https://img.shields.io/badge/version-1.0-green)

</div>

---

## 📖 Description

${description}. This payload is part of the NullSec Pineapple Suite - the ultimate payload collection for WiFi Pineapple Pager.

## ✨ Features

EOF

    for feature in "${feature_array[@]}"; do
        echo "- ✅ $feature" >> "$readme_file"
    done

    cat >> "$readme_file" << EOF

## 📋 Requirements

- WiFi Pineapple Pager
- Firmware 1.0+
- NullSec library (included in suite)

## 🚀 Installation

### Via NullSec Suite (Recommended)
\`\`\`bash
# Install full suite
git clone https://github.com/bad-antics/nullsec-pineapple-suite.git
cd nullsec-pineapple-suite
./install.sh
\`\`\`

### Standalone Installation
\`\`\`bash
# Download payload
wget https://raw.githubusercontent.com/bad-antics/nullsec-pineapple-suite/main/payloads/${category}/${name}/payload.sh

# Upload to Pager
scp payload.sh root@172.16.42.1:/root/payloads/user/nullsec/${name}/
\`\`\`

## 📱 Usage

### From Pager UI
1. Navigate to **Dashboard** → **Payloads**
2. Go to **User** → **nullsec**
3. Select **${name}**
4. Configure options and run

### From Terminal
\`\`\`bash
ssh root@172.16.42.1
/root/payloads/user/nullsec/${name}/payload.sh [options]
\`\`\`

### As Targeted Payload (Recon)
1. **Recon** → Start scan
2. Select target AP or Client
3. Choose **NullSec-${name}** from payload menu
4. Target info auto-injected!

## ⚙️ Options

| Option | Description | Default |
|--------|-------------|---------|
| \`-h\` | Show help | - |
| \`-t\` | Target BSSID/MAC | Auto (from Recon) |
| \`-c\` | Channel | Auto-detect |
| \`-v\` | Verbose output | Off |

## 📂 Output

Logs and captured data saved to:
\`\`\`
/root/loot/${name,,}/
├── ${name,,}_YYYYMMDD_HHMMSS.log
└── captures/
\`\`\`

## 🔧 Configuration

Edit \`/root/payloads/library/nullsec-lib.sh\` for global settings, or modify the payload script directly for ${name}-specific options.

## ⚠️ Disclaimer

\`\`\`
This payload is provided for EDUCATIONAL and AUTHORIZED PENETRATION TESTING
purposes only. Unauthorized access to computer networks is ILLEGAL.
Always obtain proper authorization before use.
\`\`\`

## 🔗 Related Payloads

EOF

    # Add related payloads from same category
    echo "Other ${category} payloads you might like:" >> "$readme_file"
    echo "" >> "$readme_file"
    for key in "${!PAYLOADS[@]}"; do
        if [[ "${PAYLOADS[$key]}" == "${category}|"* ]] && [ "$key" != "$name" ]; then
            echo "- [${key}](${key}_README.md)" >> "$readme_file"
        fi
    done | head -5 >> "$readme_file"

    cat >> "$readme_file" << EOF

## 📜 License

MIT License - Part of [NullSec Pineapple Suite](https://github.com/bad-antics/nullsec-pineapple-suite)

## 👤 Author

**bad-antics** - [GitHub](https://github.com/bad-antics)

---

<div align="center">

**⭐ Star the [main repo](https://github.com/bad-antics/nullsec-pineapple-suite) if you find this useful! ⭐**

Made with 💀 by NullSec Team

</div>
EOF

    echo "[+] Generated: $readme_file"
}

# Generate all READMEs
echo "=========================================="
echo "   NullSec Payload README Generator"
echo "=========================================="
echo ""

count=0
for payload in "${!PAYLOADS[@]}"; do
    generate_readme "$payload"
    ((count++))
done

echo ""
echo "=========================================="
echo "[+] Generated $count payload READMEs"
echo "[+] Output directory: $DOCS_DIR"
echo "=========================================="
