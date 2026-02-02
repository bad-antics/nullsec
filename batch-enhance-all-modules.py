#!/usr/bin/env python3
"""
Batch Enhancement Script for NullSec Modules v1.0
https://github.com/bad-antics/nullsec

Automatically generates JSON configs and enhances modules with logging
"""

__version__ = "1.0"
__author__ = "bad-antics"

import os
import re
import json
from pathlib import Path

# Module directory
MODULES_DIR = Path.home() / "nullsec" / "nullsecurity"

# Module categories and their common parameters
MODULE_CATEGORIES = {
    "network": {
        "keywords": ["scan", "port", "network", "ping", "dns", "dhcp", "arp", "snmp", "nmap"],
        "params": [
            {"name": "target", "type": "ip", "description": "Target IP address or hostname", "required": True},
            {"name": "ports", "type": "string", "description": "Port range to scan (e.g., 1-1000, 80,443)", "default": "1-65535"},
            {"name": "timeout", "type": "port", "description": "Scan timeout in seconds", "default": "300"},
            {"name": "stealth_mode", "type": "boolean", "description": "Use slower, stealthier scanning", "default": "false"}
        ]
    },
    "web": {
        "keywords": ["web", "http", "https", "url", "sqli", "xss", "api", "cms", "wordpress", "joomla"],
        "params": [
            {"name": "target_url", "type": "url", "description": "Target URL to attack", "required": True},
            {"name": "wordlist", "type": "file", "description": "Wordlist for fuzzing/brute force", "default": "/usr/share/wordlists/rockyou.txt"},
            {"name": "threads", "type": "port", "description": "Number of concurrent threads", "default": "10"},
            {"name": "user_agent", "type": "string", "description": "Custom User-Agent string", "default": "Mozilla/5.0"}
        ]
    },
    "wireless": {
        "keywords": ["wifi", "wireless", "bluetooth", "rfid", "nfc", "zigbee"],
        "params": [
            {"name": "interface", "type": "string", "description": "Wireless interface (e.g., wlan0)", "required": True},
            {"name": "target_bssid", "type": "string", "description": "Target BSSID/MAC address", "required": False},
            {"name": "channel", "type": "port", "description": "Wireless channel (1-14)", "default": "0"},
            {"name": "capture_time", "type": "port", "description": "Capture duration in seconds", "default": "300"}
        ]
    },
    "password": {
        "keywords": ["password", "hash", "crack", "brute", "hydra", "john"],
        "params": [
            {"name": "target", "type": "ip", "description": "Target IP address or hostname", "required": True},
            {"name": "username", "type": "string", "description": "Username to attack", "required": False},
            {"name": "wordlist", "type": "file", "description": "Password wordlist", "default": "/usr/share/wordlists/rockyou.txt"},
            {"name": "service", "type": "choice", "description": "Service to attack", "choices": ["ssh", "ftp", "http", "smb", "rdp"], "default": "ssh"}
        ]
    },
    "exploit": {
        "keywords": ["exploit", "cve", "vulnerability", "metasploit", "payload"],
        "params": [
            {"name": "target", "type": "ip", "description": "Target IP address", "required": True},
            {"name": "port", "type": "port", "description": "Target port", "default": "445"},
            {"name": "payload", "type": "choice", "description": "Payload type", "choices": ["reverse_shell", "bind_shell", "meterpreter"], "default": "reverse_shell"},
            {"name": "lhost", "type": "ip", "description": "Local IP for reverse connection", "required": False},
            {"name": "lport", "type": "port", "description": "Local port for reverse connection", "default": "4444"}
        ]
    },
    "enum": {
        "keywords": ["enum", "recon", "discover", "info", "gather"],
        "params": [
            {"name": "target", "type": "ip", "description": "Target IP address or hostname", "required": True},
            {"name": "output_format", "type": "choice", "description": "Output format", "choices": ["console", "json", "xml", "html"], "default": "console"},
            {"name": "verbose", "type": "boolean", "description": "Enable verbose output", "default": "false"}
        ]
    },
    "social": {
        "keywords": ["phish", "social", "email", "sms", "clone"],
        "params": [
            {"name": "target_email", "type": "string", "description": "Target email address or phone", "required": True},
            {"name": "template", "type": "file", "description": "Email/SMS template file", "required": False},
            {"name": "sender", "type": "string", "description": "Sender address/name", "required": False}
        ]
    },
    "database": {
        "keywords": ["sql", "database", "mysql", "postgres", "mongo", "redis"],
        "params": [
            {"name": "target", "type": "ip", "description": "Database server IP", "required": True},
            {"name": "port", "type": "port", "description": "Database port", "default": "3306"},
            {"name": "database", "type": "string", "description": "Database name", "required": False},
            {"name": "username", "type": "string", "description": "Database username", "required": False},
            {"name": "password", "type": "string", "description": "Database password", "required": False}
        ]
    },
    "mobile": {
        "keywords": ["android", "ios", "mobile", "apk", "app"],
        "params": [
            {"name": "target_app", "type": "file", "description": "APK/IPA file to analyze", "required": True},
            {"name": "device_ip", "type": "ip", "description": "Target device IP", "required": False},
            {"name": "analysis_depth", "type": "choice", "description": "Analysis depth", "choices": ["quick", "standard", "deep"], "default": "standard"}
        ]
    },
    "iot": {
        "keywords": ["iot", "scada", "plc", "modbus", "bacnet", "mqtt", "camera"],
        "params": [
            {"name": "target", "type": "ip", "description": "IoT device IP address", "required": True},
            {"name": "port", "type": "port", "description": "Service port", "default": "80"},
            {"name": "protocol", "type": "choice", "description": "Protocol to use", "choices": ["http", "mqtt", "modbus", "bacnet"], "default": "http"}
        ]
    },
    "generic": {
        "keywords": [],  # Fallback
        "params": [
            {"name": "target", "type": "string", "description": "Primary target (IP, domain, or file)", "required": True},
            {"name": "output_format", "type": "choice", "description": "Output format", "choices": ["console", "json", "xml"], "default": "console"},
            {"name": "verbose", "type": "boolean", "description": "Enable verbose output", "default": "false"}
        ]
    }
}

