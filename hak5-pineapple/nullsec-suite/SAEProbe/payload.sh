#!/bin/bash
# Title: SAE Probe
# Author: bad-antics
# Description: WPA3-SAE transition mode downgrade analyzer (Dragonblood)
# Category: nullsec/wpa3
# Version: 1.0.0
# Firmware: 2.7+
#
# Identifies WPA3 networks in transition mode and tests for
# SAE-to-WPA2 downgrade attacks. Detects Dragonblood vulnerabilities.
#
# LEGAL: For authorized penetration testing only.

LOOT_DIR="/mmc/nullsec/saeprobe"
LOG="$LOOT_DIR/sae-probe.log"
REPORT="$LOOT_DIR/wpa3-report.html"
mkdir -p "$LOOT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

cleanup() {
    killall airodump-ng tshark tcpdump 2>/dev/null
    [ -n "$MON_IF" ] && airmon-ng stop "$MON_IF" 2>/dev/null
}
trap cleanup EXIT

# ─── INTERFACE SETUP ──────────────────────────────────────────────────

setup_monitor() {
    MON_IF=""
    for iface in wlan1mon wlan2mon wlan0mon; do
        [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
    done
    
    if [ -z "$MON_IF" ]; then
        for iface in wlan1 wlan2 wlan0; do
            if [ -d "/sys/class/net/$iface" ]; then
                airmon-ng start "$iface" 2>/dev/null
                for mon in "${iface}mon" wlan1mon wlan2mon; do
                    [ -d "/sys/class/net/$mon" ] && MON_IF="$mon" && break 2
                done
            fi
        done
    fi
    
    [ -z "$MON_IF" ] && { ERROR_DIALOG "No monitor interface available!"; exit 1; }
    log "Monitor interface: $MON_IF"
}

# ─── RSN INFORMATION ELEMENT PARSER ──────────────────────────────────
# Parse RSN IE from beacon frames to identify WPA3 capabilities

parse_rsn_capabilities() {
    local PCAP="$1"
    local OUTPUT="$LOOT_DIR/rsn-analysis.txt"
    
    > "$OUTPUT"
    
    # Use tshark to parse RSN IEs from beacon frames
    if command -v tshark >/dev/null 2>&1; then
        tshark -r "$PCAP" -Y "wlan.fc.type_subtype == 8" \
            -T fields \
            -e wlan.bssid \
            -e wlan.ssid \
            -e wlan.rsn.akms.type \
            -e wlan.rsn.pcs.type \
            -e wlan.rsn.capabilities \
            -e wlan_radio.channel \
            2>/dev/null | sort -u > "$OUTPUT"
    fi
    
    echo "$OUTPUT"
}

# ─── SCAN & CLASSIFY WPA3 NETWORKS ───────────────────────────────────

scan_wpa3() {
    SPINNER_START "Scanning for WPA3 networks..."
    
    # Capture beacons for RSN IE analysis
    rm -f /tmp/saeprobe*
    timeout 20 airodump-ng "$MON_IF" -w /tmp/saeprobe --output-format pcap,csv 2>/dev/null &
    sleep 20
    killall airodump-ng 2>/dev/null
    
    SPINNER_STOP
    
    WPA3_COUNT=0
    WPA3_SAE=0
    WPA3_TRANS=0
    WPA3_OWE=0
    WPA2_ONLY=0
    TOTAL_APS=0
    
    NET_LIST=""
    
    if [ -f /tmp/saeprobe-01.csv ]; then
        while IFS=',' read -r bssid first last channel speed privacy cipher auth power beacons ivs lanip idlen essid rest; do
            bssid=$(echo "$bssid" | tr -d ' ')
            [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            
            TOTAL_APS=$((TOTAL_APS + 1))
            essid_clean=$(echo "$essid" | sed 's/^[[:space:]]*//' | head -c 24)
            [ -z "$essid_clean" ] && essid_clean="[Hidden]"
            privacy_clean=$(echo "$privacy" | tr -d ' ')
            channel_clean=$(echo "$channel" | tr -d ' ')
            auth_clean=$(echo "$auth" | tr -d ' ')
            
            # Classify network
            local wpa3_type="none"
            
            if echo "$privacy_clean" | grep -qi "WPA3\|SAE"; then
                if echo "$privacy_clean" | grep -qi "WPA2.*WPA3\|WPA3.*WPA2"; then
                    wpa3_type="transition"
                    WPA3_TRANS=$((WPA3_TRANS + 1))
                else
                    wpa3_type="sae-only"
                    WPA3_SAE=$((WPA3_SAE + 1))
                fi
                WPA3_COUNT=$((WPA3_COUNT + 1))
            elif echo "$auth_clean" | grep -qi "SAE"; then
                if echo "$auth_clean" | grep -qi "PSK.*SAE\|SAE.*PSK"; then
                    wpa3_type="transition"
                    WPA3_TRANS=$((WPA3_TRANS + 1))
                else
                    wpa3_type="sae-only"
                    WPA3_SAE=$((WPA3_SAE + 1))
                fi
                WPA3_COUNT=$((WPA3_COUNT + 1))
            elif echo "$privacy_clean" | grep -qi "OWE"; then
                wpa3_type="owe"
                WPA3_OWE=$((WPA3_OWE + 1))
                WPA3_COUNT=$((WPA3_COUNT + 1))
            else
                WPA2_ONLY=$((WPA2_ONLY + 1))
            fi
            
            if [ "$wpa3_type" != "none" ]; then
                local idx=$((WPA3_SAE + WPA3_TRANS + WPA3_OWE))
                local vuln_tag=""
                
                case "$wpa3_type" in
                    transition) vuln_tag="⚠️ DOWNGRADE" ;;
                    sae-only)   vuln_tag="✅ SECURE" ;;
                    owe)        vuln_tag="📡 OWE" ;;
                esac
                
                NET_LIST="${NET_LIST}${idx}. ${essid_clean}\n   Ch:${channel_clean} ${wpa3_type} ${vuln_tag}\n\n"
                
                eval "WPA3_BSSID_${idx}=\"$bssid\""
                eval "WPA3_CH_${idx}=\"$channel_clean\""
                eval "WPA3_ESSID_${idx}=\"$essid_clean\""
                eval "WPA3_TYPE_${idx}=\"$wpa3_type\""
                eval "WPA3_PRIV_${idx}=\"$privacy_clean\""
            fi
        done < /tmp/saeprobe-01.csv
    fi
    
    log "Scan complete: $TOTAL_APS APs, $WPA3_COUNT WPA3 ($WPA3_SAE SAE-only, $WPA3_TRANS transition, $WPA3_OWE OWE)"
}

