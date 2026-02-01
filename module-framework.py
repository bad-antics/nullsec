#!/usr/bin/env python3
"""
NullSec Interactive Module Framework
Enhanced module execution with rich interactive prompts and logging
"""

import os
import sys
import subprocess
import json
import shutil
import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

# Color codes
class Colors:
    RED = '\033[1;31m'
    GREEN = '\033[1;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[1;34m'
    MAGENTA = '\033[1;35m'
    CYAN = '\033[1;36m'
    WHITE = '\033[1;37m'
    GRAY = '\033[0;37m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

# Logging directory structure
LOGS_BASE_DIR = os.path.expanduser("~/nullsec/logs")
TARGETS_BASE_DIR = os.path.join(LOGS_BASE_DIR, "targets")

class ParamType(Enum):
    """Parameter types for module inputs"""
    STRING = "string"
    IP = "ip"
    PORT = "port"
    FILE = "file"
    CHOICE = "choice"
    BOOLEAN = "boolean"
    LIST = "list"
    DOMAIN = "domain"
    URL = "url"

@dataclass
class Parameter:
    """Module parameter definition"""
    name: str
    prompt: str
    param_type: ParamType
    required: bool = True
    default: Optional[str] = None
    choices: List[str] = field(default_factory=list)
    description: str = ""
    validator: Optional[callable] = None
    
@dataclass
class ModuleConfig:
    """Enhanced module configuration"""
    name: str
    description: str
    category: str
    parameters: List[Parameter] = field(default_factory=list)
    pre_run_checks: List[str] = field(default_factory=list)  # Commands to check before running
    requires_root: bool = False
    examples: List[Dict[str, str]] = field(default_factory=list)
    
