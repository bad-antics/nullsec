#!/bin/bash
# Title: SegmentShark
# Author: bad-antics (NullSec)
# Description: Network segmentation & VLAN boundary validator
# Category: nullsec/compliance
# Version: 1.0.0
# Firmware: 2.7+
#
# Validates network segmentation between wireless SSIDs/VLANs.
# Tests cross-segment reachability, DNS leaks, and shared services.
# Generates compliance-ready segmentation matrix.
#
# LEGAL: For authorized penetration testing only.

LOOT_DIR="/root/loot/segmentshark"
LOG="$LOOT_DIR/segmentshark.log"
REPORT="$LOOT_DIR/segmentation-report.html"
mkdir -p "$LOOT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

# Segment data
MAX_SEGMENTS=5
SEG_COUNT=0

# Cross-segment test matrix
declare -a MATRIX_RESULTS

cleanup() {
    killall wpa_supplicant dhclient 2>/dev/null
}
trap cleanup EXIT

# ─── SEGMENT CONFIGURATION ───────────────────────────────────────────

add_segment() {
    SEG_COUNT=$((SEG_COUNT + 1))
    eval "SEG_SSID_${SEG_COUNT}=\"$1\""
    eval "SEG_PASS_${SEG_COUNT}=\"$2\""
    eval "SEG_NAME_${SEG_COUNT}=\"$3\""  # Friendly name like "Corporate", "Guest"
    eval "SEG_IP_${SEG_COUNT}=\"\""
    eval "SEG_GW_${SEG_COUNT}=\"\""
    eval "SEG_SUBNET_${SEG_COUNT}=\"\""
    eval "SEG_DNS_${SEG_COUNT}=\"\""
}

# ─── CONNECT & ENUMERATE SEGMENT ─────────────────────────────────────

enumerate_segment() {
    local seg_num="$1"
    local iface="${2:-wlan0}"
    
    eval "local ssid=\$SEG_SSID_${seg_num}"
    eval "local pass=\$SEG_PASS_${seg_num}"
    eval "local name=\$SEG_NAME_${seg_num}"
    
    log "Connecting to segment $name ($ssid)..."
    
    # Disconnect first
    killall wpa_supplicant 2>/dev/null
    killall dhclient 2>/dev/null
    ip addr flush dev "$iface" 2>/dev/null
    sleep 1
    
    # Connect
    if [ -n "$pass" ]; then
        wpa_passphrase "$ssid" "$pass" > /tmp/seg-wpa.conf 2>/dev/null
    else
        cat > /tmp/seg-wpa.conf << EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
    fi
    
    wpa_supplicant -B -i "$iface" -c /tmp/seg-wpa.conf 2>/dev/null
    sleep 3
    dhclient -v "$iface" 2>/dev/null &
    sleep 5
    
    # Enumerate network properties
    local ip=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    local subnet=$(ip route show dev "$iface" 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1)
    local gateway=$(ip route show dev "$iface" 2>/dev/null | grep default | awk '{print $3}')
    local dns=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -1 | awk '{print $2}')
    
    [ -z "$ip" ] && { log "Failed to get IP on $ssid"; return 1; }
    
    eval "SEG_IP_${seg_num}=\"$ip\""
    eval "SEG_GW_${seg_num}=\"$gateway\""
    eval "SEG_SUBNET_${seg_num}=\"$subnet\""
    eval "SEG_DNS_${seg_num}=\"$dns\""
    
    log "Segment $name: IP=$ip GW=$gateway Subnet=$subnet DNS=$dns"
    
    # Discover hosts on this segment
    local host_count=0
    local hosts=""
    
    if command -v nmap >/dev/null 2>&1; then
        hosts=$(nmap -sn "$subnet" -T4 2>/dev/null | grep "Nmap scan report" | awk '{print $5}')
        host_count=$(echo "$hosts" | grep -c "\." 2>/dev/null || echo 0)
    else
        # ARP scan fallback
        for i in $(seq 1 20); do
            local target="${ip%.*}.$i"
            ping -c 1 -W 1 "$target" 2>/dev/null | grep -q "bytes from" && {
                host_count=$((host_count + 1))
                hosts="$hosts $target"
            }
        done
    fi
    
    eval "SEG_HOSTS_${seg_num}=\"$hosts\""
    eval "SEG_HOSTCOUNT_${seg_num}=\"$host_count\""
    
    log "Segment $name: $host_count hosts discovered"
    return 0
}

