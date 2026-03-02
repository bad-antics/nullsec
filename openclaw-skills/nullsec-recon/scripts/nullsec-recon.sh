#!/bin/bash
# NullSec Recon — Automated reconnaissance workflow
# Usage: ./nullsec-recon.sh <target-domain> [--quick|--full]

set -e

TARGET="${1:?Usage: $0 <target-domain> [--quick|--full]}"
MODE="${2:---quick}"
OUTDIR="recon-${TARGET//[^a-zA-Z0-9.]/_}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$OUTDIR"

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
ok()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*"; }

has() { command -v "$1" &>/dev/null; }

banner() {
    echo -e "${RED}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║       NullSec Recon Scanner v1.0      ║"
    echo "  ║       github.com/bad-antics           ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Target: ${CYAN}${TARGET}${NC}"
    echo -e "  Mode:   ${CYAN}${MODE}${NC}"
    echo -e "  Output: ${CYAN}${OUTDIR}/${NC}"
    echo ""
}

banner

# Phase 1: DNS
log "Phase 1: DNS Enumeration"
if has dig; then
    dig "$TARGET" ANY +noall +answer > "$OUTDIR/dns-records.txt" 2>/dev/null
    dig "$TARGET" MX +short >> "$OUTDIR/dns-records.txt" 2>/dev/null
    dig "$TARGET" NS +short >> "$OUTDIR/dns-records.txt" 2>/dev/null
    dig "$TARGET" TXT +short >> "$OUTDIR/dns-records.txt" 2>/dev/null
    ok "DNS records saved"
else
    warn "dig not found, skipping DNS"
fi

if has whois; then
    whois "$TARGET" > "$OUTDIR/whois.txt" 2>/dev/null
    ok "WHOIS saved"
fi

# Phase 2: Subdomain Enumeration
log "Phase 2: Subdomain Enumeration"
SUBS="$OUTDIR/subdomains.txt"
touch "$SUBS"

# Certificate Transparency
if has curl && has jq; then
    log "  Checking certificate transparency..."
    curl -s "https://crt.sh/?q=%.${TARGET}&output=json" 2>/dev/null | \
        jq -r '.[].name_value' 2>/dev/null | sort -u >> "$SUBS" || true
    ok "crt.sh: $(wc -l < "$SUBS") entries"
fi

if has subfinder; then
    log "  Running subfinder..."
    subfinder -d "$TARGET" -silent >> "$SUBS" 2>/dev/null || true
    sort -u -o "$SUBS" "$SUBS"
    ok "subfinder complete: $(wc -l < "$SUBS") total"
fi

if has amass && [[ "$MODE" == "--full" ]]; then
    log "  Running amass (full mode)..."
    amass enum -passive -d "$TARGET" -o "$OUTDIR/amass-subs.txt" 2>/dev/null || true
    cat "$OUTDIR/amass-subs.txt" >> "$SUBS" 2>/dev/null || true
    sort -u -o "$SUBS" "$SUBS"
    ok "amass complete: $(wc -l < "$SUBS") total"
fi

# Phase 3: Live Host Detection
log "Phase 3: Resolving live hosts"
if has httpx; then
    cat "$SUBS" | httpx -silent -status-code -title -o "$OUTDIR/live-hosts.txt" 2>/dev/null || true
    ok "Live hosts: $(wc -l < "$OUTDIR/live-hosts.txt" 2>/dev/null || echo 0)"
fi

# Phase 4: Port Scanning
log "Phase 4: Port Scanning"
if has nmap; then
    # Resolve target IP
    IP=$(dig +short "$TARGET" A | head -1)
    if [[ -n "$IP" ]]; then
        log "  Target IP: $IP"

        # Quick scan
        nmap -sC -sV -T4 --top-ports 1000 -oA "$OUTDIR/nmap-quick" "$IP" 2>/dev/null
        ok "Quick scan complete"

        if [[ "$MODE" == "--full" ]]; then
            log "  Full port scan (this may take a while)..."
            nmap -p- -T4 --min-rate 1000 -oA "$OUTDIR/nmap-full" "$IP" 2>/dev/null
            ok "Full scan complete"
        fi
    else
        warn "Could not resolve $TARGET to an IP"
    fi
else
    warn "nmap not found, skipping port scan"
fi

# Phase 5: Web Tech Detection
log "Phase 5: Web Technology Detection"
if has whatweb; then
    whatweb -v "https://$TARGET" > "$OUTDIR/whatweb.txt" 2>/dev/null || true
    whatweb -v "http://$TARGET" >> "$OUTDIR/whatweb.txt" 2>/dev/null || true
    ok "WhatWeb saved"
fi

if has curl; then
    curl -sI "https://$TARGET" > "$OUTDIR/headers.txt" 2>/dev/null || true
    curl -s "https://$TARGET/robots.txt" > "$OUTDIR/robots.txt" 2>/dev/null || true
    ok "Headers and robots.txt saved"
fi

# Summary
echo ""
echo -e "${GREEN}━━━ Recon Complete ━━━${NC}"
echo ""
echo -e "Results in: ${CYAN}${OUTDIR}/${NC}"
ls -la "$OUTDIR/" | tail -n +2 | while read -r line; do
    echo -e "  ${line}"
done
echo ""

TOTAL_SUBS=$(wc -l < "$SUBS" 2>/dev/null || echo 0)
TOTAL_LIVE=$(wc -l < "$OUTDIR/live-hosts.txt" 2>/dev/null || echo 0)
OPEN_PORTS=$(grep -c "open" "$OUTDIR/nmap-quick.nmap" 2>/dev/null || echo 0)

echo -e "  Subdomains found: ${CYAN}${TOTAL_SUBS}${NC}"
echo -e "  Live hosts:       ${CYAN}${TOTAL_LIVE}${NC}"
echo -e "  Open ports:       ${CYAN}${OPEN_PORTS}${NC}"
echo ""
echo -e "  ${YELLOW}Next steps: Review findings and proceed to exploitation phase${NC}"
echo -e "  NullSec: badxantics@gmail.com | github.com/bad-antics"
