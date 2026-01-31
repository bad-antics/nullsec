# NULLSEC FRAMEWORK
**Advanced Penetration Testing & Red Team Operations Framework**

*Developed by bad-antics development*

---

## 🎯 Overview

NULLSEC Framework is a comprehensive offensive security operations platform that integrates custom attack modules with Metasploit Framework capabilities. Designed for professional penetration testers and red team operators.

**Version:** 4.0.0  
**Modules:** 62 custom attack scripts + full MSF integration  
**Platform:** ParrotSec Linux / Kali Linux / Debian-based systems

---

## 🔥 Key Features

### Custom Attack Modules (62 total)
- **Network Attacks** - Port scanning, intrusion, MITM, DNS poisoning, VLAN hopping
- **Wireless Warfare** - WiFi deauth, Bluetooth attacks, RFID cloning, RF jamming, Zigbee
- **Web Exploitation** - SQLi, XSS, webshells, API exploits, session hijacking
- **Malware Operations** - Ransomware, RATs, rootkits, keyloggers, cryptominers
- **Social Engineering** - Phishing, vishing, smishing, watering holes, pretexting
- **Advanced Attacks** - APT kill chains, zero-days, supply chain, firmware backdoors
- **Credential Attacks** - Password cracking, stuffing, Kerberoasting, Pass-the-Hash
- **Infrastructure** - C2 servers, proxy chains, VPN tunnels, Tor services
- **Physical Security** - Lock bypasses, BadUSB, camera hijacking, alarm defeats
- **OPSEC & Dark Ops** - Crypto laundering, identity forgery, evidence destruction
- **DDoS & Disruption** - Multi-vector flooding, Slowloris, DNS amplification
- **ICS/SCADA** - Industrial control system attacks, PLC manipulation, critical infrastructure

### Metasploit Integration
- **Direct MSF Console** - Launch msfconsole with NULLSEC integration
- **Payload Generator** - Quick msfvenom payload creation
- **Multi Handler** - Automated listener setup
- **Resource Scripts** - Pre-configured MSF automation
- **Database Integration** - Shared workspace management

### Framework Console
- **Interactive Shell** - MSF-style command interface
- **Module Management** - Use, search, info, run commands
- **Context Awareness** - Module selection and options
- **Quick Launch** - Direct module execution

---

## 📦 Installation

```bash
# Clone repository
git clone https://github.com/bad-antics/nullsec
cd nullsec

# Install dependencies (ParrotSec/Kali recommended)
sudo apt update
sudo apt install -y python3 metasploit-framework nmap aircrack-ng hydra

# Make launcher executable
chmod +x nullsec nullsec-launcher.py

# Launch framework
./nullsec
```

---

## 🚀 Quick Start

### Main Launcher
```bash
# Launch interactive TUI
./nullsec

# Or directly
python3 nullsec-launcher.py
```

### Framework Console (MSF-style)
```bash
# In main menu, press [F] for Framework Console
# Then use MSF-style commands:
use 1              # Select network intrusion module
show options       # Display module info
run               # Execute module
search wifi       # Search for modules
msfconsole        # Launch Metasploit
```

### Metasploit Integration
```bash
# In main menu, press [M] for MSF Integration
# Options:
# 1 - Launch msfconsole
# 2 - MSFVenom payload generator
# 6 - Generate reverse shell
# 9 - Multi handler setup

# Or launch directly:
./nullsecurity/msf-launch.sh
```

### Direct Module Execution
```bash
# Run individual attack modules
cd nullsecurity
./port-scanner.sh
./wifi-deauth.sh
./ransomware.sh
```

---

## 📚 Usage Examples

### Example 1: Network Penetration Test
```
1. Launch nullsec framework
2. Select [1] Network Intrusion
3. Enter target: 192.168.1.0/24
4. Choose TEST MODE for safe demo
5. Review results
```

### Example 2: Generate Malware Payload
```
1. Press [M] for MSF Integration
2. Select [6] Generate Reverse Shell
3. Enter LHOST: <your IP>
4. Enter LPORT: 4444
5. Platform: windows
6. Payload saved as payload.exe
```

### Example 3: Framework Console
```
nullsec > use 35
nullsec(Password Cracker) > show options
nullsec(Password Cracker) > run
nullsec > search kerberos
nullsec > use 37
nullsec(Kerberoasting) > exploit
```

### Example 4: WiFi Attack Chain
```
1. Select [6] WiFi Deauth
2. Interface: wlan0
3. Scan for targets
4. Select target BSSID
5. Choose: LIVE MODE
6. Monitor deauth packets
```

---

## 🛠️ Module Categories

