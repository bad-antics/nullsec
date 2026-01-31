#!/usr/bin/env python3
"""
NULLSEC FRAMEWORK AI - Advanced AI-Powered Security Operations
Enhanced AI integration for offensive security automation
Developed by bad-antics

Enhanced Features:
- Multi-provider AI support (Anthropic, OpenAI, Copilot, Ollama)
- Autonomous exploit chain generation
- Real-time vulnerability analysis
- Intelligent payload crafting
- Attack path planning and optimization
- Context-aware command execution
- Learning from attack results
- Multi-target orchestration
"""

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
CONFIG_FILE = os.path.join(SCRIPT_DIR, '.nullsec-ai.json')
DB_FILE = os.path.join(SCRIPT_DIR, '.nullsec-ai.db')
OPENCODE_CONFIG = os.path.expanduser('~/.opencode.json')
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'http://localhost:11434')

# Enhanced AI System Prompts
ATTACK_PROMPTS = {
    "network": """You are NULLSEC AI, an elite offensive security expert specialized in network attacks.
Your capabilities include:
- Advanced port scanning and service enumeration (nmap, masscan, rustscan)
- Network sniffing and packet analysis (tcpdump, wireshark, tshark)
- MITM attacks (bettercap, ettercap, mitmproxy)
- Network pivoting and tunneling (chisel, ligolo-ng, sshuttle)
- Protocol exploitation (scapy, yersinia)
- Traffic manipulation and injection

Always provide:
1. Reconnaissance commands
2. Working attack commands with optimal parameters
3. Post-exploitation steps
4. Detection evasion techniques
5. Clean-up procedures""",

    "web": """You are NULLSEC AI, an elite web application security expert.
Your capabilities include:
- SQL injection (sqlmap, manual injection)
- XSS attacks (DOM, reflected, stored)
- Directory/file enumeration (gobuster, ffuf, feroxbuster)
- Authentication bypass and session hijacking
- SSRF, XXE, SSTI exploitation
- API testing and GraphQL attacks
- WebSocket exploitation
- WAF bypass techniques

Provide complete attack chains with:
1. Reconnaissance (technology detection, parameter fuzzing)
2. Vulnerability identification
3. Exploitation with working payloads
4. Post-exploitation (data exfiltration, privilege escalation)
5. Persistence mechanisms""",

    "wireless": """You are NULLSEC AI, an elite wireless security expert.
Your capabilities include:
- WiFi attacks (WPA/WPA2/WPA3 cracking, deauth, evil twin)
- Bluetooth exploitation (BlueBorne, KNOB, SweynTooth)
- RFID/NFC attacks (cloning, sniffing, replay)
- Zigbee/Z-Wave exploitation
- SDR-based attacks (replay, jamming, signal analysis)
- Rogue AP deployment

Provide:
1. Wireless reconnaissance commands
2. Capture and attack strategies
3. Cracking techniques with optimal wordlists
4. Post-compromise actions
5. Stealth considerations""",

    "credentials": """You are NULLSEC AI, an elite credential attack specialist.
Your capabilities include:
- Password cracking (hashcat GPU optimization, john, rule generation)
- Hash analysis and identification
- Credential stuffing and spraying
- Kerberoasting and AS-REP roasting
- Pass-the-hash and pass-the-ticket
- NTDS.dit extraction and parsing
- LSASS dumping techniques
- Token manipulation

Provide optimized:
1. Hash identification and extraction
2. Cracking strategies (rules, masks, hybrid attacks)
3. Online attack techniques (rate limiting, detection evasion)
4. Post-compromise credential harvesting
5. Lateral movement with credentials""",

    "social": """You are NULLSEC AI, an elite social engineering specialist.
Your capabilities include:
- Phishing campaign design and execution
- Pretexting scenario development
- Vishing and smishing tactics
- Physical security bypass techniques
- OSINT-driven targeting
- Psychological manipulation frameworks
- Credential harvesting pages

Provide complete campaigns with:
1. Target profiling and OSINT
2. Pretext development
3. Technical infrastructure (domains, hosting, templates)
4. Execution timeline and tactics
5. Post-engagement analysis""",

    "malware": """You are NULLSEC AI, an elite malware development specialist.
Your capabilities include:
- Payload generation (msfvenom, C2 frameworks)
- Persistence mechanisms (registry, services, scheduled tasks)
- Evasion techniques (obfuscation, encryption, polymorphism)
- Anti-analysis features (anti-debugging, anti-VM, sandbox detection)
- C2 infrastructure (Cobalt Strike, Havoc, custom protocols)
- Fileless malware techniques
- Rootkit development

Provide:
1. Payload generation with evasion
2. Delivery mechanisms
3. Persistence strategies
4. C2 communication setup
5. Detection bypass techniques""",

    "exploitation": """You are NULLSEC AI, an elite binary exploitation expert.
Your capabilities include:
- Buffer overflow exploitation (stack, heap)
- ROP chain development
- Format string exploitation
- Use-after-free exploitation
- Kernel exploitation
- Shellcode development and optimization
- ASLR/DEP/CFG bypass
- Exploit stability enhancement

Provide:
1. Binary analysis (checksec, IDA, Ghidra)
2. Vulnerability identification
3. Exploit development with working code
4. Reliability improvements
5. Payload delivery mechanisms""",

    "recon": """You are NULLSEC AI, an elite reconnaissance specialist.
Your capabilities include:
- OSINT gathering (theHarvester, recon-ng, Maltego)
- Subdomain enumeration (amass, subfinder, assetfinder)
- DNS intelligence (dnsenum, fierce, dnsrecon)
- Service fingerprinting (nmap, whatweb, wappalyzer)
- Shodan/Censys/ZoomEye searches
- GitHub/GitLab secret scanning
- Metadata extraction and analysis
- Social media intelligence

Provide comprehensive recon:
1. Passive information gathering
2. Active enumeration
3. Attack surface mapping
4. Vulnerability correlation
5. Target prioritization""",

    "cloud": """You are NULLSEC AI, an elite cloud security expert.
Your capabilities include:
- AWS/Azure/GCP enumeration and exploitation
- Cloud storage misconfiguration (S3, Azure Blob, GCS)
- IAM privilege escalation
- Serverless exploitation (Lambda, Functions)
- Container escape and Kubernetes attacks
- API Gateway exploitation
- Metadata service abuse

Provide:
1. Cloud environment reconnaissance
2. Misconfiguration identification
3. Privilege escalation paths
4. Data exfiltration techniques
5. Persistence in cloud environments""",

    "iot": """You are NULLSEC AI, an elite IoT security expert.
Your capabilities include:
- Firmware analysis and extraction
- Protocol reverse engineering (MQTT, CoAP, Zigbee)
- Hardware hacking (UART, JTAG, SPI)
- Embedded system exploitation
- Industrial Control System attacks
- Smart home device exploitation
- Automotive security testing

Provide:
1. Device reconnaissance and fingerprinting
2. Firmware extraction and analysis
3. Protocol exploitation
4. Hardware interface attacks
5. Post-compromise pivoting""",

    "active_directory": """You are NULLSEC AI, an elite Active Directory security expert.
Your capabilities include:
- AD enumeration (BloodHound, ADExplorer, PowerView)
- Kerberoasting and AS-REP roasting
- DCSync attacks
- Golden/Silver ticket generation
- GPO abuse and exploitation
- ADCS exploitation
- LAPS password extraction
- Trust relationship exploitation

Provide:
1. AD reconnaissance commands
2. Attack path identification
3. Credential harvesting
4. Privilege escalation chains
5. Domain dominance techniques""",

    "general": """You are NULLSEC AI, an elite offensive security expert for the NULLSEC Framework.
Developed by bad-antics, you provide comprehensive red team and penetration testing capabilities.

You excel at:
- Multi-stage attack planning and execution
- Exploit chain development
- Custom tool and payload creation
- Detection evasion and stealth operations
- Automated vulnerability assessment
- Post-exploitation and persistence
- Data exfiltration strategies
- Attack simulation and red teaming

Always provide:
1. Clear, executable commands with all required parameters
2. Multiple approaches for resilience
3. Evasion techniques to avoid detection
4. Post-exploitation steps
5. Evidence collection and reporting guidance

You can execute commands, analyze results, adapt strategies, and provide complete attack narratives."""
}

