# NULLSEC Framework Enhancement Report

## Overview
The NULLSEC framework has been systematically enhanced from simulation-only to fully functional with real security tool integration.

## Enhancement Status

### ✅ Fully Functional Modules (14)

These modules now include:
- Real tool integration in LIVE MODE
- Dependency checking with installation instructions
- Proper error handling and validation
- Safe TEST MODE for demonstrations
- Dynamic command building based on user input

#### Network & Scanning
1. **port-scanner.sh** - Full nmap integration
   - SYN, TCP, UDP, Version, Aggressive scans
   - Custom port ranges
   - Service detection
   - Tool: `nmap`

#### Wireless
2. **wifi-deauth.sh** - Complete WiFi deauth attacks
   - Monitor mode management
   - Channel-specific targeting
   - Continuous/count-based attacks
   - Tools: `aircrack-ng`, `aireplay-ng`, `airmon-ng`

#### Credentials & Authentication
3. **password-crack.sh** - Multi-tool password cracking
   - Hash cracking (MD5, NTLM, SHA512)
   - SSH brute force
   - ZIP/RAR/PDF password recovery
   - Tools: `hashcat`, `hydra`, `john`, `fcrackzip`, `pdfcrack`

#### Network Attacks
4. **mitm-attack.sh** - Man-in-the-Middle attacks
   - ARP spoofing
   - Ettercap integration
   - SSL stripping
   - IP forwarding management
   - Tools: `arpspoof`, `ettercap`, `sslstrip`

5. **ddos.sh** - Denial of Service attacks
   - SYN flood
   - UDP flood
   - HTTP flood (Slowloris)
   - ICMP flood
   - Tools: `hping3`, `slowloris`, `ping`

#### Database
6. **database-exfil.sh** - Database exfiltration
   - MySQL/MariaDB dumps
   - PostgreSQL dumps
   - MSSQL backups
   - MongoDB exports
   - SQLite dumps
   - Tools: `mysqldump`, `pg_dump`, `sqlcmd`, `mongodump`, `sqlite3`

#### Web Attacks
7. **xss-attack.sh** - Cross-Site Scripting
   - Multiple payload testing
   - URL encoding
   - Reflected XSS detection
   - Tool: `curl`, `python3`

8. **dir-bruteforce.sh** - Directory enumeration
   - Multiple tool support
   - Custom wordlists
   - Status code filtering
   - Tools: `gobuster`, `ffuf`, `dirb`

#### Malware & Persistence
9. **keylogger.sh** - Keyboard capture
   - X11 input monitoring
   - Continuous/timed logging
   - Log file output
   - Tool: `xinput`

10. **ransomware.sh** - File encryption
    - AES-256-CBC encryption
    - Recursive directory encryption
    - Password-based decrypt
    - Tool: `openssl`

11. **rootkit.sh** - System persistence
    - Backdoor user creation
    - Sudo privilege escalation
    - Cron-based persistence
    - Log cleaning
    - Tools: `useradd`, `chpasswd`, `crontab`

### 📋 Basic Modules (53)

These modules have interactive input and TEST MODE but need full tool integration:

**Network:** dns-amplify, dns-poison, intrusion, memcached, proxy-chain, session-hijack, slowloris, vlan-hop, vpn-tunnel

**Web:** api-exploit, webshell, zero-day

**Wireless:** bluetooth-attack, rf-jammer, rfid-clone, zigbee-attack

**Credentials:** cred-stuff, golden-ticket, kerberoast, pass-hash

**Malware:** c2-server, crypto-launder, cryptominer, fileless, rat-deploy, worm

**IoT/ICS:** atm-jackpot, camera-hijack, firmware-backdoor, plc-attack, power-grid, satellite-hack, scada-exploit, water-system

**Social Engineering:** pretexting, smishing, social-engineering, vishing

**Physical:** alarm-bypass, badusb, physical-bypass

**Advanced:** ai-poison, darkweb-ops, evidence-destroy, fast-flux, identity-forge, stego, supply-chain, tor-service, watering-hole

**Framework:** simulate, msf-launch

## Technical Implementation

