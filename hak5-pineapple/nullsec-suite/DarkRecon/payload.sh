#!/bin/bash
# Title: Dark Recon
# Author: bad-antics
# Description: Deep reconnaissance — OSINT, service enumeration, vulnerability fingerprinting
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/dark-recon"
mkdir -p "$LOOT_DIR"

PROMPT "DARK RECON

Deep target reconnaissance.

- Full port enumeration
- Service fingerprinting
- Vulnerability detection
- OS identification
- SSL/TLS analysis
- Default credential check

Press OK to begin."

TARGET=$(TEXT_PICKER "Target IP or range:" "192.168.1.0/24")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

PROMPT "RECON DEPTH

1. Quick (top 100 ports)
2. Standard (top 1000)
3. Full (all 65535)
4. Stealth (slow + evasion)
5. Aggressive (fast + vuln)

Select on next screen."

DEPTH=$(NUMBER_PICKER "Depth (1-5):" 2)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DEPTH=2 ;; esac

resp=$(CONFIRMATION_DIALOG "START RECON?

Target: $TARGET
Depth: $DEPTH

This may take a while
at higher depths.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "DarkRecon: target=$TARGET depth=$DEPTH"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/recon_${TIMESTAMP}"
SPINNER_START "Scanning target..."

# Distribute across mesh if available
MESH_CMD=""
if [ -f "$HOME/.config/nullsec-link/config.sh" ]; then
    source "$HOME/.config/nullsec-link/config.sh" 2>/dev/null
fi

case $DEPTH in
    1) NMAP_ARGS="-sV -sC --top-ports 100 -T4" ;;
    2) NMAP_ARGS="-sV -sC -T4 -A" ;;
    3) NMAP_ARGS="-sV -sC -p- -T3 -A" ;;
    4) NMAP_ARGS="-sV -sC -T2 -f --data-length 50 -D RND:5" ;;
    5) NMAP_ARGS="-sV -sC -A -T4 --script vuln,exploit,auth,default" ;;
esac

nmap $NMAP_ARGS "$TARGET" -oN "${REPORT}_nmap.txt" -oX "${REPORT}_nmap.xml" 2>/dev/null

# Parse results
HOSTS_UP=$(grep -c "Host is up" "${REPORT}_nmap.txt" 2>/dev/null)
OPEN_PORTS=$(grep -c "open" "${REPORT}_nmap.txt" 2>/dev/null)

# SSL/TLS check on HTTPS ports
HTTPS_HOSTS=$(grep "443/tcp.*open" "${REPORT}_nmap.txt" 2>/dev/null | grep -oP "(\d+\.){3}\d+" || true)
if [ -n "$HTTPS_HOSTS" ]; then
    echo "=== SSL/TLS ANALYSIS ===" > "${REPORT}_ssl.txt"
    for h in $HTTPS_HOSTS; do
        echo "--- $h ---" >> "${REPORT}_ssl.txt"
        echo | timeout 10 openssl s_client -connect "$h:443" 2>/dev/null | \
            openssl x509 -noout -subject -issuer -dates -serial 2>/dev/null >> "${REPORT}_ssl.txt"
        echo "" >> "${REPORT}_ssl.txt"
    done
fi

# Default credential check on common services
echo "=== DEFAULT CRED CHECK ===" > "${REPORT}_defaults.txt"
HTTP_HOSTS=$(grep -E "80/tcp.*open|8080/tcp.*open" "${REPORT}_nmap.txt" 2>/dev/null | grep -oP "(\d+\.){3}\d+")
for h in $HTTP_HOSTS; do
    for cred in "admin:admin" "admin:password" "root:root" "admin:" "user:user"; do
        U="${cred%%:*}"; P="${cred##*:}"
        R=$(curl -sf -o /dev/null -w "%{http_code}" -u "$U:$P" "http://$h/" --connect-timeout 3 2>/dev/null)
        [ "$R" = "200" ] && echo "  $h | HTTP | $U:$P | SUCCESS" >> "${REPORT}_defaults.txt"
    done
done

SPINNER_STOP

VULNS=$(grep -ciE "vuln|cve|weak|default|VULNERABLE" "${REPORT}_nmap.txt" 2>/dev/null)
DEFAULTS=$(grep -c "SUCCESS" "${REPORT}_defaults.txt" 2>/dev/null)

PROMPT "DARK RECON COMPLETE

Hosts up: $HOSTS_UP
Open ports: $OPEN_PORTS
Vulnerabilities: ${VULNS:-0}
Default creds: ${DEFAULTS:-0}

Full report saved to:
dark-recon/

Press OK to exit."