class AttackKnowledgeBase:
    """SQLite-based knowledge base for storing attack patterns and results"""
    
    def __init__(self, db_path: str = DB_FILE):
        self.db_path = db_path
        self.init_db()
    
    def init_db(self):
        """Initialize database schema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Attack sessions
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                target TEXT NOT NULL,
                category TEXT,
                start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                end_time TIMESTAMP,
                success BOOLEAN,
                notes TEXT
            )
        """)
        
        # Commands executed
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS commands (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER,
                command TEXT NOT NULL,
                output TEXT,
                exit_code INTEGER,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
        """)
        
        # Vulnerabilities found
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
        
        # Attack patterns (for learning)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS patterns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT,
                target_profile TEXT,
                attack_chain TEXT,
                success_rate REAL,
                avg_time REAL,
                notes TEXT
            )
        """)
        
        # Tool outputs and artifacts
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS artifacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER,
                artifact_type TEXT,
                file_path TEXT,
                description TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
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
            (session_id, command, output[:10000], exit_code)  # Limit output size
        )
        conn.commit()
        conn.close()
    
    def log_vulnerability(self, session_id: int, vuln_type: str, severity: str, 
                         description: str, poc: str = ""):
        """Log discovered vulnerability"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO vulnerabilities (session_id, vuln_type, severity, description, proof_of_concept) VALUES (?, ?, ?, ?, ?)",
            (session_id, vuln_type, severity, description, poc)
        )
        conn.commit()
        conn.close()
    
    def get_similar_attacks(self, target_profile: str, category: str) -> List[Dict]:
        """Get similar successful attacks for learning"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT attack_chain, success_rate, notes
            FROM patterns
            WHERE category = ? AND target_profile LIKE ?
            ORDER BY success_rate DESC
            LIMIT 5
        """, (category, f"%{target_profile}%"))
        
        results = []
        for row in cursor.fetchall():
            results.append({
                "chain": row[0],
                "success_rate": row[1],
                "notes": row[2]
            })
        
        conn.close()
        return results
    
    def end_session(self, session_id: int, success: bool = False, notes: str = ""):
        """End attack session"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE sessions SET end_time = CURRENT_TIMESTAMP, success = ?, notes = ? WHERE id = ?",
            (success, notes, session_id)
        )
        conn.commit()
        conn.close()