# ─── CROSS-SEGMENT TESTS ─────────────────────────────────────────────

test_cross_segment() {
    local from_seg="$1"
    local to_seg="$2"
    local iface="${3:-wlan0}"
    
    eval "local from_name=\$SEG_NAME_${from_seg}"
    eval "local to_name=\$SEG_NAME_${to_seg}"
    eval "local to_gw=\$SEG_GW_${to_seg}"
    eval "local to_subnet=\$SEG_SUBNET_${to_seg}"
    eval "local to_hosts=\$SEG_HOSTS_${to_seg}"
    eval "local to_dns=\$SEG_DNS_${to_seg}"
    
    log "Testing: $from_name → $to_name"
    
    local idx="${from_seg}_${to_seg}"
    local reachable=0
    local tests_run=0
    local tests_pass=0
    local details=""
    
    # Test 1: Can we reach the other segment's gateway?
    tests_run=$((tests_run + 1))
    if [ -n "$to_gw" ]; then
        if ping -c 2 -W 2 "$to_gw" 2>/dev/null | grep -q "bytes from"; then
            reachable=$((reachable + 1))
            details="${details}Gateway ($to_gw): REACHABLE\n"
        else
            tests_pass=$((tests_pass + 1))
            details="${details}Gateway ($to_gw): BLOCKED\n"
        fi
    fi
    
    # Test 2: Can we reach hosts on the other segment?
    for host in $to_hosts; do
        tests_run=$((tests_run + 1))
        if ping -c 1 -W 2 "$host" 2>/dev/null | grep -q "bytes from"; then
            reachable=$((reachable + 1))
            details="${details}Host ($host): REACHABLE\n"
        else
            tests_pass=$((tests_pass + 1))
            details="${details}Host ($host): BLOCKED\n"
        fi
        
        # Test common ports
        for port in 80 443 445 22 3389; do
            tests_run=$((tests_run + 1))
            if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
                reachable=$((reachable + 1))
                details="${details}  Port $port: OPEN\n"
            else
                tests_pass=$((tests_pass + 1))
            fi
        done
    done
    
    # Test 3: DNS cross-segment resolution
    tests_run=$((tests_run + 1))
    if [ -n "$to_dns" ]; then
        local dns_test=$(dig @"$to_dns" +short google.com 2>/dev/null)
        if [ -n "$dns_test" ]; then
            reachable=$((reachable + 1))
            details="${details}DNS ($to_dns): ACCESSIBLE\n"
        else
            tests_pass=$((tests_pass + 1))
            details="${details}DNS ($to_dns): BLOCKED\n"
        fi
    fi
    
    # Store results
    local result="ISOLATED"
    [ $reachable -gt 0 ] && result="BREACHED"
    [ $reachable -gt 0 ] && [ $tests_pass -gt $reachable ] && result="PARTIAL"
    
    eval "MATRIX_${idx}_RESULT=\"$result\""
    eval "MATRIX_${idx}_REACHABLE=\"$reachable\""
    eval "MATRIX_${idx}_TOTAL=\"$tests_run\""
    eval "MATRIX_${idx}_DETAILS=\"$details\""
    
    log "$from_name → $to_name: $result ($reachable/$tests_run reachable)"
}

# ─── GENERATE HTML REPORT ────────────────────────────────────────────

