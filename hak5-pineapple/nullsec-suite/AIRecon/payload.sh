#!/bin/bash
# Title: AI Recon
# Author: bad-antics
# Description: AI-powered network reconnaissance using Ollama for analysis
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/ai-recon"
mkdir -p "$LOOT_DIR"

PROMPT "AI RECON

AI-powered intelligence.
Scans networks then uses
LLM to analyze results
and suggest attack paths.

Requires Ollama running
on a mesh node.

Press OK to begin."

# Find Ollama
OLLAMA_HOST=""
OLLAMA_MODEL="llama3"

if curl -sf http://localhost:11434/api/version &>/dev/null; then
    OLLAMA_HOST="localhost"
elif [ -f "$HOME/.config/nullsec-link/config.sh" ]; then
    source "$HOME/.config/nullsec-link/config.sh" 2>/dev/null
    for name in $(echo "${!MACHINES[@]}" | tr ' ' '\n'); do
        IP=$(echo "${MACHINES[$name]}" | cut -d'|' -f1)
        USER=$(echo "${MACHINES[$name]}" | cut -d'|' -f2)
        if ssh -o BatchMode=yes -o ConnectTimeout=3 "${USER}@${IP}" "curl -sf http://localhost:11434/api/version" &>/dev/null; then
            OLLAMA_HOST="${USER}@${IP}"
            break
        fi
    done
fi

if [ -z "$OLLAMA_HOST" ]; then
    resp=$(CONFIRMATION_DIALOG "No Ollama found!

Continue with scan only?
(No AI analysis)")
    [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
fi

# Phase 1: Network scan
PROMPT "PHASE 1: SCAN

Scanning local subnet
for hosts, services,
and vulnerabilities.

This takes 2-5 minutes.

Press OK to start."

SPINNER_START "Network scan..."

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
SUBNET=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(\d+\.){3}0/\d+' | head -1)
[ -z "$SUBNET" ] && SUBNET="192.168.1.0/24"

SCAN_FILE="$LOOT_DIR/scan_$(date +%Y%m%d_%H%M%S).txt"

# Quick host discovery
nmap -sn "$SUBNET" -oN "$LOOT_DIR/hosts.txt" 2>/dev/null
HOST_COUNT=$(grep -c "Host is up" "$LOOT_DIR/hosts.txt" 2>/dev/null)

# Service scan on live hosts
LIVE_IPS=$(grep "Nmap scan report" "$LOOT_DIR/hosts.txt" | grep -oP '(\d+\.){3}\d+')
echo "$LIVE_IPS" | head -20 | xargs -I{} nmap -sV -sC --top-ports 100 -T4 {} -oN "$SCAN_FILE" --append-output 2>/dev/null

# WiFi scan
if [ -d "/sys/class/net/wlan0" ]; then
    timeout 15 airodump-ng wlan0 --write-interval 5 -w /tmp/ai_wifi --output-format csv 2>/dev/null
    WIFI_DATA=$(cat /tmp/ai_wifi*.csv 2>/dev/null)
    echo -e "\n--- WIFI SCAN ---\n$WIFI_DATA" >> "$SCAN_FILE"
fi

SPINNER_STOP

# Phase 2: AI Analysis
if [ -n "$OLLAMA_HOST" ]; then
    PROMPT "PHASE 2: AI ANALYSIS

Feeding scan data to
$OLLAMA_MODEL for threat
assessment and attack
path recommendations.

Press OK to analyze."

    SPINNER_START "AI analyzing..."

    SCAN_SUMMARY=$(head -200 "$SCAN_FILE" 2>/dev/null)
    PROMPT_TEXT="You are a penetration testing AI assistant. Analyze this network scan and provide:
1. HIGH VALUE TARGETS (top 3 hosts to investigate)
2. VULNERABILITIES (any open services with known issues)
3. ATTACK PATHS (suggested next steps for a pentest)
4. WIFI RISKS (any insecure wireless networks)

Keep response under 300 words. Be specific with IPs and ports.

SCAN DATA:
$SCAN_SUMMARY"

    if [ "$OLLAMA_HOST" = "localhost" ]; then
        AI_RESULT=$(curl -sf http://localhost:11434/api/generate \
            -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":$(echo "$PROMPT_TEXT" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))'),\"stream\":false}" 2>/dev/null | \
            python3 -c "import sys,json;print(json.load(sys.stdin).get('response','Analysis failed'))" 2>/dev/null)
    else
        AI_RESULT=$(ssh -o BatchMode=yes "$OLLAMA_HOST" "curl -sf http://localhost:11434/api/generate \
            -d '{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"Analyze this network scan summary and list top targets and vulnerabilities: $HOST_COUNT hosts found\",\"stream\":false}'" 2>/dev/null | \
            python3 -c "import sys,json;print(json.load(sys.stdin).get('response','Analysis failed'))" 2>/dev/null)
    fi

    SPINNER_STOP

    echo -e "\n--- AI ANALYSIS ---\n$AI_RESULT" >> "$SCAN_FILE"

    PROMPT "AI ASSESSMENT

$AI_RESULT

Full report saved.
Press OK to continue."
else
    PROMPT "SCAN COMPLETE

Hosts found: $HOST_COUNT
Scan saved to:
$(basename "$SCAN_FILE")

No AI analysis
(Ollama not available)

Press OK to see summary."
fi

# Summary
OPEN_PORTS=$(grep -c "open" "$SCAN_FILE" 2>/dev/null)
HTTP_HOSTS=$(grep -c "http" "$SCAN_FILE" 2>/dev/null)
SSH_HOSTS=$(grep -c "ssh" "$SCAN_FILE" 2>/dev/null)
VULN_COUNT=$(grep -ci "vuln\|cve\|weak\|default" "$SCAN_FILE" 2>/dev/null)

PROMPT "RECON SUMMARY

Hosts:  $HOST_COUNT
Ports:  $OPEN_PORTS open
HTTP:   $HTTP_HOSTS services
SSH:    $SSH_HOSTS services
Alerts: $VULN_COUNT

Report: ai-recon/
Press OK to exit."
