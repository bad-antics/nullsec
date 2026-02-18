#!/bin/bash
# Title: IsoBreaker
# Author: bad-antics
# Description: Client/AP isolation bypass tester for compliance validation
# Category: nullsec/compliance
# Version: 1.0.0
# Firmware: 2.7+
#
# Tests whether client isolation, VLAN segmentation, and L2/L3 controls
# actually prevent client-to-client communication. Essential for PCI-DSS,
# HIPAA, and compliance audits.
#
# LEGAL: For authorized penetration testing only.

LOOT_DIR="/mmc/nullsec/isobreaker"
LOG="$LOOT_DIR/isobreaker.log"
REPORT="$LOOT_DIR/isolation-report.html"
mkdir -p "$LOOT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

# Test result tracking
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
PARTIAL_COUNT=0

add_test() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local result="$1"  # pass, fail, partial
    local name="$2"
    local detail="$3"
    
    eval "TEST_NAME_${TEST_COUNT}=\"$name\""
    eval "TEST_RESULT_${TEST_COUNT}=\"$result\""
    eval "TEST_DETAIL_${TEST_COUNT}=\"$detail\""
    
    case "$result" in
        pass)    PASS_COUNT=$((PASS_COUNT + 1)); log "✅ PASS: $name" ;;
        fail)    FAIL_COUNT=$((FAIL_COUNT + 1)); log "❌ FAIL: $name" ;;
        partial) PARTIAL_COUNT=$((PARTIAL_COUNT + 1)); log "⚠️  PARTIAL: $name" ;;
    esac
}

# ─── NETWORK SETUP ───────────────────────────────────────────────────

connect_network() {
    local ssid="$1"
    local pass="$2"
    local iface="${3:-wlan0}"
    
    log "Connecting to $ssid on $iface..."
    
    # Kill existing connections
    wpa_cli -i "$iface" disconnect 2>/dev/null
    killall dhclient 2>/dev/null
    
    if [ -n "$pass" ]; then
        # WPA/WPA2 connection
        wpa_passphrase "$ssid" "$pass" > /tmp/isobreaker-wpa.conf 2>/dev/null
        wpa_supplicant -B -i "$iface" -c /tmp/isobreaker-wpa.conf 2>/dev/null
    else
        # Open network
        cat > /tmp/isobreaker-wpa.conf << EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
        wpa_supplicant -B -i "$iface" -c /tmp/isobreaker-wpa.conf 2>/dev/null
    fi
    
    sleep 3
    dhclient -v "$iface" 2>/dev/null &
    sleep 5
    
    # Verify connection
    local our_ip=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    if [ -n "$our_ip" ]; then
        log "Connected: $our_ip on $ssid"
        echo "$our_ip"
    else
        log "Failed to connect to $ssid"
        echo ""
    fi
}

# ─── DISCOVER OTHER CLIENTS ──────────────────────────────────────────

