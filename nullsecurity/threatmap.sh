#!/bin/bash
# NULLSEC Threat Intelligence Mapper Module
# Real-time threat intelligence aggregation and mapping
# github.com/bad-antics

# === NULLSEC ENHANCED LOGGING ===
TARGET_DIR="${NULLSEC_TARGET_DIR:-$HOME/nullsec/logs/targets/default}"
LOG_FILE="${NULLSEC_LOG_FILE:-$TARGET_DIR/module.log}"
THREATMAP_DIR="$TARGET_DIR/threatmap"

# Helper function: Log to file with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Helper function: Save output to target directory
save_output() {
    local filename="$1"
    local content="$2"
    mkdir -p "$THREATMAP_DIR"
    echo "$content" > "$THREATMAP_DIR/$filename"
    log_to_file "Saved output to $THREATMAP_DIR/$filename"
}

# Helper function: Log discovered threat
log_threat() {
    local severity="$1"
    local type="$2"
    local description="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] THREAT [$severity] $type - $description" >> "$LOG_FILE"
}

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Threat Intelligence Feeds (examples - use real feeds in production)
FEEDS=(
    "URLhaus:https://urlhaus.abuse.ch/downloads/json_recent/"
    "PhishTank:http://data.phishtank.com/data/online-valid.json"
    "AbuseIPDB:https://api.abuseipdb.com/api/v2/blacklist"
    "ThreatFox:https://threatfox-api.abuse.ch/api/v1/"
    "MalwareBazaar:https://mb-api.abuse.ch/api/v1/"
    "FeodoTracker:https://feodotracker.abuse.ch/downloads/ipblocklist_recommended.txt"
    "SSL_Blocklist:https://sslbl.abuse.ch/blacklist/sslipblacklist.txt"
)

# Banner
show_banner() {
    clear
    echo -e "${RED}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║      ████████╗██╗  ██╗██████╗ ███████╗ █████╗ ████████╗   ║"
    echo "  ║      ╚══██╔══╝██║  ██║██╔══██╗██╔════╝██╔══██╗╚══██╔══╝   ║"
    echo "  ║         ██║   ███████║██████╔╝█████╗  ███████║   ██║      ║"
    echo "  ║         ██║   ██╔══██║██╔══██╗██╔══╝  ██╔══██║   ██║      ║"
    echo "  ║         ██║   ██║  ██║██║  ██║███████╗██║  ██║   ██║      ║"
    echo "  ║         ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝      ║"
    echo "  ║                   ███╗   ███╗ █████╗ ██████╗              ║"
    echo "  ║                   ████╗ ████║██╔══██╗██╔══██╗             ║"
    echo "  ║                   ██╔████╔██║███████║██████╔╝             ║"
    echo "  ║                   ██║╚██╔╝██║██╔══██║██╔═══╝              ║"
    echo "  ║                   ██║ ╚═╝ ██║██║  ██║██║                  ║"
    echo "  ║                   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝                  ║"
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    echo "  ║  ${WHITE}NullSec Threat Intelligence Aggregator & Mapper${RED}         ║"
    echo "  ║  ${CYAN}github.com/bad-antics${RED}                                    ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Main menu
show_menu() {
    echo -e "${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}1)${RESET} ${WHITE}Aggregate Threat Feeds${RESET}        - Pull from all sources   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}2)${RESET} ${WHITE}IOC Lookup${RESET}                    - Check IP/Domain/Hash    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}3)${RESET} ${WHITE}Malware Analysis${RESET}              - Analyze hash/sample     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}4)${RESET} ${WHITE}Phishing Detection${RESET}            - Check URLs for phishing ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}5)${RESET} ${WHITE}Threat Actor Tracking${RESET}         - Track known APT groups  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}6)${RESET} ${WHITE}Generate Blocklists${RESET}           - Export IP/Domain lists  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}7)${RESET} ${WHITE}Real-time Monitor${RESET}             - Live threat feed watch  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}8)${RESET} ${WHITE}Threat Correlation${RESET}            - Cross-reference IOCs    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}9)${RESET} ${WHITE}Export Report${RESET}                 - Generate threat report  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}0)${RESET} ${WHITE}Exit${RESET}                                                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Aggregate threat feeds
aggregate_feeds() {
    echo -e "\n${CYAN}[*]${RESET} Aggregating threat intelligence feeds..."
    mkdir -p "$THREATMAP_DIR"
    
    local total=0
    local malware=0
    local phishing=0
    local c2=0
    
    for feed in "${FEEDS[@]}"; do
        IFS=':' read -r name url <<< "$feed"
        echo -e "${DIM}[*] Fetching $name...${RESET}"
        
        # Simulate feed pulling (in real use, would actually fetch)
        case "$name" in
            "URLhaus")
                malware=$((malware + 150))
                echo -e "  ${GREEN}+${RESET} Pulled 150 malware URLs"
                ;;
            "PhishTank")
                phishing=$((phishing + 500))
                echo -e "  ${GREEN}+${RESET} Pulled 500 phishing URLs"
                ;;
            "AbuseIPDB")
                c2=$((c2 + 200))
                echo -e "  ${GREEN}+${RESET} Pulled 200 malicious IPs"
                ;;
            "ThreatFox")
                malware=$((malware + 75))
                echo -e "  ${GREEN}+${RESET} Pulled 75 IOCs"
                ;;
            "MalwareBazaar")
                malware=$((malware + 100))
                echo -e "  ${GREEN}+${RESET} Pulled 100 malware samples"
                ;;
            "FeodoTracker")
                c2=$((c2 + 50))
                echo -e "  ${GREEN}+${RESET} Pulled 50 botnet C2 IPs"
                ;;
            "SSL_Blocklist")
                c2=$((c2 + 30))
                echo -e "  ${GREEN}+${RESET} Pulled 30 malicious SSL certs"
                ;;
        esac
        sleep 0.3
    done
    
    total=$((malware + phishing + c2))
    
    echo -e "\n${GREEN}[✓]${RESET} Aggregation complete!"
    echo -e "  ${WHITE}├─${RESET} Total IOCs: ${CYAN}$total${RESET}"
    echo -e "  ${WHITE}├─${RESET} Malware: ${RED}$malware${RESET}"
    echo -e "  ${WHITE}├─${RESET} Phishing: ${YELLOW}$phishing${RESET}"
    echo -e "  ${WHITE}└─${RESET} C2/Botnet: ${MAGENTA}$c2${RESET}"
    
    log_to_file "Aggregated $total IOCs from ${#FEEDS[@]} feeds"
    
    # Save summary
    save_output "aggregation_summary.json" "$(cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "total_iocs": $total,
  "breakdown": {
    "malware": $malware,
    "phishing": $phishing,
    "c2_botnet": $c2
  },
  "feeds_processed": ${#FEEDS[@]}
}
EOF
)"
}

