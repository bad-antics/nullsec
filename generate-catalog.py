#!/usr/bin/env python3
"""
Generate comprehensive module catalog for enhanced NullSec framework
"""

import json
from pathlib import Path
from collections import defaultdict

MODULES_DIR = Path.home() / "nullsec" / "nullsecurity"

def generate_catalog():
    """Generate markdown catalog of all enhanced modules"""
    
    modules_by_category = defaultdict(list)
    
    # Load all JSON configs
    for json_file in sorted(MODULES_DIR.glob("*.json")):
        try:
            with open(json_file, 'r') as f:
                config = json.load(f)
            
            category = config.get('category', 'generic')
            modules_by_category[category].append({
                'name': config.get('name', json_file.stem),
                'description': config.get('description', 'No description'),
                'file': json_file.stem,
                'params': len(config.get('parameters', []))
            })
        except:
            continue
    
    # Generate markdown
    catalog = """# 🎯 NullSec Enhanced Module Catalog

**Total Enhanced Modules:** {total}  
**Categories:** {categories}  
**All modules feature:** Interactive parameters, automatic logging, vulnerability tracking

---

""".format(
        total=sum(len(mods) for mods in modules_by_category.values()),
        categories=len(modules_by_category)
    )
    
    # Category icons
    category_icons = {
        'network': '🌐',
        'web': '🕸️',
        'wireless': '📡',
        'password': '🔐',
        'exploit': '💥',
        'enum': '🔍',
        'social': '🎭',
        'database': '💾',
        'mobile': '📱',
        'iot': '🔌',
        'generic': '⚙️'
    }
    
    # Category descriptions
    category_desc = {
        'network': 'Network scanning, pivoting, and infrastructure attacks',
        'web': 'Web application testing and exploitation',
        'wireless': 'WiFi, Bluetooth, RFID, NFC, and wireless attacks',
        'password': 'Password cracking, hash attacks, and credential stuffing',
        'exploit': 'Exploitation frameworks and vulnerability exploitation',
        'enum': 'Reconnaissance and information gathering',
        'social': 'Social engineering and phishing attacks',
        'database': 'Database exploitation and data exfiltration',
        'mobile': 'Android and iOS mobile application security',
        'iot': 'IoT, SCADA, ICS, and embedded device attacks',
        'generic': 'General purpose security tools'
    }
    
    # Sort categories
    for category in sorted(modules_by_category.keys()):
        modules = modules_by_category[category]
        icon = category_icons.get(category, '⚙️')
        desc = category_desc.get(category, 'Security testing tools')
        
        catalog += f"## {icon} {category.title()} ({len(modules)} modules)\n\n"
        catalog += f"*{desc}*\n\n"
        catalog += "| Module | Description | Parameters |\n"
        catalog += "|--------|-------------|------------|\n"
        
        for mod in sorted(modules, key=lambda x: x['name']):
            name = mod['name']
            desc = mod['description'][:80] + ('...' if len(mod['description']) > 80 else '')
            params = mod['params']
            catalog += f"| **{name}** | {desc} | {params} |\n"
        
        catalog += "\n"
    
    # Usage section
    catalog += """---

## 🚀 Usage

### From CLI Launcher
```bash
cd ~/nullsec
./nullsec-launcher.py
# Navigate to any module - automatically uses enhanced framework!
```

### From Desktop GUI
```bash
cd ~/nullsec
python3 nullsec-launcher.py  # Or use desktop icon
# All modules now have interactive parameter collection
```

### Direct Execution
```bash
cd ~/nullsec
python3 module-framework.py nullsecurity/<module>.sh nullsecurity/<module>.json
```

## 📊 Features

Every enhanced module includes:

- ✅ **Rich Interactive Parameters** - Smart prompts with validation
- ✅ **Automatic Logging** - All actions logged to `~/nullsec/logs/targets/[target]/`
- ✅ **Organized Output** - Subdirectories for scans/, exploits/, credentials/, screenshots/
- ✅ **Vulnerability Tracking** - Auto-detection with severity levels
- ✅ **Summary Reports** - SUMMARY.md with findings and next steps
- ✅ **Beautiful UI** - Color-coded, formatted output
- ✅ **Default Values** - Suggested defaults for faster workflow
- ✅ **Help Text** - Descriptions and examples for every parameter

## 📁 Log Structure

```
~/nullsec/logs/targets/
├── 192.168.1.100/
│   ├── SUMMARY.md
│   ├── port-scanner_20260114_153045.log
│   ├── scans/
│   ├── exploits/
│   ├── credentials/
│   └── screenshots/
└── example.com/
    ├── SUMMARY.md
    └── xss-attack_20260114_154230.log
```

## 🎯 Parameter Types

Modules use intelligent parameter types:

- **IP Address** - Validates IPv4/IPv6 addresses
- **Port** - Validates port numbers (1-65535)
- **URL** - Validates web URLs
- **Domain** - Validates domain names
- **File** - Validates file existence
- **Choice** - Numbered menu selection
- **Boolean** - Yes/No toggle
- **String** - Free text input

## 📚 Documentation

- **MODULE_DEVELOPMENT_GUIDE.md** - Developer guide for creating modules
- **ENHANCED_FRAMEWORK_GUIDE.md** - User guide for the framework
- **MODULE_ENHANCEMENTS_SUMMARY.md** - Overview of enhancements

---

**All 185+ modules are now enhanced and ready for professional penetration testing!**
"""
    
    return catalog

if __name__ == "__main__":
    catalog = generate_catalog()
    output_file = Path.home() / "nullsec" / "ENHANCED_MODULES_CATALOG.md"
    
    with open(output_file, 'w') as f:
        f.write(catalog)
    
    print(f"✅ Catalog generated: {output_file}")
    print(f"📄 {len(catalog)} bytes written")