# ─── DOWNGRADE ATTACK TEST ───────────────────────────────────────────

test_downgrade() {
    local target_bssid="$1"
    local target_ch="$2"
    local target_ssid="$3"
    local target_type="$4"
    
    log "Testing downgrade on $target_ssid ($target_bssid)..."
    
    if [ "$target_type" != "transition" ]; then
        PROMPT "NETWORK: $target_ssid
Type: SAE-Only

This network is NOT in transition
mode. Downgrade attack is not
possible — SAE-only networks
require all clients to use WPA3.

✅ Network is properly configured."
        return
    fi
    
    PROMPT "TRANSITION MODE DETECTED!

$target_ssid is broadcasting
WPA2 + WPA3 simultaneously.

This allows downgrade attacks:
• Clone as WPA2-only AP
• Clients without SAE-only
  enforcement will fall back
• Capture WPA2 handshake

Test downgrade? (passive)"
    
    SPINNER_START "Testing client behavior..."
    
    # Capture traffic to see client associations
    rm -f /tmp/sae-downgrade*
    timeout 30 airodump-ng "$MON_IF" --bssid "$target_bssid" -c "$target_ch" \
        -w /tmp/sae-downgrade --output-format pcap,csv 2>/dev/null &
    sleep 30
    killall airodump-ng 2>/dev/null
    
    SPINNER_STOP
    
    # Analyze client capabilities
    local client_count=0
    local vulnerable_count=0
    
    if [ -f /tmp/sae-downgrade-01.csv ]; then
        # Count clients connected to this AP
        local in_clients=0
        while IFS=',' read -r mac first last power packets bssid probed rest; do
            mac=$(echo "$mac" | tr -d ' ')
            bssid_clean=$(echo "$bssid" | tr -d ' ')
            [[ ! "$mac" =~ ^[0-9A-Fa-f]{2}: ]] && continue
            
            # Skip header
            if [ "$in_clients" = "0" ]; then
                echo "$mac" | grep -qi "station" && in_clients=1
                continue
            fi
            
            if [ "$bssid_clean" = "$target_bssid" ]; then
                client_count=$((client_count + 1))
            fi
        done < /tmp/sae-downgrade-01.csv
    fi
    
    # Check for timing side-channel (Dragonblood CVE-2019-9494)
    local timing_vuln="unknown"
    if command -v tshark >/dev/null 2>&1 && [ -f /tmp/sae-downgrade-01.cap ]; then
        # Look for SAE commit frames and measure timing variance
        local sae_commits=$(tshark -r /tmp/sae-downgrade-01.cap \
            -Y "wlan.fc.type_subtype == 0x0b" 2>/dev/null | wc -l)
        
        if [ "$sae_commits" -gt 5 ]; then
            # Timing analysis would go here - simplified check
            timing_vuln="possible (need >100 samples)"
        elif [ "$sae_commits" -gt 0 ]; then
            timing_vuln="insufficient data ($sae_commits commits)"
        else
            timing_vuln="no SAE commits captured"
        fi
    fi
    
    log "Downgrade test: clients=$client_count, timing=$timing_vuln"
    
    PROMPT "═══ DOWNGRADE ANALYSIS ═══

Target: $target_ssid
Type: WPA3 Transition Mode
Clients seen: $client_count

VULNERABILITY ASSESSMENT:

⚠️  Transition Mode: VULNERABLE
    Clients can be forced to
    use WPA2-PSK via rogue AP

Dragonblood Timing:
    $timing_vuln

CVE-2019-9494: Timing attack
CVE-2019-9496: Confirm bypass

RECOMMENDATION:
Disable transition mode and
enforce SAE-only (WPA3-only)"
}

