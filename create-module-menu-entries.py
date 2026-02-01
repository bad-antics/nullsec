#!/usr/bin/env python3

"""
NullSec Linux - Module Desktop Entry Generator
Creates .desktop files for all modules grouped by exploit type
"""

import os
import json
from pathlib import Path

# Category definitions
CATEGORIES = {
    'Network': '🌐',
    'Web': '🌍', 
    'Wireless': '📡',
    'Exploitation': '💣',
    'Password': '🔑',
    'Social Engineering': '🎭',
    'IoT': '📱',
    'Cloud': '☁️',
    'Active Directory': '🏢',
    'Database': '🗄️',
    'Mobile': '📲',
    'Forensics': '🔍',
    'Misc': '⚡'
}

def get_module_category(script_name):
    """Determine category based on script name patterns"""
    name_lower = script_name.lower()
    
    # Network-based
    if any(x in name_lower for x in ['port', 'network', 'tcp', 'udp', 'nmap', 'dns', 'snmp', 'route', 'smb', 'ssh', 'ftp', 'vnc', 'rdp']):
        return 'Network'
    
    # Web-based
    elif any(x in name_lower for x in ['web', 'http', 'sql', 'xss', 'csrf', 'xxe', 'ssrf', 'lfi', 'rfi', 'api', 'cms', 'wordpress', 'joomla', 'drupal']):
        return 'Web'
    
    # Wireless
    elif any(x in name_lower for x in ['wifi', 'wireless', 'bluetooth', 'wpa', 'wep', 'aircrack', 'kismet']):
        return 'Wireless'
    
    # Exploitation
    elif any(x in name_lower for x in ['exploit', 'shellcode', 'buffer', 'overflow', 'rop', 'metasploit', 'vmware', 'kernel']):
        return 'Exploitation'
    
    # Password/Credentials
    elif any(x in name_lower for x in ['pass', 'crack', 'hash', 'brute', 'john', 'hydra', 'credential', 'mimikatz', 'kerberos']):
        return 'Password'
    
    # Social Engineering
    elif any(x in name_lower for x in ['phish', 'social', 'pretex', 'vishing', 'smishing']):
        return 'Social Engineering'
    
    # IoT/ICS
    elif any(x in name_lower for x in ['iot', 'scada', 'modbus', 'mqtt', 'coap', 'zigbee']):
        return 'IoT'
    
    # Cloud
    elif any(x in name_lower for x in ['cloud', 'aws', 's3', 'azure', 'gcp', 'docker', 'kubernetes', 'container']):
        return 'Cloud'
    
    # Active Directory
    elif any(x in name_lower for x in ['ad-', 'ldap', 'domain', 'kerberos', 'ntlm', 'bloodhound']):
        return 'Active Directory'
    
    # Database
    elif any(x in name_lower for x in ['mysql', 'postgres', 'mongo', 'redis', 'oracle', 'mssql', 'database']):
        return 'Database'
    
    # Mobile
    elif any(x in name_lower for x in ['android', 'ios', 'mobile', 'apk']):
        return 'Mobile'
    
    # Forensics
    elif any(x in name_lower for x in ['forensic', 'memory', 'disk', 'volatility']):
        return 'Forensics'
    
    else:
        return 'Misc'

def create_desktop_entry(module_name, script_path, category, output_dir):
    """Create a .desktop file for a module"""
    
    # Clean name
    display_name = module_name.replace('.sh', '').replace('-', ' ').title()
    icon = CATEGORIES.get(category, '⚡')
    
    # Check if JSON config exists
    json_path = script_path.replace('.sh', '.json')
    has_config = os.path.exists(json_path)
    
    # Get description from JSON if available
    description = f"{category} attack module"
    if has_config:
        try:
            with open(json_path, 'r') as f:
                config = json.load(f)
                description = config.get('description', description)
        except:
            pass
    
    # Create desktop entry content
    desktop_content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={icon} {display_name}
Comment={description}
Exec=bash -c 'cd {os.path.dirname(script_path)} && bash {script_path}; read -p "Press Enter to close..."'
Icon=/usr/share/icons/hicolor/256x256/apps/nullsec.png
Terminal=true
Categories=NullSecTools;{category.replace(' ', '')};
Keywords=nullsec;pentesting;security;{category.lower()};
StartupNotify=false
"""
    
    # Sanitize filename
    safe_name = module_name.replace('.sh', '').replace(' ', '-').lower()
    desktop_file = f"nullsec-{safe_name}.desktop"
    
    output_path = os.path.join(output_dir, desktop_file)
    
    with open(output_path, 'w') as f:
        f.write(desktop_content)
    
    return output_path

def main():
    print("\n" + "="*75)
    print("  NullSec Linux - Module Desktop Entry Generator")
    print("="*75 + "\n")
    
    # Paths
    modules_dir = os.path.expanduser("~/nullsec/nullsecurity")
    output_dir = os.path.expanduser("~/.local/share/applications/nullsec-modules")
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Get all .sh files
    modules = sorted([f for f in os.listdir(modules_dir) if f.endswith('.sh')])
    
    print(f"[*] Found {len(modules)} modules")
    print(f"[*] Output directory: {output_dir}\n")
    
    # Group by category
    categorized = {}
    for module in modules:
        category = get_module_category(module)
        if category not in categorized:
            categorized[category] = []
        categorized[category].append(module)
    
    # Create desktop entries
    total_created = 0
    for category, mods in sorted(categorized.items()):
        print(f"\n{CATEGORIES.get(category, '⚡')} {category}: {len(mods)} modules")
        
        for mod in mods:
            script_path = os.path.join(modules_dir, mod)
            desktop_file = create_desktop_entry(mod, script_path, category, output_dir)
            total_created += 1
            print(f"  ✓ {mod}")
    
    print(f"\n" + "="*75)
    print(f"  ✅ Created {total_created} desktop entries")
    print(f"  📁 Location: {output_dir}")
    print("="*75 + "\n")
    
    # Create category summary
    print("\n📊 Category Distribution:\n")
    for category, mods in sorted(categorized.items(), key=lambda x: len(x[1]), reverse=True):
        icon = CATEGORIES.get(category, '⚡')
        bar = "█" * min(50, len(mods))
        print(f"  {icon} {category:20s} [{len(mods):3d}] {bar}")
    
    print("\n")

if __name__ == "__main__":
    main()