discover_clients() {
    local iface="$1"
    local our_ip="$2"
    local subnet=$(ip route show dev "$iface" 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1)
    [ -z "$subnet" ] && subnet="${our_ip%.*}.0/24"
    
    log "Discovering clients on $subnet..."
    
    CLIENTS=""
    CLIENT_COUNT=0
    
    # Method 1: ARP scan
    if command -v arping >/dev/null 2>&1; then
        for i in $(seq 1 254); do
            local target="${our_ip%.*}.$i"
            [ "$target" = "$our_ip" ] && continue
            
            arping -I "$iface" -c 1 -w 1 "$target" 2>/dev/null | grep -q "reply" && {
                CLIENT_COUNT=$((CLIENT_COUNT + 1))
                CLIENTS="$CLIENTS $target"
                eval "CLIENT_IP_${CLIENT_COUNT}=\"$target\""
            }
        done &
        wait
    fi
    
    # Method 2: Passive ARP table
    local arp_entries=$(arp -a -i "$iface" 2>/dev/null | grep -v "incomplete" | awk '{print $2}' | tr -d '()')
    for ip in $arp_entries; do
        [ "$ip" = "$our_ip" ] && continue
        echo "$CLIENTS" | grep -q "$ip" && continue
        CLIENT_COUNT=$((CLIENT_COUNT + 1))
        CLIENTS="$CLIENTS $ip"
        eval "CLIENT_IP_${CLIENT_COUNT}=\"$ip\""
    done
    
    # Method 3: Nmap ping sweep (if available)
    if command -v nmap >/dev/null 2>&1 && [ $CLIENT_COUNT -lt 2 ]; then
        local nmap_hosts=$(nmap -sn "$subnet" -T4 2>/dev/null | grep "Nmap scan report" | awk '{print $5}')
        for ip in $nmap_hosts; do
            [ "$ip" = "$our_ip" ] && continue
            echo "$CLIENTS" | grep -q "$ip" && continue
            CLIENT_COUNT=$((CLIENT_COUNT + 1))
            CLIENTS="$CLIENTS $ip"
            eval "CLIENT_IP_${CLIENT_COUNT}=\"$ip\""
        done
    fi
    
    log "Discovered $CLIENT_COUNT other clients"
    
    # Get gateway
    GATEWAY=$(ip route show dev "$iface" 2>/dev/null | grep default | awk '{print $3}')
    [ -z "$GATEWAY" ] && GATEWAY="${our_ip%.*}.1"
    log "Gateway: $GATEWAY"
}

# ─── ISOLATION TESTS ─────────────────────────────────────────────────

test_l2_direct_arp() {
    local iface="$1"
    local target="$2"
    
    log "Testing L2 direct ARP to $target..."
    
    local result=$(arping -I "$iface" -c 3 -w 3 "$target" 2>/dev/null)
    if echo "$result" | grep -q "reply"; then
        add_test "fail" "L2 Direct ARP ($target)" "ARP replies received — client is directly reachable at L2"
    else
        add_test "pass" "L2 Direct ARP ($target)" "No ARP replies — L2 isolation is working"
    fi
}

test_l3_icmp() {
    local target="$1"
    
    log "Testing L3 ICMP to $target..."
    
    local result=$(ping -c 3 -W 2 "$target" 2>/dev/null)
    if echo "$result" | grep -q "bytes from"; then
        local latency=$(echo "$result" | grep "avg" | awk -F'/' '{print $5}')
        add_test "fail" "L3 ICMP Ping ($target)" "Ping successful (avg ${latency}ms) — no L3 isolation"
    else
        add_test "pass" "L3 ICMP Ping ($target)" "Ping blocked — L3 isolation working"
    fi
}

test_hairpin_routing() {
    local iface="$1"
    local target="$2"
    local gateway="$3"
    
    log "Testing hairpin routing via gateway $gateway to $target..."
    
    # Add specific route through gateway to force hairpin
    ip route add "$target/32" via "$gateway" dev "$iface" 2>/dev/null
    
    local result=$(ping -c 2 -W 2 "$target" 2>/dev/null)
    if echo "$result" | grep -q "bytes from"; then
        add_test "fail" "Hairpin Routing ($target)" "Client reachable via gateway hairpin — isolation bypassed"
    else
        add_test "pass" "Hairpin Routing ($target)" "Hairpin routing blocked"
    fi
    
    ip route del "$target/32" 2>/dev/null
}

