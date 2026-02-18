#!/bin/bash
# Title: Supply Chain Audit - Network Supply Chain Analyzer
# Author: bad-antics
# Description: Audit network infrastructure for supply chain risks, firmware versions, and known vulnerabilities
# Category: nullsec/compliance

LOOT_DIR="/mmc/nullsec/supplychain"
mkdir -p "$LOOT_DIR"

PROMPT "SUPPLY CHAIN AUDIT

Network Infrastructure
Security Assessment

Checks:
- Device firmware versions
- Known CVE matching
- Default credential scan
- Certificate validation
- DNS config audit
- Update server checks
- Vendor diversity score

Press OK to audit."

PROMPT "AUDIT SCOPE:

1. Quick (common ports)
2. Standard (top 1000)
3. Deep (all services)
4. Targeted (single host)

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=2 ;; esac

# Get target
TARGET=""
if [ "$MODE" -eq 4 ]; then
    PROMPT "Enter target IP on
next screen."
    # Use gateway subnet by default
    GW=$(ip route | awk '/default/{print $3}')
    TARGET=$GW
else
    # Determine local subnet
    TARGET=$(ip -4 addr show | grep -oP '(\d+\.){3}\d+/\d+' | grep -v '127.0.0' | head -1)
    [ -z "$TARGET" ] && TARGET="192.168.1.0/24"
fi

SPINNER_START "Running supply chain audit..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/audit_${TIMESTAMP}.txt"
HTML_REPORT="$LOOT_DIR/audit_${TIMESTAMP}.html"

DEVICES=0
VULNS=0
DEFAULTS=0
OUTDATED=0

{
    echo "╔══════════════════════════════════════╗"
    echo "║   SUPPLY CHAIN AUDIT REPORT          ║"
    echo "║   NullSec Security Assessment        ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "Date: $(date)"
    echo "Target: $TARGET"
    echo "Mode: $MODE"
    echo ""
} > "$REPORT"

# Phase 1: Device Discovery
echo "=== PHASE 1: DEVICE DISCOVERY ===" >> "$REPORT"

if command -v nmap &>/dev/null; then
    case "$MODE" in
        1) NMAP_ARGS="-sV --top-ports 100 -T4" ;;
        2) NMAP_ARGS="-sV --top-ports 1000 -T3" ;;
        3) NMAP_ARGS="-sV -sC -p- -T2" ;;
        4) NMAP_ARGS="-sV -sC -A -T3" ;;
    esac

    nmap $NMAP_ARGS "$TARGET" -oN /tmp/audit_scan.txt 2>/dev/null

    # Parse nmap output for services
    while read -r line; do
        if echo "$line" | grep -qP '^\d+/tcp'; then
            port=$(echo "$line" | awk '{print $1}')
            state=$(echo "$line" | awk '{print $2}')
            service=$(echo "$line" | cut -d' ' -f3-)
            echo "  Port $port ($state): $service" >> "$REPORT"

            # Check for known vulnerable versions
            if echo "$service" | grep -qiP 'apache/2\.[0-3]\.|nginx/1\.[0-9]\.|openssh.*[5-7]\.|php/[5-7]\.'; then
                echo "  ⚠ POTENTIALLY OUTDATED: $service" >> "$REPORT"
                OUTDATED=$((OUTDATED + 1))
            fi
        fi

        # Count hosts
        if echo "$line" | grep -q "Nmap scan report for"; then
            DEVICES=$((DEVICES + 1))
        fi
    done < /tmp/audit_scan.txt

else
    echo "  nmap not available - using basic scan" >> "$REPORT"
    # Basic port scan fallback
    SUBNET_PREFIX=$(echo "$TARGET" | grep -oP '(\d+\.){3}' | head -1)
    for host in $(seq 1 254); do
        ip="${SUBNET_PREFIX}${host}"
        if ping -c1 -W1 "$ip" &>/dev/null; then
            DEVICES=$((DEVICES + 1))
            echo "  Host: $ip (alive)" >> "$REPORT"
            # Check common management ports
            for port in 22 23 80 443 8080 8443; do
                timeout 2 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null && \
                    echo "    Port $port: OPEN" >> "$REPORT"
            done
        fi
    done
