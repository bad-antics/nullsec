#!/bin/bash
#
# NullSec GitHub Community Helper
# Version: 1.1
# Finds open issues you can answer and generates response templates
# Author: bad-antics
# Repository: https://github.com/bad-antics/nullsec
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

GITHUB_USER="bad-antics"
FLIPPER_SUITE="https://github.com/bad-antics/nullsec-flipper-suite"
PINEAPPLE_SUITE="https://github.com/bad-antics/nullsec-pineapple-suite"

banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║       NullSec GitHub Community Helper                     ║"
    echo "║       Find issues to answer & build reputation            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

search_issues() {
    local query="$1"
    local limit="${2:-10}"
    
    echo -e "${YELLOW}🔍 Searching: ${query}${NC}"
    gh search issues "$query" --state=open --limit "$limit" 2>/dev/null
}

find_flipper_issues() {
    echo -e "\n${GREEN}═══ FLIPPER ZERO ISSUES ═══${NC}\n"
    
    echo -e "${BLUE}📌 I-Am-Jakoby/Flipper-Zero-BadUSB${NC}"
    gh issue list --repo I-Am-Jakoby/Flipper-Zero-BadUSB --state open --limit 10 2>/dev/null
    
    echo -e "\n${BLUE}📌 UberGuidoZ/Flipper${NC}"
    gh issue list --repo UberGuidoZ/Flipper --state open --limit 10 2>/dev/null
    
    echo -e "\n${BLUE}📌 flipperdevices/flipperzero-firmware${NC}"
    gh issue list --repo flipperdevices/flipperzero-firmware --state open --limit 10 --search "badusb OR payload" 2>/dev/null
}

find_hak5_issues() {
    echo -e "\n${GREEN}═══ HAK5 ISSUES ═══${NC}\n"
    
    echo -e "${BLUE}📌 hak5/usbrubberducky-payloads${NC}"
    gh issue list --repo hak5/usbrubberducky-payloads --state open --limit 10 2>/dev/null
    
    echo -e "\n${BLUE}📌 hak5/bashbunny-payloads${NC}"
    gh issue list --repo hak5/bashbunny-payloads --state open --limit 10 2>/dev/null
}

find_security_issues() {
    echo -e "\n${GREEN}═══ SECURITY TOOL ISSUES ═══${NC}\n"
    
    search_issues "badusb script not working" 10
    echo ""
    search_issues "ducky payload help" 10
    echo ""
    search_issues "powershell payload" 10
}

generate_answer_template() {
    local issue_type="$1"
    
    case "$issue_type" in
        "not_working")
            cat << 'EOF'

═══════════════════════════════════════════════════════════
📝 TEMPLATE: Scripts Not Working
═══════════════════════════════════════════════════════════

Hey! Here's a troubleshooting guide for BadUSB payload issues:

### Common fixes:

**1. PowerShell execution policy**
```
STRING powershell -ExecutionPolicy Bypass -WindowStyle Hidden
```

**2. Increase delays (Windows 11 is slower)**
```
DELAY 2000
```

**3. USB mode instead of Bluetooth**
Press LEFT on the script → Config → Set to USB

**4. Keyboard layout**
Add at the top:
```
DUCKY_LANG US
```

### Working payloads
I maintain tested payloads here:
👉 https://github.com/bad-antics/nullsec-flipper-suite

Let me know if you need specific help!

═══════════════════════════════════════════════════════════
EOF
            ;;
        "virus")
            cat << 'EOF'

═══════════════════════════════════════════════════════════
📝 TEMPLATE: Virus/AV Detection
═══════════════════════════════════════════════════════════

This is expected! Windows Defender correctly identifies these as potentially malicious because they do things malware does.

### Solutions:

1. **Add exclusion folder**
   Windows Security → Virus & Threat Protection → Exclusions → Add Folder

2. **Use Windows Sandbox or VM**
   Test in isolated environment

3. **Download via git CLI**
   ```
   git clone [REPO_URL]
   ```

4. **Temporarily disable Real-time protection**
   ⚠️ Only on test machines!

### Safe demo payloads
For learning without AV issues, check my prank payloads:
👉 https://github.com/bad-antics/nullsec-flipper-suite

═══════════════════════════════════════════════════════════
EOF
            ;;
        "macos")
            cat << 'EOF'

═══════════════════════════════════════════════════════════
📝 TEMPLATE: macOS BadUSB
═══════════════════════════════════════════════════════════

macOS payloads work differently than Windows. Key changes:

### Open Spotlight (instead of Run):
```
GUI SPACE
DELAY 500
```

### Open Terminal:
```
STRING terminal
ENTER
DELAY 1000
```

### Example macOS payload:
```
REM macOS Recon
DELAY 1000
GUI SPACE
DELAY 500
STRING terminal
ENTER
DELAY 1000
STRING whoami && id && sw_vers
ENTER
```

### Working macOS payloads
Check `23_MacOSRecon.txt` in my collection:
👉 https://github.com/bad-antics/nullsec-flipper-suite

═══════════════════════════════════════════════════════════
EOF
            ;;
        "linux")
            cat << 'EOF'

═══════════════════════════════════════════════════════════
📝 TEMPLATE: Linux BadUSB
═══════════════════════════════════════════════════════════

Linux payloads need different approach than Windows:

### Open terminal (varies by distro):
```
CTRL ALT t
DELAY 1000
```

### Example Linux payload:
```
REM Linux Recon
DELAY 1000
CTRL ALT t
DELAY 1500
STRING whoami && id && uname -a && cat /etc/os-release
ENTER
```

### Working Linux payloads
Check `21_LinuxRecon.txt` and `22_LinuxReverseShell.txt`:
👉 https://github.com/bad-antics/nullsec-flipper-suite

═══════════════════════════════════════════════════════════
EOF
            ;;
        *)
            cat << 'EOF'

═══════════════════════════════════════════════════════════
📝 TEMPLATE: General Help
═══════════════════════════════════════════════════════════

Happy to help! Could you share:
1. What OS are you targeting?
2. What payload are you trying to run?
3. What error/behavior are you seeing?

In the meantime, check my tested payload collection:
👉 https://github.com/bad-antics/nullsec-flipper-suite

Contains 25+ payloads for Windows, Linux, and macOS!

═══════════════════════════════════════════════════════════
EOF
            ;;
    esac
}

post_answer() {
    local repo="$1"
    local issue_num="$2"
    local answer="$3"
    
    echo -e "${YELLOW}Posting answer to ${repo}#${issue_num}...${NC}"
    gh issue comment "$issue_num" --repo "$repo" --body "$answer"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Answer posted successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to post answer${NC}"
    fi
}

view_issue() {
    local repo="$1"
    local issue_num="$2"
    
    echo -e "\n${CYAN}═══ ISSUE DETAILS ═══${NC}\n"
    gh issue view "$issue_num" --repo "$repo" 2>/dev/null
}

interactive_menu() {
    while true; do
        echo -e "\n${GREEN}═══ MAIN MENU ═══${NC}"
        echo "1) Find Flipper Zero issues"
        echo "2) Find Hak5 issues"
        echo "3) Find general security issues"
        echo "4) Generate answer template"
        echo "5) View specific issue"
        echo "6) Post answer to issue"
        echo "7) Check my PR status"
        echo "8) Quick search"
        echo "q) Quit"
        echo ""
        read -p "Select option: " choice
        
        case "$choice" in
            1) find_flipper_issues ;;
            2) find_hak5_issues ;;
            3) find_security_issues ;;
            4)
                echo -e "\nTemplate types:"
                echo "  1) not_working - Scripts not working"
                echo "  2) virus - AV detection issues"
                echo "  3) macos - macOS payloads"
                echo "  4) linux - Linux payloads"
                echo "  5) general - General help"
                read -p "Select template: " tmpl
                case "$tmpl" in
                    1) generate_answer_template "not_working" ;;
                    2) generate_answer_template "virus" ;;
                    3) generate_answer_template "macos" ;;
                    4) generate_answer_template "linux" ;;
                    5) generate_answer_template "general" ;;
                esac
                ;;
            5)
                read -p "Enter repo (e.g., I-Am-Jakoby/Flipper-Zero-BadUSB): " repo
                read -p "Enter issue number: " num
                view_issue "$repo" "$num"
                ;;
            6)
                read -p "Enter repo: " repo
                read -p "Enter issue number: " num
                echo "Enter your answer (end with EOF on new line):"
                answer=""
                while IFS= read -r line; do
                    [[ "$line" == "EOF" ]] && break
                    answer+="$line"$'\n'
                done
                post_answer "$repo" "$num" "$answer"
                ;;
            7)
                echo -e "\n${CYAN}═══ YOUR OPEN PRs ═══${NC}\n"
                gh pr list --author "$GITHUB_USER" --state open
                ;;
            8)
                read -p "Enter search query: " query
                search_issues "$query" 15
                ;;
            q|Q) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# Quick mode - just list issues
quick_mode() {
    banner
    find_flipper_issues
    find_hak5_issues
    
    echo -e "\n${GREEN}═══ QUICK ANSWER TEMPLATES ═══${NC}"
    echo "Run with -t flag to see templates:"
    echo "  $0 -t not_working"
    echo "  $0 -t virus"
    echo "  $0 -t macos"
    echo "  $0 -t linux"
}

# Main
case "${1:-}" in
    -i|--interactive)
        banner
        interactive_menu
        ;;
    -t|--template)
        generate_answer_template "${2:-general}"
        ;;
    -s|--search)
        search_issues "${2:-badusb}" "${3:-15}"
        ;;
    -f|--flipper)
        find_flipper_issues
        ;;
    -h|--hak5)
        find_hak5_issues
        ;;
    -p|--post)
        # Quick post: ./script.sh -p repo issue_num template_type
        if [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
            answer=$(generate_answer_template "$4")
            post_answer "$2" "$3" "$answer"
        else
            echo "Usage: $0 -p <repo> <issue_num> <template_type>"
        fi
        ;;
    --help)
        echo "NullSec GitHub Community Helper"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  -i, --interactive    Interactive menu mode"
        echo "  -t, --template TYPE  Show answer template"
        echo "  -s, --search QUERY   Search for issues"
        echo "  -f, --flipper        Find Flipper Zero issues"
        echo "  -h, --hak5           Find Hak5 issues"
        echo "  -p, --post           Post answer to issue"
        echo "  --help               Show this help"
        echo ""
        echo "Template types: not_working, virus, macos, linux, general"
        ;;
    *)
        quick_mode
        ;;
esac