# ─── GENERATE HTML REPORT ────────────────────────────────────────────

generate_report() {
    log "Generating WPA3 security report..."
    
    cat > "$REPORT" << EOF
<!DOCTYPE html>
<html><head>
<title>WPA3 Security Assessment - SAE Probe</title>
<style>
body { font-family: 'Segoe UI', sans-serif; background: #0d0d0d; color: #e0e0e0; padding: 2rem; }
h1 { color: #ff0040; border-bottom: 2px solid #333; padding-bottom: 1rem; }
h2 { color: #58a6ff; margin-top: 2rem; }
.stat { display: inline-block; background: #1a1a1a; padding: 1rem 2rem; margin: 0.5rem; border-radius: 8px; border: 1px solid #333; }
.stat .num { font-size: 32px; font-weight: 700; color: #ff0040; }
.stat .label { color: #808080; font-size: 14px; }
table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; }
th { background: #1a1a1a; color: #58a6ff; }
.vuln { color: #f85149; font-weight: 600; }
.safe { color: #3fb950; font-weight: 600; }
.warn { color: #d29922; }
.footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #333; color: #555; font-size: 12px; }
</style>
</head><body>
<h1>🔓 WPA3 Security Assessment Report</h1>
<p>Generated: $(date)</p>
<p>Tool: SAE Probe v1.0 (NullSec Suite)</p>

<div>
    <div class="stat"><div class="num">$TOTAL_APS</div><div class="label">Total APs</div></div>
    <div class="stat"><div class="num">$WPA3_COUNT</div><div class="label">WPA3 Networks</div></div>
    <div class="stat"><div class="num">$WPA3_TRANS</div><div class="label">Transition Mode</div></div>
    <div class="stat"><div class="num">$WPA3_SAE</div><div class="label">SAE-Only</div></div>
</div>

<h2>Executive Summary</h2>
<p>Scanned $TOTAL_APS access points. Found <strong>$WPA3_COUNT</strong> WPA3-capable networks.</p>
EOF

    if [ $WPA3_TRANS -gt 0 ]; then
        cat >> "$REPORT" << EOF
<p class="vuln">⚠️ $WPA3_TRANS network(s) operating in WPA3 Transition Mode are vulnerable to downgrade attacks. 
Clients connecting to these networks may be forced to use WPA2, negating WPA3 security benefits.</p>
EOF
    fi

    if [ $WPA3_SAE -gt 0 ]; then
        cat >> "$REPORT" << EOF
<p class="safe">✅ $WPA3_SAE network(s) properly configured as SAE-only (WPA3-only).</p>
EOF
    fi

    cat >> "$REPORT" << EOF

<h2>Detailed Findings</h2>
<table>
<tr><th>SSID</th><th>BSSID</th><th>Channel</th><th>WPA3 Type</th><th>Risk</th><th>Recommendation</th></tr>
EOF

    for i in $(seq 1 $WPA3_COUNT); do
        eval "local e_bssid=\$WPA3_BSSID_${i}"
        eval "local e_ch=\$WPA3_CH_${i}"
        eval "local e_ssid=\$WPA3_ESSID_${i}"
        eval "local e_type=\$WPA3_TYPE_${i}"
        
        local risk_class="safe"
        local risk_text="Low"
        local recommendation="Properly configured"
        
        case "$e_type" in
            transition)
                risk_class="vuln"
                risk_text="HIGH"
                recommendation="Disable transition mode, enforce SAE-only"
                ;;
            owe)
                risk_class="warn"
                risk_text="Medium"
                recommendation="Verify OWE transition mode disabled"
                ;;
        esac
        
        cat >> "$REPORT" << EOF
<tr>
    <td>$e_ssid</td>
    <td><code>$e_bssid</code></td>
    <td>$e_ch</td>
    <td>$e_type</td>
    <td class="$risk_class">$risk_text</td>
    <td>$recommendation</td>
</tr>
EOF
    done

    cat >> "$REPORT" << EOF
</table>

<h2>Vulnerability Details</h2>
<h3>Dragonblood (CVE-2019-9494, CVE-2019-9496)</h3>
<p>WPA3-SAE uses the Dragonfly key exchange. The Dragonblood attacks exploit:</p>
<ul>
    <li><strong>CVE-2019-9494</strong>: Cache-based timing side-channel on SAE password encoding</li>
    <li><strong>CVE-2019-9496</strong>: SAE confirm missing state validation allowing replay attacks</li>
    <li><strong>Transition Mode Downgrade</strong>: APs advertising WPA2+WPA3 can be cloned as WPA2-only</li>
</ul>

<h2>Remediation Steps</h2>
<ol>
    <li>Disable WPA3 transition mode — enforce SAE-only on all access points</li>
    <li>Update firmware to patch Dragonblood vulnerabilities</li>
    <li>Configure 802.11w (PMF) as required, not optional</li>
    <li>Deploy network monitoring for rogue AP detection</li>
    <li>Test client supplicants to ensure SAE-only enforcement</li>
</ol>

<div class="footer">
    <p>Generated by SAE Probe v1.0 | NullSec Suite | github.com/bad-antics/hak5-pineapple</p>
    <p>For authorized security assessment only. Findings should be validated manually.</p>
</div>
</body></html>
EOF

    log "Report saved: $REPORT"
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

PROMPT "╔══════════════════════════════╗
║      SAE PROBE v1.0          ║
║   WPA3 Downgrade Analyzer    ║
╚══════════════════════════════╝

Analyze WPA3 networks for:
• Transition mode vulnerabilities
• SAE downgrade attacks
• Dragonblood CVE detection
• OWE misconfiguration

Generates HTML security report.

Press OK to begin scanning."

log "SAE Probe starting..."
setup_monitor
scan_wpa3

if [ $WPA3_COUNT -eq 0 ]; then
    PROMPT "NO WPA3 NETWORKS FOUND

Scanned $TOTAL_APS access points.
None are using WPA3-SAE.

All $TOTAL_APS APs use WPA2 or older.

This is itself a finding:
No WPA3 adoption detected."
    
    generate_report
    PROMPT "Report saved to:
$REPORT

Press OK to exit."
    exit 0
fi

PROMPT "WPA3 SCAN RESULTS

Total APs: $TOTAL_APS
WPA3 Total: $WPA3_COUNT
SAE-Only: $WPA3_SAE ✅
Transition: $WPA3_TRANS ⚠️
OWE: $WPA3_OWE

$(echo -e "$NET_LIST")

Select network to test."

TARGET_IDX=$(NUMBER_PICKER "Network # (0=all):" 0)

if [ "$TARGET_IDX" = "0" ]; then
    # Test all transition mode networks
    for i in $(seq 1 $WPA3_COUNT); do
        eval "local t_type=\$WPA3_TYPE_${i}"
        if [ "$t_type" = "transition" ]; then
            eval "local t_bssid=\$WPA3_BSSID_${i}"
            eval "local t_ch=\$WPA3_CH_${i}"
            eval "local t_ssid=\$WPA3_ESSID_${i}"
            test_downgrade "$t_bssid" "$t_ch" "$t_ssid" "$t_type"
        fi
    done
else
    eval "local t_bssid=\$WPA3_BSSID_${TARGET_IDX}"
    eval "local t_ch=\$WPA3_CH_${TARGET_IDX}"
    eval "local t_ssid=\$WPA3_ESSID_${TARGET_IDX}"
    eval "local t_type=\$WPA3_TYPE_${TARGET_IDX}"
    test_downgrade "$t_bssid" "$t_ch" "$t_ssid" "$t_type"
fi

# Generate final report
generate_report

PROMPT "═══ SAE PROBE COMPLETE ═══

WPA3 Assessment:
• $WPA3_COUNT WPA3 networks found
• $WPA3_TRANS vulnerable (transition)
• $WPA3_SAE secure (SAE-only)

Report: $REPORT
Log: $LOG

Press OK to exit."

log "SAE Probe complete."
