#!/bin/bash
#
# NULLSEC Framework v2.0 - Quick Start Guide v1.1
# Repository: https://github.com/bad-antics/nullsec
#

cat << 'EOF'
═══════════════════════════════════════════════════════════════════════
  NULLSEC FRAMEWORK v2.0 - QUICK START GUIDE
═══════════════════════════════════════════════════════════════════════

🚀 LAUNCHING THE FRAMEWORK
══════════════════════════

  CLI Launcher:
  $ cd /home/antics/nullsec
  $ python3 nullsec-launcher.py

  Desktop GUI:
  $ cd /home/antics/nullsec/nullsec-desktop
  $ python3 nullsec_desktop.py

  AI Assistant:
  $ cd /home/antics/nullsec
  $ python3 nullsec-ai.py


📦 MODULES (185 Total)
═══════════════════════

  The framework automatically discovers all modules from:
  /home/antics/nullsec/nullsecurity/*.sh

  Categories:
  • Network (15+)       - Port scanning, network recon, MITM, WiFi
  • Web (20+)          - XSS, SQLi, CSRF, JWT, OAuth, API attacks
  • Credentials (10+)  - Password cracking, hash dumping, Kerberos
  • Cloud (12+)        - AWS, Azure, GCP, Kubernetes, Docker
  • Database (10+)     - MySQL, MongoDB, Redis, PostgreSQL
  • Exploitation (15+) - Kernel exploits, ROP chains, shellcode
  • Evasion (10+)      - AMSI bypass, EDR evasion, AV bypass
  • And 15 more categories...


🎯 QUICK ACTIONS
═════════════════

  Run specific module:
  $ cd /home/antics/nullsec/nullsecurity
  $ bash port-scanner.sh

  Search modules:
  From launcher: Press [S], then enter search term

  Browse by category:
  From launcher: Press [C], select category

  Run all modules:
  From launcher: Press [A] (not recommended - takes hours!)

  Random module:
  From launcher: Press [R]


🔧 INTEGRATIONS
════════════════

  Metasploit:
  From launcher: Press [M]
  - Launch msfconsole
  - Generate payloads
  - Search exploits
  - Multi-handler setup

  Shodan:
  From launcher: Press [H]
  - Internet-wide reconnaissance
  - 17 search modes
  - Export targets for attacks

  AI Assistant:
  From launcher: Press [I]
  - Autonomous attack planning
  - Multi-provider support (Ollama/OpenAI/Claude)
  - Knowledge base learning


📊 NAVIGATION
══════════════

  CLI Launcher Controls:
  [N] - Next page of modules
  [P] - Previous page
  [C] - Browse by category
  [S] - Search modules
  [M] - Metasploit integration
  [H] - Shodan search
  [I] - AI assistant
  [E] - Command console
  [X] - Credits
  [Q] - Quit

  [1-185] - Run module by number


💡 TIPS & TRICKS
═════════════════

  1. Demo Mode:
     Most modules support demo/test mode - runs without real targets

  2. Module Pagination:
     15 modules per page - use [N]/[P] to navigate

  3. Category Filtering:
     Press [C] to see modules by category, great for focused work

  4. Shodan Targets:
     Use Shodan [H] to find targets, then [16] to export for attacks

  5. Command History:
     In exec console [E], type 'history' to see previous commands

  6. AI Autonomous Mode:
     In AI console, enable autonomous mode for automated attack chains


📁 FILE LOCATIONS
══════════════════

  Framework Root:     /home/antics/nullsec
  Attack Modules:     /home/antics/nullsec/nullsecurity
  Logs:              /home/antics/nullsec/logs
  Shodan Cache:      /home/antics/nullsec/.shodan_cache
  Target Export:     /home/antics/nullsec/.shodan_target


🛠️ UTILITIES
══════════════

  Target Database:
  $ python3 /home/antics/nullsec/utils/target-db.py

  Network Manager:
  $ python3 /home/antics/nullsec/utils/netmgr.py

  Framework Enhancer:
  $ python3 /home/antics/nullsec/enhance-framework.py


🔍 MODULE DETAILS
══════════════════

  Each module includes:
  • Detailed description
  • Demo/test mode
  • Help information
  • Target specification
  • Output logging

  Run any module with -h or --help for details


⚠️ LEGAL NOTICE
════════════════

  This framework is for AUTHORIZED SECURITY TESTING ONLY.
  
  You must have explicit permission to test any system.
  Unauthorized access to computer systems is illegal.
  
  Use responsibly and ethically.


📚 RESOURCES
═════════════

  Documentation:     /home/antics/nullsec/README.md
  API Docs:         /home/antics/nullsec/API_DOCUMENTATION.md
  Shodan Guide:     /home/antics/nullsec/SHODAN_INTEGRATION.md
  Framework Guide:  /home/antics/nullsec/FRAMEWORK.md
  V2 Summary:       /home/antics/nullsec/NULLSEC_V2_SUMMARY.md


🆘 SUPPORT
═══════════

  GitHub: github.com/bad-antics
  Issues: github.com/bad-antics/nullsec/issues


═══════════════════════════════════════════════════════════════════════
  NULLSEC v2.0 - Stay dangerous. Stay anonymous.
  bad-antics development
═══════════════════════════════════════════════════════════════════════

EOF