class NullSecAI:
    """Enhanced NULLSEC Framework AI with multi-provider support and autonomous capabilities"""
    
    def __init__(self):
        self.opencode_available = self._check_opencode()
        self.ollama_available = self._check_ollama()
        self.config = self._load_config()
        self.current_target = None
        self.current_session = None
        self.kb = AttackKnowledgeBase()
        self.session_history = []
        self.context_buffer = []
        
    def _check_opencode(self) -> bool:
        """Check if opencode is installed"""
        return shutil.which('opencode') is not None
    
    def _check_ollama(self) -> bool:
        """Check if Ollama is running"""
        try:
            result = subprocess.run(
                ['curl', '-s', f'{OLLAMA_HOST}/api/tags'],
                capture_output=True,
                timeout=2
            )
            return result.returncode == 0
        except:
            return False
    
    def _load_config(self) -> dict:
        """Load NULLSEC AI configuration"""
        default_config = {
            "provider": "anthropic",  # anthropic, openai, copilot, ollama
            "model": "claude-sonnet-4-20250514",
            "ollama_model": "llama3.1:70b",
            "temperature": 0.7,
            "max_tokens": 8000,
            "auto_execute": False,
            "confirm_dangerous": True,
            "log_sessions": True,
            "default_category": "general",
            "autonomous_mode": False,
            "multi_target": False,
            "learning_enabled": True,
            "exploit_db_path": "/usr/share/exploitdb",
            "wordlist_path": "/usr/share/wordlists"
        }
        
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    config = json.load(f)
                    default_config.update(config)
            except:
                pass
        
        return default_config
    
    def _save_config(self):
        """Save configuration"""
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def print_banner(self):
        """Print enhanced NULLSEC AI banner"""
        print(f"""
{Colors.RED}    ███▓   ██▓██▓   ██▓██▓     ██▓     ███████▓███████▓ ██████▓
    ████▓  ██████   ██████     ███     ██▓━━━━▓██▓━━━━▓██▓━━━━▓
    ██▓██▓ ██████   ██████     ███     ███████▓█████▓  ███     
    ███▓██▓██████   ██████     ███     ▓━━━━█████▓━━▓  ███     
    ███ ▓█████▓██████▓▓███████▓███████▓███████████████▓▓██████▓
    ▓━▓  ▓━━━╸ ╺━━━━━╸ ╺━━━━━━╸╺━━━━━━╸╺━━━━━━╸╺━━━━━━╸ ╺━━━━━╸
         █████== ██==    ███████==███==   ██==██==  ██== █████== ███==   ██== ██████==███████==██████== 
        ██==██==██|    ██====████==  ██|██|  ██|██==██==████==  ██|██====██====██==██==
        ███████|██|    █████==  ██==██== ██|███████|███████|██==██== ██|██|     █████==  ██|  ██|
        ██==██|██|    ██====  ██|==██==██|██==██|██==██|██|==██==██|██|     ██====  ██|  ██|
        ██|  ██|██|    ███████==██| ==████|██|  ██|██|  ██|██| ==████|==██████==███████==██████====
        ====  ========    ========  ========  ========  ========  ==== ============ {Colors.RESET}
{Colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.RESET}
{Colors.WHITE}                      ☠  NULLSEC FRAMEWORK AI ENHANCED  ☠{Colors.RESET}
{Colors.MAGENTA}              AI-Powered Autonomous Security Operations{Colors.RESET}
{Colors.DIM}                       bad-antics development v2.0{Colors.RESET}
{Colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.RESET}
""")
        
        # Show system status
        status = []
        if self.opencode_available:
            status.append(f"{Colors.GREEN}✓ OpenCode{Colors.RESET}")
        if self.ollama_available:
            status.append(f"{Colors.GREEN}✓ Ollama{Colors.RESET}")
        
        provider_status = f"{Colors.GREEN}✓{Colors.RESET}" if self.config['provider'] else f"{Colors.RED}✗{Colors.RESET}"
        status.append(f"{provider_status} Provider: {self.config['provider']}")
        
        if status:
            print(f"{Colors.DIM}  Status: {' | '.join(status)}{Colors.RESET}\n")
    
    def execute_with_ollama(self, prompt: str, system_prompt: str = "") -> Optional[str]:
        """Execute prompt with local Ollama"""
        if not self.ollama_available:
            return None
        
        payload = {
            "model": self.config.get("ollama_model", "llama3.1:70b"),
            "prompt": prompt,
            "system": system_prompt,
            "stream": False,
            "options": {
                "temperature": self.config.get("temperature", 0.7),
                "num_predict": self.config.get("max_tokens", 4000)
            }
        }
        
        try:
            result = subprocess.run(
                ['curl', '-s', f'{OLLAMA_HOST}/api/generate', 
                 '-d', json.dumps(payload)],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode == 0:
                response = json.loads(result.stdout)
                return response.get('response', '')
        except Exception as e:
            print(f"{Colors.YELLOW}[!] Ollama error: {e}{Colors.RESET}")
        
        return None
    
    def execute_with_opencode(self, prompt: str, system_prompt: str = "", 
                             interactive: bool = False) -> Optional[str]:
        """Execute prompt through OpenCode"""
        if not self.opencode_available:
            return None
        
        full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
        
        if interactive:
            os.chdir(SCRIPT_DIR)
            subprocess.run(['opencode'], check=False)
            return None
        else:
            try:
                result = subprocess.run(
                    ['opencode', '-p', full_prompt, '-q'],
                    capture_output=True,
                    text=True,
                    timeout=120,
                    cwd=SCRIPT_DIR
                )
                
                if result.returncode == 0:
                    return result.stdout.strip()
                    
            except subprocess.TimeoutExpired:
                print(f"{Colors.YELLOW}[!] Request timed out{Colors.RESET}")
            except Exception as e:
                print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
        
        return None
    
    def execute_ai_prompt(self, prompt: str, category: str = "general", 
                          interactive: bool = False, use_context: bool = True) -> Optional[str]:
        """Execute AI prompt with provider selection and context"""
        
        # Build system context
        system_prompt = ATTACK_PROMPTS.get(category, ATTACK_PROMPTS["general"])
        
        # Add target context
        if self.current_target:
            system_prompt += f"\n\nCurrent target: {self.current_target}"
        
        # Add session history for context
        if use_context and self.context_buffer:
            context = "\n".join(self.context_buffer[-5:])  # Last 5 interactions
            system_prompt += f"\n\nRecent context:\n{context}"
        
        # Add learned patterns
        if self.config.get("learning_enabled") and self.current_target:
            similar = self.kb.get_similar_attacks(self.current_target, category)
            if similar:
                patterns = "\n".join([f"- {s['chain']} (success: {s['success_rate']})" for s in similar[:3]])
                system_prompt += f"\n\nSuccessful patterns for similar targets:\n{patterns}"
        
        # Execute based on provider
        provider = self.config.get("provider", "anthropic")
        response = None
        
        if provider == "ollama" and self.ollama_available:
            response = self.execute_with_ollama(prompt, system_prompt)
        elif provider in ["anthropic", "openai", "copilot"] and self.opencode_available:
            response = self.execute_with_opencode(prompt, system_prompt, interactive)
        else:
            # Fallback
            if self.opencode_available:
                response = self.execute_with_opencode(prompt, system_prompt, interactive)
            elif self.ollama_available:
                response = self.execute_with_ollama(prompt, system_prompt)
        
        # Store in context buffer
        if response and use_context:
            self.context_buffer.append(f"Q: {prompt[:100]}\nA: {response[:200]}")
            if len(self.context_buffer) > 10:
                self.context_buffer.pop(0)
        
        return response
    
    def autonomous_attack(self, target: str, category: str = "general", 
                         max_iterations: int = 10) -> bool:
        """Fully autonomous attack execution with adaptive strategy"""
        
        print(f"\n{Colors.RED}{'='*80}{Colors.RESET}")
        print(f"{Colors.WHITE}  AUTONOMOUS ATTACK MODE{Colors.RESET}")
        print(f"{Colors.RED}{'='*80}{Colors.RESET}\n")
        
        self.current_target = target
        session_id = self.kb.create_session(target, category)
        self.current_session = session_id
        
        iteration = 0
        objectives_completed = []
        
        # Initial reconnaissance
        print(f"{Colors.CYAN}[Phase 1]{Colors.RESET} Initial Reconnaissance")
        recon_prompt = f"""Target: {target}

Execute comprehensive reconnaissance:
1. Identify live services and open ports
2. Enumerate technologies and versions
3. Search for known vulnerabilities
4. Identify attack vectors
5. Provide initial attack plan

Provide executable commands and interpret results."""
        
        recon_result = self.execute_ai_prompt(recon_prompt, "recon")
        
        if not recon_result:
            print(f"{Colors.RED}[!] Reconnaissance failed{Colors.RESET}")
            return False
        
        print(f"\n{Colors.GREEN}{recon_result}{Colors.RESET}\n")
        
        # Extract and execute recon commands
        commands = self._extract_commands(recon_result)
        recon_output = {}
        
        for cmd in commands[:5]:  # Limit initial recon
            print(f"{Colors.DIM}[>] {cmd}{Colors.RESET}")
            success, output = self._execute_command_safe(cmd, session_id)
            if success:
                recon_output[cmd] = output
        
        # Adaptive attack phase
        while iteration < max_iterations:
            iteration += 1
            print(f"\n{Colors.CYAN}[Phase {iteration + 1}]{Colors.RESET} Exploitation Attempt {iteration}")
            
            # Build context from previous attempts
            context = f"""Target: {target}
Iteration: {iteration}/{max_iterations}
Completed objectives: {', '.join(objectives_completed) if objectives_completed else 'None'}

Reconnaissance results:
{json.dumps(recon_output, indent=2)[:2000]}

Based on the above, determine next attack vector and execute.
Provide:
1. Attack strategy
2. Executable commands
3. Expected outcomes
4. Alternative approaches if this fails

Focus on: {'exploitation' if iteration < 5 else 'privilege escalation and persistence'}
"""
            
            attack_result = self.execute_ai_prompt(context, category)
            
            if not attack_result:
                continue
            
            print(f"\n{Colors.WHITE}{attack_result}{Colors.RESET}\n")
            
            # Execute attack commands
            attack_commands = self._extract_commands(attack_result)
            
            for cmd in attack_commands[:3]:  # Limit per iteration
                print(f"{Colors.YELLOW}[*] Executing: {cmd}{Colors.RESET}")
                success, output = self._execute_command_safe(cmd, session_id)
                
                if success and output:
                    # Check for success indicators
                    if any(indicator in output.lower() for indicator in 
                          ['shell', 'session', 'success', 'password', 'flag', 'root']):
                        objectives_completed.append(f"Iteration {iteration}")
                        print(f"{Colors.GREEN}[+] Objective achieved!{Colors.RESET}")
                        
                        # Log vulnerability
                        self.kb.log_vulnerability(
                            session_id, 
                            category,
                            "HIGH",
                            f"Successful exploitation at iteration {iteration}",
                            cmd
                        )
            
            # Check if we should continue
            if len(objectives_completed) >= 3:
                print(f"\n{Colors.GREEN}[+] Multiple objectives achieved. Attack successful!{Colors.RESET}")
                self.kb.end_session(session_id, True, f"Completed {len(objectives_completed)} objectives")
                return True
        
        print(f"\n{Colors.YELLOW}[*] Max iterations reached{Colors.RESET}")
        self.kb.end_session(session_id, len(objectives_completed) > 0, 
                           f"Completed {len(objectives_completed)} objectives")
        return len(objectives_completed) > 0
    
    def _extract_commands(self, text: str) -> List[str]:
        """Enhanced command extraction with better pattern matching"""
        commands = []
        
        # Match code blocks
        code_blocks = re.findall(r'```(?:bash|sh|shell)?\n(.*?)```', text, re.DOTALL)
        for block in code_blocks:
            for line in block.strip().split('\n'):
                line = line.strip()
                if line and not line.startswith('#') and len(line) > 3:
                    # Remove common prefixes
                    line = re.sub(r'^[\$>\#]\s*', '', line)
                    if line:
                        commands.append(line)
        
        # Match inline commands
        patterns = [
            r'(?:^|\n)\s*[$>]\s*(.+?)(?:\n|$)',
            r'(?:execute|run):\s*`([^`]+)`',
            r'(?:command|cmd):\s*(.+?)(?:\n|$)',
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, text, re.MULTILINE)
            for match in matches:
                if match.strip() and len(match.strip()) > 3:
                    commands.append(match.strip())
        
        # Match tool-specific patterns
        tools = ['nmap', 'sqlmap', 'hydra', 'nikto', 'gobuster', 'ffuf', 'msfconsole',
                'metasploit', 'john', 'hashcat', 'aircrack', 'ettercap', 'bettercap',
                'wpscan', 'nuclei', 'amass', 'subfinder', 'feroxbuster']
        
        for line in text.split('\n'):
            line = line.strip()
            if any(line.startswith(tool) for tool in tools):
                commands.append(line)
        
        # Deduplicate while preserving order
        seen = set()
        unique_commands = []
        for cmd in commands:
            if cmd not in seen and len(cmd) > 3:
                seen.add(cmd)
                unique_commands.append(cmd)
        
        return unique_commands
    
    def _execute_command_safe(self, command: str, session_id: Optional[int] = None) -> Tuple[bool, str]:
        """Execute command with safety checks and logging"""
        
        # Blacklist dangerous commands
        dangerous_patterns = [
            r'rm\s+-rf\s+/',
            r'mkfs',
            r'dd\s+if=.*of=/dev/',
            r':(\(\)){:\|:&};:',  # Fork bomb
            r'>\s*/dev/sd',
            r'shred\s+/dev/',
        ]
        
        for pattern in dangerous_patterns:
            if re.search(pattern, command, re.IGNORECASE):
                print(f"{Colors.RED}[!] BLOCKED: Dangerous command detected{Colors.RESET}")
                return False, ""
        
        # Confirm risky commands
        if self.config.get("confirm_dangerous", True):
            risky_keywords = ['rm', 'dd', 'mkfs', 'fdisk', 'format', 'del', 'shutdown', 'reboot']
            if any(keyword in command.lower() for keyword in risky_keywords):
                confirm = input(f"{Colors.YELLOW}[?] Execute risky command? {command}\n    [y/N]: {Colors.RESET}")
                if confirm.lower() != 'y':
                    return False, ""
        
        # Execute
        print(f"{Colors.DIM}[>] {command}{Colors.RESET}")
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            output = result.stdout + result.stderr
            success = result.returncode == 0
            
            # Log to knowledge base
            if session_id:
                self.kb.log_command(session_id, command, output, result.returncode)
            
            # Display output
            if output:
                print(output[:2000])  # Limit output display
                if len(output) > 2000:
                    print(f"{Colors.DIM}... (output truncated){Colors.RESET}")
            
            return success, output
            
        except subprocess.TimeoutExpired:
            print(f"{Colors.YELLOW}[!] Command timed out{Colors.RESET}")
            return False, "TIMEOUT"
        except Exception as e:
            print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
            return False, str(e)
    
    def generate_payload(self, payload_type: str, target_os: str = "linux", 
                        lhost: str = "10.0.0.100", lport: int = 4444) -> Optional[str]:
        """AI-powered payload generation with evasion"""
        
        prompt = f"""Generate a {payload_type} payload for {target_os}.

Requirements:
- Target OS: {target_os}
- LHOST: {lhost}
- LPORT: {lport}
- Include evasion techniques (obfuscation, encoding, anti-AV)
- Provide multiple delivery methods
- Include persistence mechanism

Provide:
1. Payload code (fully functional)
2. Compilation/preparation commands
3. Delivery methods
4. Listener setup
5. Post-exploitation steps

Make it production-ready and evasive."""
        
        result = self.execute_ai_prompt(prompt, "malware")
        
        if result:
            # Save to file
            payload_dir = os.path.join(SCRIPT_DIR, "payloads")
            os.makedirs(payload_dir, exist_ok=True)
            
            filename = f"{payload_type}_{target_os}_{int(time.time())}.txt"
            filepath = os.path.join(payload_dir, filename)
            
            with open(filepath, 'w') as f:
                f.write(result)
            
            print(f"\n{Colors.GREEN}[+] Payload saved: {filepath}{Colors.RESET}\n")
        
        return result
    
    def analyze_vulnerability(self, vuln_id: str) -> Optional[str]:
        """AI-powered vulnerability analysis and exploitation guide"""
        
        prompt = f"""Analyze vulnerability: {vuln_id}

Provide comprehensive analysis:
1. Vulnerability description and affected systems
2. Technical details and root cause
3. Exploitation techniques and proof-of-concept
4. Available exploits and tools
5. Detection and mitigation strategies

If this is a CVE, search ExploitDB and provide working exploits.
Include executable commands and code."""
        
        result = self.execute_ai_prompt(prompt, "exploitation")
        return result
    
    def interactive_console(self):
        """Enhanced interactive console with more capabilities"""
        self.print_banner()
        
        # Check dependencies
        if not self.opencode_available and not self.ollama_available:
            print(f"{Colors.YELLOW}[!] No AI backend available{Colors.RESET}")
            print(f"{Colors.CYAN}[?] Install OpenCode or Ollama to continue{Colors.RESET}\n")
            
            choice = input(f"  1) Install OpenCode\n  2) Setup Ollama\n  3) Exit\n\n  Choice: ")
            
            if choice == '1':
                self.install_opencode()
                self.configure_opencode()
            elif choice == '2':
                self.setup_ollama()
            else:
                return
        
        print(f"""
{Colors.YELLOW}  ENHANCED COMMANDS:{Colors.RESET}
{Colors.CYAN}Core AI:{Colors.RESET}
  ai                    - Interactive AI assistant
  ask <prompt>          - Ask AI a question
  attack <module>       - Execute attack module
  autonomous <target>   - Fully autonomous attack
  
{Colors.CYAN}Payloads & Exploits:{Colors.RESET}
  payload <type>        - Generate custom payload
  exploit <CVE>         - Analyze and exploit vulnerability
  obfuscate <code>      - Obfuscate code for evasion
  
{Colors.CYAN}Intelligence:{Colors.RESET}
  recon <target>        - Comprehensive reconnaissance
  vuln-scan <target>    - AI-powered vulnerability scan
  attack-path <target>  - Generate attack path
  
{Colors.CYAN}Session Management:{Colors.RESET}
  target <ip>           - Set current target
  session               - View current session
  history               - View command history
  export                - Export session report
  
{Colors.CYAN}Configuration:{Colors.RESET}
  config                - Configure settings
  provider <name>       - Switch AI provider
  model <name>          - Change model
  
{Colors.CYAN}Other:{Colors.RESET}
  help                  - Show this help
  clear                 - Clear screen
  exit                  - Exit console
""")
        
        while True:
            try:
                # Build prompt
                prompt_parts = [f"{Colors.RED}nullsec-ai{Colors.RESET}"]
                
                if self.current_target:
                    prompt_parts.append(f"{Colors.CYAN}({self.current_target}){Colors.RESET}")
                
                if self.current_session:
                    prompt_parts.append(f"{Colors.DIM}[S:{self.current_session}]{Colors.RESET}")
                
                prompt_str = " ".join(prompt_parts) + f" {Colors.WHITE}>{Colors.RESET} "
                
                cmd = input(prompt_str).strip()
                
                if not cmd:
                    continue
                    
                # Parse command
                parts = cmd.split(maxsplit=1)
                command = parts[0].lower()
                args = parts[1] if len(parts) > 1 else ""
                
                # Execute command
                if command in ['exit', 'quit', 'q']:
                    break
                    
                elif command == 'clear':
                    os.system('clear')
                    self.print_banner()
                    
                elif command == 'ai':
                    self.execute_ai_prompt("", interactive=True)
                    
                elif command == 'ask':
                    if args:
                        response = self.execute_ai_prompt(args)
                        if response:
                            print(f"\n{Colors.WHITE}{response}{Colors.RESET}\n")
                    else:
                        print(f"{Colors.YELLOW}[!] Usage: ask <question>{Colors.RESET}")
                        
                elif command == 'attack':
                    if args:
                        self.auto_execute_attack(args, "general")
                    else:
                        print(f"{Colors.YELLOW}[!] Usage: attack <module>{Colors.RESET}")
                        
                elif command == 'autonomous':
                    if args:
                        self.autonomous_attack(args)
                    else:
                        print(f"{Colors.YELLOW}[!] Usage: autonomous <target>{Colors.RESET}")
                        
                elif command == 'payload':
                    payload_type = args or "reverse_shell"
                    lhost = input(f"  LHOST [10.0.0.100]: ").strip() or "10.0.0.100"
                    lport = input(f"  LPORT [4444]: ").strip() or "4444"
                    target_os = input(f"  OS [linux]: ").strip() or "linux"
                    
                    result = self.generate_payload(payload_type, target_os, lhost, int(lport))
                    if result:
                        print(f"\n{Colors.WHITE}{result}{Colors.RESET}\n")
                        
                elif command == 'exploit':
                    if args:
                        result = self.analyze_vulnerability(args)
                        if result:
                            print(f"\n{Colors.WHITE}{result}{Colors.RESET}\n")
                    else:
                        print(f"{Colors.YELLOW}[!] Usage: exploit <CVE-ID>{Colors.RESET}")
                        
                elif command == 'recon':
                    if args:
                        result = self.execute_ai_prompt(
                            f"Perform comprehensive reconnaissance on {args}. Provide all executable commands.",
                            "recon"
                        )
                        if result:
                            print(f"\n{Colors.WHITE}{result}{Colors.RESET}\n")
                    else:
                        print(f"{Colors.YELLOW}[!] Usage: recon <target>{Colors.RESET}")
                        
                elif command == 'target':
                    if args:
                        self.current_target = args
                        print(f"{Colors.GREEN}[+] Target set: {self.current_target}{Colors.RESET}")
                        # Create new session
                        self.current_session = self.kb.create_session(args)
                    else:
                        if self.current_target:
                            print(f"  Current target: {self.current_target}")
                        else:
                            print(f"{Colors.YELLOW}[!] No target set{Colors.RESET}")
                            
                elif command == 'session':
                    if self.current_session:
                        print(f"  Session ID: {self.current_session}")
                        print(f"  Target: {self.current_target}")
                    else:
                        print(f"{Colors.YELLOW}[!] No active session{Colors.RESET}")
                        
                elif command == 'config':
                    self._config_menu()
                    
                elif command == 'provider':
                    if args in ['anthropic', 'openai', 'copilot', 'ollama']:
                        self.config['provider'] = args
                        self._save_config()
                        print(f"{Colors.GREEN}[+] Provider set to: {args}{Colors.RESET}")
                    else:
                        print(f"{Colors.YELLOW}[!] Invalid provider. Choose: anthropic, openai, copilot, ollama{Colors.RESET}")
                        
                elif command == 'help':
                    os.system('clear')
                    self.print_banner()
                    
                else:
                    # Treat as AI prompt
                    response = self.execute_ai_prompt(cmd)
                    if response:
                        print(f"\n{Colors.WHITE}{response}{Colors.RESET}\n")
                        
            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}[*] Use 'exit' to quit{Colors.RESET}")
            except EOFError:
                break
            except Exception as e:
                print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
        
        print(f"\n{Colors.RED}[*] NULLSEC AI terminated{Colors.RESET}\n")
    
    def auto_execute_attack(self, module_name: str, module_category: str, 
                            target: Optional[str] = None) -> bool:
        """Execute attack module with AI assistance"""
        
        if target:
            self.current_target = target
        
        print(f"\n{Colors.CYAN}{'▓'*80}{Colors.RESET}")
        print(f"{Colors.WHITE}  NULLSEC AI - Attack Execution{Colors.RESET}")
        print(f"{Colors.CYAN}{'▓'*80}{Colors.RESET}")
        print(f"\n{Colors.YELLOW}[*] Module: {module_name}{Colors.RESET}")
        print(f"{Colors.YELLOW}[*] Category: {module_category}{Colors.RESET}")
        if self.current_target:
            print(f"{Colors.YELLOW}[*] Target: {self.current_target}{Colors.RESET}")
        
        prompt = f"""Execute attack module: {module_name}
Target: {self.current_target or 'Not specified'}
Category: {module_category}

Provide complete attack execution plan:
1. Pre-attack reconnaissance
2. Vulnerability identification
3. Exploitation commands (fully executable)
4. Post-exploitation steps
5. Persistence mechanisms
6. Evidence collection

Execute step-by-step, explaining each command."""
        
        response = self.execute_ai_prompt(prompt, module_category.lower())
        
        if response:
            print(f"\n{Colors.WHITE}{response}{Colors.RESET}\n")
            
            # Extract and execute commands
            commands = self._extract_commands(response)
            
            if commands:
                print(f"{Colors.CYAN}[*] Extracted {len(commands)} commands{Colors.RESET}")
                
                if self.config.get("auto_execute", False):
                    print(f"{Colors.YELLOW}[*] Auto-executing...{Colors.RESET}\n")
                    for cmd in commands:
                        self._execute_command_safe(cmd, self.current_session)
                else:
                    print(f"\n{Colors.CYAN}Extracted commands:{Colors.RESET}")
                    for i, cmd in enumerate(commands, 1):
                        print(f"  {Colors.DIM}[{i}]{Colors.RESET} {cmd}")
                    
                    execute = input(f"\n{Colors.YELLOW}[?] Execute these commands? [y/N]: {Colors.RESET}")
                    if execute.lower() == 'y':
                        for cmd in commands:
                            self._execute_command_safe(cmd, self.current_session)
            
            return True
        
        return False
    
    def _config_menu(self):
        """Enhanced configuration menu"""
        while True:
            print(f"""
{Colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.RESET}
{Colors.WHITE}  NULLSEC AI Configuration{Colors.RESET}
{Colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.RESET}

  {Colors.YELLOW}[1]{Colors.RESET} Provider: {Colors.GREEN}{self.config.get('provider')}{Colors.RESET}
  {Colors.YELLOW}[2]{Colors.RESET} Model: {self.config.get('model')}
  {Colors.YELLOW}[3]{Colors.RESET} Ollama Model: {self.config.get('ollama_model')}
  {Colors.YELLOW}[4]{Colors.RESET} Temperature: {self.config.get('temperature')}
  {Colors.YELLOW}[5]{Colors.RESET} Max Tokens: {self.config.get('max_tokens')}
  {Colors.YELLOW}[6]{Colors.RESET} Auto-execute: {Colors.GREEN if self.config.get('auto_execute') else Colors.RED}{self.config.get('auto_execute')}{Colors.RESET}
  {Colors.YELLOW}[7]{Colors.RESET} Confirm dangerous: {Colors.GREEN if self.config.get('confirm_dangerous') else Colors.RED}{self.config.get('confirm_dangerous')}{Colors.RESET}
  {Colors.YELLOW}[8]{Colors.RESET} Learning enabled: {Colors.GREEN if self.config.get('learning_enabled') else Colors.RED}{self.config.get('learning_enabled')}{Colors.RESET}
  {Colors.YELLOW}[9]{Colors.RESET} Set API key
  {Colors.YELLOW}[0]{Colors.RESET} Back
""")
            choice = input(f"{Colors.WHITE}  [>] Select: {Colors.RESET}").strip()
            
            if choice == '0' or not choice:
                break
            elif choice == '1':
                print("\n  Providers: anthropic, openai, copilot, ollama")
                provider = input("  Provider: ").strip()
                if provider in ['anthropic', 'openai', 'copilot', 'ollama']:
                    self.config['provider'] = provider
                    self._save_config()
                    print(f"{Colors.GREEN}[+] Provider updated{Colors.RESET}")
            elif choice == '2':
                model = input("  Model name: ").strip()
                if model:
                    self.config['model'] = model
                    self._save_config()
                    print(f"{Colors.GREEN}[+] Model updated{Colors.RESET}")
            elif choice == '3':
                model = input("  Ollama model [llama3.1:70b]: ").strip()
                if model:
                    self.config['ollama_model'] = model
                    self._save_config()
                    print(f"{Colors.GREEN}[+] Ollama model updated{Colors.RESET}")
            elif choice == '4':
                temp = input("  Temperature [0.0-1.0]: ").strip()
                try:
                    self.config['temperature'] = float(temp)
                    self._save_config()
                    print(f"{Colors.GREEN}[+] Temperature updated{Colors.RESET}")
                except:
                    print(f"{Colors.RED}[!] Invalid value{Colors.RESET}")
            elif choice == '5':
                tokens = input("  Max tokens: ").strip()
                try:
                    self.config['max_tokens'] = int(tokens)
                    self._save_config()
                    print(f"{Colors.GREEN}[+] Max tokens updated{Colors.RESET}")
                except:
                    print(f"{Colors.RED}[!] Invalid value{Colors.RESET}")
            elif choice == '6':
                self.config['auto_execute'] = not self.config.get('auto_execute', False)
                self._save_config()
                print(f"{Colors.GREEN}[+] Auto-execute toggled{Colors.RESET}")
            elif choice == '7':
                self.config['confirm_dangerous'] = not self.config.get('confirm_dangerous', True)
                self._save_config()
                print(f"{Colors.GREEN}[+] Confirm dangerous toggled{Colors.RESET}")
            elif choice == '8':
                self.config['learning_enabled'] = not self.config.get('learning_enabled', True)
                self._save_config()
                print(f"{Colors.GREEN}[+] Learning toggled{Colors.RESET}")
            elif choice == '9':
                key = input("  API Key: ").strip()
                if key:
                    os.environ['ANTHROPIC_API_KEY'] = key
                    print(f"{Colors.GREEN}[+] API key set for session{Colors.RESET}")
    
    def install_opencode(self):
        """Install OpenCode"""
        print(f"\n{Colors.YELLOW}[*] Installing OpenCode...{Colors.RESET}")
        
        try:
            result = subprocess.run(
                ['bash', '-c', 'curl -fsSL https://opencode.ai/install | bash'],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode == 0:
                print(f"{Colors.GREEN}[+] OpenCode installed{Colors.RESET}")
                self.opencode_available = True
                return True
        except Exception as e:
            print(f"{Colors.RED}[!] Installation failed: {e}{Colors.RESET}")
        
        return False
    
    def configure_opencode(self):
        """Configure OpenCode for NULLSEC"""
        config = {
            "data": {"directory": os.path.join(SCRIPT_DIR, ".nullsec-ai-data")},
            "providers": {
                "anthropic": {"disabled": False},
                "openai": {"disabled": False},
                "copilot": {"disabled": False}
            },
            "agents": {
                "coder": {
                    "model": self.config.get("model", "claude-sonnet-4-20250514"),
                    "maxTokens": self.config.get("max_tokens", 8000)
                }
            },
            "autoCompact": True,
            "debug": False
        }
        
        with open(OPENCODE_CONFIG, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"{Colors.GREEN}[+] OpenCode configured{Colors.RESET}")
    
    def setup_ollama(self):
        """Setup Ollama"""
        print(f"\n{Colors.CYAN}[*] Ollama Setup{Colors.RESET}")
        print(f"""
1. Install Ollama: curl https://ollama.ai/install.sh | sh
2. Start service: ollama serve
3. Pull model: ollama pull llama3.1:70b

Or visit: https://ollama.ai
""")


def main():
    """Enhanced main entry point"""
    ai = NullSecAI()
    
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        
        if cmd in ['--help', '-h']:
            print(f"""
{Colors.RED}NULLSEC FRAMEWORK AI ENHANCED{Colors.RESET}
{Colors.DIM}AI-Powered Autonomous Security Operations - bad-antics development{Colors.RESET}

{Colors.CYAN}Usage:{Colors.RESET}
  nullsec-ai                        Launch interactive console
  nullsec-ai ask <prompt>           Ask AI a question
  nullsec-ai attack <module>        Execute attack module
  nullsec-ai autonomous <target>    Fully autonomous attack
  nullsec-ai payload <type>         Generate payload
  nullsec-ai exploit <CVE>          Analyze vulnerability
  nullsec-ai recon <target>         Reconnaissance
  nullsec-ai install                Install backends
  nullsec-ai config                 Configure

{Colors.CYAN}Examples:{Colors.RESET}
  nullsec-ai autonomous 192.168.1.100
  nullsec-ai ask "How do I exploit SQL injection in login forms?"
  nullsec-ai payload reverse_shell --os windows --lhost 10.0.0.5
  nullsec-ai exploit CVE-2024-1234
  nullsec-ai recon target.com

{Colors.CYAN}Options:{Colors.RESET}
  -h, --help         Show this help
  --provider <name>  Set AI provider (anthropic/openai/ollama)
  --target <ip>      Set target
  --auto-execute     Auto-execute commands
""")
        
        elif cmd == 'install':
            ai.install_opencode()
            ai.configure_opencode()
            ai.setup_ollama()
        
        elif cmd == 'ask' and len(sys.argv) > 2:
            prompt = ' '.join(sys.argv[2:])
            response = ai.execute_ai_prompt(prompt)
            if response:
                print(f"\n{response}\n")
        
        elif cmd == 'attack' and len(sys.argv) > 2:
            ai.auto_execute_attack(sys.argv[2], "general")
        
        elif cmd == 'autonomous' and len(sys.argv) > 2:
            ai.autonomous_attack(sys.argv[2])
        
        elif cmd == 'payload' and len(sys.argv) > 2:
            ai.generate_payload(sys.argv[2])
        
        elif cmd == 'exploit' and len(sys.argv) > 2:
            result = ai.analyze_vulnerability(sys.argv[2])
            if result:
                print(f"\n{result}\n")
        
        elif cmd == 'recon' and len(sys.argv) > 2:
            result = ai.execute_ai_prompt(
                f"Comprehensive reconnaissance on {sys.argv[2]}",
                "recon"
            )
            if result:
                print(f"\n{result}\n")
        
        elif cmd == 'config':
            ai._config_menu()
        
        else:
            ai.interactive_console()
    else:
        ai.interactive_console()


if __name__ == "__main__":
    main()