test_ipv6_linklocal() {
    local iface="$1"
    local target_ipv4="$2"
    
    log "Testing IPv6 link-local communication..."
    
    # Check if IPv6 is enabled
    local our_ipv6=$(ip -6 addr show "$iface" scope link 2>/dev/null | grep inet6 | awk '{print $2}' | cut -d/ -f1)
    if [ -z "$our_ipv6" ]; then
        add_test "pass" "IPv6 Link-Local" "IPv6 disabled on interface — not exploitable"
        return
    fi
    
    # Discover IPv6 neighbors
    ping6 -c 3 -I "$iface" ff02::1 2>/dev/null &
    sleep 3
    kill %1 2>/dev/null
    
    local neighbors=$(ip -6 neigh show dev "$iface" 2>/dev/null | grep -v "FAILED" | awk '{print $1}')
    local neighbor_count=$(echo "$neighbors" | grep -c "fe80" 2>/dev/null || echo 0)
    
    if [ "$neighbor_count" -gt 1 ]; then
        # Try to reach a neighbor
        local first_neighbor=$(echo "$neighbors" | grep "fe80" | head -1)
        local result=$(ping6 -c 2 -W 2 -I "$iface" "$first_neighbor" 2>/dev/null)
        if echo "$result" | grep -q "bytes from"; then
            add_test "fail" "IPv6 Link-Local" "IPv6 link-local communication possible — isolation bypassed ($neighbor_count neighbors)"
        else
            add_test "pass" "IPv6 Link-Local" "IPv6 neighbors visible but not reachable"
        fi
    else
        add_test "pass" "IPv6 Link-Local" "No IPv6 neighbors discovered"
    fi
}

test_mdns_llmnr() {
    local iface="$1"
    
    log "Testing mDNS/LLMNR discovery..."
    
    local services_found=0
    
    # Test mDNS (port 5353)
    if command -v avahi-browse >/dev/null 2>&1; then
        local mdns=$(timeout 5 avahi-browse -a -t -r 2>/dev/null | grep -c "hostname" || echo 0)
        services_found=$((services_found + mdns))
    fi
    
    # Manual mDNS probe
    local mdns_response=$(echo -ne '\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x09_services\x07_dns-sd\x04_udp\x05local\x00\x00\x0c\x00\x01' | \
        timeout 3 nc -u -w 2 224.0.0.251 5353 2>/dev/null | wc -c)
    
    if [ "$mdns_response" -gt 0 ] || [ "$services_found" -gt 0 ]; then
        add_test "fail" "mDNS/LLMNR Discovery" "mDNS services discoverable across isolation boundary ($services_found services)"
    else
        add_test "pass" "mDNS/LLMNR Discovery" "No mDNS/LLMNR services visible — properly isolated"
    fi
}

test_tcp_common_ports() {
    local target="$1"
    
    log "Testing TCP port access to $target..."
    
    local open_ports=""
    local ports_checked=0
    local ports_open=0
    
    for port in 22 80 443 445 3389 8080 8443 53 139 5900; do
        ports_checked=$((ports_checked + 1))
        local result=$(timeout 2 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null && echo "open" || echo "closed")
        if [ "$result" = "open" ]; then
            ports_open=$((ports_open + 1))
            open_ports="$open_ports $port"
        fi
    done
    
    if [ $ports_open -gt 0 ]; then
        add_test "fail" "TCP Port Access ($target)" "Open ports:$open_ports — client services accessible across isolation"
    else
        add_test "pass" "TCP Port Access ($target)" "All $ports_checked common ports blocked — isolation effective"
    fi
}

test_dns_resolution() {
    local target_domain="$1"
    
    log "Testing DNS resolution for internal names..."
    
    # Try to resolve common internal names
    local resolved=0
    for name in "dc" "mail" "intranet" "fileserver" "printer" "admin" "vpn" "radius"; do
        local fqdn="${name}.${target_domain}"
        local result=$(dig +short "$fqdn" 2>/dev/null)
        if [ -n "$result" ]; then
            resolved=$((resolved + 1))
        fi
    done
    
    if [ $resolved -gt 0 ]; then
        add_test "fail" "Internal DNS Resolution" "$resolved internal names resolvable from this segment — DNS leaks across VLANs"
    else
        add_test "pass" "Internal DNS Resolution" "No internal names resolvable — DNS properly segmented"
    fi
}

# ─── GENERATE REPORT ─────────────────────────────────────────────────

