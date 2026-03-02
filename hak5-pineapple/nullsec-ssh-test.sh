#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NullSec Fleet SSH Key Auth Test
# Tests passwordless SSH to all cluster nodes
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${BOLD}       NullSec Fleet SSH Key Auth Test              ${NC}${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

PASS=0
FAIL=0
TOTAL=0

# Node format: alias:user@host
NODES=(
    "r420:root@192.168.40.209"
    "nullkia:antics@192.168.40.43"
    "parrot:antics@192.168.40.214"
    "doomsday:antics@192.168.40.22"
    "thinkcentre:doom@192.168.40.55"
    "fairy:fairy@192.168.40.163"
    "desktop65:antics@192.168.40.65"
)

printf "${BOLD}%-15s %-25s %-10s %s${NC}\n" "HOST" "TARGET" "STATUS" "DETAILS"
echo "─────────────── ───────────────────────── ────────── ──────────────"

for entry in "${NODES[@]}"; do
    name="${entry%%:*}"
    target="${entry##*:}"
    TOTAL=$((TOTAL + 1))

    printf "%-15s %-25s " "$name" "$target"

    # Test with BatchMode=yes (no password prompt), ConnectTimeout=3
    result=$(timeout 4 ssh -o BatchMode=yes -o ConnectTimeout=3 -o ConnectionAttempts=1 "$name" "echo OK" 2>&1 | tr -d '\r\n')

    if [ "$result" = "OK" ]; then
        echo -e "${GREEN}✅ KEY_AUTH${NC}  Passwordless OK"
        PASS=$((PASS + 1))
    else
        # Check if it's a connection issue vs auth issue
        if echo "$result" | grep -qi "refused\|timed out\|No route\|unreachable"; then
            echo -e "${RED}❌ NO_SSH${NC}   $result"
        elif echo "$result" | grep -qi "denied\|permission\|authentication"; then
            echo -e "${RED}❌ NO_KEY${NC}   Key auth not configured"
        else
            echo -e "${YELLOW}⚠  UNKNOWN${NC}  $result"
        fi
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "─────────────── ───────────────────────── ────────── ──────────────"
echo -e "${BOLD}Results:${NC} ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} / $TOTAL total"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ All nodes have passwordless SSH key auth!${NC}"
elif [ "$FAIL" -eq 1 ]; then
    echo -e "${YELLOW}${BOLD}⚠  1 node needs attention (see above)${NC}"
else
    echo -e "${RED}${BOLD}❌ $FAIL nodes need SSH key deployment${NC}"
fi

echo ""
echo "SSH Config: ~/.ssh/config"
echo "SSH Key:    ~/.ssh/id_ed25519.pub"
echo ""