generate_report() {
    cat > "$REPORT" << EOF
<!DOCTYPE html>
<html><head>
<title>Network Segmentation Report - SegmentShark</title>
<style>
body { font-family: 'Segoe UI', sans-serif; background: #0d0d0d; color: #e0e0e0; padding: 2rem; max-width: 1100px; margin: 0 auto; }
h1 { color: #ff0040; }
h2 { color: #58a6ff; margin-top: 2rem; }
.matrix { border-collapse: collapse; margin: 2rem 0; width: 100%; }
.matrix th, .matrix td { padding: 12px; border: 1px solid #333; text-align: center; }
.matrix th { background: #1a1a1a; color: #58a6ff; }
.isolated { background: #0f2e0f; color: #3fb950; font-weight: 600; }
.breached { background: #2e0f0f; color: #f85149; font-weight: 600; }
.partial { background: #2e250f; color: #d29922; font-weight: 600; }
.self { background: #1a1a1a; color: #555; }
.segment-info { background: #111; border: 1px solid #333; border-radius: 8px; padding: 1rem; margin: 0.5rem 0; }
.segment-info h3 { color: #ff0040; margin-bottom: 0.5rem; }
.footer { margin-top: 3rem; color: #555; font-size: 12px; border-top: 1px solid #333; padding-top: 1rem; }
code { background: #1a1a1a; padding: 2px 6px; border-radius: 3px; color: #3fb950; }
</style>
</head><body>
<h1>🦈 Network Segmentation Validation Report</h1>
<p>Generated: $(date) | Tool: SegmentShark v1.0</p>

<h2>Segment Inventory</h2>
EOF

    for i in $(seq 1 $SEG_COUNT); do
        eval "local name=\$SEG_NAME_${i}"
        eval "local ssid=\$SEG_SSID_${i}"
        eval "local ip=\$SEG_IP_${i}"
        eval "local gw=\$SEG_GW_${i}"
        eval "local subnet=\$SEG_SUBNET_${i}"
        eval "local dns=\$SEG_DNS_${i}"
        eval "local hostcount=\$SEG_HOSTCOUNT_${i}"
        
        cat >> "$REPORT" << EOF
<div class="segment-info">
    <h3>$name</h3>
    <p>SSID: <code>$ssid</code> | IP: <code>$ip</code> | Gateway: <code>$gw</code> | Subnet: <code>$subnet</code> | DNS: <code>$dns</code> | Hosts: $hostcount</p>
</div>
EOF
    done

    # Segmentation Matrix
    cat >> "$REPORT" << EOF
<h2>Segmentation Matrix</h2>
<p>Shows whether traffic can cross between segments. <span class="isolated">ISOLATED</span> = properly segmented, <span class="breached">BREACHED</span> = isolation failure.</p>
<table class="matrix">
<tr><th>From ↓ / To →</th>
EOF

    for j in $(seq 1 $SEG_COUNT); do
        eval "local name=\$SEG_NAME_${j}"
        echo "<th>$name</th>" >> "$REPORT"
    done
    echo "</tr>" >> "$REPORT"

    for i in $(seq 1 $SEG_COUNT); do
        eval "local from_name=\$SEG_NAME_${i}"
        echo "<tr><th>$from_name</th>" >> "$REPORT"
        
        for j in $(seq 1 $SEG_COUNT); do
            if [ "$i" = "$j" ]; then
                echo "<td class=\"self\">—</td>" >> "$REPORT"
            else
                local idx="${i}_${j}"
                eval "local result=\$MATRIX_${idx}_RESULT"
                eval "local reach=\$MATRIX_${idx}_REACHABLE"
                eval "local total=\$MATRIX_${idx}_TOTAL"
                
                local css_class="isolated"
                [ "$result" = "BREACHED" ] && css_class="breached"
                [ "$result" = "PARTIAL" ] && css_class="partial"
                
                echo "<td class=\"$css_class\">$result<br><small>$reach/$total</small></td>" >> "$REPORT"
            fi
        done
        echo "</tr>" >> "$REPORT"
    done

    cat >> "$REPORT" << 'EOF'
</table>

<h2>Compliance Assessment</h2>
<table style="width:100%; border-collapse: collapse;">
<tr style="background:#1a1a1a"><th style="padding:10px; border:1px solid #333">Framework</th><th style="padding:10px; border:1px solid #333">Requirement</th><th style="padding:10px; border:1px solid #333">Status</th></tr>
<tr><td style="padding:10px; border:1px solid #333">PCI-DSS 4.0</td><td style="padding:10px; border:1px solid #333">Req 1.4 — Network segmentation between CDE and non-CDE</td><td style="padding:10px; border:1px solid #333">See matrix</td></tr>
<tr><td style="padding:10px; border:1px solid #333">HIPAA</td><td style="padding:10px; border:1px solid #333">§164.312(e)(1) — Transmission security controls</td><td style="padding:10px; border:1px solid #333">See matrix</td></tr>
<tr><td style="padding:10px; border:1px solid #333">NIST 800-153</td><td style="padding:10px; border:1px solid #333">Wireless network segmentation and isolation</td><td style="padding:10px; border:1px solid #333">See matrix</td></tr>
<tr><td style="padding:10px; border:1px solid #333">SOC 2</td><td style="padding:10px; border:1px solid #333">CC6.1 — Logical access controls</td><td style="padding:10px; border:1px solid #333">See matrix</td></tr>
</table>

<div class="footer">
    <p>Generated by SegmentShark v1.0 | NullSec Suite | github.com/bad-antics/hak5-pineapple</p>
</div>
</body></html>
EOF

    log "Report saved: $REPORT"
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

PROMPT "╔══════════════════════════════╗
║    SEGMENTSHARK v1.0         ║
║   VLAN Boundary Validator    ║
╚══════════════════════════════╝

Validates network segmentation
between wireless SSIDs/VLANs.

Tests cross-segment:
• Gateway reachability
• Host accessibility
• Port access (TCP)
• DNS resolution
• Service discovery

Generates compliance matrix.

Press OK to configure segments."

# Configure segments (up to 5)
PROMPT "SEGMENT CONFIGURATION

Enter the WiFi networks to test
segmentation between.

You'll enter SSIDs and passwords
for each segment (up to 5).

Common segments:
• Corporate WiFi
• Guest WiFi
• IoT network
• BYOD network
• Management network"

for seg in 1 2 3 4 5; do
    PROMPT "SEGMENT $seg of 5

Enter SSID (blank to stop)."
    
    local ssid=$(TEXT_INPUT "SSID:" "")
    [ -z "$ssid" ] && break
    
    local pass=$(TEXT_INPUT "Password (blank=open):" "")
    local name=$(TEXT_INPUT "Name (e.g. Corporate):" "Segment-$seg")
    [ -z "$name" ] && name="Segment-$seg"
    
    add_segment "$ssid" "$pass" "$name"
done

if [ $SEG_COUNT -lt 2 ]; then
    ERROR_DIALOG "Need at least 2 segments to test segmentation!"
    exit 1
fi

PROMPT "CONFIGURED $SEG_COUNT SEGMENTS

$(for i in $(seq 1 $SEG_COUNT); do
    eval "echo \"$i. \$SEG_NAME_${i} (\$SEG_SSID_${i})\""
done)

Will test cross-segment access
between all pairs.

Press OK to begin."

IFACE="wlan0"
for iface in wlan0 wlan1; do
    [ -d "/sys/class/net/$iface" ] && IFACE="$iface" && break
done

# Phase 1: Enumerate each segment
log "Phase 1: Enumerating segments..."

for i in $(seq 1 $SEG_COUNT); do
    eval "local name=\$SEG_NAME_${i}"
    SPINNER_START "Enumerating $name..."
    enumerate_segment "$i" "$IFACE"
    SPINNER_STOP
done

PROMPT "ENUMERATION COMPLETE

$(for i in $(seq 1 $SEG_COUNT); do
    eval "echo \"\$SEG_NAME_${i}: \$SEG_IP_${i} (\$SEG_HOSTCOUNT_${i} hosts)\""
done)

Phase 2: Cross-segment testing
Testing all ${SEG_COUNT}x${SEG_COUNT} pairs...

Press OK to continue."

# Phase 2: Test cross-segment access
log "Phase 2: Cross-segment testing..."

TOTAL_BREACHES=0
for i in $(seq 1 $SEG_COUNT); do
    eval "local from_name=\$SEG_NAME_${i}"
    
    # Connect to segment i
    SPINNER_START "Testing from $from_name..."
    enumerate_segment "$i" "$IFACE"
    
    # Test access to all other segments
    for j in $(seq 1 $SEG_COUNT); do
        [ "$i" = "$j" ] && continue
        eval "local to_name=\$SEG_NAME_${j}"
        
        test_cross_segment "$i" "$j" "$IFACE"
        
        local idx="${i}_${j}"
        eval "local result=\$MATRIX_${idx}_RESULT"
        [ "$result" = "BREACHED" ] && TOTAL_BREACHES=$((TOTAL_BREACHES + 1))
    done
    SPINNER_STOP
done

# Generate report
generate_report

# Summary
VERDICT="PASS"
[ $TOTAL_BREACHES -gt 0 ] && VERDICT="FAIL"

PROMPT "═══ SEGMENTSHARK RESULTS ═══

Segments tested: $SEG_COUNT
Segment pairs: $((SEG_COUNT * (SEG_COUNT - 1)))
Breaches found: $TOTAL_BREACHES

Verdict: $VERDICT

Report: $REPORT

Press OK to exit."

log "SegmentShark complete. Breaches: $TOTAL_BREACHES"