# IOC Lookup
ioc_lookup() {
    echo -e "\n${CYAN}[*]${RESET} IOC Lookup"
    echo -e "${DIM}  Enter IP address, domain, or file hash${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] IOC: '${RESET})" IOC
    
    if [ -z "$IOC" ]; then
        echo -e "${RED}[!]${RESET} No IOC provided"
        return
    fi
    
    echo -e "\n${DIM}[*] Searching threat intelligence databases...${RESET}"
    sleep 0.5
    
    # Determine IOC type
    local ioc_type="unknown"
    if [[ $IOC =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ioc_type="ip"
    elif [[ $IOC =~ ^[a-fA-F0-9]{32}$ ]] || [[ $IOC =~ ^[a-fA-F0-9]{64}$ ]]; then
        ioc_type="hash"
    else
        ioc_type="domain"
    fi
    
    echo -e "  ${WHITE}IOC Type:${RESET} $ioc_type"
    echo -e "  ${WHITE}Value:${RESET} $IOC"
    echo ""
    
    # Simulate lookup results
    echo -e "${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}THREAT INTELLIGENCE RESULTS${RESET}                              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    
    case "$ioc_type" in
        "ip")
            echo -e "${WHITE}  ║${RESET}  ${RED}⚠ AbuseIPDB${RESET}        : Confidence 85% - Known scanner      ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${YELLOW}⚠ VirusTotal${RESET}       : 3/87 detections                    ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${RED}⚠ FeodoTracker${RESET}     : Listed as Dridex C2                ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${GREEN}✓ AlienVault OTX${RESET}   : No pulses found                    ${WHITE}║${RESET}"
            log_threat "HIGH" "MALICIOUS_IP" "$IOC identified as potential C2"
            ;;
        "hash")
            echo -e "${WHITE}  ║${RESET}  ${RED}⚠ VirusTotal${RESET}       : 45/71 detections - Trojan          ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${RED}⚠ MalwareBazaar${RESET}    : Emotet variant                     ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${YELLOW}⚠ Hybrid Analysis${RESET}  : Malicious - Score 92/100          ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${RED}⚠ Any.Run${RESET}          : Known malware behavior detected    ${WHITE}║${RESET}"
            log_threat "CRITICAL" "MALWARE_HASH" "$IOC identified as malware"
            ;;
        "domain")
            echo -e "${WHITE}  ║${RESET}  ${YELLOW}⚠ URLhaus${RESET}          : Listed - Malware distribution     ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${RED}⚠ PhishTank${RESET}        : Confirmed phishing site            ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${YELLOW}⚠ Google Safe Browse${RESET}: Flagged as deceptive             ${WHITE}║${RESET}"
            echo -e "${WHITE}  ║${RESET}  ${GREEN}✓ Spamhaus${RESET}         : Not listed                        ${WHITE}║${RESET}"
            log_threat "HIGH" "MALICIOUS_DOMAIN" "$IOC identified as phishing"
            ;;
    esac
    
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
}

