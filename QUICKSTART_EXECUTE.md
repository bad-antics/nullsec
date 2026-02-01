# NULLSEC Command Execution - Quick Start Guide

## 🚀 Getting Started in 3 Steps

### Step 1: Launch NULLSEC
```bash
cd /home/antics/nullsec
./nullsec-launcher.py
```

### Step 2: Enter Execute Console
Press `[E]` from the main menu

### Step 3: Start Executing Commands
```bash
nullsec@exec > exec nmap -sV 192.168.1.1
nullsec@exec > run ./demo-external-script.sh
nullsec@exec > check wireshark
```

---

## ⚡ Common Commands

### Execute Shell Commands
```bash
# Network scanning
nullsec@exec > exec nmap -sV scanme.nmap.org

# WiFi recon
nullsec@exec > exec airodump-ng wlan0

# Password cracking
nullsec@exec > exec hashcat -m 0 hashes.txt wordlist.txt

# SQL injection
nullsec@exec > exec sqlmap -u "http://target.com/page?id=1" --dbs
```

### Run External Scripts
```bash
# Bash script
nullsec@exec > run /tmp/scan-network.sh

# Python exploit
nullsec@exec > run ~/exploits/rce.py

# Any script anywhere
nullsec@exec > run /opt/custom-tools/enumeration.pl
```

### Check Tool Availability
```bash
nullsec@exec > check nmap
[✓] nmap is installed: /usr/bin/nmap

nullsec@exec > check msfconsole
[✗] msfconsole not found
```

### Install Missing Tools
```bash
# Install with apt
nullsec@exec > install metasploit-framework

# Install with pip
nullsec@exec > install shodan pip

# Install with npm
nullsec@exec > install eslint npm
```

---

## 🎯 Common Workflows

### Workflow 1: Port Scanning
```bash
# Check if nmap is installed
nullsec@exec > check nmap

# If not, install it
nullsec@exec > install nmap

# Run scan
nullsec@exec > exec nmap -sV -sC 192.168.1.0/24
```

### Workflow 2: WiFi Attack
```bash
# Check dependencies
nullsec@exec > check aircrack-ng

# Run from NULLSEC modules
nullsec@exec > run /home/antics/nullsec/nullsecurity/wifi-deauth.sh
```

### Workflow 3: Custom Exploit
```bash
# Review script first
nullsec@exec > exec cat /tmp/exploit.py

# Run it
nullsec@exec > run /tmp/exploit.py
```

### Workflow 4: Tool Installation
```bash
# Install multiple tools
nullsec@exec > install hashcat
nullsec@exec > install hydra
nullsec@exec > install john
```

---

## 📚 Command Reference

| Command | Purpose | Example |
|---------|---------|---------|
| `exec` | Execute shell command | `exec nmap -sV 192.168.1.1` |
| `run` | Run external script | `run /tmp/exploit.py` |
| `install` | Install package | `install metasploit-framework` |
| `check` | Check availability | `check wireshark` |
| `history` | View command log | `history` |
| `clear` | Clear screen | `clear` |
| `help` | Show help | `help` |
| `exit` | Return to menu | `exit` |

---

## 💡 Pro Tips

### Tip 1: Use Demo Script
Test the system with the included demo:
```bash
nullsec@exec > run ./demo-external-script.sh
```

### Tip 2: Check Before Installing
Always verify first:
```bash
nullsec@exec > check nmap
```

### Tip 3: View Command History
Review what you've done:
```bash
nullsec@exec > history
```

### Tip 4: Integration with Shodan
Use targets from Shodan:
```bash
# Get target from Shodan first (press [H] from main menu)
# Then use it:
nullsec@exec > exec nmap -sV $(cat .shodan_target)
```

### Tip 5: Test Mode First
Always use test mode for reconnaissance:
```bash
# From main menu, run any module in TEST mode
# Then use Execute console for real attacks
```

---

## ⚠️ Troubleshooting

### Problem: "Command not found"
**Solution:** Install the missing package
```bash
nullsec@exec > install <package-name>
```

### Problem: "Permission denied"
**Solution:** Run with sudo or check file permissions
```bash
nullsec@exec > exec sudo <command>
nullsec@exec > exec chmod +x script.sh
```

### Problem: Script won't run
**Solution:** Check interpreter availability
```bash
nullsec@exec > check python3
nullsec@exec > install python3
```

### Problem: Installation fails
**Solution:** Update package lists
```bash
nullsec@exec > exec sudo apt update
```

---

## 🔐 Security Notes

1. **Always get authorization** before testing
2. **Use TEST MODE first** for reconnaissance
3. **Review scripts** before executing
4. **Track your commands** with history
5. **Install from official repos** only

---

## 📖 More Information

- Full Documentation: [COMMAND_EXECUTION.md](COMMAND_EXECUTION.md)
- Implementation Details: [COMMAND_EXECUTION_SUMMARY.md](COMMAND_EXECUTION_SUMMARY.md)
- Demo Script: `./demo-external-script.sh`
- Dependency Helper: `nullsecurity/dep-check.sh`

---

## 🎓 Learning Path

### Beginner
1. Launch NULLSEC
2. Press `[E]` for Execute
3. Try: `check nmap`
4. Try: `exec nmap --version`
5. Try: `run ./demo-external-script.sh`

### Intermediate
1. Install tools: `install hashcat`
2. Run module: `run nullsecurity/port-scanner.sh`
3. Check history: `history`
4. Execute scan: `exec nmap -sV target.com`

### Advanced
1. Custom scripts: `run /opt/custom-exploit.py`
2. Shodan integration: `exec nmap $(cat .shodan_target)`
3. Tool chains: Multiple commands in sequence
4. Automated workflows: Create custom scripts

---

**Ready to execute? Launch NULLSEC and press [E]!**

*Developed by bad-antics | github.com/bad-antics*
