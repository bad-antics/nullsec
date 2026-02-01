#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Pineapple Suite - Payload Uploader
# Developed by: bad-antics
#═══════════════════════════════════════════════════════════════════════════════

PINEAPPLE_IP="${PINEAPPLE_IP:-172.16.42.1}"
REMOTE_PATH="/root/payloads/user/nullsec"
LIB_PATH="/mmc/nullsec/lib"
LOCAL_DIR="$(dirname "$0")/payloads"
LOCAL_LIB="$(dirname "$0")/lib"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     NullSec Pineapple Suite - Payload Uploader               ║"
echo "║                    Developed by: bad-antics                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check connection
echo -e "${YELLOW}[*] Checking Pineapple connection...${NC}"
if ! ping -c 1 -W 3 "$PINEAPPLE_IP" >/dev/null 2>&1; then
    echo -e "${RED}[✗] Cannot reach Pineapple at $PINEAPPLE_IP${NC}"
    echo "    Connect via USB or set PINEAPPLE_IP environment variable"
    exit 1
fi
echo -e "${GREEN}[✓] Pineapple connected at $PINEAPPLE_IP${NC}"

# Create remote directories
echo -e "${YELLOW}[*] Creating remote directories...${NC}"
ssh root@$PINEAPPLE_IP "mkdir -p $REMOTE_PATH $LIB_PATH" 2>/dev/null

# Upload library files
echo -e "${YELLOW}[*] Uploading library files...${NC}"
if [ -d "$LOCAL_LIB" ]; then
    for lib in "$LOCAL_LIB"/*.sh; do
        [ -f "$lib" ] || continue
        scp "$lib" root@$PINEAPPLE_IP:$LIB_PATH/ 2>/dev/null && \
            echo -e "${GREEN}  [✓] $(basename $lib)${NC}" || \
            echo -e "${RED}  [✗] $(basename $lib)${NC}"
    done
fi

# Upload payloads
echo -e "${YELLOW}[*] Uploading payloads...${NC}"
COUNT=0
FAIL=0
for payload in "$LOCAL_DIR"/*_payload.sh; do
    [ -f "$payload" ] || continue
    NAME=$(basename "$payload" _payload.sh)
    scp "$payload" root@$PINEAPPLE_IP:$REMOTE_PATH/${NAME}_payload.sh 2>/dev/null
    if [ $? -eq 0 ]; then
        ((COUNT++))
        echo -e "${GREEN}  [✓] $NAME${NC}"
    else
        ((FAIL++))
        echo -e "${RED}  [✗] $NAME${NC}"
    fi
done

# Set permissions
echo -e "${YELLOW}[*] Setting permissions...${NC}"
ssh root@$PINEAPPLE_IP "chmod +x $REMOTE_PATH/*.sh $LIB_PATH/*.sh" 2>/dev/null

# Summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}[✓] Upload complete!${NC}"
echo -e "    Payloads uploaded: ${GREEN}$COUNT${NC}"
[ $FAIL -gt 0 ] && echo -e "    Failed: ${RED}$FAIL${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Payloads are now available in: Payloads → User → nullsec"
echo ""
echo -e "${CYAN}Developed by: bad-antics${NC}"