def detect_module_category(module_name, module_content):
    """Detect module category based on name and content"""
    module_lower = module_name.lower()
    content_lower = module_content.lower()
    
    scores = {}
    for category, config in MODULE_CATEGORIES.items():
        if category == "generic":
            continue
        score = 0
        for keyword in config["keywords"]:
            if keyword in module_lower:
                score += 5
            if keyword in content_lower:
                score += 1
        scores[category] = score
    
    if scores and max(scores.values()) > 0:
        return max(scores, key=scores.get)
    return "generic"

def extract_module_description(module_content):
    """Extract description from module comments"""
    lines = module_content.split('\n')
    description = None
    
    for line in lines[:20]:  # Check first 20 lines
        if line.strip().startswith('#') and len(line) > 10:
            clean = line.strip('#').strip()
            if clean and not clean.startswith('!') and len(clean) > 20:
                description = clean
                break
    
    if not description:
        description = "Security testing module"
    
    return description

def generate_json_config(module_name, module_path):
    """Generate JSON configuration for a module"""
    
    # Skip if already has config
    json_path = module_path.with_suffix('.json')
    if json_path.exists():
        print(f"  ⏭️  {module_name} - already has config")
        return False
    
    # Skip helper/batch scripts
    if module_name in ['batch-create-modules.sh', 'batch-enhance.sh', 'module-template.sh']:
        print(f"  ⏭️  {module_name} - utility script")
        return False
    
    # Read module content
    try:
        with open(module_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except:
        print(f"  ❌ {module_name} - cannot read")
        return False
    
    # Detect category
    category = detect_module_category(module_name, content)
    category_config = MODULE_CATEGORIES[category]
    
    # Extract description
    description = extract_module_description(content)
    
    # Build config
    config = {
        "name": module_name.replace('.sh', '').replace('-', ' ').title(),
        "description": description,
        "category": category,
        "author": "NullSec Team",
        "version": "1.0",
        "parameters": category_config["params"]
    }
    
    # Write JSON
    try:
        with open(json_path, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"  ✅ {module_name} - created config ({category})")
        return True
    except Exception as e:
        print(f"  ❌ {module_name} - failed: {e}")
        return False

def enhance_module_with_logging(module_path):
    """Add logging helpers to a module"""
    
    try:
        with open(module_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except:
        return False
    
    # Check if already enhanced
    if 'log_to_file()' in content and 'NULLSEC_TARGET_DIR' in content:
        return False
    
    # Skip if very small (likely placeholder)
    if len(content) < 100:
        return False
    
    # Find where to insert helpers (after shebang and initial comments)
    lines = content.split('\n')
    insert_pos = 0
    
    for i, line in enumerate(lines):
        if line.strip() and not line.strip().startswith('#'):
            insert_pos = i
            break
    
    # Create helper functions
    helpers = '''
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
'''
    
    # Insert helpers
    lines.insert(insert_pos, helpers)
    
    # Write back
    try:
        with open(module_path, 'w') as f:
            f.write('\n'.join(lines))
        return True
    except:
        return False

def main():
    """Main enhancement process"""
    print("╭─ NULLSEC MODULE BATCH ENHANCEMENT")
    print("│")
    
    # Get all modules
    modules = sorted(MODULES_DIR.glob("*.sh"))
    print(f"├─ Found {len(modules)} modules in {MODULES_DIR}")
    print("│")
    
    # Generate JSON configs
    print("├─ PHASE 1: Generating JSON Configurations")
    configs_created = 0
    for module_path in modules:
        if generate_json_config(module_path.name, module_path):
            configs_created += 1
    print(f"│  ✓ Created {configs_created} new configurations")
    print("│")
    
    # Enhance with logging
    print("├─ PHASE 2: Adding Logging Helpers")
    modules_enhanced = 0
    for module_path in modules:
        if enhance_module_with_logging(module_path):
            modules_enhanced += 1
            print(f"  ✅ {module_path.name} - added logging")
    print(f"│  ✓ Enhanced {modules_enhanced} modules")
    print("│")
    
    # Summary
    print("╰─ COMPLETE")
    print(f"\n📊 Summary:")
    print(f"  • Total modules: {len(modules)}")
    print(f"  • JSON configs created: {configs_created}")
    print(f"  • Modules enhanced with logging: {modules_enhanced}")
    print(f"\n✨ All modules ready for interactive framework!")

if __name__ == "__main__":
    main()