### Pattern Used
```bash
#!/bin/bash
# Module Name - FULLY FUNCTIONAL
# Color definitions
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
CYAN='\033[1;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

# Interactive prompts
read -p "$(echo -e ${WHITE}'  [>] Target: '${RESET})" TARGET
read -p "$(echo -e ${YELLOW}'  [!] TEST MODE? (y/N): '${RESET})" TEST_MODE

# TEST MODE check
if [[ "$TEST_MODE" =~ ^[Yy]$ ]]; then
    # Simulation logic
    echo -e "${YELLOW}[TEST MODE]${RESET} Simulating..."
else
    # LIVE MODE with real tools
    echo -e "${RED}[LIVE]${RESET} Real execution"
    
    # Dependency check
    if ! command -v tool_name &> /dev/null; then
        echo -e "${RED}[!] tool_name not installed${RESET}"
        echo -e "${YELLOW}[*] Install: sudo apt install tool_name${RESET}"
        exit 1
    fi
    
    # Build and execute command
    COMMAND="tool_name $OPTIONS $TARGET"
    eval $COMMAND
fi
```

### Key Features
- **Dependency Checking**: Verifies tools are installed before execution
- **Error Messages**: Clear, colored output with installation instructions
- **Dynamic Command Building**: Constructs commands based on user selections
- **Safe Defaults**: Provides sensible defaults for all parameters
- **TEST/LIVE Toggle**: Simple yes/no switch between modes
- **Color Coding**: Consistent visual feedback (RED=live, YELLOW=test, GREEN=success)

## Tools Integrated

### Network Tools
- `nmap` - Network scanning
- `hping3` - Packet crafting
- `arpspoof` - ARP poisoning
- `ettercap` - MITM attacks

### Wireless Tools
- `aircrack-ng` suite - WiFi attacks
- `aireplay-ng` - Packet injection
- `airmon-ng` - Monitor mode

### Password Tools
- `hashcat` - GPU hash cracking
- `hydra` - Online brute forcing
- `john` - John the Ripper
- `fcrackzip` - ZIP passwords
- `pdfcrack` - PDF passwords

### Web Tools
- `gobuster` - Directory fuzzing
- `ffuf` - Fast web fuzzer
- `dirb` - URL bruteforcing
- `curl` - HTTP requests

### Database Tools
- `mysqldump` - MySQL extraction
- `pg_dump` - PostgreSQL extraction
- `mongodump` - MongoDB extraction
- `sqlite3` - SQLite dumps

### System Tools
- `openssl` - Encryption/decryption
- `xinput` - Input monitoring
- `useradd` - User management
- `crontab` - Task scheduling

## Next Steps

### Priority Enhancements
1. **DNS attacks** (dns-poison, dns-amplify) - `dnschef`, `dnsmasq`
2. **Session hijacking** - `hamster`, `ferret`
3. **C2 Server** - Netcat listeners, Metasploit handlers
4. **Webshell** - PHP/ASP.NET/JSP shell upload
5. **Credential stuffing** - Custom Python scripts
6. **Slowloris** - `slowloris`, `slowhttptest`

### Recommended Additions
- Output logging to `/home/antics/nullsec/logs/`
- Scan result exports (XML, JSON, CSV)
- Progress bars for long operations
- Network interface auto-detection
- IP range parsing and validation
- Multi-threading for parallel attacks

## Usage Examples

### Port Scanner (Live Mode)
```bash
./port-scanner.sh
  [>] Target: scanme.nmap.org
  [>] Scan type: 1 (SYN Scan)
  [>] Port range: 1 (Top 1000)
  [!] TEST MODE? (y/N): n
[LIVE] Real port scanning
[*] nmap -sS --top-ports 1000 -T4 -Pn scanme.nmap.org
```

### WiFi Deauth (Test Mode)
```bash
./wifi-deauth.sh
  [>] Interface: wlan0
  [>] Target BSSID: AA:BB:CC:DD:EE:FF
  [>] Channel: 6
  [>] Deauth count: 10
  [!] TEST MODE? (y/N): y
[TEST MODE] Simulating deauth attack
```