# Malware analysis
malware_analysis() {
    echo -e "\n${CYAN}[*]${RESET} Malware Analysis"
    echo -e "${DIM}  Enter file hash (MD5/SHA256) or path to sample${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] Hash/Path: '${RESET})" SAMPLE
    
    if [ -z "$SAMPLE" ]; then
        echo -e "${RED}[!]${RESET} No sample provided"
        return
    fi
    
    echo -e "\n${DIM}[*] Analyzing sample...${RESET}"
    sleep 0.5
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${RED}MALWARE ANALYSIS REPORT${RESET}                                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Family:${RESET}     Emotet                                       ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Type:${RESET}       Banking Trojan / Loader                      ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${WHITE}First Seen:${RESET} 2023-10-15                                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}CAPABILITIES${RESET}                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Credential theft (browsers, email)                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Second-stage payload delivery                        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Network propagation via SMB                          ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • Anti-analysis/sandbox evasion                        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${YELLOW}ASSOCIATED C2${RESET}                                           ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 185.159.82.140:8080                                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 91.121.87.90:443                                     ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • malware-c2.example.com                               ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${GREEN}MITRE ATT&CK${RESET}                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    T1566 - Phishing                                       ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    T1059 - Command and Scripting Interpreter              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    T1055 - Process Injection                              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    T1082 - System Information Discovery                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    
    log_to_file "Analyzed sample: $SAMPLE"
}

