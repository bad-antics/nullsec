#!/bin/bash
#===============================================================================
#  NULLSEC RECON SUITE - Comprehensive Network Reconnaissance
#===============================================================================

LOOT_DIR="/root/loot/nullsec-recon"
mkdir -p "$LOOT_DIR"/{hosts,services,vulns,screenshots,osint}

log() { echo -e "\033[0;32m[+]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }

# Quick network discovery
discover_hosts() {
    local range="${1:-$(ip route | grep -v default | head -1 | awk '{print $1}')}"
    local output="$LOOT_DIR/hosts/discover_$(date +%s).txt"
    
    log "Discovering hosts in $range"
    
    # ARP scan (fastest for local)
    if command -v arp-scan &>/dev/null; then
        arp-scan -l 2>/dev/null | tee -a "$output"
    fi
    
    # Nmap ping sweep
    nmap -sn -T4 "$range" -oG - | grep "Up" | tee -a "$output"
    
    log "Results: $output"
}

# Service enumeration
enum_services() {
    local target="$1"
    local output="$LOOT_DIR/services/enum_${target}_$(date +%s)"
    
    log "Enumerating services on $target"
    
    # Quick port scan
    nmap -sS -T4 --top-ports 1000 "$target" -oA "${output}_ports"
    
    # Service versions
    nmap -sV -sC -T4 -p- "$target" -oA "${output}_full" &
    
    # Specific service checks
    # SMB
    if nc -zw2 "$target" 445 2>/dev/null; then
        log "SMB detected, enumerating..."
        enum4linux -a "$target" > "${output}_smb.txt" 2>/dev/null &
        smbclient -L "//$target" -N >> "${output}_smb.txt" 2>/dev/null &
    fi
    
    # HTTP/HTTPS
    for port in 80 443 8080 8443; do
        if nc -zw2 "$target" $port 2>/dev/null; then
            log "HTTP on port $port detected"
            whatweb "http://$target:$port" >> "${output}_web.txt" 2>/dev/null &
            nikto -h "$target" -p $port -o "${output}_nikto_$port.txt" 2>/dev/null &
        fi
    done
    
    # SNMP
    if nc -zuw2 "$target" 161 2>/dev/null; then
        log "SNMP detected"
        snmpwalk -v2c -c public "$target" > "${output}_snmp.txt" 2>/dev/null &
    fi
    
    wait
    log "Enumeration complete: $output"
}

# Vulnerability scan
vuln_scan() {
    local target="$1"
    local output="$LOOT_DIR/vulns/vuln_${target}_$(date +%s)"
    
    log "Scanning for vulnerabilities on $target"
    
    # Nmap vuln scripts
    nmap --script=vuln "$target" -oA "${output}_nmap"
    
    # Common CVE checks
    nmap --script=smb-vuln*,ms17-010 "$target" -p 445 >> "${output}_smb_vulns.txt" 2>/dev/null
    nmap --script=http-vuln* "$target" -p 80,443,8080 >> "${output}_http_vulns.txt" 2>/dev/null
    
    log "Vuln scan complete: $output"
}

# OSINT gathering
osint_gather() {
    local target="$1"
    local output="$LOOT_DIR/osint/osint_${target}_$(date +%s)"
    
    log "Gathering OSINT for $target"
    
    mkdir -p "$output"
    
    # DNS enumeration
    dig "$target" ANY +short > "${output}/dns_any.txt"
    dig "$target" MX +short > "${output}/dns_mx.txt"
    dig "$target" NS +short > "${output}/dns_ns.txt"
    dig "$target" TXT +short > "${output}/dns_txt.txt"
    
    # Subdomain enumeration
    if command -v subfinder &>/dev/null; then
        subfinder -d "$target" -o "${output}/subdomains.txt" 2>/dev/null
    fi
    
    # WHOIS
    whois "$target" > "${output}/whois.txt" 2>/dev/null
    
    # Shodan (if API key set)
    if [[ -n "$SHODAN_API_KEY" ]]; then
        curl -s "https://api.shodan.io/shodan/host/$target?key=$SHODAN_API_KEY" | \
            jq '.' > "${output}/shodan.json" 2>/dev/null
    fi
    
    log "OSINT complete: $output"
}

# Full auto recon
auto_recon() {
    local target="${1:-$(ip route | grep default | awk '{print $3}' | sed 's/\.[0-9]*$/.0\/24/')}"
    
    log "Starting full auto-recon on $target"
    
    # Phase 1: Discovery
    log "Phase 1: Host Discovery"
    discover_hosts "$target"
    
    # Get live hosts
    local hosts=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOOT_DIR/hosts/"*.txt 2>/dev/null | sort -u)
    
    # Phase 2: Enumeration
    log "Phase 2: Service Enumeration"
    for host in $hosts; do
        enum_services "$host" &
        sleep 2  # Throttle
    done
    wait
    
    # Phase 3: Vuln scan interesting hosts
    log "Phase 3: Vulnerability Scanning"
    for host in $hosts; do
        vuln_scan "$host" &
        sleep 5
    done
    wait
    
    # Generate report
    generate_report
}

# Generate summary report
generate_report() {
    local report="$LOOT_DIR/REPORT_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report" << REPORT
╔═══════════════════════════════════════════════════════════════════╗
║              NULLSEC RECONNAISSANCE REPORT                        ║
║              Generated: $(date)                     ║
╚═══════════════════════════════════════════════════════════════════╝

=== HOSTS DISCOVERED ===
$(cat "$LOOT_DIR/hosts/"*.txt 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)

=== OPEN PORTS SUMMARY ===
$(grep -h "open" "$LOOT_DIR/services/"*_ports.gnmap 2>/dev/null | sort -u)

=== VULNERABILITIES FOUND ===
$(grep -h "VULNERABLE" "$LOOT_DIR/vulns/"*.txt 2>/dev/null)

=== INTERESTING FINDINGS ===
$(grep -hiE "password|admin|root|credential|secret|key" "$LOOT_DIR/"*/*.txt 2>/dev/null | head -50)

REPORT
    
    log "Report generated: $report"
}

case "${1:-menu}" in
    discover) shift; discover_hosts "$@" ;;
    enum) shift; enum_services "$@" ;;
    vuln) shift; vuln_scan "$@" ;;
    osint) shift; osint_gather "$@" ;;
    auto) shift; auto_recon "$@" ;;
    report) generate_report ;;
    *)
        echo "NullSec Recon Suite"
        echo "Usage: $0 <command> [target]"
        echo ""
        echo "Commands:"
        echo "  discover [range]    - Host discovery"
        echo "  enum <target>       - Service enumeration"
        echo "  vuln <target>       - Vulnerability scan"
        echo "  osint <domain>      - OSINT gathering"
        echo "  auto [range]        - Full auto recon"
        echo "  report              - Generate report"
        ;;
esac