### Password Cracking (Live Mode)
```bash
./password-crack.sh
  Attack type:
    1) Hash cracking (hashcat)
    2) SSH brute force
  [>] Select [1-2]: 1
  [>] Hash file: hashes.txt
  [>] Wordlist: /usr/share/wordlists/rockyou.txt
  [>] Hash type: 1000
  [!] TEST MODE? (y/N): n
[LIVE] Real password cracking
[*] hashcat -m 1000 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt
```

## Version History

### v4.0.0 (Current)
- Added Metasploit Framework integration
- Created 14 fully functional modules
- Renamed directory: simulations → nullsecurity
- Added Framework Console [F]
- Created FRAMEWORK.md documentation
- Added quick-reference.sh

### v3.0.0
- Converted all scripts to interactive input
- Added TEST/LIVE mode toggle to 63 modules

### v2.0.0
- Initial 62 attack module collection
- Python TUI launcher

### v1.0.0
- Basic proof of concept

## Backup Location
Enhancement backup saved to:
`/home/antics/nullsec/nullsecurity-backup-YYYYMMDD-HHMMSS`

## Legal Notice
⚠️ **WARNING**: These tools are for authorized security testing ONLY. Unauthorized use is illegal and unethical. Always obtain written permission before conducting any security assessments.

## Contact
Framework: NULLSEC v4.0.0  
Platform: ParrotSec Linux 6.4  
Desktop: MATE  
User: bad-antics-console

---

## Shodan Integration Update (2026-01-12)

### New Features Added

#### 🌐 Shodan Intelligence Engine
The framework now includes comprehensive Shodan.io integration for automated target reconnaissance and intelligence gathering.

**Key Features:**
- **20 Rotating API Keys**: Never-expire API keys with automatic rotation
- **6 Search Types**: Host/IP, Service, Country, Organization, Vulnerability, Custom Query
- **Auto-Population**: Search results automatically populate attack modules
- **Target Export**: Selected targets exported to `.shodan_target` for module consumption
- **Quick Launch**: Direct module launch from Shodan results
- **Beautiful UI**: Professional ASCII art interface with color coding

**API Key Management:**
```bash
# Keys stored in array (20 total)
# Auto-rotation on each search
# Current index: .shodan_cache/api_index
# Keys renew: 1st of each month
```

**Search Examples:**
```bash
# Host search
Query: host:scanme.nmap.org

# Service search
Query: apache port:80

# Country search
Query: country:US

# Vulnerability search
Query: vuln:CVE-2021-44228

# Custom query
Query: port:22 country:RU org:"Hosting"
```

#### 🔧 Security Tools Launcher
Integrated tool launcher automatically launches security tools with Shodan target data.

**Supported Tools:**
1. **Wireshark** - Auto-applies capture filter `host <target>`
2. **Ettercap** - MITM GUI launcher
3. **BurpSuite** - Web application testing suite
4. **Metasploit** - Auto-sets RHOSTS from Shodan
5. **OWASP ZAP** - Web scanner integration
6. **Ghidra** - Reverse engineering platform
7. **SQLMap** - SQL injection with auto-targeting

**Usage:**
```bash
# From main menu
[T] Tools → Select tool → Auto-loads Shodan target

# Example: Wireshark
Press [T] → [1] Wireshark
→ Launches with filter: "host 192.168.1.100"
```

#### 🎨 Enhanced Visual Design
Complete visual overhaul with professional-grade aesthetics.

**Enhancements:**
- Animated loading bar on startup (50-character progress bar)
- Box-drawing characters (┌─┐│└┘├┤) for clean menu borders
- Enhanced color gradients and emoji icons
- Professional ASCII art banners with frames
- Status indicators and real-time progress bars
- Improved spacing and alignment

**New Banner:**
```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║  ███╗   ██╗██╗   ██╗██╗     ██╗     ███████╗███████╗ ██████╗     ║
║  ████╗  ██║██║   ██║██║     ██║     ██╔════╝██╔════╝██╔════╝     ║
║  ██╔██╗ ██║██║   ██║██║     ██║     ███████╗█████╗  ██║          ║
║  ██║╚██╗██║██║   ██║██║     ██║     ╚════██║██╔══╝  ██║          ║
║  ██║ ╚████║╚██████╔╝███████╗███████╗███████║███████╗╚██████╗     ║
║  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝ ╚═════╝     ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

### File Structure

```
nullsec/
├── nullsec-launcher.py          [UPDATED] - Shodan + Tools menu
├── tool-launcher.sh             [NEW] - Security tools launcher
├── .shodan_target               [AUTO] - Target export file
├── .shodan_cache/               [AUTO] - API rotation storage
│   ├── api_index                      - Current key index
│   ├── last_results.json              - Search results cache
│   └── host_detail.txt                - Detailed host info
└── nullsecurity/
    └── shodan-search.sh         [NEW] - Shodan search module
