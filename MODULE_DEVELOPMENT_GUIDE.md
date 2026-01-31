# NullSec Enhanced Framework - Complete Guide

## 📋 Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Directory Structure](#directory-structure)
4. [Using Enhanced Modules](#using-enhanced-modules)
5. [Creating Enhanced Modules](#creating-enhanced-modules)
6. [Attack Logging System](#attack-logging-system)
7. [Vulnerability Tracking](#vulnerability-tracking)
8. [Examples](#examples)

## 🎯 Overview

The NullSec Enhanced Framework provides:
- **Interactive Parameter Collection** - Rich prompts with validation
- **Automatic Logging** - Every attack is logged with timestamps
- **Vulnerability Tracking** - Auto-detect and catalog discovered vulnerabilities
- **Organized Storage** - Target-specific folders for all attack data
- **Next Steps Suggestions** - AI-generated recommendations after each attack
- **Professional Output** - Beautiful formatted displays and summaries

## ✨ Features

### Interactive Elements
- ✅ Multiple parameter types (IP, Port, File, Choice, Boolean, etc.)
- ✅ Real-time input validation
- ✅ Default value suggestions
- ✅ Help text and descriptions
- ✅ Numbered choice menus
- ✅ Confirmation before execution

### Logging & Output
- 📝 Timestamped execution logs
- 📊 Vulnerability severity tracking
- 📁 Organized target directories
- 📋 Markdown summary reports
- 🎯 Suggested next steps
- 💾 All output files preserved

### Auto-Discovery
- 🔍 Detects vulnerabilities from log output
- 🎯 Categorizes by severity (Critical/High/Medium/Low)
- 📊 Generates exploitation recommendations
- 🗺️ Maps attack paths automatically

## 📁 Directory Structure

All attack results are organized under `~/nullsec/logs/`:

```
~/nullsec/logs/
├── targets/
│   ├── 192.168.1.100/
│   │   ├── SUMMARY.md                    # Main summary with all attacks
│   │   ├── ad-attack_20260114_153045.log # Timestamped attack logs
│   │   ├── nmap-scan_20260114_154230.log
│   │   ├── scans/                        # Scan results
│   │   │   ├── nmap_full.xml
│   │   │   ├── nikto_output.txt
│   │   │   └── enum4linux.txt
│   │   ├── exploits/                     # Exploit attempts
│   │   │   ├── exploit_log.txt
│   │   │   └── payload.bin
│   │   ├── credentials/                  # Captured credentials
│   │   │   ├── hashes.txt
│   │   │   ├── passwords.txt
│   │   │   └── kerberos_tickets.kirbi
│   │   └── screenshots/                  # Evidence screenshots
│   │       └── desktop_20260114.png
│   │
│   ├── dc01.corp.local/
│   │   ├── SUMMARY.md
│   │   ├── asrep_hashes.txt
│   │   ├── bloodhound_corp_20260114.zip
│   │   └── ldap_enumeration.txt
│   │
│   └── webserver.example.com/
│       ├── SUMMARY.md
│       ├── sql_injection_test.log
│       └── xss_vectors.txt
```

## 🚀 Using Enhanced Modules

### From NullSec Launcher
```bash
cd ~/nullsec
./nullsec-launcher.py
# Select any module with a .json config - it uses enhanced mode automatically
```

### From NullSec Desktop
- Launch NullSec Desktop GUI
- Browse modules by category
- Click any enhanced module
- Interactive prompts appear in terminal

### Direct Execution
```bash
python3 module-framework.py <script.sh> <config.json>

# Example:
python3 module-framework.py \
    nullsecurity/ad-attack-enhanced.sh \
    nullsecurity/ad-attack.json
```

## 🔧 Creating Enhanced Modules

### Step 1: Copy Templates
```bash
cd ~/nullsec/nullsecurity/
cp module-template.sh my-new-module.sh
cp module-template.json my-new-module.json
```

### Step 2: Edit JSON Configuration
```json
{
  "name": "My Custom Attack",
  "description": "What this module does",
  "category": "Exploitation",
  "requires_root": false,
  "pre_run_checks": ["nmap", "nikto"],
  "parameters": [
    {
      "name": "target",
      "prompt": "Target IP Address",
      "param_type": "ip",
      "required": true,
      "description": "Primary attack target"
    }
  ],
  "examples": [
    {"desc": "Example usage scenario"}
  ]
}
```

### Step 3: Edit Bash Script
```bash
#!/bin/bash
# Read parameters from environment
TARGET="${NULLSEC_TARGET}"
PORT="${NULLSEC_PORT}"

# Logging paths (auto-provided)
TARGET_DIR="${NULLSEC_TARGET_DIR}"
LOG_FILE="${NULLSEC_LOG_FILE}"

# Use helper functions
log_to_file "Attack started against $TARGET"
save_output "results.txt" "Attack data here"
log_vulnerability "high" "SQL Injection" "Found in login form"
```

### Parameter Types Available
- `string` - Free text input
- `ip` - IP address with validation
- `port` - Port number (1-65535)
- `file` - File path with existence check
- `choice` - Multiple choice menu
- `boolean` - Yes/No question
- `domain` - Domain name
- `url` - URL validation

### Helper Functions in Scripts

#### log_to_file
```bash
log_to_file "Your message here"
# Adds timestamped entry to log file
```

#### save_output
```bash
save_output "filename.txt" "content to save"
# Saves to target directory and logs it
```

#### log_vulnerability
```bash
log_vulnerability "severity" "Vulnerability Type" "Description"
# Severities: critical, high, medium, low
# Examples:
log_vulnerability "critical" "RCE" "Remote code execution in upload function"
log_vulnerability "high" "SQLi" "SQL injection in search parameter"
log_vulnerability "medium" "XSS" "Reflected XSS in username field"
```

## 📊 Attack Logging System

### What Gets Logged
- ✅ Execution timestamps (start/end)
- ✅ All parameters used (passwords redacted)
- ✅ Module output and results
- ✅ Discovered vulnerabilities
- ✅ Exit codes and errors
- ✅ Generated files and their paths

### Log File Format
```
[2026-01-14 15:30:45] === NullSec Attack Log ===
[2026-01-14 15:30:45] Target: dc01.corp.local
[2026-01-14 15:30:45] Module: Active Directory Attack
[2026-01-14 15:30:45] Timestamp: 2026-01-14T15:30:45
[2026-01-14 15:30:45] Target Directory: /home/user/nullsec/logs/targets/dc01.corp.local
[2026-01-14 15:30:45] ==================================================
[2026-01-14 15:30:45] Execution started with parameters:
[2026-01-14 15:30:45]   attack_type: AS-REP Roasting
[2026-01-14 15:30:45]   domain_controller: dc01.corp.local
[2026-01-14 15:30:45]   domain: corp.local
[2026-01-14 15:30:46] Connected to LDAP://dc01.corp.local:389
[2026-01-14 15:30:47] VULNERABILITY: Found 3 AS-REP roastable accounts
[2026-01-14 15:30:48] Saved output to .../asrep_hashes.txt
[2026-01-14 15:30:50] Execution completed in 5.23 seconds
[2026-01-14 15:30:50] Exit code: 0
```

### Summary Report (SUMMARY.md)
Each target gets a markdown summary with:
- Attack history and timeline
- All parameters used
- Discovered vulnerabilities (color-coded by severity)
- Suggested next steps
- Links to all output files

## 🎯 Vulnerability Tracking

### Automatic Detection
The framework automatically detects these patterns in logs:
- Weak/default credentials
- SQL Injection
- Cross-Site Scripting (XSS)
- Remote Code Execution (RCE)
- File inclusion vulnerabilities
- Exposed services
- Outdated software
- Misconfigurations

### Manual Logging
```bash
log_vulnerability "critical" "Authentication Bypass" "Admin panel accessible without credentials"
```

### Severity Levels
- 🔴 **Critical** - Immediate exploitation possible (RCE, auth bypass)
- 🟠 **High** - Significant impact (SQLi, XSS, privilege escalation)
- 🟡 **Medium** - Security weaknesses (weak passwords, misconfig)
- 🟢 **Low** - Information disclosure, minor issues

## 📚 Examples

### Example 1: Active Directory Attack
```bash
python3 module-framework.py \
    nullsecurity/ad-attack-enhanced.sh \
    nullsecurity/ad-attack.json
```

**Interactive prompts:**
1. Select attack vector (choice menu)
2. Enter domain controller
3. Enter domain name
4. Optional credentials
5. Stealth mode preference
6. Output format
7. Timeout value

**Result:**
- Log: `~/nullsec/logs/targets/dc01.corp.local/ad-attack_20260114_153045.log`
- Hashes: `~/nullsec/logs/targets/dc01.corp.local/asrep_hashes.txt`
- Summary: `~/nullsec/logs/targets/dc01.corp.local/SUMMARY.md`

### Example 2: Network Scan
```bash
# Create nmap-scan.json:
{
  "name": "Network Scanner",
  "parameters": [
    {"name": "target", "prompt": "Target IP/Network", "param_type": "ip", "required": true},
    {"name": "scan_type", "prompt": "Scan Type", "param_type": "choice", 
     "choices": ["Quick", "Full", "Stealth"], "required": true}
  ]
}

# Create nmap-scan.sh:
#!/bin/bash
TARGET="${NULLSEC_TARGET}"
SCAN_TYPE="${NULLSEC_SCAN_TYPE}"
log_to_file "Starting $SCAN_TYPE scan of $TARGET"
# ... nmap commands ...
save_output "nmap_results.xml" "$nmap_output"
```

## 🔐 Security Best Practices

1. **Credential Handling**
   - Passwords are automatically redacted in logs
   - Store captured credentials in `credentials/` subdirectory
   - Never commit logs with real credentials to git

2. **Target Authorization**
   - Only test targets you have written permission to test
   - Keep authorization documentation in target folder
   - Document scope and limitations

3. **Data Protection**
   - Encrypt sensitive log data
   - Secure delete when testing is complete
   - Follow data retention policies

## 🆘 Troubleshooting

### Module not using enhanced mode
- Ensure `.json` file exists with same base name as `.sh`
- Check JSON syntax with: `python3 -m json.tool config.json`
- Verify `module-framework.py` is in ~/nullsec/

### Logs not being created
- Check permissions on ~/nullsec/logs/
- Ensure `NULLSEC_TARGET_DIR` environment variable is set
- Verify disk space available

### Parameters not working
- Check parameter names match between JSON and bash script
- Remember to prefix with `NULLSEC_` in environment variables
- Use `printenv | grep NULLSEC` to debug

## 📞 Support

For issues or enhancements:
- Review this guide thoroughly
- Check existing modules for examples
- Test with `module-template.sh` first
- Consult ENHANCED_FRAMEWORK_GUIDE.md

## 🎓 Learning Resources

- Study `ad-attack-enhanced.sh` for complete example
- Review `module-framework.py` for framework internals
- Check `SUMMARY.md` files for output format examples
- Explore existing `.json` configs for parameter patterns
