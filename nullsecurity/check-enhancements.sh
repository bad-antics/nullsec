#!/bin/bash
# Check which modules are enhanced


# Source common library for Shodan integration

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
    echo "$content" > "$TARGET_DIR/$filename"
    log_to_file "Saved output to $TARGET_DIR/$filename"
}

# Helper function: Log discovered vulnerability
log_vulnerability() {
    local severity="$1"
    local title="$2"
    local description="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VULNERABILITY [$severity] $title - $description" >> "$LOG_FILE"
}

# Read environment variables set by framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

# Check for Shodan target
SHODAN_TARGET="/home/antics/nullsec/.shodan_target"
if [ -f "$SHODAN_TARGET" ]; then
    source "$SHODAN_TARGET"
    if [ ! -z "$TARGET" ]; then
        echo -e "${GREEN}[+]${RESET} Shodan target available: ${GREEN}$TARGET${RESET}"
    fi
fi

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
DIM='\033[2m'; RESET='\033[0m'

echo -e "${CYAN}=== NULLSEC Module Enhancement Status ===${RESET}"
echo ""

ENHANCED=0
BASIC=0

echo -e "${YELLOW}Enhanced Modules (Fully Functional):${RESET}"
for script in *.sh; do
    if grep -q "FULLY FUNCTIONAL" "$script" 2>/dev/null; then
        echo -e "${GREEN}  ✓${RESET} $script"
        ((ENHANCED++))
    fi
done

echo ""
echo -e "${DIM}Basic Modules (Still using simple SIMULATION):${RESET}"
for script in *.sh; do
    if ! grep -q "FULLY FUNCTIONAL" "$script" 2>/dev/null && [ "$script" != "batch-enhance.sh" ] && [ "$script" != "enhance-all-modules.sh" ] && [ "$script" != "check-enhancements.sh" ]; then
        echo -e "${DIM}  -${RESET} $script"
        ((BASIC++))
    fi
done

echo ""
echo -e "${CYAN}Summary:${RESET}"
echo -e "  ${GREEN}Enhanced:${RESET} $ENHANCED modules"
echo -e "  ${DIM}Basic:${RESET} $BASIC modules"
echo -e "  ${YELLOW}Total:${RESET} $((ENHANCED + BASIC)) modules"
echo ""