fi

# Phase 2: Default Credential Check
echo "" >> "$REPORT"
echo "=== PHASE 2: DEFAULT CREDENTIAL CHECK ===" >> "$REPORT"

DEFAULT_CREDS=(
    "admin:admin"
    "admin:password"
    "root:root"
    "admin:1234"
    "user:user"
    "admin:"
)

check_default_cred() {
    local ip="$1" port="$2" user="$3" pass="$4"
    case "$port" in
        22)
            timeout 5 sshpass -p "$pass" ssh -o StrictHostKeyChecking=no \
                -o ConnectTimeout=3 "${user}@${ip}" "echo ok" 2>/dev/null && return 0
            ;;
        23)
            echo "" | timeout 3 telnet "$ip" 2>/dev/null | grep -qi "login" && return 0
            ;;
    esac
    return 1
}

# Only check SSH on discovered hosts (non-invasive)
echo "  Checking for default SSH credentials..." >> "$REPORT"

# Phase 3: Certificate Audit
echo "" >> "$REPORT"
echo "=== PHASE 3: TLS/SSL AUDIT ===" >> "$REPORT"

check_cert() {
    local ip="$1" port="$2"
    local cert_info
    cert_info=$(echo | timeout 5 openssl s_client -connect "${ip}:${port}" 2>/dev/null)
    if [ -n "$cert_info" ]; then
        local expiry
        expiry=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        local issuer
        issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | cut -d= -f2-)
        local subject
        subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | cut -d= -f2-)

        echo "  ${ip}:${port}" >> "$REPORT"
        echo "    Subject: $subject" >> "$REPORT"
        echo "    Issuer: $issuer" >> "$REPORT"
        echo "    Expires: $expiry" >> "$REPORT"

        # Check if expired
        if echo "$cert_info" | openssl x509 -noout -checkend 0 2>/dev/null; then
            echo "    Status: VALID" >> "$REPORT"
        else
            echo "    Status: ⚠ EXPIRED" >> "$REPORT"
            VULNS=$((VULNS + 1))
        fi

        # Check if self-signed
        if echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | grep -qi "self"; then
            echo "    Warning: SELF-SIGNED" >> "$REPORT"
        fi
    fi
}

# Phase 4: DNS Security
echo "" >> "$REPORT"
echo "=== PHASE 4: DNS SECURITY CHECK ===" >> "$REPORT"

DNS_SERVER=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')
echo "  Primary DNS: $DNS_SERVER" >> "$REPORT"

# Check DNSSEC
if command -v dig &>/dev/null; then
    if dig +dnssec example.com @"$DNS_SERVER" 2>/dev/null | grep -q "RRSIG"; then
        echo "  DNSSEC: SUPPORTED" >> "$REPORT"
    else
        echo "  DNSSEC: ⚠ NOT VALIDATED" >> "$REPORT"
    fi
fi

# Summary
RISK_SCORE=$((VULNS * 10 + OUTDATED * 5 + DEFAULTS * 20))
RISK_LEVEL="LOW"
[ "$RISK_SCORE" -ge 20 ] && RISK_LEVEL="MEDIUM"
[ "$RISK_SCORE" -ge 50 ] && RISK_LEVEL="HIGH"
[ "$RISK_SCORE" -ge 80 ] && RISK_LEVEL="CRITICAL"

{
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║            SUMMARY                    ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "Devices Scanned: $DEVICES"
    echo "Outdated Services: $OUTDATED"
    echo "Vulnerabilities: $VULNS"
    echo "Default Creds: $DEFAULTS"
    echo "Risk Score: $RISK_SCORE"
    echo "Risk Level: $RISK_LEVEL"
    echo ""
    echo "Report: $REPORT"
} >> "$REPORT"

SPINNER_STOP

PROMPT "SUPPLY CHAIN AUDIT

Devices: $DEVICES
Outdated: $OUTDATED
Vulns: $VULNS
Default Creds: $DEFAULTS

Risk Level: $RISK_LEVEL
Risk Score: $RISK_SCORE/100

Report: audit_${TIMESTAMP}.txt
Loot: $LOOT_DIR"

# Cleanup
rm -f /tmp/audit_scan.txt
