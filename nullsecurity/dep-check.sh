#!/bin/bash
# Dependency checker and auto-installer for NULLSEC modules

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

# Source this file in your scripts: source ./dep-check.sh

check_and_install() {
    local cmd="$1"
    local package="${2:-$cmd}"
    local installer="${3:-apt}"
    
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${YELLOW}[!] $cmd is not installed${RESET}"
        echo -ne "${CYAN}[?] Install $package now? (y/n): ${RESET}"
        read -r install_choice
        
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[*] Installing $package...${RESET}"
            
            case "$installer" in
                apt)
                    sudo apt update -qq
                    sudo apt install -y "$package"
                    ;;
                pip|pip3)
                    pip3 install "$package"
                    ;;
                npm)
                    sudo npm install -g "$package"
                    ;;
                snap)
                    sudo snap install "$package"
                    ;;
                gem)
                    sudo gem install "$package"
                    ;;
                *)
                    echo -e "${RED}[!] Unknown installer: $installer${RESET}"
                    return 1
                    ;;
            esac
            
            if command -v "$cmd" &> /dev/null; then
                echo -e "${GREEN}[✓] $package installed successfully${RESET}"
                return 0
            else
                echo -e "${RED}[✗] Installation failed${RESET}"
                return 1
            fi
        else
            echo -e "${YELLOW}[*] Skipping installation${RESET}"
            return 1
        fi
    fi
    return 0
}

# Check multiple dependencies
check_dependencies() {
    local missing=0
    
    for dep in "$@"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}[✗] Missing: $dep${RESET}"
            missing=$((missing + 1))
        else
            echo -e "${GREEN}[✓] Found: $dep${RESET}"
        fi
    done
    
    return $missing
}

# Offer to install missing dependency with package mapping
smart_install() {
    local cmd="$1"
    
    # Common package mappings
    declare -A package_map=(
        ["nmap"]="nmap apt"
        ["wireshark"]="wireshark apt"
        ["tshark"]="tshark apt"
        ["aircrack-ng"]="aircrack-ng apt"
        ["airodump-ng"]="aircrack-ng apt"
        ["aireplay-ng"]="aircrack-ng apt"
        ["hashcat"]="hashcat apt"
        ["hydra"]="hydra apt"
        ["john"]="john apt"
        ["msfconsole"]="metasploit-framework apt"
        ["msfvenom"]="metasploit-framework apt"
        ["ettercap"]="ettercap-text-only apt"
        ["sqlmap"]="sqlmap apt"
        ["nikto"]="nikto apt"
        ["dirb"]="dirb apt"
        ["gobuster"]="gobuster apt"
        ["ffuf"]="ffuf apt"
        ["wfuzz"]="wfuzz apt"
        ["burpsuite"]="burpsuite apt"
        ["zaproxy"]="zaproxy apt"
        ["ghidra"]="ghidra apt"
        ["netcat"]="netcat-traditional apt"
        ["nc"]="netcat-traditional apt"
        ["socat"]="socat apt"
        ["tcpdump"]="tcpdump apt"
        ["arpspoof"]="dsniff apt"
        ["hping3"]="hping3 apt"
        ["masscan"]="masscan apt"
        ["proxychains"]="proxychains apt"
        ["tor"]="tor apt"
        ["openvpn"]="openvpn apt"
        ["git"]="git apt"
        ["curl"]="curl apt"
        ["wget"]="wget apt"
        ["jq"]="jq apt"
        ["python3"]="python3 apt"
        ["pip3"]="python3-pip apt"
        ["ruby"]="ruby apt"
        ["perl"]="perl apt"
        ["node"]="nodejs apt"
        ["npm"]="npm apt"
    )
    
    if [[ -n "${package_map[$cmd]}" ]]; then
        read -r package installer <<< "${package_map[$cmd]}"
        check_and_install "$cmd" "$package" "$installer"
    else
        echo -e "${YELLOW}[!] $cmd not found${RESET}"
        echo -ne "${CYAN}[?] Package name to install (or ENTER to skip): ${RESET}"
        read -r package
        
        if [[ -n "$package" ]]; then
            echo -ne "${CYAN}[?] Installer (apt/pip/npm/snap) [apt]: ${RESET}"
            read -r installer
            installer="${installer:-apt}"
            check_and_install "$cmd" "$package" "$installer"
        else
            return 1
        fi
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}[!] This operation requires root privileges${RESET}"
        echo -ne "${CYAN}[?] Run with sudo? (y/n): ${RESET}"
        read -r sudo_choice
        
        if [[ "$sudo_choice" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}[*] Restarting with sudo...${RESET}"
            sudo "$0" "$@"
            exit $?
        else
            echo -e "${RED}[!] Cannot proceed without root${RESET}"
            return 1
        fi
    fi
    return 0
}

export -f check_and_install
export -f check_dependencies
export -f smart_install
export -f check_root
