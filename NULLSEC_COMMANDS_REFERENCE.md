# NULLSEC FRAMEWORK v2.0 - COMPLETE COMMAND REFERENCE
## Generated: 2026-01-13 | Author: bad-antics Development Team

═══════════════════════════════════════════════════════════════════════════════

## TABLE OF CONTENTS

1. [Framework Launch Commands](#framework-launch-commands)
2. [NULLSEC AI v3.0 Commands](#nullsec-ai-v30-commands)
3. [Attack Module Categories](#attack-module-categories)
4. [All 185 Attack Modules](#all-185-attack-modules)
5. [Pager/SSH Transfer Commands](#pagerssh-transfer-commands)
6. [Flipper Zero Commands](#flipper-zero-commands)
7. [Desktop GUI Usage](#desktop-gui-usage)

═══════════════════════════════════════════════════════════════════════════════

## FRAMEWORK LAUNCH COMMANDS

### Command Line Launcher
```bash
# Launch main framework
python3 nullsec-launcher.py

# With sudo (for privileged modules)
sudo python3 nullsec-launcher.py
```

### Desktop GUI
```bash
# Launch desktop version
python3 nullsec-desktop/nullsec_desktop.py

# Or use desktop shortcut
./nullsec-launcher.desktop
```

### NULLSEC AI
```bash
# Launch AI assistant
python3 nullsec-ai.py

# Install AI models (if needed)
bash install-ai.sh
```

═══════════════════════════════════════════════════════════════════════════════

## NULLSEC AI v3.0 COMMANDS

### Interactive Mode Commands

| Command | Description |
|---------|-------------|
| `set target <ip/domain>` | Set current target for attacks |
| `set category <name>` | Set attack category context |
| `models` | List available AI models |
| `install <model>` | Install Ollama model |
| `execute <cmd>` | Execute shell command |
| `history` | Show session history |
| `clear` | Clear screen |
| `help` | Show help |
| `exit` | Exit AI mode |

### Attack Categories

| Category | Focus Area |
|----------|------------|
| `network` | Port scanning, pivoting, protocols |
| `web` | OWASP Top 10, SQLi, XSS, APIs |
| `wireless` | WiFi, Bluetooth, RF, SDR |
| `credentials` | Password cracking, Kerberos, NTLM |
| `malware` | Payloads, C2, evasion, persistence |
| `recon` | OSINT, DNS, subdomain discovery |
| `cloud` | AWS, Azure, GCP exploitation |
| `mobile` | Android, iOS exploitation |
| `general` | General pentesting assistance |

### AI Models Available (12 Models ~73GB Total)

| Model | Size | Specialty |
|-------|------|-----------|
| `deepseek-coder:6.7b` | 3.8GB | Exploit development, shellcode |
| `codellama:13b` | 7.4GB | Code analysis, reverse engineering |
| `wizardlm2:7b` | 4.1GB | Complex reasoning |
| `mixtral:8x7b` | 26GB | Expert-level, most powerful |
| `mistral:7b` | 4.4GB | Fast general purpose |
| `openhermes` | 4.1GB | Instruction following |
| `solar` | 6.1GB | Advanced reasoning |
| `phi:2.7b` | 1.6GB | Lightweight, fast |
| `orca2:13b` | 7.4GB | Research-grade reasoning |
| `neural-chat:7b` | 4.1GB | Conversational intelligence |
| `starling-lm:7b` | 4.1GB | Fine-tuned for security |

### Example AI Queries

```
nullsec-ai> set target 192.168.1.100
nullsec-ai> set category network
nullsec-ai> scan for open ports and identify services
nullsec-ai> set category web
nullsec-ai> find sql injection vulnerabilities
nullsec-ai> generate xss payloads for waf bypass
nullsec-ai> set category credentials
nullsec-ai> crack this hash: 5f4dcc3b5aa765d61d8327deb882cf99
nullsec-ai> execute nmap -sV -sC 192.168.1.100
```

═══════════════════════════════════════════════════════════════════════════════

## ATTACK MODULE CATEGORIES

NULLSEC automatically organizes 185 modules into 22 categories:

| # | Category | Description | Module Count |
|---|----------|-------------|--------------|
| 1 | Network Attacks | Scanning, MITM, protocols | ~15 |
| 2 | Web Exploitation | SQLi, XSS, SSRF, APIs | ~20 |
| 3 | Wireless/RF | WiFi, Bluetooth, SDR | ~10 |
| 4 | Credential Attacks | Password, hash, Kerberos | ~12 |
| 5 | Malware/Payloads | C2, persistence, RAT | ~15 |
| 6 | Reconnaissance | OSINT, enumeration | ~10 |
| 7 | Cloud Security | AWS, Azure, GCP | ~8 |
| 8 | Mobile Attacks | Android, iOS | ~5 |
| 9 | Physical Security | Badge cloning, bypass | ~8 |
| 10 | ICS/SCADA | Industrial systems | ~10 |
| 11 | Social Engineering | Phishing, vishing | ~6 |
| 12 | Evasion | AV, EDR, AMSI bypass | ~10 |
| 13 | Post-Exploitation | Privesc, lateral | ~12 |
| 14 | Cryptography | Stego, encryption | ~5 |
| 15 | Container/Cloud | Docker, K8s, serverless | ~8 |
| 16 | Memory Attacks | Buffer overflow, ROP | ~8 |
| 17 | Windows Attacks | AD, tokens, UAC | ~12 |
| 18 | Linux Attacks | Privesc, kernel | ~8 |
| 19 | IoT/Embedded | Firmware, cameras | ~10 |
| 20 | Protocol Attacks | DNS, SNMP, VoIP | ~10 |
| 21 | Infrastructure | Network devices | ~8 |
| 22 | Other/Misc | Utilities, custom | ~10 |

═══════════════════════════════════════════════════════════════════════════════

## ALL 185 ATTACK MODULES

### Alphabetical Listing

| Module | Description | Category |
|--------|-------------|----------|
| `2fa-bypass.sh` | Two-factor authentication bypass | Credential Attacks |
| `ad-attack.sh` | Active Directory exploitation | Windows Attacks |
| `ai-attack.sh` | AI model exploitation | Web Exploitation |
| `ai-poison.sh` | AI/ML model poisoning | Malware/Payloads |
| `alarm-bypass.sh` | Physical alarm bypass | Physical Security |
| `amsi-bypass.sh` | AMSI bypass techniques | Evasion |
| `android-exploit.sh` | Android device exploitation | Mobile Attacks |
| `anti-debug.sh` | Anti-debugging techniques | Evasion |
| `anti-vm.sh` | Virtual machine detection | Evasion |
| `api-exploit.sh` | REST/GraphQL API attacks | Web Exploitation |
| `api-fuzzer.sh` | API endpoint fuzzing | Web Exploitation |
| `apt-attack.sh` | Advanced persistent threats | Malware/Payloads |
| `atm-jackpot.sh` | ATM exploitation (educational) | Physical Security |
| `av-evasion.sh` | Antivirus evasion | Evasion |
| `azure-exploit.sh` | Microsoft Azure attacks | Cloud Security |
| `bacnet-attack.sh` | Building automation protocol | ICS/SCADA |
| `badusb.sh` | BadUSB payload deployment | Physical Security |
| `bluetooth-attack.sh` | Bluetooth exploitation | Wireless/RF |
| `bootloader-unlock.sh` | Device bootloader attacks | Mobile Attacks |
| `c2-server.sh` | Command & control setup | Malware/Payloads |
| `camera-hijack.sh` | Security camera exploitation | IoT/Embedded |
| `captcha-bypass.sh` | CAPTCHA bypass techniques | Web Exploitation |
| `checkpoint-exploit.sh` | CheckPoint firewall attacks | Infrastructure |
| `cisco-asa-exploit.sh` | Cisco ASA exploitation | Infrastructure |
| `citrix-attack.sh` | Citrix vulnerability exploitation | Infrastructure |
| `cloud-attack.sh` | Multi-cloud attacks | Cloud Security |
| `cloud-enum.sh` | Cloud resource enumeration | Reconnaissance |
| `confluence-exploit.sh` | Atlassian Confluence RCE | Web Exploitation |
| `container-exploit.sh` | Container escape/exploitation | Container/Cloud |
| `cors-exploit.sh` | CORS misconfiguration attacks | Web Exploitation |
| `couchdb-attack.sh` | CouchDB exploitation | Web Exploitation |
| `cred-stuff.sh` | Credential stuffing attacks | Credential Attacks |
| `crypto-launder.sh` | Cryptocurrency tracing | Other/Misc |
| `cryptominer.sh` | Cryptominer deployment | Malware/Payloads |
| `csp-bypass.sh` | Content Security Policy bypass | Web Exploitation |
| `darkweb-ops.sh` | Tor/Dark web operations | Other/Misc |
| `database-exfil.sh` | Database exfiltration | Post-Exploitation |
| `ddos.sh` | DDoS attack simulation | Network Attacks |
| `deobfuscator.sh` | Code deobfuscation | Other/Misc |
| `dep-check.sh` | Dependency vulnerability check | Reconnaissance |
| `deserialization.sh` | Insecure deserialization | Web Exploitation |
| `dir-bruteforce.sh` | Directory brute forcing | Web Exploitation |
| `dll-injection.sh` | DLL injection techniques | Windows Attacks |
| `dns-amplify.sh` | DNS amplification attacks | Network Attacks |
| `dns-poison.sh` | DNS cache poisoning | Network Attacks |
| `dns-tunnel.sh` | DNS tunneling/exfiltration | Network Attacks |
| `docker-escape.sh` | Docker container escape | Container/Cloud |
| `edr-evasion.sh` | EDR evasion techniques | Evasion |
| `evidence-destroy.sh` | Anti-forensics | Post-Exploitation |
| `exchange-exploit.sh` | Microsoft Exchange RCE | Web Exploitation |
| `fast-flux.sh` | Fast-flux DNS network | Malware/Payloads |
| `fileless.sh` | Fileless malware techniques | Malware/Payloads |
| `firewall-bypass.sh` | Firewall bypass techniques | Network Attacks |
| `firmware-backdoor.sh` | Firmware backdoor injection | IoT/Embedded |
| `firmware-extract.sh` | Firmware extraction/analysis | IoT/Embedded |
| `fortinet-exploit.sh` | FortiGate exploitation | Infrastructure |
| `gcp-enum.sh` | Google Cloud enumeration | Cloud Security |
| `gitlab-attack.sh` | GitLab exploitation | Web Exploitation |
| `golden-ticket.sh` | Kerberos golden ticket | Windows Attacks |
| `graphql-attack.sh` | GraphQL exploitation | Web Exploitation |
| `grpc-exploit.sh` | gRPC service attacks | Web Exploitation |
| `heap-spray.sh` | Heap spray exploitation | Memory Attacks |
| `http2-exploit.sh` | HTTP/2 protocol attacks | Network Attacks |
| `http3-attack.sh` | HTTP/3 QUIC attacks | Network Attacks |
| `identity-forge.sh` | Identity document forgery | Social Engineering |
| `ids-evasion.sh` | IDS/IPS evasion | Evasion |
| `intrusion.sh` | General intrusion techniques | Network Attacks |
| `ios-attack.sh` | iOS device exploitation | Mobile Attacks |
| `iot-camera.sh` | IoT camera exploitation | IoT/Embedded |
| `jenkins-exploit.sh` | Jenkins CI/CD exploitation | Web Exploitation |
| `jira-exploit.sh` | Jira vulnerability exploitation | Web Exploitation |
| `juniper-attack.sh` | Juniper device attacks | Infrastructure |
| `jwt-attack.sh` | JWT token manipulation | Web Exploitation |
| `kafka-attack.sh` | Apache Kafka exploitation | Web Exploitation |
| `kerberoast.sh` | Kerberoasting attacks | Windows Attacks |
| `kernel-exploit.sh` | Kernel exploitation | Linux Attacks |
| `keylogger.sh` | Keylogger deployment | Malware/Payloads |
| `kubernetes-exploit.sh` | Kubernetes exploitation | Container/Cloud |
| `lateral-movement.sh` | Lateral movement techniques | Post-Exploitation |
| `ldap-injection.sh` | LDAP injection attacks | Web Exploitation |
| `linux-privesc.sh` | Linux privilege escalation | Linux Attacks |
| `lorawan-exploit.sh` | LoRaWAN exploitation | Wireless/RF |
| `macos-exploit.sh` | macOS exploitation | Other/Misc |
| `memcached-attack.sh` | Memcached exploitation | Network Attacks |
| `memcached.sh` | Memcached attacks | Network Attacks |
| `memory-exploit.sh` | Memory corruption attacks | Memory Attacks |
| `metamorphic-gen.sh` | Metamorphic code generator | Malware/Payloads |
| `mikrotik-attack.sh` | MikroTik router exploitation | Infrastructure |
| `mitm-attack.sh` | Man-in-the-middle attacks | Network Attacks |
| `mobile-attack.sh` | General mobile attacks | Mobile Attacks |
| `modbus-exploit.sh` | Modbus protocol attacks | ICS/SCADA |
| `mongodb-exploit.sh` | MongoDB exploitation | Web Exploitation |
| `msf-integration.rc` | Metasploit resource file | Other/Misc |
| `msf-launch.sh` | Metasploit launcher | Other/Misc |
| `nas-attack.sh` | NAS device exploitation | IoT/Embedded |
| `neo4j-exploit.sh` | Neo4j graph DB attacks | Web Exploitation |
| `netgear-exploit.sh` | Netgear device attacks | Infrastructure |
| `network-pivot.sh` | Network pivoting | Post-Exploitation |
| `nfc-attack.sh` | NFC exploitation | Physical Security |
| `oauth-exploit.sh` | OAuth/OIDC attacks | Web Exploitation |
| `packer-detector.sh` | Packer/crypter detection | Other/Misc |
| `palo-alto-attack.sh` | Palo Alto firewall attacks | Infrastructure |
| `pass-hash.sh` | Pass-the-hash attacks | Windows Attacks |
| `password-crack.sh` | Password cracking suite | Credential Attacks |
| `pci-exploit.sh` | PCI device exploitation | Memory Attacks |
| `persistence.sh` | Persistence mechanisms | Post-Exploitation |
| `physical-bypass.sh` | Physical security bypass | Physical Security |
| `plc-attack.sh` | PLC exploitation | ICS/SCADA |
| `polymorphic-gen.sh` | Polymorphic code generator | Malware/Payloads |
| `port-scanner.sh` | Port scanning suite | Reconnaissance |
| `power-grid.sh` | Power grid attacks | ICS/SCADA |
| `pretexting.sh` | Social engineering pretexts | Social Engineering |
| `printer-exploit.sh` | Printer exploitation | IoT/Embedded |
| `process-hollow.sh` | Process hollowing | Windows Attacks |
| `process-injection.sh` | Process injection techniques | Windows Attacks |
| `protobuf-attack.sh` | Protocol buffer attacks | Web Exploitation |
| `proxy-chain.sh` | Proxy chain setup | Network Attacks |
| `qnap-exploit.sh` | QNAP NAS exploitation | IoT/Embedded |
| `quic-attack.sh` | QUIC protocol attacks | Network Attacks |
| `race-condition.sh` | Race condition exploits | Web Exploitation |
| `ransomware.sh` | Ransomware simulation | Malware/Payloads |
| `rat-deploy.sh` | RAT deployment | Malware/Payloads |
| `redis-exploit.sh` | Redis exploitation | Web Exploitation |
| `rf-jammer.sh` | RF jamming attacks | Wireless/RF |
| `rfid-clone.sh` | RFID cloning | Physical Security |
| `rootkit.sh` | Rootkit deployment | Malware/Payloads |
| `rop-chain.sh` | ROP chain generator | Memory Attacks |
| `s3-bucket-finder.sh` | AWS S3 bucket enumeration | Cloud Security |
| `saml-exploit.sh` | SAML assertion attacks | Web Exploitation |
| `sandbox-escape.sh` | Sandbox escape techniques | Evasion |
| `satellite-hack.sh` | Satellite communication attacks | Wireless/RF |
| `scada-attack.sh` | SCADA system attacks | ICS/SCADA |
| `scada-exploit.sh` | SCADA exploitation | ICS/SCADA |
| `session-hijack.sh` | Session hijacking | Web Exploitation |
| `sharepoint-attack.sh` | SharePoint exploitation | Web Exploitation |
| `shellcode-gen.sh` | Shellcode generator | Memory Attacks |
| `shodan-search.sh` | Shodan search integration | Reconnaissance |
| `simulate.sh` | Attack simulation | Other/Misc |
| `sip-flood.sh` | SIP flooding attacks | Protocol Attacks |
| `slowloris.sh` | Slowloris DoS attack | Network Attacks |
| `smart-tv-exploit.sh` | Smart TV exploitation | IoT/Embedded |
| `smishing.sh` | SMS phishing | Social Engineering |
| `social-engineering.sh` | Social engineering toolkit | Social Engineering |
| `sonicwall-attack.sh` | SonicWall exploitation | Infrastructure |
| `sso-attack.sh` | Single sign-on attacks | Credential Attacks |
| `ssti-exploit.sh` | Server-side template injection | Web Exploitation |
| `stego.sh` | Steganography tools | Cryptography |
| `subdomain-takeover.sh` | Subdomain takeover | Web Exploitation |
| `supply-chain.sh` | Supply chain attacks | Malware/Payloads |
| `synology-attack.sh` | Synology NAS attacks | IoT/Embedded |
| `template-injection.sh` | Template injection | Web Exploitation |
| `thrift-exploit.sh` | Apache Thrift attacks | Web Exploitation |
| `thunderbolt-attack.sh` | Thunderbolt DMA attacks | Physical Security |
| `token-impersonate.sh` | Token impersonation | Windows Attacks |
| `token-manipulation.sh` | Token manipulation | Windows Attacks |
| `tor-service.sh` | Tor hidden service setup | Other/Misc |
| `uac-bypass.sh` | UAC bypass techniques | Windows Attacks |
| `ubiquiti-exploit.sh` | Ubiquiti device attacks | Infrastructure |
| `unpacker.sh` | Malware unpacker | Other/Misc |
| `usb-attack.sh` | USB attack vectors | Physical Security |
| `vishing.sh` | Voice phishing | Social Engineering |
| `vlan-hop.sh` | VLAN hopping | Network Attacks |
| `vmware-exploit.sh` | VMware exploitation | Container/Cloud |
| `voip-attack.sh` | VoIP exploitation | Protocol Attacks |
| `vpn-tunnel.sh` | VPN tunneling | Network Attacks |
| `waf-bypass.sh` | WAF bypass techniques | Web Exploitation |
| `water-system.sh` | Water system attacks | ICS/SCADA |
| `watering-hole.sh` | Watering hole attacks | Social Engineering |
| `web-exploit.sh` | General web exploitation | Web Exploitation |
| `webshell.sh` | Webshell deployment | Web Exploitation |
| `websocket-attack.sh` | WebSocket attacks | Web Exploitation |
| `wifi-deauth.sh` | WiFi deauthentication | Wireless/RF |
| `windows-exploit.sh` | Windows exploitation | Windows Attacks |
| `worm.sh` | Worm propagation | Malware/Payloads |
| `xpath-injection.sh` | XPath injection | Web Exploitation |
| `xss-attack.sh` | Cross-site scripting | Web Exploitation |
| `xxe-exploit.sh` | XML external entity | Web Exploitation |
| `zero-day.sh` | Zero-day simulation | Memory Attacks |
| `zigbee-attack.sh` | Zigbee exploitation | Wireless/RF |
| `zigbee-exploit.sh` | Zigbee protocol attacks | Wireless/RF |
| `zwave-attack.sh` | Z-Wave exploitation | Wireless/RF |

═══════════════════════════════════════════════════════════════════════════════

## PAGER/SSH TRANSFER COMMANDS

Source: `pager.sh`

```bash
# Load pager commands
source /home/antics/nullsec/pager.sh

# Available commands:
pager_ping        # Check if Pager is online
pager_ssh         # SSH into Pager
pager_exec <cmd>  # Execute command on Pager
pager_info        # Get Pager system info
pager_payloads    # List available payloads
pager_themes      # List available themes
pager_run <path>  # Run a payload
pager_loot        # View loot directory
pager_upload <local> <remote>   # Upload file to Pager
pager_download <remote> <local> # Download file from Pager
pager_internet    # Enable internet sharing
pager_web         # Open Pager web interface
pager_help        # Show help menu
```

═══════════════════════════════════════════════════════════════════════════════

## FLIPPER ZERO COMMANDS

Source: `flipper.sh`

```bash
# Load flipper commands
source /home/antics/nullsec/flipper.sh

# Flipper Zero integration commands
flipper_connect   # Connect to Flipper Zero
flipper_upload    # Upload payloads
flipper_download  # Download captured data
flipper_cli       # Interactive CLI
flipper_update    # Update firmware
```

═══════════════════════════════════════════════════════════════════════════════

## DESKTOP GUI USAGE

### Launch
```bash
cd /home/antics/nullsec/nullsec-desktop
python3 nullsec_desktop.py
```

### Features
- Category-based module browser
- Search functionality
- One-click module execution
- Module favorites
- Dark theme interface
- Real-time output display

### Keyboard Shortcuts
- `Ctrl+F` - Search modules
- `Ctrl+Q` - Quit
- `Enter` - Run selected module
- `Escape` - Cancel/Back

═══════════════════════════════════════════════════════════════════════════════

## QUICK START EXAMPLES

### Basic Network Recon
```bash
python3 nullsec-launcher.py
# Select: Port Scanner
# Enter target IP
```

### AI-Assisted Attack
```bash
python3 nullsec-ai.py
> set target 192.168.1.100
> set category network
> scan target and identify vulnerabilities
```

### Run Specific Module
```bash
cd /home/antics/nullsec/nullsecurity
sudo bash port-scanner.sh
```

### Transfer Files to Remote
```bash
source pager.sh
pager_upload ./payload.sh /root/payloads/
pager_run /root/payloads/payload.sh
```

═══════════════════════════════════════════════════════════════════════════════

## DIRECTORY STRUCTURE

```
nullsec/
├── nullsec-launcher.py      # Main CLI launcher
├── nullsec-ai.py            # AI assistant v3.0
├── install-ai.sh            # AI installation wizard
├── pager.sh                 # SSH/transfer commands
├── flipper.sh               # Flipper Zero integration
├── nullsec-desktop/         # Desktop GUI
│   ├── nullsec_desktop.py   # Main desktop app
│   └── config.json          # Desktop configuration
├── nullsecurity/            # 185 attack modules
├── nullsec-flipper/         # Flipper Zero tools
├── nullsec-pineapple/       # WiFi Pineapple tools
├── nullsec-pentester/       # Pentester toolkit
└── static/                  # Static resources
```

═══════════════════════════════════════════════════════════════════════════════

## REQUIREMENTS

### Python Dependencies
- Python 3.8+
- requests (for AI)
- gi (GTK for desktop)

### System Tools
- nmap, masscan
- hydra, medusa
- sqlmap
- gobuster/ffuf
- metasploit-framework
- aircrack-ng
- hashcat/john

### AI Requirements
- Ollama (recommended)
- 4GB+ RAM (8GB recommended)
- 50GB+ storage for models

═══════════════════════════════════════════════════════════════════════════════

## LEGAL DISCLAIMER

This framework is for AUTHORIZED SECURITY TESTING ONLY.

- Always obtain written permission before testing
- Only test systems you own or have authorization for
- Follow responsible disclosure practices
- Comply with all applicable laws and regulations

The developers are not responsible for misuse of this tool.

═══════════════════════════════════════════════════════════════════════════════
                    NULLSEC Framework v2.0 | bad-antics
═══════════════════════════════════════════════════════════════════════════════