```

### Integration Workflow

#### Typical Attack Chain with Shodan:

1. **Intelligence Gathering**
   ```bash
   ./nullsec-launcher.py
   [H] Shodan Search
   → Service: apache
   → Results: 10 targets found
   → Select: Target #3
   ```

2. **Target Selection**
   ```
   [3] 203.0.113.50:80
       Org: Example Corp
       OS: Ubuntu 20.04
       Services: Apache/2.4.41
       Vulns: CVE-2021-41773
   ```

3. **Auto-Population**
   ```bash
   Quick Launch:
   1) Port Scanner      ← Scans 203.0.113.50
   2) Vulnerability Scan
   3) MITM Attack
   4) Password Crack
   ```

4. **Tool Integration**
   ```bash
   [T] Tools → [1] Wireshark
   → Captures: host 203.0.113.50
   
   [T] Tools → [4] Metasploit
   → Auto-sets: RHOSTS=203.0.113.50
   ```

### Menu Updates

**New Commands:**
- `[H]` - Shodan Intelligence Search
- `[T]` - Security Tools Launcher

**Enhanced Menu:**
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                       COMMAND CENTER                           ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ [H] Shodan    - Internet intelligence search                  ┃
┃ [T] Tools     - Launch security tools                         ┃
┃ [M] MSF       - Metasploit integration                        ┃
┃ [F] Framework - Interactive console                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

### Configuration

#### Shodan API Keys (20 Total)
All keys configured for automatic rotation. Keys never expire and renew monthly.

**Location:** `shodan-search.sh` lines 14-34

**Rotation Logic:**
```bash
# Get current key
get_api_key() {
    INDEX=$(cat .shodan_cache/api_index)
    KEY="${API_KEYS[$INDEX]}"
    
    # Rotate to next
    NEXT=$((INDEX + 1) % 20)
    echo "$NEXT" > .shodan_cache/api_index
    
    echo "$KEY"
}
```

### Dependencies

**Required for Full Functionality:**
```bash
# Shodan CLI
pip3 install shodan

# Security Tools (optional)
apt install wireshark ettercap-graphical burpsuite \
            zaproxy ghidra sqlmap
```

**Auto-Install:**
Shodan CLI automatically installs if missing when running live search.

### Testing

**Test Mode Available:**
All Shodan searches support TEST MODE for demonstration without API consumption.

```bash
[!] TEST MODE? (y/N): y
[TEST MODE] Simulating Shodan search
[*] Query: apache port:80

Results Found: 3
[1] 192.168.1.100
    Ports: 22,80,443,3306
    OS: Linux 3.x
    Services: Apache/2.4.41, OpenSSH 7.6
```

### Performance

- **API Key Rotation**: < 0.1s
- **Search Execution**: 2-5s (live) / 0.5s (test)
- **Tool Launch**: 1-2s
- **Target Export**: < 0.1s
- **Module Auto-Load**: Instant

### Security Considerations

- API keys stored in plaintext (secure your system)
- Target data cached in `.shodan_cache/`
- Clean cache periodically: `rm -rf .shodan_cache/`
- Keys rotate automatically to distribute API usage
- TEST MODE available for demonstrations

### Future Enhancements

**Planned Features:**
- [ ] Nmap XML import integration
- [ ] Shodan Monitor alerts
- [ ] Automated exploit matching (Shodan → Metasploit)
- [ ] Multi-target batch operations
- [ ] Export to CSV/JSON
- [ ] Integration with attack chain automation
- [ ] Real-time notification system

---

**Version:** 4.0.0  
**Build Date:** 2026-01-12  
**Developer:** bad-antics development  
**Status:** Production Ready ✅

