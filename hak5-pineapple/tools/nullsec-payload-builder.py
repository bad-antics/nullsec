#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║              NullSec Payload Builder v1.0                                    ║
║       Create • Validate • Package • Deploy Pineapple Payloads               ║
║                    Author: bad-antics                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

CLI tool for managing the NullSec payload development lifecycle.

Usage:
    payload-builder new <name> [--category CAT] [--template TPL]
    payload-builder validate [<path>]
    payload-builder lint [<path>]
    payload-builder package <name> [--output DIR]
    payload-builder list [--category CAT] [--format FMT]
    payload-builder stats
    payload-builder doctor
"""

import argparse
import json
import os
import re
import shutil
import stat
import sys
import textwrap
from datetime import datetime
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

VERSION = "1.0.0"
SCRIPT_DIR = Path(__file__).parent.resolve()
SUITE_DIR = SCRIPT_DIR.parent / "nullsec-suite"
AUTHOR = "bad-antics"
DEVICE = "WiFi Pineapple Mark VII"
FRAMEWORK = "nullsec-suite"
REPO = "https://github.com/bad-antics/nullsec"

CATEGORIES = [
    "nullsec/attack", "nullsec/recon", "nullsec/defense", "nullsec/exploit",
    "nullsec/persistence", "nullsec/exfiltration", "nullsec/evasion",
    "nullsec/enterprise", "nullsec/wireless", "nullsec/bluetooth",
    "nullsec/iot", "nullsec/utility", "nullsec/misc",
]

TEMPLATES = {
    "basic": "Basic payload with standard LOOT_DIR and logging",
    "scanner": "Network/WiFi scanner with monitor mode and CSV output",
    "attack": "Attack payload with target selection, confirmation, and cleanup",
    "recon": "Passive reconnaissance with stealth and data collection",
    "exfil": "Data exfiltration with multiple channels",
    "persist": "Persistence payload with cron/service installation",
    "defense": "Defensive monitoring and alerting payload",
}

BANNER = """
\033[32m╔══════════════════════════════════════════════════════════════╗
║           NullSec Payload Builder v{ver}                    ║
║          Create • Validate • Package • Deploy                ║
╚══════════════════════════════════════════════════════════════╝\033[0m
""".format(ver=VERSION)

# ═══════════════════════════════════════════════════════════════════════════════
# Color helpers
# ═══════════════════════════════════════════════════════════════════════════════

def c(text, color):
    colors = {"g": "\033[32m", "r": "\033[31m", "y": "\033[33m", "b": "\033[34m",
              "c": "\033[36m", "m": "\033[35m", "w": "\033[97m", "d": "\033[90m"}
    return f"{colors.get(color, '')}{text}\033[0m"

def ok(msg): print(f"  {c('✓', 'g')} {msg}")
def warn(msg): print(f"  {c('⚠', 'y')} {msg}")
def err(msg): print(f"  {c('✗', 'r')} {msg}")
def info(msg): print(f"  {c('●', 'c')} {msg}")

# ═══════════════════════════════════════════════════════════════════════════════
# Templates
# ═══════════════════════════════════════════════════════════════════════════════

def get_template(name, template_type="basic"):
    loot_name = name.lower().replace(" ", "")

    templates = {
        "basic": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add description
# Category: nullsec/misc

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}

LOG "{name} starting..."

# ═══════════════════════════════════════════════════════
# Main payload logic here
# ═══════════════════════════════════════════════════════



LOG "{name} complete."
''',

        "scanner": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add scanner description
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}
SCAN_FILE="$LOOT_DIR/scan_$(date +%Y%m%d_%H%M%S).csv"

# Detect monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done

if [ -z "$MON_IF" ]; then
    LOG "No monitor interface found. Attempting to enable..."
    for wlan in wlan1 wlan2 wlan0; do
        [ -d "/sys/class/net/$wlan" ] && {{
            airmon-ng start "$wlan" 2>/dev/null
            MON_IF="${{wlan}}mon"
            break
        }}
    done
fi

[ -z "$MON_IF" ] && {{ LOG "FATAL: No wireless interface available"; exit 1; }}
LOG "Using interface: $MON_IF"

# ═══════════════════════════════════════════════════════
# Scan logic
# ═══════════════════════════════════════════════════════

LOG "Starting scan..."
echo "timestamp,bssid,channel,signal,essid" > "$SCAN_FILE"

timeout 30 airodump-ng "$MON_IF" -w /tmp/{loot_name}_scan --output-format csv 2>/dev/null &
sleep 30
killall airodump-ng 2>/dev/null

# Parse results
if [ -f /tmp/{loot_name}_scan-01.csv ]; then
    while IFS="," read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d " ")
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{{2}}: ]] && continue
        essid=$(echo "$essid" | sed "s/^[[:space:]]*//" | head -c 32)
        channel=$(echo "$channel" | tr -d " ")
        power=$(echo "$power" | tr -d " ")
        echo "$(date +%Y-%m-%dT%H:%M:%S),$bssid,$channel,$power,$essid" >> "$SCAN_FILE"
    done < /tmp/{loot_name}_scan-01.csv
fi

RESULT_COUNT=$(wc -l < "$SCAN_FILE")
RESULT_COUNT=$((RESULT_COUNT - 1))
LOG "Scan complete. Found $RESULT_COUNT targets."
LOG "Results: $SCAN_FILE"

rm -f /tmp/{loot_name}_scan* 2>/dev/null
''',

        "attack": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add attack description
# Category: nullsec/attack

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}
LOG_FILE="$LOOT_DIR/attack_$(date +%Y%m%d_%H%M%S).log"

# Detect monitor interface
MON_IF=""
for iface in wlan1mon wlan2mon wlan0mon; do
    [ -d "/sys/class/net/$iface" ] && MON_IF="$iface" && break
done
[ -z "$MON_IF" ] && {{ LOG "No monitor interface!"; exit 1; }}

# ═══════════════════════════════════════════════════════
# Target Selection
# ═══════════════════════════════════════════════════════

LOG "Scanning for targets..."
rm -f /tmp/{loot_name}*
timeout 12 airodump-ng "$MON_IF" -w /tmp/{loot_name} --output-format csv 2>/dev/null &
sleep 12
killall airodump-ng 2>/dev/null

NET_COUNT=0
if [ -f /tmp/{loot_name}-01.csv ]; then
    while IFS="," read -r bssid x1 x2 channel x3 x4 x5 x6 power x7 x8 x9 x10 essid rest; do
        bssid=$(echo "$bssid" | tr -d " ")
        [[ ! "$bssid" =~ ^[0-9A-Fa-f]{{2}}: ]] && continue
        NET_COUNT=$((NET_COUNT + 1))
        eval "BSSID_${{NET_COUNT}}=\\"$bssid\\""
        eval "CH_${{NET_COUNT}}=$(echo $channel | tr -d " ")"
        [ $NET_COUNT -ge 10 ] && break
    done < /tmp/{loot_name}-01.csv
fi

[ $NET_COUNT -eq 0 ] && {{ LOG "No targets found!"; exit 1; }}
LOG "Found $NET_COUNT targets"

# ═══════════════════════════════════════════════════════
# Attack Logic
# ═══════════════════════════════════════════════════════

# TODO: Implement attack logic here

LOG "Attack complete. Log: $LOG_FILE"
rm -f /tmp/{loot_name}* 2>/dev/null
''',

        "recon": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add recon description
# Category: nullsec/recon

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}

RECON_DIR="$LOOT_DIR/recon_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RECON_DIR"

LOG "{name} - Passive Reconnaissance Starting"

# ═══════════════════════════════════════════════════════
# Network Environment
# ═══════════════════════════════════════════════════════

LOG "Collecting network environment..."
ip addr show > "$RECON_DIR/interfaces.txt" 2>/dev/null
ip route show > "$RECON_DIR/routes.txt" 2>/dev/null
cat /etc/resolv.conf > "$RECON_DIR/dns.txt" 2>/dev/null
arp -a > "$RECON_DIR/arp_table.txt" 2>/dev/null

# ═══════════════════════════════════════════════════════
# Wireless Environment
# ═══════════════════════════════════════════════════════

LOG "Scanning wireless environment..."
iw dev > "$RECON_DIR/wireless_devices.txt" 2>/dev/null
iwlist scan 2>/dev/null | grep -E "ESSID|Channel|Signal|Encryption" > "$RECON_DIR/wifi_scan.txt"

# ═══════════════════════════════════════════════════════
# Service Discovery
# ═══════════════════════════════════════════════════════

LOG "Discovering local services..."
ss -tlnp > "$RECON_DIR/listening_ports.txt" 2>/dev/null
ps aux > "$RECON_DIR/processes.txt" 2>/dev/null

FILE_COUNT=$(find "$RECON_DIR" -type f | wc -l)
LOG "Recon complete. Collected $FILE_COUNT files."
LOG "Output: $RECON_DIR"
''',

        "exfil": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add exfil description
# Category: nullsec/exfiltration

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}

STAGING="$LOOT_DIR/staging_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$STAGING"

LOG "{name} - Data Collection Starting"

# ═══════════════════════════════════════════════════════
# Collection Phase
# ═══════════════════════════════════════════════════════

# TODO: Define what data to collect
# Examples:
# cp /etc/passwd "$STAGING/"
# cp /etc/shadow "$STAGING/" 2>/dev/null
# find / -name "*.conf" -exec cp {{}} "$STAGING/" \\; 2>/dev/null

# ═══════════════════════════════════════════════════════
# Packaging
# ═══════════════════════════════════════════════════════

ARCHIVE="$LOOT_DIR/exfil_$(date +%Y%m%d_%H%M%S).tar.gz"
tar czf "$ARCHIVE" -C "$STAGING" . 2>/dev/null

SIZE=$(du -sh "$ARCHIVE" 2>/dev/null | cut -f1)
LOG "Packaged $SIZE to $ARCHIVE"

# Cleanup staging
rm -rf "$STAGING"

LOG "Exfiltration complete."
''',

        "persist": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add persistence description
# Category: nullsec/persistence

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}

LOG "{name} - Persistence Installation"

# ═══════════════════════════════════════════════════════
# Cron Persistence
# ═══════════════════════════════════════════════════════

CRON_CMD="*/5 * * * * /bin/bash $LOOT_DIR/beacon.sh"

install_cron() {{
    (crontab -l 2>/dev/null | grep -v "{loot_name}"; echo "$CRON_CMD") | crontab -
    LOG "Cron job installed"
}}

# ═══════════════════════════════════════════════════════
# Beacon Script
# ═══════════════════════════════════════════════════════

cat > "$LOOT_DIR/beacon.sh" << 'BEACON'
#!/bin/bash
# Heartbeat beacon
echo "$(date +%Y-%m-%dT%H:%M:%S) ALIVE $(hostname) $(ip -4 addr show | grep inet | head -1 | awk '{{print $2}}')" >> /tmp/.{loot_name}_beacon.log
BEACON
chmod +x "$LOOT_DIR/beacon.sh"

# ═══════════════════════════════════════════════════════
# Install
# ═══════════════════════════════════════════════════════

install_cron
LOG "Persistence installed. Beacon runs every 5 minutes."
''',

        "defense": f'''#!/bin/bash
# Title: {name}
# Author: {AUTHOR}
# Description: TODO - Add defense description
# Category: nullsec/defense

LOOT_DIR="/mmc/nullsec/{loot_name}"
mkdir -p "$LOOT_DIR"

LOG() {{ echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOOT_DIR/run.log"; }}
ALERT_LOG="$LOOT_DIR/alerts_$(date +%Y%m%d).log"

LOG "{name} - Defensive Monitor Starting"

ALERT() {{
    local level="$1" msg="$2"
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] [$level] $msg" >> "$ALERT_LOG"
    LOG "ALERT [$level]: $msg"
}}

# ═══════════════════════════════════════════════════════
# Monitoring Loop
# ═══════════════════════════════════════════════════════

DURATION=${{1:-300}}
END=$((SECONDS + DURATION))

LOG "Monitoring for ${{DURATION}}s..."

while [ $SECONDS -lt $END ]; do
    # Check for deauth frames
    # Check for rogue APs
    # Check for new devices
    # TODO: Add monitoring logic

    sleep 5
done

ALERT_COUNT=$(wc -l < "$ALERT_LOG" 2>/dev/null || echo 0)
LOG "Monitor complete. $ALERT_COUNT alerts logged."
''',
    }

    return templates.get(template_type, templates["basic"])


def get_info_json(name, description="", category="nullsec/misc", template="basic"):
    loot_name = name.lower().replace(" ", "")
    tags = {
        "scanner": ["scanner", "recon", "wireless"],
        "attack": ["attack", "offensive", "wireless"],
        "recon": ["recon", "passive", "intelligence"],
        "exfil": ["exfiltration", "data", "covert"],
        "persist": ["persistence", "implant", "stealth"],
        "defense": ["defense", "monitoring", "ids"],
        "basic": ["utility"],
    }
    return {
        "name": name,
        "author": AUTHOR,
        "description": description or f"{name} payload for WiFi Pineapple",
        "version": "1.0.0",
        "category": category,
        "device": DEVICE,
        "framework": FRAMEWORK,
        "tags": tags.get(template, []),
        "requirements": [],
        "loot_dir": f"/mmc/nullsec/{loot_name}",
        "legal_disclaimer": "Authorized testing only. Obtain written permission before use.",
        "min_firmware": "2.0.0",
        "max_firmware": "",
        "repository": REPO,
    }


# ═══════════════════════════════════════════════════════════════════════════════
# Linter / Validator
# ═══════════════════════════════════════════════════════════════════════════════

class PayloadLinter:
    """Lint and validate payload scripts."""

    def __init__(self, path):
        self.path = Path(path)
        self.errors = []
        self.warnings = []
        self.info_items = []

    def lint(self):
        """Run all lint checks."""
        if not self.path.exists():
            self.errors.append(f"File not found: {self.path}")
            return self

        content = self.path.read_text()
        lines = content.split("\n")

        self._check_shebang(lines)
        self._check_headers(lines, content)
        self._check_loot_dir(content)
        self._check_logging(content)
        self._check_cleanup(content)
        self._check_hardcoded(content)
        self._check_permissions()
        self._check_info_json()
        self._check_shellcheck(content)
        return self

    def _check_shebang(self, lines):
        if not lines or not lines[0].startswith("#!"):
            self.errors.append("Missing shebang (#!/bin/bash)")
        elif "bash" not in lines[0]:
            self.warnings.append(f"Non-bash shebang: {lines[0]} (prefer #!/bin/bash)")

    def _check_headers(self, lines, content):
        required = ["Title:", "Author:", "Description:"]
        for tag in required:
            if f"# {tag}" not in content:
                self.errors.append(f"Missing header: # {tag}")

        if "# Author:" in content:
            match = re.search(r"# Author:\s*(.+)", content)
            if match and match.group(1).strip() != AUTHOR:
                self.warnings.append(f"Author is '{match.group(1).strip()}' (expected '{AUTHOR}')")

    def _check_loot_dir(self, content):
        if "/root/loot" in content:
            self.errors.append("Uses /root/loot/ (should be /mmc/nullsec/)")
        if "LOOT_DIR=" not in content and "loot" in content.lower():
            self.warnings.append("References loot but doesn't define LOOT_DIR")
        if 'mkdir -p "$LOOT_DIR"' not in content and "LOOT_DIR=" in content:
            self.warnings.append("LOOT_DIR defined but mkdir -p not called")

    def _check_logging(self, content):
        if "LOG" not in content and "echo" not in content:
            self.warnings.append("No logging or output found")

    def _check_cleanup(self, content):
        if "tmp/" in content and "rm " not in content:
            self.warnings.append("Uses /tmp/ files but no cleanup (rm) found")
        if "killall" not in content and ("airodump" in content or "aireplay" in content):
            self.warnings.append("Uses aircrack tools but no killall cleanup")

    def _check_hardcoded(self, content):
        if re.search(r"192\.168\.\d+\.\d+", content):
            self.warnings.append("Contains hardcoded IP address")
        if re.search(r"password|passwd|secret", content, re.IGNORECASE):
            if "# " not in content.split("password")[0][-20:] if "password" in content.lower() else True:
                self.info_items.append("Contains password-related strings (verify no credentials)")

    def _check_permissions(self):
        if self.path.exists():
            mode = self.path.stat().st_mode
            if not (mode & stat.S_IXUSR):
                self.warnings.append("File is not executable (chmod +x)")

    def _check_info_json(self):
        info_path = self.path.parent / "info.json"
        if not info_path.exists():
            self.errors.append("Missing info.json metadata file")
        else:
            try:
                data = json.loads(info_path.read_text())
                for field in ["name", "author", "description", "category"]:
                    if field not in data or not data[field]:
                        self.errors.append(f"info.json missing required field: {field}")
                if data.get("description", "").startswith("TODO"):
                    self.warnings.append("info.json description is still TODO")
            except json.JSONDecodeError:
                self.errors.append("info.json is not valid JSON")

    def _check_shellcheck(self, content):
        # Basic shell issues
        if "[ " in content and "[[ " not in content:
            self.info_items.append("Uses [ ] instead of [[ ]] (bash best practice)")
        if "`" in content:
            self.warnings.append("Uses backticks instead of $() for command substitution")

    def report(self):
        """Print lint report."""
        name = self.path.name
        total = len(self.errors) + len(self.warnings)

        if self.errors:
            for e in self.errors:
                err(f"{name}: {e}")
        if self.warnings:
            for w in self.warnings:
                warn(f"{name}: {w}")
        if self.info_items:
            for i in self.info_items:
                info(f"{name}: {i}")
        if not self.errors and not self.warnings:
            ok(f"{name}: All checks passed")

        return len(self.errors) == 0


# ═══════════════════════════════════════════════════════════════════════════════
# Commands
# ═══════════════════════════════════════════════════════════════════════════════

def cmd_new(args):
    """Create a new payload from template."""
    name = args.name
    category = args.category or "nullsec/misc"
    template = args.template or "basic"
    description = args.description or ""

    if template not in TEMPLATES:
        err(f"Unknown template: {template}")
        print(f"  Available: {', '.join(TEMPLATES.keys())}")
        return 1

    payload_dir = SUITE_DIR / name
    if payload_dir.exists():
        err(f"Payload already exists: {name}")
        return 1

    payload_dir.mkdir(parents=True)

    # Write payload.sh
    payload_file = payload_dir / "payload.sh"
    payload_file.write_text(get_template(name, template))
    payload_file.chmod(0o755)

    # Write info.json
    info_file = payload_dir / "info.json"
    info_data = get_info_json(name, description, category, template)
    info_file.write_text(json.dumps(info_data, indent=2) + "\n")

    ok(f"Created payload: {c(name, 'w')}")
    info(f"Template: {template}")
    info(f"Category: {category}")
    info(f"Directory: {payload_dir}")
    info(f"Edit: {payload_file}")
    print()
    print(f"  Next steps:")
    print(f"    1. Edit {c('payload.sh', 'c')} with your logic")
    print(f"    2. Update {c('info.json', 'c')} description")
    print(f"    3. Run {c('payload-builder validate ' + name, 'g')}")
    return 0


def cmd_validate(args):
    """Validate one or all payloads."""
    print(c("  Validating payloads...\n", "c"))

    if args.path:
        path = Path(args.path)
        if path.is_dir():
            path = path / "payload.sh"
        linter = PayloadLinter(path).lint()
        linter.report()
        return 0 if not linter.errors else 1
    else:
        # Validate all
        errors = 0
        checked = 0
        for payload_dir in sorted(SUITE_DIR.iterdir()):
            payload_sh = payload_dir / "payload.sh"
            if payload_sh.exists():
                linter = PayloadLinter(payload_sh).lint()
                if not linter.report():
                    errors += 1
                checked += 1

        print()
        print(f"  Checked: {c(str(checked), 'w')} payloads")
        if errors:
            err(f"{errors} payloads have errors")
        else:
            ok("All payloads passed validation")
        return 1 if errors else 0


def cmd_lint(args):
    """Alias for validate with more detail."""
    return cmd_validate(args)


def cmd_package(args):
    """Package a payload for distribution."""
    name = args.name
    payload_dir = SUITE_DIR / name
    output_dir = Path(args.output) if args.output else Path(".")

    if not payload_dir.exists():
        err(f"Payload not found: {name}")
        return 1

    # Validate first
    linter = PayloadLinter(payload_dir / "payload.sh").lint()
    if linter.errors:
        err("Fix errors before packaging:")
        linter.report()
        return 1

    # Create tarball
    output_dir.mkdir(parents=True, exist_ok=True)
    archive = output_dir / f"{name}-v1.0.0.tar.gz"

    import tarfile
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(payload_dir, arcname=name)

    size = archive.stat().st_size
    ok(f"Packaged: {c(str(archive), 'w')} ({size:,} bytes)")
    return 0


def cmd_list(args):
    """List all payloads."""
    fmt = args.format or "table"
    cat_filter = args.category

    payloads = []
    for payload_dir in sorted(SUITE_DIR.iterdir()):
        info_file = payload_dir / "info.json"
        payload_sh = payload_dir / "payload.sh"

        if not payload_sh.exists():
            continue

        data = {"name": payload_dir.name, "category": "unknown", "description": ""}
        if info_file.exists():
            try:
                data.update(json.loads(info_file.read_text()))
            except Exception:
                pass

        if cat_filter and cat_filter not in data.get("category", ""):
            continue

        payloads.append(data)

    if fmt == "json":
        print(json.dumps(payloads, indent=2))
    elif fmt == "csv":
        print("name,category,description,author,version")
        for p in payloads:
            print(f"{p['name']},{p.get('category','')},{p.get('description','')},{p.get('author','')},{p.get('version','')}")
    else:
        # Table format
        if not payloads:
            warn("No payloads found")
            return 0

        cats = {}
        for p in payloads:
            cat = p.get("category", "unknown")
            cats.setdefault(cat, []).append(p)

        print(f"\n  {c('NullSec Suite', 'g')} — {c(str(len(payloads)), 'w')} payloads\n")
        for cat in sorted(cats.keys()):
            print(f"  {c(cat, 'c')} ({len(cats[cat])})")
            for p in cats[cat]:
                desc = p.get("description", "")[:50]
                print(f"    {c(p['name'], 'w'):30s} {c(desc, 'd')}")
            print()

    return 0


def cmd_stats(args):
    """Show suite statistics."""
    total = 0
    cats = {}
    authors = {}
    has_info = 0
    has_loot = 0
    total_lines = 0

    for payload_dir in sorted(SUITE_DIR.iterdir()):
        payload_sh = payload_dir / "payload.sh"
        if not payload_sh.exists():
            continue

        total += 1
        content = payload_sh.read_text()
        total_lines += content.count("\n")

        if (payload_dir / "info.json").exists():
            has_info += 1
            try:
                data = json.loads((payload_dir / "info.json").read_text())
                cat = data.get("category", "unknown")
                author = data.get("author", "unknown")
                cats[cat] = cats.get(cat, 0) + 1
                authors[author] = authors.get(author, 0) + 1
            except Exception:
                pass

        if "LOOT_DIR=" in content:
            has_loot += 1

    print(BANNER)
    print(f"  {c('Total Payloads:', 'w')}  {c(str(total), 'g')}")
    print(f"  {c('Total Lines:', 'w')}     {c(f'{total_lines:,}', 'c')}")
    print(f"  {c('With info.json:', 'w')} {c(str(has_info), 'g')}/{total}")
    print(f"  {c('With LOOT_DIR:', 'w')}  {c(str(has_loot), 'g')}/{total}")
    print()
    print(f"  {c('Categories:', 'w')}")
    for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
        bar = "█" * count
        print(f"    {cat:30s} {c(str(count), 'w'):>3s} {c(bar, 'g')}")
    print()
    print(f"  {c('Authors:', 'w')}")
    for author, count in sorted(authors.items(), key=lambda x: -x[1]):
        print(f"    {author:30s} {c(str(count), 'w')}")
    return 0


def cmd_doctor(args):
    """Health check the entire suite."""
    print(BANNER)
    print(c("  Running suite health check...\n", "c"))

    checks = {
        "suite_dir": SUITE_DIR.exists(),
        "nodes_conf": Path(NODES_CONF).exists() if 'NODES_CONF' in dir() else False,
    }

    if checks["suite_dir"]:
        ok(f"Suite directory: {SUITE_DIR}")
    else:
        err(f"Suite directory not found: {SUITE_DIR}")
        return 1

    # Check all payloads
    total = 0
    errors = 0
    for payload_dir in sorted(SUITE_DIR.iterdir()):
        payload_sh = payload_dir / "payload.sh"
        if payload_sh.exists():
            total += 1
            linter = PayloadLinter(payload_sh).lint()
            if linter.errors:
                errors += 1
                linter.report()

    print()
    ok(f"Checked {total} payloads")
    if errors:
        err(f"{errors} payloads have errors")
    else:
        ok("All payloads healthy")

    return 1 if errors else 0


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="NullSec Payload Builder - Create, validate, and package payloads",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")

    sub = parser.add_subparsers(dest="command")

    # new
    p_new = sub.add_parser("new", help="Create a new payload")
    p_new.add_argument("name", help="Payload name (PascalCase)")
    p_new.add_argument("--category", "-c", help="Category (e.g., nullsec/attack)")
    p_new.add_argument("--template", "-t", choices=TEMPLATES.keys(), help="Template type")
    p_new.add_argument("--description", "-d", help="Payload description")

    # validate
    p_val = sub.add_parser("validate", help="Validate payloads")
    p_val.add_argument("path", nargs="?", help="Payload path (or validate all)")

    # lint
    p_lint = sub.add_parser("lint", help="Lint payloads (alias for validate)")
    p_lint.add_argument("path", nargs="?", help="Payload path")

    # package
    p_pkg = sub.add_parser("package", help="Package payload for distribution")
    p_pkg.add_argument("name", help="Payload name")
    p_pkg.add_argument("--output", "-o", help="Output directory")

    # list
    p_list = sub.add_parser("list", help="List payloads")
    p_list.add_argument("--category", "-c", help="Filter by category")
    p_list.add_argument("--format", "-f", choices=["table", "json", "csv"], help="Output format")

    # stats
    sub.add_parser("stats", help="Suite statistics")

    # doctor
    sub.add_parser("doctor", help="Health check suite")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    commands = {
        "new": cmd_new, "validate": cmd_validate, "lint": cmd_lint,
        "package": cmd_package, "list": cmd_list, "stats": cmd_stats,
        "doctor": cmd_doctor,
    }

    return commands[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
