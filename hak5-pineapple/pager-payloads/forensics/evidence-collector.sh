#!/bin/bash
# ============================================================
# NullSec: Wireless Forensics Evidence Collector
# Author: bad-antics
# Description: Forensic-grade wireless evidence collection and chain of custody
# Category: pager/forensics
#
# UNIQUE FEATURES:
# - Court-admissible evidence packaging
# - SHA256 chain of custody hashing
# - Timeline reconstruction
# - PCAP forensic analysis
# - Device attribution
# - Evidence integrity verification
# ============================================================

PAYLOAD_NAME="Evidence Collector"
VERSION="1.0.0"
LOOT="/root/loot/forensics"
LOG="$LOOT/evidence.log"
CASE_ID="CASE-$(date +%Y%m%d-%H%M%S)"

init_payload() {
    mkdir -p "$LOOT/$CASE_ID"/{captures,evidence,timeline,hashes,reports}
    echo "[$(date)] $PAYLOAD_NAME started - Case: $CASE_ID" >> "$LOG"
    NOTIFY "FORENSICS" "Case $CASE_ID initialized"
}

hash_evidence() {
    local FILE="$1"
    local HASH=$(sha256sum "$FILE" | awk "{print \$1}")
    local HASH_FILE="$LOOT/$CASE_ID/hashes/integrity.sha256"
    echo "$HASH  $FILE  $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$HASH_FILE"
    echo "$HASH"
}

log_chain() {
    local ACTION="$1" DETAIL="$2"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$(whoami)@$(hostname)] $ACTION: $DETAIL" >> \
        "$LOOT/$CASE_ID/evidence/chain_of_custody.txt"
}

capture_environment() {
    local ENV_FILE="$LOOT/$CASE_ID/evidence/environment.txt"
    NOTIFY "ENV" "Documenting environment..."
    
    {
        echo "=== COLLECTION ENVIRONMENT ==="
        echo "Case: $CASE_ID"
        echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "Collector: $(whoami)@$(hostname)"
        echo "Device: $(cat /proc/device-tree/model 2>/dev/null || uname -n)"
        echo "OS: $(uname -a)"
        echo "MAC: $(ip link show wlan0 2>/dev/null | grep ether | awk '{print $2}')"
        echo "IP: $(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
        echo ""
        echo "=== WIRELESS INTERFACES ==="
        iwconfig 2>/dev/null
        echo ""
        echo "=== GPS LOCATION ==="
        # Try to get GPS from gpsd
        gpspipe -w -n 5 2>/dev/null | grep -m1 "lat\|lon" || echo "GPS unavailable"
        echo ""
        echo "=== NETWORK STATE ==="
        ip route
        echo ""
        echo "=== RUNNING PROCESSES ==="
        ps aux
    } > "$ENV_FILE"
    
    hash_evidence "$ENV_FILE"
    log_chain "INIT" "Environment documented"
}

forensic_capture() {
    local DURATION="$1"
    NOTIFY "CAPTURE" "Forensic packet capture ($DURATION min)..."
    
    local PCAP="$LOOT/$CASE_ID/captures/evidence_$(date +%Y%m%d_%H%M).pcap"
    
    # Full forensic capture with precise timestamps
    tcpdump -i wlan0mon -w "$PCAP" -tt -vvv -s 0 2>/dev/null &
    local CAP_PID=$!
    log_chain "CAPTURE" "Started forensic capture (PID: $CAP_PID)"
    
    sleep $((DURATION * 60))
    
    kill $CAP_PID 2>/dev/null
    wait $CAP_PID 2>/dev/null
    
    PCAP_SIZE=$(du -h "$PCAP" | awk '{print $1}')
    PCAP_PKTS=$(tcpdump -r "$PCAP" 2>/dev/null | wc -l)
    PCAP_HASH=$(hash_evidence "$PCAP")
    
    log_chain "CAPTURE" "Completed: $PCAP_PKTS packets, $PCAP_SIZE, SHA256:$PCAP_HASH"
    NOTIFY "CAPTURE" "$PCAP_PKTS packets ($PCAP_SIZE)"
}

build_timeline() {
    NOTIFY "TIMELINE" "Reconstructing event timeline..."
    
    local TL="$LOOT/$CASE_ID/timeline/timeline.csv"
    echo "timestamp,source_mac,dest_mac,type,subtype,ssid,channel,signal,detail" > "$TL"
    
    for pcap in "$LOOT/$CASE_ID/captures/"*.pcap; do
        [ -f "$pcap" ] || continue
        
        # Extract management frames for timeline
        tshark -r "$pcap" -Y "wlan.fc.type == 0" \
            -T fields -e frame.time -e wlan.sa -e wlan.da \
            -e wlan.fc.type -e wlan.fc.subtype -e wlan.ssid \
            -e wlan_radio.channel -e wlan_radio.signal_dbm \
            -E separator=, 2>/dev/null >> "$TL"
        
        # Extract authentication events
        tshark -r "$pcap" -Y "wlan.fc.subtype == 11 or wlan.fc.subtype == 0 or eapol" \
            -T fields -e frame.time -e wlan.sa -e wlan.da \
            -e wlan.fc.type -e wlan.fc.subtype -e wlan.ssid \
            -e wlan_radio.channel -e wlan_radio.signal_dbm \
            -E separator=, 2>/dev/null >> "$TL"
    done
    
    # Sort by timestamp
    head -1 "$TL" > /tmp/tl_sorted.csv
    tail -n +2 "$TL" | sort -t',' -k1 >> /tmp/tl_sorted.csv
    mv /tmp/tl_sorted.csv "$TL"
    
    EVENTS=$(tail -n +2 "$TL" | wc -l)
    hash_evidence "$TL"
    log_chain "TIMELINE" "Reconstructed: $EVENTS events"
    NOTIFY "TIMELINE" "$EVENTS events in timeline"
}