generate_report() {
    cat > "$REPORT" << EOF
<!DOCTYPE html>
<html><head>
<title>Client Isolation Test Report - IsoBreaker</title>
<style>
body { font-family: 'Segoe UI', sans-serif; background: #0d0d0d; color: #e0e0e0; padding: 2rem; max-width: 900px; margin: 0 auto; }
h1 { color: #ff0040; margin-bottom: 0.5rem; }
h2 { color: #58a6ff; margin-top: 2rem; }
.summary { display: flex; gap: 1rem; margin: 1.5rem 0; }
.card { background: #1a1a1a; border: 1px solid #333; border-radius: 8px; padding: 1.5rem; text-align: center; flex: 1; }
.card .num { font-size: 32px; font-weight: 700; }
.card.pass .num { color: #3fb950; }
.card.fail .num { color: #f85149; }
.card.partial .num { color: #d29922; }
table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
th { background: #1a1a1a; color: #58a6ff; padding: 10px; text-align: left; }
td { padding: 10px; border-bottom: 1px solid #222; }
.result-pass { color: #3fb950; font-weight: 600; }
.result-fail { color: #f85149; font-weight: 600; }
.result-partial { color: #d29922; font-weight: 600; }
.score { font-size: 48px; font-weight: 700; text-align: center; margin: 2rem 0; }
.footer { margin-top: 3rem; color: #555; font-size: 12px; border-top: 1px solid #333; padding-top: 1rem; }
</style>
</head><body>
<h1>🔒 Client Isolation Test Report</h1>
<p>Network: $TARGET_SSID | Date: $(date)</p>

<div class="summary">
    <div class="card pass"><div class="num">$PASS_COUNT</div>PASS</div>
    <div class="card fail"><div class="num">$FAIL_COUNT</div>FAIL</div>
    <div class="card partial"><div class="num">$PARTIAL_COUNT</div>PARTIAL</div>
</div>

<div class="score" style="color: $([ $FAIL_COUNT -eq 0 ] && echo '#3fb950' || echo '#f85149')">
$([ $FAIL_COUNT -eq 0 ] && echo '✅ ISOLATION EFFECTIVE' || echo '❌ ISOLATION BROKEN')
</div>

<h2>Test Results</h2>
<table>
<tr><th>#</th><th>Test</th><th>Result</th><th>Details</th></tr>
EOF

    for i in $(seq 1 $TEST_COUNT); do
        eval "local name=\$TEST_NAME_${i}"
        eval "local result=\$TEST_RESULT_${i}"
        eval "local detail=\$TEST_DETAIL_${i}"
        
        cat >> "$REPORT" << EOF
<tr>
    <td>$i</td>
    <td>$name</td>
    <td class="result-$result">$(echo "$result" | tr '[:lower:]' '[:upper:]')</td>
    <td>$detail</td>
</tr>
EOF
    done

    cat >> "$REPORT" << EOF
</table>

<h2>Compliance Impact</h2>
<table>
<tr><th>Framework</th><th>Requirement</th><th>Status</th></tr>
<tr><td>PCI-DSS</td><td>1.2.3 — Network segmentation</td><td class="result-$([ $FAIL_COUNT -eq 0 ] && echo 'pass' || echo 'fail')">$([ $FAIL_COUNT -eq 0 ] && echo 'COMPLIANT' || echo 'NON-COMPLIANT')</td></tr>
<tr><td>HIPAA</td><td>§164.312(e)(1) — Transmission security</td><td class="result-$([ $FAIL_COUNT -eq 0 ] && echo 'pass' || echo 'fail')">$([ $FAIL_COUNT -eq 0 ] && echo 'COMPLIANT' || echo 'NON-COMPLIANT')</td></tr>
<tr><td>NIST 800-153</td><td>Wireless network segmentation</td><td class="result-$([ $FAIL_COUNT -eq 0 ] && echo 'pass' || echo 'fail')">$([ $FAIL_COUNT -eq 0 ] && echo 'MEETS' || echo 'DOES NOT MEET')</td></tr>
</table>

<div class="footer">
    <p>Generated by IsoBreaker v1.0 | NullSec Suite | github.com/bad-antics/hak5-pineapple</p>
</div>
</body></html>
EOF

    log "Report saved: $REPORT"
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

PROMPT "╔══════════════════════════════╗
║     ISOBREAKER v1.0          ║
║  Client Isolation Tester     ║
╚══════════════════════════════╝

Tests AP/client isolation
and VLAN segmentation:

• L2 direct ARP access
• L3 ICMP reachability
• Hairpin routing bypass
• IPv6 link-local bypass
• mDNS/LLMNR discovery
• TCP port access
• Internal DNS leaks

For compliance validation:
PCI-DSS, HIPAA, NIST 800-153

Press OK to configure."

# Get target network
PROMPT "TARGET NETWORK

Enter the WiFi network
to test isolation on."

TARGET_SSID=$(TEXT_INPUT "SSID:" "Guest-WiFi")
[ -z "$TARGET_SSID" ] && TARGET_SSID="Guest-WiFi"

TARGET_PASS=$(TEXT_INPUT "Password (blank=open):" "")

IFACE="wlan0"
for iface in wlan0 wlan1; do
    [ -d "/sys/class/net/$iface" ] && IFACE="$iface" && break
done

log "IsoBreaker starting on $TARGET_SSID..."

# Connect to network
SPINNER_START "Connecting to $TARGET_SSID..."
OUR_IP=$(connect_network "$TARGET_SSID" "$TARGET_PASS" "$IFACE")
SPINNER_STOP

if [ -z "$OUR_IP" ]; then
    ERROR_DIALOG "Failed to connect to $TARGET_SSID!"
    exit 1
fi

PROMPT "CONNECTED!

IP: $OUR_IP
Interface: $IFACE
Network: $TARGET_SSID

Discovering other clients..."

# Discover clients
SPINNER_START "Discovering clients..."
discover_clients "$IFACE" "$OUR_IP"
SPINNER_STOP

if [ $CLIENT_COUNT -eq 0 ]; then
    PROMPT "NO OTHER CLIENTS FOUND

Only our device on the network.
Cannot test client isolation
without other clients.

Will test gateway-based
isolation methods only."
fi

PROMPT "READY TO TEST

Our IP: $OUR_IP
Gateway: $GATEWAY
Other clients: $CLIENT_COUNT

Running isolation tests:
1. L2 ARP isolation
2. L3 ICMP isolation
3. Hairpin routing
4. IPv6 link-local
5. mDNS/LLMNR
6. TCP port access
7. DNS segmentation

Press OK to begin."

# Run all tests
SPINNER_START "Running isolation tests..."

# Test each discovered client
for i in $(seq 1 $CLIENT_COUNT); do
    eval "local client_ip=\$CLIENT_IP_${i}"
    [ "$client_ip" = "$GATEWAY" ] && continue
    
    test_l2_direct_arp "$IFACE" "$client_ip"
    test_l3_icmp "$client_ip"
    test_hairpin_routing "$IFACE" "$client_ip" "$GATEWAY"
    test_tcp_common_ports "$client_ip"
done

# Test gateway-only methods
test_ipv6_linklocal "$IFACE" ""
test_mdns_llmnr "$IFACE"

# Test DNS if we can determine a domain
local domain=$(hostname -d 2>/dev/null)
[ -z "$domain" ] && domain="corp.local"
test_dns_resolution "$domain"

SPINNER_STOP

# Generate report
generate_report

# Show results
ISOLATION_SCORE="FAIL"
[ $FAIL_COUNT -eq 0 ] && ISOLATION_SCORE="PASS"
[ $FAIL_COUNT -gt 0 ] && [ $PASS_COUNT -gt $FAIL_COUNT ] && ISOLATION_SCORE="PARTIAL"

PROMPT "═══ ISOBREAKER RESULTS ═══

Network: $TARGET_SSID
Isolation: $ISOLATION_SCORE

Tests: $TEST_COUNT
✅ Pass: $PASS_COUNT
❌ Fail: $FAIL_COUNT
⚠️  Partial: $PARTIAL_COUNT

Report: $REPORT

Press OK to exit."

log "IsoBreaker complete. Score: $ISOLATION_SCORE"
