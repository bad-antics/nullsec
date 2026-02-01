# NullSec Linux 1.0 (void) - Tester Guide

**Version:** 1.0  
**Codename:** void  
**Date:** January 14, 2026  
**Status:** Production Release

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Installation Instructions](#installation-instructions)
3. [Framework Functions](#framework-functions)
4. [Module Usage](#module-usage)
5. [Testing Checklist](#testing-checklist)
6. [Known Issues](#known-issues)
7. [Reporting Bugs](#reporting-bugs)

---

## 🖥️ System Overview

### What is NullSec Linux?

NullSec Linux 1.0 (void) is an enterprise-grade penetration testing and offensive security operating system featuring:

- **188 Attack Modules** across 13 categories
- **AI-Powered Framework** with 12 AI models (73GB total)
- **Interactive Launcher** with enhanced logging and encryption
- **Desktop Integration** with click-to-launch tools
- **Comprehensive Resources** including wordlists, payloads, and multi-language scripts

### System Requirements

**Minimum:**
- CPU: 64-bit dual-core processor (2.0 GHz+)
- RAM: 8GB
- Storage: 100GB free space
- Network: Ethernet or Wi-Fi adapter

**Recommended:**
- CPU: 64-bit quad-core processor (3.0 GHz+)
- RAM: 16GB or more
- Storage: 250GB+ SSD
- Network: Multiple adapters for testing
- GPU: NVIDIA/AMD for AI acceleration

### Based On

- **Base OS:** Parrot Security OS (Debian-based)
- **Desktop:** MATE Desktop Environment
- **Kernel:** Linux 6.x
- **Package Manager:** apt/dpkg

---

## 💿 Installation Instructions

### Option 1: USB Installation (Recommended for Testing)

#### Prerequisites
- USB drive (16GB+ recommended)
- NullSec Linux ISO file
- USB creation tool (Rufus, Etcher, or dd)

#### Steps

**1. Download/Obtain ISO**
```bash
# ISO Location on test system
/home/antics/nullsec-linux-1.0-amd64.iso

# Also available on "The Lulz Boat" USB drive
```

**2. Create Bootable USB (Linux)**
```bash
# Identify USB device
lsblk

# Create bootable USB (replace /dev/sdX with your USB device)
sudo dd if=nullsec-linux-1.0-amd64.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

**3. Create Bootable USB (Windows)**
- Download Rufus: https://rufus.ie/
- Select NullSec ISO
- Select USB drive
- Click "Start"
- Use DD mode when prompted

**4. Boot from USB**
- Insert USB drive
- Restart computer
- Enter BIOS/UEFI (usually F2, F12, DEL, or ESC)
- Select USB drive as boot device
- Choose "Live mode" or "Install"

#### Live Mode Testing
```bash
# Boot to live mode without installation
# Login credentials (if prompted):
Username: antics
Password: [provided separately]

# Test all features before installation
# No changes persist after reboot
```

#### Full Installation
1. Boot from USB
2. Select "Install NullSec Linux"
3. Choose language and keyboard layout
4. Select installation target (disk)
5. Create user account
6. Wait for installation (15-30 minutes)
7. Reboot and remove USB
8. Login with created credentials

### Option 2: Virtual Machine (Safe Testing)

#### Using VirtualBox

**1. Create New VM**
```
Name: NullSec Linux
Type: Linux
Version: Debian (64-bit)
RAM: 8192 MB (minimum)
Disk: 100 GB dynamically allocated
```

**2. VM Settings**
- System → Processor: 4 CPUs (or more)
- Display → Video Memory: 128 MB
- Network → Adapter 1: NAT
- Network → Adapter 2: Host-only (for isolated testing)
- Storage → Add NullSec ISO to optical drive

**3. Start VM and Install**
- Follow normal installation steps
- Install Guest Additions after setup

#### Using VMware

**1. Create New VM**
```
Configuration: Custom
OS: Linux → Debian 11.x 64-bit
RAM: 8 GB
Disk: 100 GB
Network: NAT + Host-only
```

**2. Mount ISO and Install**
- Attach NullSec ISO
- Power on VM
- Complete installation
- Install VMware Tools

---

## 🚀 Framework Functions

### 1. NullSec Launcher (Main Interface)

#### Starting the Launcher
```bash
# From terminal
cd ~/nullsec
./nullsec-launcher.py

# Or double-click desktop icon
# Or type: nullsec
```

#### Command Center Options

**Main Menu:**
```
[N] Next Page       - Navigate to next module page
[P] Previous Page   - Navigate to previous page
[A] Run ALL         - Execute all modules sequentially
[R] Random          - Run random module selection

[C] Categories      - Browse modules by category
[S] Search          - Search modules by name/desc
[M] Metasploit      - Launch Metasploit Framework
[H] Shodan          - Shodan API integration

[D] Module List     - Detailed module browser (NEW!)
[E] Exec Console    - Direct command execution
[F] Framework       - Framework documentation
[T] Tools           - External tools menu

[I] AI Console      - AI-powered assistance
[X] Credits         - System information
[Q] Quit            - Exit launcher
[1-188]             - Launch specific module by number
```

#### Module Browser ([D] Option)

**14 Browse Options:**
1. View All Modules - Paginated list with descriptions
2. Browse by Category - 13 organized categories
3. Search - Name/description/category search
4. Recently Used - Last 10 executed modules
5. Enhanced Modules - Show JSON-configured modules only
6. Desktop GUI Launcher - Launch GUI application
7. CLI Framework - Command-line usage
8. Direct Execution - Bash execution info
9. Network Modules - Quick access
10. Web Exploitation - Quick access
11. Credential Attacks - Quick access
12. Active Directory - Quick access
13. Cloud & Container - Quick access
14. IoT & ICS/SCADA - Quick access

### 2. Desktop Menu Integration

#### Accessing via Applications Menu
```
Applications → ⚡ NullSec Tools → [Category] → [Module]
```

**Available Categories:**
- 🌐 Network Exploitation (5 modules)
- 🌍 Web Exploitation (11 modules)
- 📡 Wireless Attacks (2 modules)
- 💣 Exploitation (37 modules)
- 🔑 Password Attacks (12 modules)
- ☁️ Cloud & Container (5 modules)
- 🏢 Active Directory (4 modules)
- 📱 IoT & ICS/SCADA (3 modules)

**Plus Main Tools:**
- ⚡ NullSec Framework Launcher
- ⚡ NullSec Desktop GUI

### 3. Interactive Framework

#### Enhanced Module Execution
```bash
# Method 1: Through Launcher
./nullsec-launcher.py
# Select module, answer prompts

# Method 2: Direct Framework Call
python3 ~/nullsec/module-framework.py \
    ~/nullsec/nullsecurity/module.sh \
    ~/nullsec/nullsecurity/module.json

# Method 3: Standard Bash
cd ~/nullsec/nullsecurity
bash module.sh
```

#### Interactive Features
- **Parameter Collection:** Smart prompts for each module
- **Validation:** Input validation (IP, port, URL, domain, etc.)
- **Logging:** Automatic logging to ~/nullsec/logs/targets/
- **Vulnerability Tracking:** Automatic detection and categorization
- **Summary Reports:** Markdown summaries with next steps
- **Encryption Option:** Optional AES-256 log encryption

### 4. AI Integration

#### NULLSEC AI v3.0

**Launch AI Console:**
```bash
# From launcher: Press [I]
# Or directly:
python3 ~/nullsec/nullsec-ai.py
```

**Available AI Models (12 total):**
1. GPT-4 (OpenAI)
2. Claude 3 (Anthropic)
3. Llama 2 (Meta)
4. Mixtral (Mistral AI)
5. CodeLlama (Meta)
6. PaLM 2 (Google)
7. Gemini Pro (Google)
8. Command R+ (Cohere)
9. Falcon (TII)
10. MPT (MosaicML)
11. Vicuna (LMSYS)
12. WizardCoder (Microsoft)

**AI Capabilities:**
- Exploit analysis and recommendations
- Code generation and modification
- Vulnerability assessment
- Attack planning and automation
- Report generation
- Custom payload creation

### 5. Resource Library

#### Environment Variables
```bash
# Automatically set in ~/.bashrc
export NULLSEC_RESOURCES="$HOME/nullsec/resources"
export NULLSEC_WORDLISTS="$NULLSEC_RESOURCES/wordlists"
export NULLSEC_SCRIPTS="$NULLSEC_RESOURCES/scripts"
export NULLSEC_PAYLOADS="$NULLSEC_RESOURCES/payloads"
```

#### Available Resources

**Wordlists:**
```bash
# Passwords (146 entries)
$NULLSEC_WORDLISTS/passwords/common-passwords.txt
$NULLSEC_WORDLISTS/passwords/rockyou-top1000.txt

# Usernames (40 entries)
$NULLSEC_WORDLISTS/usernames/common-usernames.txt

# Subdomains (100 entries)
$NULLSEC_WORDLISTS/subdomains/common-subdomains.txt

# Directories/Files (90 entries)
$NULLSEC_WORDLISTS/directories/common-directories.txt
$NULLSEC_WORDLISTS/files/common-files.txt

# Fuzzing payloads (85 entries)
$NULLSEC_WORDLISTS/fuzzing/sql-injection.txt
$NULLSEC_WORDLISTS/fuzzing/xss-payloads.txt
$NULLSEC_WORDLISTS/fuzzing/api-endpoints.txt

# Token patterns (20 entries)
$NULLSEC_WORDLISTS/tokens/api-keys.txt
```

**Helper Scripts:**
```bash
# Python scripts
python3 $NULLSEC_SCRIPTS/python/port_scanner.py <target>
python3 $NULLSEC_SCRIPTS/python/subdomain_enum.py <domain>
python3 $NULLSEC_SCRIPTS/python/hash_cracker.py <hash> <wordlist>
python3 $NULLSEC_SCRIPTS/python/http_client.py <url>
python3 $NULLSEC_SCRIPTS/python/payload_gen.py

# Ruby scripts
ruby $NULLSEC_SCRIPTS/ruby/web_crawler.rb <url>

# Go scripts (compile first)
cd $NULLSEC_SCRIPTS/go
go build fast_scanner.go
./fast_scanner <target>

# PowerShell scripts
pwsh $NULLSEC_SCRIPTS/powershell/Invoke-PortScan.ps1 <target>
```

**Payloads:**
```bash
# Web shells
$NULLSEC_PAYLOADS/web/simple-shell.php
$NULLSEC_PAYLOADS/web/simple-shell.jsp
$NULLSEC_PAYLOADS/web/simple-shell.aspx

# Reverse shells
$NULLSEC_PAYLOADS/network/reverse-shell.sh <LHOST> <LPORT>
python3 $NULLSEC_PAYLOADS/network/reverse-shell.py <LHOST> <LPORT>
```

### 6. Log Encryption

#### Setting Up Encryption
```bash
# Install encryption system
bash ~/nullsec/install-log-encryption.sh

# Generate encryption key (first time)
python3 ~/nullsec/log-encrypt.py --generate-key
# Enter a strong password (SAVE THIS!)
```

#### Using Encryption

**Automatic (In Framework):**
```
When running modules, answer 'y' to:
"Encrypt logs after execution? [y/N]:"
```

**Manual Encryption:**
```bash
# Encrypt a log file
python3 ~/nullsec/log-encrypt.py --encrypt attack.log
# Output: attack.log.enc + attack.log.enc.meta

# Decrypt a log file
python3 ~/nullsec/log-encrypt.py --decrypt attack.log.enc
# Output: attack.log (original restored)

# Encrypt entire directory
python3 ~/nullsec/log-encrypt.py --encrypt-dir ~/nullsec/logs/targets

# Decrypt entire directory
python3 ~/nullsec/log-encrypt.py --decrypt-dir ~/nullsec/logs/targets
```

**Security Notes:**
- Uses AES-256 encryption
- PBKDF2 key derivation (100,000 iterations)
- Password CANNOT be recovered if lost!
- Backup ~/.nullsec/ directory for key recovery

---

## 🎯 Module Usage

### Module Categories (13 Total)

1. **Network** (5 modules) - Port scanning, network pivoting, DNS attacks
2. **Web** (11 modules) - SQL injection, XSS, API fuzzing, web shells
3. **Wireless** (2 modules) - WiFi deauth, Bluetooth attacks
4. **Exploitation** (37 modules) - RCE, kernel exploits, container escapes
5. **Password** (12 modules) - Hash cracking, brute force, 2FA bypass
6. **Social Engineering** (4 modules) - Phishing, vishing, pretexting
7. **IoT** (3 modules) - IoT camera attacks, Zigbee, SCADA
8. **Cloud** (5 modules) - AWS/Azure/GCP enumeration, container exploits
9. **Active Directory** (4 modules) - Kerberoasting, LDAP injection, domain attacks
10. **Database** (1 module) - Database exfiltration
11. **Mobile** (2 modules) - Android/iOS attacks
12. **Forensics** (0 modules) - Coming soon
13. **Misc** (102 modules) - Various attack tools and utilities

### Example Module Workflows

#### Network Reconnaissance
```bash
1. Launch NullSec Launcher
   ./nullsec-launcher.py

2. Press [D] for Module List
   Select [9] Network Modules

3. Choose port-scanner module
   Enter target: 192.168.1.0/24
   Choose scan type: Full
   Enable log encryption: y

4. Review results in:
   ~/nullsec/logs/targets/192.168.1.0_24/
```

#### Web Application Testing
```bash
1. Launch via Desktop Menu
   Applications → NullSec Tools → Web Exploitation → SQL Injection

2. Or use framework directly:
   python3 ~/nullsec/module-framework.py \
       ~/nullsec/nullsecurity/web-exploit.sh \
       ~/nullsec/nullsecurity/web-exploit.json

3. Follow interactive prompts:
   - Target URL
   - Injection point
   - Payload type
   - Encryption option

4. Check results and next steps in SUMMARY.md
```

#### Password Cracking
```bash
1. Collect hash from target
   # Example: 5f4dcc3b5aa765d61d8327deb882cf99

2. Use hash cracker:
   python3 $NULLSEC_SCRIPTS/python/hash_cracker.py \
       5f4dcc3b5aa765d61d8327deb882cf99 \
       $NULLSEC_WORDLISTS/passwords/rockyou-top1000.txt \
       md5

3. Or use module:
   ./nullsec-launcher.py
   Select password-crack module
   Enter hash and select wordlist
```

#### Active Directory Attack Chain
```bash
1. Initial Reconnaissance
   Module: network-pivot
   Discover domain controllers

2. Enumeration
   Module: ad-attack-enhanced
   Collect user/group information

3. Credential Harvesting
   Module: kerberoast
   Extract service account hashes

4. Exploitation
   Module: golden-ticket
   Create persistence mechanism

5. Lateral Movement
   Module: lateral-movement
   Move to high-value targets
```

---

## ✅ Testing Checklist

### Pre-Test Setup

- [ ] NullSec Linux installed (bare metal or VM)
- [ ] System updated: `sudo apt update && sudo apt upgrade`
- [ ] Network connectivity verified
- [ ] Test targets prepared (isolated lab environment)
- [ ] Backup created (if testing on production system)
- [ ] Legal authorization obtained for testing

### Core Functionality Tests

#### 1. Launcher Tests
- [ ] Launch nullsec-launcher.py successfully
- [ ] Navigate between pages ([N], [P])
- [ ] Access Module List ([D])
- [ ] Search functionality works ([S])
- [ ] Category browser works ([C])
- [ ] Module execution (select by number)
- [ ] AI Console launches ([I])
- [ ] Framework info displays ([F])
- [ ] Tools menu displays ([T])
- [ ] Exit properly ([Q])

#### 2. Desktop Integration Tests
- [ ] Applications menu shows "⚡ NullSec Tools"
- [ ] All 8 category submenus visible
- [ ] Click-to-launch works for modules
- [ ] NullSec Framework Launcher icon works
- [ ] NullSec Desktop GUI launches

#### 3. Module Execution Tests
- [ ] Run module via launcher (interactive)
- [ ] Run module via desktop menu (click)
- [ ] Run module via framework directly
- [ ] Run module via standard bash
- [ ] Run module in external terminal

#### 4. Resource Library Tests
- [ ] Environment variables set correctly (`echo $NULLSEC_RESOURCES`)
- [ ] Wordlists accessible and readable
- [ ] Python scripts executable and functional
- [ ] Ruby scripts work (if Ruby installed)
- [ ] Go scripts compile and run
- [ ] PowerShell scripts work (if pwsh installed)
- [ ] Payloads accessible

#### 5. Logging & Encryption Tests
- [ ] Logs created in ~/nullsec/logs/targets/
- [ ] SUMMARY.md generated correctly
- [ ] Vulnerability tracking works
- [ ] Log encryption key generation works
- [ ] Log encryption succeeds
- [ ] Log decryption restores original
- [ ] Directory-wide encryption works
- [ ] Encrypted logs are unreadable without key

#### 6. AI Integration Tests
- [ ] AI console launches
- [ ] Can select AI model
- [ ] AI responds to prompts
- [ ] Code generation works
- [ ] Exploit recommendations provided
- [ ] AI integration with modules functional

#### 7. Performance Tests
- [ ] System responsive during normal operation
- [ ] Module execution completes in reasonable time
- [ ] No memory leaks during extended use
- [ ] Log files don't grow excessively
- [ ] Encryption/decryption speed acceptable

### Module-Specific Tests

#### Network Modules
- [ ] Port scanner completes successfully
- [ ] DNS enumeration works
- [ ] Network pivoting functional
- [ ] Results logged properly

#### Web Modules
- [ ] SQL injection detection works
- [ ] XSS payload generation functional
- [ ] API fuzzing completes
- [ ] Web shells deploy successfully (in test env)

#### Wireless Modules
- [ ] WiFi adapter detection works
- [ ] Deauth attacks functional (in isolated env)
- [ ] Bluetooth enumeration works

#### Exploitation Modules
- [ ] Exploit selection appropriate
- [ ] Payload generation works
- [ ] Exploitation succeeds against vulnerable targets
- [ ] Post-exploitation modules functional

#### Password Modules
- [ ] Hash identification correct
- [ ] Cracking completes successfully
- [ ] Brute force attacks work
- [ ] 2FA bypass attempts logged properly

---

## 🐛 Known Issues

### Current Known Issues (as of January 14, 2026)

1. **Issue:** Some modules may show "command not found" in minimal shells
   - **Workaround:** Use full paths or run from framework
   - **Status:** Fixed in system-audit.sh, testing ongoing

2. **Issue:** Log encryption requires password entry for each file
   - **Workaround:** Use directory-wide encryption once
   - **Status:** Feature, not bug - security by design

3. **Issue:** AI models require 73GB storage
   - **Workaround:** Install on system with sufficient space
   - **Status:** Expected, all models optional

4. **Issue:** Desktop menu may not update immediately after installation
   - **Workaround:** Log out and back in, or run: `xdg-desktop-menu forceupdate`
   - **Status:** Desktop environment cache issue

5. **Issue:** Some wireless modules require specific hardware
   - **Workaround:** Ensure compatible WiFi adapter (monitor mode capable)
   - **Status:** Hardware limitation, not software issue

### Testing Focus Areas

Please pay special attention to:
- Module execution across different launch methods
- Log encryption/decryption with various file sizes
- Desktop menu integration and icon display
- Resource library accessibility
- Interactive prompts and validation
- Error handling and recovery

---

## 📝 Reporting Bugs

### Bug Report Template

When reporting issues, please include:

```
**Bug Title:** Brief description

**Environment:**
- NullSec Linux Version: 1.0 (void)
- Installation Type: [USB Live / Full Install / VM]
- Hardware: [CPU, RAM, etc.]
- Network: [WiFi / Ethernet]

**Steps to Reproduce:**
1. Launch component
2. Execute action
3. Observe issue

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happened

**Logs/Screenshots:**
- Error messages
- Screenshots
- Log file contents from ~/nullsec/logs/

**Additional Context:**
Any other relevant information
```

### How to Submit

**Method 1: Direct Contact**
- Email: [provided separately]
- Include "NullSec Bug:" in subject line

**Method 2: Log Files**
```bash
# Collect all relevant logs
cd ~/nullsec
tar -czf nullsec-bug-report-$(date +%Y%m%d).tar.gz logs/

# Share the tarball
```

**Method 3: System Info**
```bash
# Generate system information
bash ~/nullsec/system-audit.sh > system-info.txt

# Include in bug report
```

---

## 🎓 Training Resources

### Documentation Files

Located in `~/nullsec/`:

1. **TESTER_GUIDE.md** (this file) - Comprehensive testing guide
2. **QUICK_REFERENCE.txt** - Quick command reference
3. **NULLSEC_COMMANDS_REFERENCE.md** - All 188 modules documented
4. **NULLSEC_AI_V3_GUIDE.md** - AI system usage guide
5. **SCREENSAVER_GUIDE.md** - Screensaver customization
6. **MODULE_DEVELOPMENT_GUIDE.md** - Creating new modules
7. **API_DOCUMENTATION.md** - API reference

### Video Tutorials (If Available)

- System installation walkthrough
- Launcher navigation tutorial
- Module execution examples
- Log encryption demonstration
- AI integration showcase

### Support Resources

- **Community:** [provided separately]
- **Documentation:** ~/nullsec/*.md files
- **Examples:** ~/nullsec/logs/examples/ (if available)
- **Scripts:** ~/nullsec/resources/scripts/

---

## 🔒 Security Reminders for Testers

### Legal Compliance

⚠️ **IMPORTANT:** Only test against systems you own or have explicit written permission to test!

- Unauthorized penetration testing is illegal
- Always obtain proper authorization
- Document scope and limitations
- Follow responsible disclosure practices

### Isolated Testing Environment

**Recommended Setup:**
```
Internet
   ↓
[Host Machine] ← Your workstation
   ↓
[Isolated Network] ← Internal network with NO internet
   ↓
[Test Targets] ← Vulnerable systems for testing
```

**Never:**
- Test against production systems without authorization
- Use on public networks without permission
- Execute attacks against internet targets
- Share exploits publicly before disclosure period

### Data Protection

- Encrypt all test logs
- Secure test environment properly
- Delete test data after completion
- Follow data retention policies
- Backup critical findings securely

---

## 📊 Test Results Submission

### Required Test Report

After testing, please provide:

```markdown
# NullSec Linux 1.0 Test Report

**Tester Name:** [Your Name]
**Test Date:** [Date Range]
**Environment:** [Hardware/VM specs]

## Tests Completed

- [ ] Installation (USB/Full/VM)
- [ ] Launcher functionality
- [ ] Desktop integration
- [ ] Module execution (how many tested)
- [ ] Resource library
- [ ] Log encryption
- [ ] AI integration
- [ ] Performance testing

## Issues Found

1. [Issue description]
   - Severity: Critical/High/Medium/Low
   - Reproducible: Yes/No
   - Workaround: [if any]

## Suggestions

1. [Improvement suggestion]
2. [Feature request]

## Overall Assessment

- Stability: [1-10]
- Performance: [1-10]
- Usability: [1-10]
- Documentation: [1-10]

## Additional Comments

[Free-form feedback]
```

---

## 🚀 Quick Start for Testers

### First 30 Minutes

```bash
# 1. Boot NullSec Linux (Live or Installed)

# 2. Open terminal and verify setup
cd ~/nullsec
ls -la
cat QUICK_REFERENCE.txt

# 3. Launch framework
./nullsec-launcher.py

# 4. Explore module browser
# Press [D] in launcher
# Try options 1-3

# 5. Run a simple module
# Select port-scanner (or any network module)
# Use 127.0.0.1 as target
# Review logs in ~/nullsec/logs/

# 6. Test desktop menu
# Applications → NullSec Tools → Network Exploitation
# Click any module

# 7. Test resource library
echo $NULLSEC_RESOURCES
ls $NULLSEC_WORDLISTS
python3 $NULLSEC_SCRIPTS/python/port_scanner.py 127.0.0.1

# 8. Set up encryption (optional but recommended)
bash ~/nullsec/install-log-encryption.sh
python3 ~/nullsec/log-encrypt.py --generate-key

# 9. Review documentation
cat ~/nullsec/NULLSEC_COMMANDS_REFERENCE.md | less

# 10. Start comprehensive testing using checklist above
```

---

## 📞 Contact & Support

**For Testing Support:**
- Primary Contact: [provided separately]
- Test Coordinator: [provided separately]
- Emergency: [provided separately]

**Testing Timeline:**
- Test Period: [dates]
- Report Due: [date]
- Review Meeting: [date]

---

**Thank you for testing NullSec Linux!**

Your feedback is critical to making this the best penetration testing platform available.

---

*NullSec Linux 1.0 (void) - Built with ⚡ for offensive security professionals*  
*"The ultimate penetration testing and security research operating system"*