class InteractiveFramework:
    """Enhanced interactive framework for module execution"""
    
    def __init__(self):
        self.module_configs = {}
        self.load_module_configs()
        self.session_log = []
        self.vulnerabilities = []
        self.target_dir = None
        self.log_file = None
        self.encrypt_logs = False
        self.encryption_password = None
        
    def setup_logging(self, target: str, module_name: str):
        """Setup logging directory structure for target"""
        # Create base logs directory
        os.makedirs(LOGS_BASE_DIR, exist_ok=True)
        os.makedirs(TARGETS_BASE_DIR, exist_ok=True)
        
        # Sanitize target name for filesystem
        safe_target = "".join(c if c.isalnum() or c in ".-_" else "_" for c in target)
        
        # Create target directory
        self.target_dir = os.path.join(TARGETS_BASE_DIR, safe_target)
        os.makedirs(self.target_dir, exist_ok=True)
        
        # Create subdirectories
        os.makedirs(os.path.join(self.target_dir, "scans"), exist_ok=True)
        os.makedirs(os.path.join(self.target_dir, "exploits"), exist_ok=True)
        os.makedirs(os.path.join(self.target_dir, "credentials"), exist_ok=True)
        os.makedirs(os.path.join(self.target_dir, "screenshots"), exist_ok=True)
        
        # Create log file
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_module = "".join(c if c.isalnum() or c in "-_" else "_" for c in module_name)
        self.log_file = os.path.join(self.target_dir, f"{safe_module}_{timestamp}.log")
        
        self.log_message(f"=== NullSec Attack Log ===")
        self.log_message(f"Target: {target}")
        self.log_message(f"Module: {module_name}")
        self.log_message(f"Timestamp: {datetime.datetime.now().isoformat()}")
        self.log_message(f"Target Directory: {self.target_dir}")
        self.log_message("=" * 50)
        
    def log_message(self, message: str):
        """Add message to log"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.session_log.append(log_entry)
        
        if self.log_file:
            with open(self.log_file, 'a') as f:
                f.write(log_entry + '\n')
    
    def encrypt_log_files(self):
        """Encrypt log files after module execution"""
        try:
            # Import encryption utility
            log_encrypt_path = os.path.join(os.path.dirname(__file__), 'log-encrypt.py')
            if not os.path.exists(log_encrypt_path):
                print(f"{Colors.YELLOW}│{Colors.RESET}  {Colors.YELLOW}⚠ Log encryption utility not found{Colors.RESET}")
                return
            
            import subprocess
            
            # Encrypt main log file
            if self.log_file and os.path.exists(self.log_file):
                cmd = ['python3', log_encrypt_path, '--encrypt', self.log_file]
                if self.encryption_password:
                    # Use password from environment or config
                    env = os.environ.copy()
                    env['ENCRYPTION_PASSWORD'] = self.encryption_password
                    result = subprocess.run(cmd, env=env, capture_output=True, text=True)
                else:
                    result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.GREEN}✓ Log file encrypted{Colors.RESET}")
                    # Remove original log file
                    os.remove(self.log_file)
                    self.log_file = self.log_file + '.enc'
                else:
                    print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.YELLOW}⚠ Log encryption failed{Colors.RESET}")
                    
        except Exception as e:
            print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.YELLOW}⚠ Encryption error: {e}{Colors.RESET}")
                
    def add_vulnerability(self, vuln_type: str, description: str, severity: str = "medium", 
                         details: Dict[str, Any] = None):
        """Record discovered vulnerability"""
        vuln = {
            "type": vuln_type,
            "description": description,
            "severity": severity,
            "details": details or {},
            "timestamp": datetime.datetime.now().isoformat()
        }
        self.vulnerabilities.append(vuln)
        self.log_message(f"VULNERABILITY: [{severity.upper()}] {vuln_type} - {description}")
        
    def save_results_summary(self, params: Dict[str, Any], config: ModuleConfig):
        """Save comprehensive results summary"""
        if not self.target_dir:
            return
            
        summary_file = os.path.join(self.target_dir, "SUMMARY.md")
        
        # Create or append to summary
        mode = 'a' if os.path.exists(summary_file) else 'w'
        with open(summary_file, mode) as f:
            if mode == 'w':
                f.write(f"# Attack Summary: {params.get('target', params.get('domain_controller', 'Unknown'))}\n\n")
                
            f.write(f"\n## {config.name} - {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"**Category:** {config.category}\n\n")
            f.write(f"**Description:** {config.description}\n\n")
            
            f.write("### Parameters\n\n")
            for key, value in params.items():
                if 'password' not in key.lower():
                    f.write(f"- **{key}:** `{value}`\n")
                else:
                    f.write(f"- **{key}:** `[REDACTED]`\n")
                    
            if self.vulnerabilities:
                f.write("\n### Discovered Vulnerabilities\n\n")
                for vuln in self.vulnerabilities:
                    severity_emoji = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}
                    emoji = severity_emoji.get(vuln['severity'], "⚪")
                    f.write(f"{emoji} **{vuln['type']}** ({vuln['severity'].upper()})\n")
                    f.write(f"  - {vuln['description']}\n")
                    if vuln['details']:
                        for key, val in vuln['details'].items():
                            f.write(f"  - {key}: {val}\n")
                    f.write("\n")
                    
            f.write("\n### Suggested Next Steps\n\n")
            next_steps = self.generate_next_steps(params, config)
            for step in next_steps:
                f.write(f"- {step}\n")
                
            f.write(f"\n### Log File\n\n`{self.log_file}`\n\n")
            f.write("---\n")
            
        print(f"\n{Colors.CYAN}╭─ RESULTS SAVED{Colors.RESET}")
        print(f"{Colors.CYAN}│{Colors.RESET}")
        print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.WHITE}Target Directory:{Colors.RESET} {Colors.GREEN}{self.target_dir}{Colors.RESET}")
        print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.WHITE}Summary:{Colors.RESET} {Colors.GREEN}{summary_file}{Colors.RESET}")
        print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.WHITE}Detailed Log:{Colors.RESET} {Colors.GREEN}{self.log_file}{Colors.RESET}")
        
        # Encrypt logs if enabled
        if self.encrypt_logs:
            self.encrypt_log_files()
        
        if self.vulnerabilities:
            print(f"{Colors.CYAN}│{Colors.RESET}")
            print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.YELLOW}Vulnerabilities Found: {len(self.vulnerabilities)}{Colors.RESET}")
            for vuln in self.vulnerabilities:
                severity_color = {
                    "critical": Colors.RED,
                    "high": Colors.RED,
                    "medium": Colors.YELLOW,
                    "low": Colors.GREEN
                }
                color = severity_color.get(vuln['severity'], Colors.WHITE)
                print(f"{Colors.CYAN}│{Colors.RESET}    {color}• [{vuln['severity'].upper()}] {vuln['type']}{Colors.RESET}")
                
        print(f"{Colors.CYAN}╰{'─' * 75}{Colors.RESET}\n")
        
    def generate_next_steps(self, params: Dict[str, Any], config: ModuleConfig) -> List[str]:
        """Generate suggested next steps based on attack results"""
        steps = []
        
        # Category-specific recommendations
        if "recon" in config.category.lower() or "enumeration" in config.name.lower():
            steps.append("🔍 Analyze discovered services for known vulnerabilities")
            steps.append("📊 Use discovered information to plan exploitation phase")
            steps.append("🎯 Prioritize targets based on criticality and exposure")
            
        if "active directory" in config.name.lower() or "ad" in config.name.lower():
            steps.append("🔐 Crack any captured password hashes with hashcat")
            steps.append("🗺️ Import BloodHound data to identify privilege escalation paths")
            steps.append("🎫 Test captured credentials for lateral movement")
            steps.append("📋 Document findings for compliance reporting")
            
        if "web" in config.category.lower():
            steps.append("🌐 Test for additional OWASP Top 10 vulnerabilities")
            steps.append("🔒 Check for authentication bypass opportunities")
            steps.append("📝 Review source code for sensitive information disclosure")
            
        if "exploit" in config.category.lower():
            steps.append("✅ Verify successful exploitation")
            steps.append("🎯 Establish persistent access if authorized")
            steps.append("📊 Document proof-of-concept for reporting")
            steps.append("🔄 Attempt privilege escalation")
            
        # Generic recommendations
        if not steps:
            steps.append("📋 Review all collected data thoroughly")
            steps.append("🔍 Verify any discovered vulnerabilities")
            steps.append("📊 Plan follow-up attacks based on findings")
            steps.append("📝 Document all activities for final report")
            
        # Add vulnerability-specific steps
        for vuln in self.vulnerabilities:
            if "password" in vuln['type'].lower():
                if "🔐 Attempt password reuse across other services" not in steps:
                    steps.append("🔐 Attempt password reuse across other services")
            elif "rce" in vuln['type'].lower() or "execution" in vuln['type'].lower():
                if "🚀 Establish reverse shell for deeper access" not in steps:
                    steps.append("🚀 Establish reverse shell for deeper access")
                    
        return steps
        
    def clear_screen(self):
        """Clear terminal screen"""
        os.system('clear' if os.name == 'posix' else 'cls')
        
    def print_banner(self, module_name: str):
        """Print module banner"""
        self.clear_screen()
        print(f"{Colors.RED}===={Colors.RESET}")
        print(f"{Colors.RED}|{Colors.RESET}  {Colors.WHITE}NULLSEC INTERACTIVE MODULE FRAMEWORK{Colors.RESET}")
        print(f"{Colors.RED}|{Colors.RESET}  {Colors.CYAN}Module: {Colors.WHITE}{module_name}{Colors.RESET}")
        print(f"{Colors.RED}===={Colors.RESET}\n")
        
    def print_param_help(self, param: Parameter):
        """Print parameter help information"""
        if param.description:
            print(f"  {Colors.GRAY}ℹ {param.description}{Colors.RESET}")
        if param.default:
            print(f"  {Colors.GRAY}Default: {param.default}{Colors.RESET}")
        if param.choices:
            print(f"  {Colors.GRAY}Options: {', '.join(param.choices)}{Colors.RESET}")
            
    def validate_input(self, value: str, param: Parameter) -> tuple[bool, str]:
        """Validate parameter input"""
        if not value and param.required:
            return False, "This parameter is required"
            
        if not value and param.default:
            return True, param.default
            
        if param.param_type == ParamType.IP:
            parts = value.split('.')
            if len(parts) != 4 or not all(p.isdigit() and 0 <= int(p) <= 255 for p in parts):
                return False, "Invalid IP address format"
                
        elif param.param_type == ParamType.PORT:
            if not value.isdigit() or not (1 <= int(value) <= 65535):
                return False, "Port must be between 1 and 65535"
                
        elif param.param_type == ParamType.FILE:
            if not os.path.exists(value):
                return False, f"File not found: {value}"
                
        elif param.param_type == ParamType.CHOICE:
            if value not in param.choices:
                return False, f"Must be one of: {', '.join(param.choices)}"
                
        elif param.param_type == ParamType.BOOLEAN:
            if value.lower() not in ['y', 'n', 'yes', 'no', 'true', 'false', '1', '0']:
                return False, "Enter yes/no"
                
        if param.validator:
            return param.validator(value)
            
        return True, value
        
    def collect_parameters(self, config: ModuleConfig) -> Dict[str, Any]:
        """Interactively collect all module parameters"""
        params = {}
        
        print(f"{Colors.CYAN}╭─ CONFIGURATION{Colors.RESET}")
        print(f"{Colors.CYAN}│{Colors.RESET}")
        
        for i, param in enumerate(config.parameters, 1):
            print(f"{Colors.CYAN}├─[{i}/{len(config.parameters)}]{Colors.RESET} {Colors.WHITE}{param.prompt}{Colors.RESET}")
            
            if param.description or param.default or param.choices:
                self.print_param_help(param)
                
            while True:
                prompt_str = f"{Colors.CYAN}│  ▸{Colors.RESET} "
                if param.param_type == ParamType.CHOICE:
                    print(f"{Colors.CYAN}│{Colors.RESET}")
                    for j, choice in enumerate(param.choices, 1):
                        print(f"{Colors.CYAN}│{Colors.RESET}    {Colors.YELLOW}{j}{Colors.RESET}) {choice}")
                    prompt_str = f"{Colors.CYAN}│  ▸{Colors.RESET} Select [1-{len(param.choices)}]: "
                    
                user_input = input(prompt_str).strip()
                
                # Handle choice selection by number
                if param.param_type == ParamType.CHOICE and user_input.isdigit():
                    idx = int(user_input) - 1
                    if 0 <= idx < len(param.choices):
                        user_input = param.choices[idx]
                        
                # Apply default if empty
                if not user_input and param.default:
                    user_input = param.default
                    print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.GRAY}Using default: {user_input}{Colors.RESET}")
                    
                # Validate
                valid, result = self.validate_input(user_input, param)
                
                if valid:
                    params[param.name] = result
                    print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.GREEN}✓{Colors.RESET}")
                    if i < len(config.parameters):
                        print(f"{Colors.CYAN}│{Colors.RESET}")
                    break
                else:
                    print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.RED}✗ {result}{Colors.RESET}")
                    print(f"{Colors.CYAN}│{Colors.RESET}  {Colors.YELLOW}Try again:{Colors.RESET}")
                    
        print(f"{Colors.CYAN}╰{'─' * 75}{Colors.RESET}\n")
        return params
        
    def show_summary(self, config: ModuleConfig, params: Dict[str, Any]):
        """Show parameter summary before execution"""
        print(f"{Colors.YELLOW}╭─ EXECUTION SUMMARY{Colors.RESET}")
        print(f"{Colors.YELLOW}│{Colors.RESET}")
        print(f"{Colors.YELLOW}│{Colors.RESET}  {Colors.WHITE}Module:{Colors.RESET} {config.name}")
        print(f"{Colors.YELLOW}│{Colors.RESET}  {Colors.WHITE}Description:{Colors.RESET} {config.description}")
        print(f"{Colors.YELLOW}│{Colors.RESET}")
        print(f"{Colors.YELLOW}│{Colors.RESET}  {Colors.CYAN}Parameters:{Colors.RESET}")
        
        for key, value in params.items():
            print(f"{Colors.YELLOW}│{Colors.RESET}    • {Colors.WHITE}{key}:{Colors.RESET} {Colors.GREEN}{value}{Colors.RESET}")
        
        print(f"{Colors.YELLOW}│{Colors.RESET}")
        
        # Ask about log encryption
        encrypt_choice = input(f"{Colors.YELLOW}│  ▸{Colors.RESET} Encrypt logs after execution? [y/N]: ").strip().lower()
        if encrypt_choice in ['y', 'yes']:
            self.encrypt_logs = True
            print(f"{Colors.YELLOW}│{Colors.RESET}  {Colors.GREEN}✓ Logs will be encrypted{Colors.RESET}")
        else:
            self.encrypt_logs = False
            
        print(f"{Colors.YELLOW}╰{'─' * 75}{Colors.RESET}\n")
        
        confirm = input(f"{Colors.WHITE}  Continue with attack? [Y/n]: {Colors.RESET}").strip().lower()
        return confirm in ['', 'y', 'yes']
        
    def check_prerequisites(self, config: ModuleConfig) -> tuple[bool, List[str]]:
        """Check if all prerequisites are met"""
        missing = []
        
        for cmd in config.pre_run_checks:
            if not shutil.which(cmd):
                missing.append(cmd)
                
        if config.requires_root and os.geteuid() != 0:
            missing.append("root privileges")
            
        return len(missing) == 0, missing
        
    def execute_module(self, module_script: str, params: Dict[str, Any], config: ModuleConfig):
        """Execute the module with collected parameters"""
        # Setup logging
        target = params.get('target') or params.get('domain_controller') or params.get('domain') or 'unknown'
        self.setup_logging(target, config.name)
        
        # Log parameters
        self.log_message("Execution started with parameters:")
        for key, value in params.items():
            if 'password' not in key.lower():
                self.log_message(f"  {key}: {value}")
            else:
                self.log_message(f"  {key}: [REDACTED]")
        
        print(f"{Colors.GREEN}╭─ EXECUTION{Colors.RESET}")
        print(f"{Colors.GREEN}│{Colors.RESET}")
        print(f"{Colors.GREEN}│{Colors.RESET}  {Colors.CYAN}[*]{Colors.RESET} Launching attack module...")
        print(f"{Colors.GREEN}│{Colors.RESET}  {Colors.GRAY}Logs: {self.log_file}{Colors.RESET}")
        print(f"{Colors.GREEN}╰{'─' * 75}{Colors.RESET}\n")
        
        # Set environment variables for parameters
        env = os.environ.copy()
        for key, value in params.items():
            env[f"NULLSEC_{key.upper()}"] = str(value)
            
        # Add logging paths to environment
        env['NULLSEC_TARGET_DIR'] = self.target_dir
        env['NULLSEC_LOG_FILE'] = self.log_file
            
        # Execute the module
        try:
            start_time = datetime.datetime.now()
            result = subprocess.run(['bash', module_script], env=env, check=False,
                                   capture_output=False, text=True)
            end_time = datetime.datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            self.log_message(f"Execution completed in {duration:.2f} seconds")
            self.log_message(f"Exit code: {result.returncode}")
            
            print(f"\n{Colors.GREEN}╭─ COMPLETE{Colors.RESET}")
            print(f"{Colors.GREEN}│{Colors.RESET}")
            
            if result.returncode == 0:
                print(f"{Colors.GREEN}│{Colors.RESET}  {Colors.GREEN}✓ Module executed successfully{Colors.RESET}")
                print(f"{Colors.GREEN}│{Colors.RESET}  {Colors.GRAY}Duration: {duration:.2f}s{Colors.RESET}")
            else:
                print(f"{Colors.GREEN}│{Colors.RESET}  {Colors.YELLOW}⚠ Module exited with code {result.returncode}{Colors.RESET}")
                
            print(f"{Colors.GREEN}╰{'─' * 75}{Colors.RESET}\n")
            
            # Parse output log for vulnerabilities (if module wrote to log)
            self.parse_vulnerabilities_from_log()
            
            # Save comprehensive results
            self.save_results_summary(params, config)
            
        except Exception as e:
            print(f"{Colors.RED}[✗] Execution failed: {e}{Colors.RESET}")
            self.log_message(f"ERROR: {e}")
            
    def parse_vulnerabilities_from_log(self):
        """Parse the execution log for vulnerability indicators"""
        if not self.log_file or not os.path.exists(self.log_file):
            return
            
        # Common vulnerability indicators
        vuln_patterns = {
            "weak password": ("Weak Credentials", "medium"),
            "default credentials": ("Default Credentials", "high"),
            "sql injection": ("SQL Injection", "critical"),
            "xss": ("Cross-Site Scripting", "high"),
            "rce": ("Remote Code Execution", "critical"),
            "lfi": ("Local File Inclusion", "high"),
            "rfi": ("Remote File Inclusion", "critical"),
            "ssrf": ("Server-Side Request Forgery", "high"),
            "open port": ("Exposed Service", "low"),
            "outdated": ("Outdated Software", "medium"),
            "misconfiguration": ("Security Misconfiguration", "medium"),
        }
        
        try:
            with open(self.log_file, 'r') as f:
                content = f.read().lower()
                
            for pattern, (vuln_type, severity) in vuln_patterns.items():
                if pattern in content:
                    # Avoid duplicates
                    if not any(v['type'] == vuln_type for v in self.vulnerabilities):
                        self.add_vulnerability(
                            vuln_type,
                            f"Potential {vuln_type} detected during scan",
                            severity
                        )
        except Exception:
            pass
            
    def run_interactive_module(self, module_script: str, config: ModuleConfig):
        """Main interactive module runner"""
        self.print_banner(config.name)
        
        # Show module info
        print(f"{Colors.WHITE}Description:{Colors.RESET} {config.description}")
        print(f"{Colors.WHITE}Category:{Colors.RESET} {config.category}\n")
        
        if config.examples:
            print(f"{Colors.CYAN}Example Usage:{Colors.RESET}")
            for ex in config.examples:
                print(f"  {Colors.GRAY}• {ex.get('desc', 'Example')}{Colors.RESET}")
            print()
            
        # Check prerequisites
        prereqs_ok, missing = self.check_prerequisites(config)
        if not prereqs_ok:
            print(f"{Colors.RED}[✗] Missing prerequisites: {', '.join(missing)}{Colors.RESET}\n")
            input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
            return
            
        # Collect parameters
        params = self.collect_parameters(config)
        
        # Show summary and confirm
        if not self.show_summary(config, params):
            print(f"{Colors.YELLOW}[!] Aborted{Colors.RESET}\n")
            input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
            return
            
        # Execute
        self.execute_module(module_script, params, config)
        
        input(f"{Colors.YELLOW}Press ENTER to continue...{Colors.RESET}")
        
    def load_module_configs(self):
        """Load module configurations"""
        # This will be populated from JSON files or defined here
        pass
        
    def load_config_from_json(self, json_path: str) -> Optional[ModuleConfig]:
        """Load module configuration from JSON file"""
        try:
            with open(json_path, 'r') as f:
                data = json.load(f)
                
            parameters = []
            for p in data.get('parameters', []):
                # Support both 'prompt' and 'description' for backwards compatibility
                prompt_text = p.get('prompt') or p.get('description') or p['name']
                
                # Map type strings to ParamType enum
                type_mapping = {
                    'ip': ParamType.IP,
                    'port': ParamType.PORT,
                    'url': ParamType.URL,
                    'domain': ParamType.DOMAIN,
                    'file': ParamType.FILE,
                    'choice': ParamType.CHOICE,
                    'boolean': ParamType.BOOLEAN,
                    'string': ParamType.STRING,
                    'list': ParamType.LIST
                }
                param_type_str = p.get('type', p.get('param_type', 'string')).lower()
                param_type = type_mapping.get(param_type_str, ParamType.STRING)
                
                param = Parameter(
                    name=p['name'],
                    prompt=prompt_text,
                    param_type=param_type,
                    required=p.get('required', True),
                    default=p.get('default'),
                    choices=p.get('choices', []),
                    description=p.get('description', '')
                )
                parameters.append(param)
                
            return ModuleConfig(
                name=data['name'],
                description=data['description'],
                category=data['category'],
                parameters=parameters,
                pre_run_checks=data.get('pre_run_checks', []),
                requires_root=data.get('requires_root', False),
                examples=data.get('examples', [])
            )
        except Exception as e:
            print(f"{Colors.RED}[!] Error loading config: {e}{Colors.RESET}")
            return None

# Example usage
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"{Colors.RED}Usage: {sys.argv[0]} <module_script> [config_json]{Colors.RESET}")
        sys.exit(1)
        
    framework = InteractiveFramework()
    module_script = sys.argv[1]
    
    # Load config from JSON if provided, otherwise use defaults
    if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
        config = framework.load_config_from_json(sys.argv[2])
        if not config:
            print(f"{Colors.RED}[!] Failed to load module configuration{Colors.RESET}")
            sys.exit(1)
    else:
        # Fallback basic config
        config = ModuleConfig(
            name=os.path.basename(module_script),
            description="Attack module",
            category="Security Testing",
            parameters=[
                Parameter(
                    name="target",
                    prompt="Target IP/Hostname",
                    param_type=ParamType.STRING,
                    description="Primary target for the attack"
                )
            ]
        )
    
    framework.run_interactive_module(module_script, config)