| Category | Count | Examples |
|----------|-------|----------|
| Network | 5 | Intrusion, Port Scanner, MITM, DNS Poison |
| Wireless | 5 | WiFi Deauth, Bluetooth, RFID, RF Jammer |
| Web | 6 | SQLi, XSS, WebShell, Dir Bruteforce |
| Malware | 7 | Ransomware, RAT, Rootkit, Keylogger |
| Social | 5 | Phishing, Vishing, Smishing, Watering Hole |
| Advanced | 6 | APT, Zero-Day, Supply Chain, Firmware |
| Credentials | 5 | Password Crack, Kerberoast, Pass-the-Hash |
| Infrastructure | 5 | C2 Server, Proxy Chain, VPN, Tor |
| Physical | 5 | Bypass, BadUSB, Camera Hijack, Alarm |
| OPSEC | 5 | Dark Web, Crypto Launder, Evidence Destroy |
| DDoS | 4 | DDoS, Slowloris, DNS Amp, Memcached |
| ICS/SCADA | 4 | SCADA, PLC, Power Grid, Water System |

---

## 🔒 Operation Modes

### TEST MODE (Default)
- Safe visual simulation
- No actual exploitation
- Uses real user inputs
- Shows realistic output
- Perfect for demos/training

### LIVE MODE
- Executes real attacks
- Requires installed tools
- For authorized testing only
- Professional use only
- Legal authorization required

---

## ⚙️ Configuration

### Environment Variables
```bash
# Set default interface
export NULLSEC_IFACE="eth0"

# Set default workspace
export NULLSEC_WORKSPACE="$HOME/nullsec-ops"

# MSF database
export NULLSEC_MSFDB="nullsec"
```

### Custom Resource Scripts
```bash
# Create custom MSF resource script
nano ~/.nullsec/custom.rc

# Load in MSF integration
msfconsole -r ~/.nullsec/custom.rc
```

---

## 📊 Framework Architecture

```
nullsec/
├── nullsec-launcher.py    # Main TUI launcher
├── nullsec                # Quick launch wrapper
├── nullsecurity/          # Attack module directory
│   ├── *.sh              # 62 attack scripts
│   ├── simulate.sh       # Quick module launcher
│   ├── msf-launch.sh     # MSF integration launcher
│   └── msf-integration.rc # MSF resource script
├── logs/                  # Operation logs
└── README.md             # This file
```

---

## 🎓 Educational Use

NULLSEC Framework is designed for:
- **Penetration Testing Training**
- **Red Team Operations Practice**
- **Security Awareness Demonstrations**
- **Academic Research**
- **Authorized Security Assessments**

All modules support TEST MODE for safe learning environments.

---

## ⚠️ Legal Disclaimer

**FOR AUTHORIZED SECURITY TESTING ONLY**

This framework is designed for professional penetration testers and red team operators conducting **AUTHORIZED** security assessments.

- ✅ Use on systems you own or have written permission to test
- ✅ Educational purposes in controlled environments
- ✅ Authorized penetration testing engagements
- ❌ Unauthorized access to computer systems
- ❌ Malicious activities
- ❌ Illegal hacking

**Unauthorized access to computer systems is illegal under:**
- Computer Fraud and Abuse Act (CFAA) - USA
- Computer Misuse Act - UK
- Similar laws in your jurisdiction

**You are responsible for your actions.**

---

## 🤝 Contributing

NULLSEC Framework is actively developed. Contributions welcome!

```bash
# Fork repository
# Create feature branch
git checkout -b feature/new-attack-module

# Make changes
# Commit and push
git commit -m "Add: New attack module"
git push origin feature/new-attack-module

# Create pull request
```

---

## 📞 Support & Contact

**Developer:** bad-antics development  
**GitHub:** https://github.com/bad-antics  
**Project:** https://github.com/bad-antics/nullsec

For bugs, feature requests, or questions:
- Open an issue on GitHub
- Submit a pull request
- Contact via GitHub

---

## 📝 License

This project is for educational and authorized security testing purposes only.

**Use responsibly. Stay legal. Stay ethical.**

---

## 🏆 Credits

- **Framework:** bad-antics development
- **Metasploit:** Rapid7
- **Tools:** Aircrack-ng, Nmap, Hydra, Hashcat, John the Ripper, and others
- **Community:** Security researchers worldwide

---

## 🔄 Version History

**v4.0.0** - NULLSEC Framework + MSF Integration
- Added 62 custom attack modules
- Integrated Metasploit Framework
- Added Framework Console (MSF-style interface)
- Real + Test Mode for all modules
- Enhanced TUI launcher
- Renamed simulations → nullsecurity

**v3.7.1** - Enhanced Attack Suite
- Added 20+ new modules
- Improved script quality
- bad-antics branding

**v3.0.0** - Initial Release
- Core attack modules
- Basic TUI launcher

---

**Stay dangerous. Stay anonymous. Stay legal.**

*NULLSEC Framework - Where offensive security meets operational excellence.*