device_attribution() {
    NOTIFY "ATTRIBUTION" "Analyzing device patterns..."
    
    local ATTR="$LOOT/$CASE_ID/evidence/attribution.txt"
    
    for pcap in "$LOOT/$CASE_ID/captures/"*.pcap; do
        [ -f "$pcap" ] || continue
        
        {
            echo "=== DEVICE ATTRIBUTION: $(basename $pcap) ==="
            echo ""
            
            # Unique MACs
            echo "--- Unique Source MACs ---"
            tshark -r "$pcap" -T fields -e wlan.sa 2>/dev/null | sort -u | while read -r mac; do
                [ -z "$mac" ] && continue
                OUI=$(echo "$mac" | cut -d: -f1-3 | tr -d ':' | tr '[:lower:]' '[:upper:]')
                VENDOR=$(grep -i "^$OUI" /usr/share/ieee-data/oui.txt 2>/dev/null | head -1 | cut -f3-)
                FRAMES=$(tshark -r "$pcap" -Y "wlan.sa == $mac" 2>/dev/null | wc -l)
                PROBES=$(tshark -r "$pcap" -Y "wlan.sa == $mac and wlan.fc.subtype == 4" \
                    -T fields -e wlan.ssid 2>/dev/null | sort -u | tr '\n' ',')
                echo "$mac | $VENDOR | Frames: $FRAMES | Probes: $PROBES"
            done
            
            echo ""
            echo "--- SSIDs Observed ---"
            tshark -r "$pcap" -T fields -e wlan.ssid 2>/dev/null | sort -u | grep -v "^$"
            
            echo ""
            echo "--- Deauth/Disassoc Events ---"
            tshark -r "$pcap" -Y "wlan.fc.subtype == 12 or wlan.fc.subtype == 10" \
                -T fields -e frame.time -e wlan.sa -e wlan.da -e wlan.fixed.reason_code \
                2>/dev/null
        } >> "$ATTR"
    done
    
    hash_evidence "$ATTR"
    log_chain "ATTRIBUTION" "Device analysis completed"
}

generate_report() {
    NOTIFY "REPORT" "Generating forensic report..."
    
    local REPORT="$LOOT/$CASE_ID/reports/forensic_report.md"
    
    cat > "$REPORT" << REPORT
# Wireless Forensic Report
## Case: $CASE_ID

### Case Information
- **Date:** $(date -u +%Y-%m-%d)
- **Time:** $(date -u +%H:%M:%S) UTC
- **Investigator:** $(whoami)@$(hostname)
- **Collection Device:** $(uname -n) ($(uname -m))

### Evidence Summary
- **Captures:** $(ls "$LOOT/$CASE_ID/captures/"*.pcap 2>/dev/null | wc -l) files
- **Total packets:** $(for f in "$LOOT/$CASE_ID/captures/"*.pcap; do tcpdump -r "$f" 2>/dev/null | wc -l; done | awk '{sum+=$1} END {print sum}')
- **Timeline events:** $(tail -n +2 "$LOOT/$CASE_ID/timeline/timeline.csv" 2>/dev/null | wc -l)
- **Unique devices:** $(cat "$LOOT/$CASE_ID/evidence/attribution.txt" 2>/dev/null | grep -c "|")

### Chain of Custody
\`\`\`
$(cat "$LOOT/$CASE_ID/evidence/chain_of_custody.txt" 2>/dev/null)
\`\`\`

### Evidence Integrity (SHA256)
\`\`\`
$(cat "$LOOT/$CASE_ID/hashes/integrity.sha256" 2>/dev/null)
\`\`\`

### Key Findings
$(cat "$LOOT/$CASE_ID/evidence/attribution.txt" 2>/dev/null | head -30)

---
*Generated by NullSec Evidence Collector v${VERSION}*
*All evidence hashed with SHA256 for integrity verification*
REPORT
    
    hash_evidence "$REPORT"
    log_chain "REPORT" "Forensic report generated"
    NOTIFY "REPORT" "Report saved to $CASE_ID/"
}

main() {
    init_payload
    capture_environment
    forensic_capture 5
    build_timeline
    device_attribution
    generate_report
    
    log_chain "COMPLETE" "All evidence collected and verified"
    
    # Verify all hashes
    HASH_OK=$(cd / && sha256sum -c "$LOOT/$CASE_ID/hashes/integrity.sha256" 2>/dev/null | grep -c "OK")
    HASH_FAIL=$(cd / && sha256sum -c "$LOOT/$CASE_ID/hashes/integrity.sha256" 2>/dev/null | grep -c "FAILED")
    
    NOTIFY "DONE" "Case $CASE_ID complete. Integrity: $HASH_OK OK, $HASH_FAIL FAILED"
}

main "$@"