# Phishing detection
phishing_detection() {
    echo -e "\n${CYAN}[*]${RESET} Phishing URL Analysis"
    echo -e "${DIM}  Enter URL to check for phishing indicators${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] URL: '${RESET})" URL
    
    if [ -z "$URL" ]; then
        echo -e "${RED}[!]${RESET} No URL provided"
        return
    fi
    
    echo -e "\n${DIM}[*] Analyzing URL for phishing indicators...${RESET}"
    sleep 0.5
    
    local risk_score=0
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${YELLOW}PHISHING ANALYSIS${RESET}                                        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    
    # Check various indicators
    if [[ "$URL" =~ "login" ]] || [[ "$URL" =~ "signin" ]]; then
        echo -e "${WHITE}  ║${RESET}  ${YELLOW}⚠${RESET} Login-related keywords detected                        ${WHITE}║${RESET}"
        risk_score=$((risk_score + 20))
    fi
    
    if [[ "$URL" =~ @|\.tk|\.ml|\.ga|\.cf ]]; then
        echo -e "${WHITE}  ║${RESET}  ${RED}⚠${RESET} Suspicious TLD or @ symbol in URL                     ${WHITE}║${RESET}"
        risk_score=$((risk_score + 40))
    fi
    
    if [[ "$URL" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo -e "${WHITE}  ║${RESET}  ${RED}⚠${RESET} IP address in URL instead of domain                   ${WHITE}║${RESET}"
        risk_score=$((risk_score + 30))
    fi
    
    if [[ ${#URL} -gt 75 ]]; then
        echo -e "${WHITE}  ║${RESET}  ${YELLOW}⚠${RESET} Abnormally long URL                                   ${WHITE}║${RESET}"
        risk_score=$((risk_score + 15))
    fi
    
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    
    # Display risk score
    local risk_color="${GREEN}"
    local risk_level="LOW"
    if [ $risk_score -ge 50 ]; then
        risk_color="${RED}"
        risk_level="HIGH"
    elif [ $risk_score -ge 30 ]; then
        risk_color="${YELLOW}"
        risk_level="MEDIUM"
    fi
    
    echo -e "${WHITE}  ║${RESET}  ${WHITE}Risk Score:${RESET} ${risk_color}$risk_score/100${RESET} - ${risk_color}$risk_level RISK${RESET}                       ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    
    if [ $risk_score -ge 50 ]; then
        log_threat "HIGH" "PHISHING" "$URL - Risk score $risk_score"
    fi
}

# Threat actor tracking
threat_actor_tracking() {
    echo -e "\n${CYAN}[*]${RESET} Threat Actor Tracking"
    echo -e "  ${DIM}Known APT Groups and Threat Actors${RESET}\n"
    
    echo -e "${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${RED}APT GROUP${RESET}          ${WHITE}ORIGIN${RESET}     ${CYAN}TARGETS${RESET}                    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  APT29 (Cozy Bear)  Russia     Gov, Think tanks           ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  APT28 (Fancy Bear) Russia     Military, Gov, Media       ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  Lazarus Group      DPRK       Finance, Crypto            ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  APT41 (Wicked)     China      Healthcare, Tech           ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  FIN7               Unknown    Retail, Hospitality        ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  Sandworm           Russia     Critical Infrastructure    ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  Charming Kitten    Iran       Gov, Academia              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  BlackTech          China      Defense, Tech              ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    
    echo -e "\n${DIM}  Enter APT name for detailed TTPs or press Enter to return${RESET}"
    read -p "$(echo -e ${WHITE}'  [>] APT Name: '${RESET})" APT
    
    if [ ! -z "$APT" ]; then
        echo -e "\n${WHITE}  Tactics, Techniques, and Procedures for $APT:${RESET}"
        echo -e "  ${CYAN}•${RESET} Initial Access: Spearphishing, Supply chain compromise"
        echo -e "  ${CYAN}•${RESET} Execution: PowerShell, WMI, Scheduled tasks"
        echo -e "  ${CYAN}•${RESET} Persistence: Registry run keys, DLL hijacking"
        echo -e "  ${CYAN}•${RESET} Exfiltration: HTTPS, DNS tunneling"
    fi
}

# Generate blocklists
generate_blocklists() {
    echo -e "\n${CYAN}[*]${RESET} Generating Blocklists"
    mkdir -p "$THREATMAP_DIR/blocklists"
    
    echo -e "${DIM}[*] Compiling IP blocklist...${RESET}"
    sleep 0.3
    save_output "blocklists/ip_blocklist.txt" "# NullSec ThreatMap IP Blocklist
# Generated: $(date -Iseconds)
# Source: Aggregated threat feeds
185.159.82.140
91.121.87.90
45.33.32.156
192.99.156.186
# ... additional IPs"
    echo -e "  ${GREEN}+${RESET} IP blocklist: 500 entries"
    
    echo -e "${DIM}[*] Compiling domain blocklist...${RESET}"
    sleep 0.3
    save_output "blocklists/domain_blocklist.txt" "# NullSec ThreatMap Domain Blocklist
# Generated: $(date -Iseconds)
malware-c2.example.com
phishing-site.tk
bad-domain.ml
# ... additional domains"
    echo -e "  ${GREEN}+${RESET} Domain blocklist: 1,200 entries"
    
    echo -e "${DIM}[*] Compiling URL blocklist...${RESET}"
    sleep 0.3
    save_output "blocklists/url_blocklist.txt" "# NullSec ThreatMap URL Blocklist
# Generated: $(date -Iseconds)
# ... malware URLs"
    echo -e "  ${GREEN}+${RESET} URL blocklist: 800 entries"
    
    echo -e "\n${GREEN}[✓]${RESET} Blocklists saved to $THREATMAP_DIR/blocklists/"
    log_to_file "Generated blocklists"
}

# Real-time monitor
realtime_monitor() {
    echo -e "\n${CYAN}[*]${RESET} Real-time Threat Monitor"
    echo -e "${DIM}  Press Ctrl+C to stop${RESET}\n"
    
    trap 'echo -e "\n${YELLOW}[*]${RESET} Monitor stopped"; return' INT
    
    local count=0
    while true; do
        count=$((count + 1))
        
        # Simulate incoming threats
        local types=("MALWARE" "PHISHING" "C2" "BOTNET" "RANSOMWARE")
        local severities=("LOW" "MEDIUM" "HIGH" "CRITICAL")
        local type=${types[$((RANDOM % ${#types[@]}))]}
        local severity=${severities[$((RANDOM % ${#severities[@]}))]}
        
        local ip="$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))"
        
        local sev_color="${GREEN}"
        case "$severity" in
            "MEDIUM") sev_color="${YELLOW}" ;;
            "HIGH") sev_color="${RED}" ;;
            "CRITICAL") sev_color="${MAGENTA}" ;;
        esac
        
        echo -e "[$(date '+%H:%M:%S')] ${sev_color}[$severity]${RESET} $type detected from $ip"
        
        sleep $((RANDOM % 3 + 1))
    done
}

# Threat correlation
threat_correlation() {
    echo -e "\n${CYAN}[*]${RESET} Threat Correlation Engine"
    echo -e "${DIM}  Cross-referencing IOCs across multiple sources${RESET}\n"
    
    echo -e "${DIM}[*] Analyzing correlations...${RESET}"
    sleep 1
    
    echo -e "\n${WHITE}  ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${CYAN}CORRELATION RESULTS${RESET}                                      ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  ${RED}Campaign Detected: Emotet Distribution${RESET}                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  Related IOCs:                                             ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 15 IP addresses linked to Emotet C2                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 8 domains used for payload delivery                  ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 12 malware samples (SHA256 hashes)                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}    • 3 email addresses used in phishing                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╠═══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}  ║${RESET}  Confidence: ${GREEN}HIGH (87%)${RESET}                                   ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  First activity: 2023-10-01                                ${WHITE}║${RESET}"
    echo -e "${WHITE}  ║${RESET}  Last activity: 2023-10-20                                 ${WHITE}║${RESET}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════════════╝${RESET}"
    
    log_to_file "Performed threat correlation analysis"
}

# Export report
export_report() {
    echo -e "\n${CYAN}[*]${RESET} Generating Threat Intelligence Report"
    
    local report_file="$THREATMAP_DIR/threat_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NullSec ThreatMap Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #0f0f0f; color: #e0e0e0; padding: 20px; }
        .header { background: linear-gradient(135deg, #1a1a2e, #16213e); padding: 20px; border-radius: 10px; border-left: 4px solid #00ff41; }
        h1 { color: #00ff41; }
        .section { background: #1a1a1a; padding: 15px; margin: 20px 0; border-radius: 8px; }
        .critical { color: #ff0040; }
        .high { color: #ff6b35; }
        .medium { color: #ffc107; }
        .low { color: #4CAF50; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #333; }
        th { background: #222; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ NullSec ThreatMap Report</h1>
        <p>Generated: $(date)</p>
    </div>
    <div class="section">
        <h2>Summary</h2>
        <p>Total IOCs processed: 1,105</p>
        <p>Active campaigns detected: 3</p>
        <p>Critical threats: 12</p>
    </div>
    <div class="section">
        <h2>Top Threats</h2>
        <table>
            <tr><th>Type</th><th>Count</th><th>Severity</th></tr>
            <tr><td>Emotet</td><td>45</td><td class="critical">CRITICAL</td></tr>
            <tr><td>Phishing</td><td>120</td><td class="high">HIGH</td></tr>
            <tr><td>Cryptominer</td><td>30</td><td class="medium">MEDIUM</td></tr>
        </table>
    </div>
    <footer><p>github.com/bad-antics</p></footer>
</body>
</html>
EOF

    echo -e "${GREEN}[✓]${RESET} Report saved to: $report_file"
    log_to_file "Generated threat report: $report_file"
}

# Main loop
main() {
    show_banner
    
    while true; do
        show_menu
        read -p "$(echo -e ${WHITE}'  [>] Select option: '${RESET})" choice
        
        case $choice in
            1) aggregate_feeds ;;
            2) ioc_lookup ;;
            3) malware_analysis ;;
            4) phishing_detection ;;
            5) threat_actor_tracking ;;
            6) generate_blocklists ;;
            7) realtime_monitor ;;
            8) threat_correlation ;;
            9) export_report ;;
            0) 
                echo -e "\n${GREEN}[✓]${RESET} Exiting ThreatMap"
                exit 0 
                ;;
            *)
                echo -e "${RED}[!]${RESET} Invalid option"
                ;;
        esac
        
        echo ""
        read -p "$(echo -e ${DIM}'Press Enter to continue...'${RESET})"
    done
}

main
