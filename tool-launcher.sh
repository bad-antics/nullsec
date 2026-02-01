#!/bin/bash
# NULLSEC Tool Launcher v1.1 - Auto-launch security tools
# Integrates with framework modules
# GitHub: github.com/bad-antics/nullsec-linux

VERSION="1.1"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

TOOL_NAME=$1
TARGET=$2
CAPTURE_FILE=${3:-"/tmp/nullsec_capture_$(date +%s).pcap"}

launch_tool() {
    local tool=$1
    local target=$2
    
    case $tool in
        wireshark)
            if command -v wireshark &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching Wireshark..."
                if [ ! -z "$target" ]; then
                    # Launch with capture filter
                    echo -e "${CYAN}[*]${RESET} Capture filter: host $target"
                    wireshark -i any -k -f "host $target" -w "$CAPTURE_FILE" &
                else
                    wireshark &
                fi
                echo -e "${GREEN}[✓]${RESET} Wireshark launched (PID: $!)"
            else
                echo -e "${RED}[!]${RESET} Wireshark not installed"
                echo -e "${YELLOW}[*]${RESET} Install: sudo apt install wireshark"
                return 1
            fi
            ;;
            
        ettercap)
            if command -v ettercap &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching Ettercap GUI..."
                ettercap -G &
                echo -e "${GREEN}[✓]${RESET} Ettercap launched (PID: $!)"
            else
                echo -e "${RED}[!]${RESET} Ettercap not installed"
                echo -e "${YELLOW}[*]${RESET} Install: sudo apt install ettercap-graphical"
                return 1
            fi
            ;;
            
        burpsuite)
            if command -v burpsuite &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching BurpSuite..."
                burpsuite &
                echo -e "${GREEN}[✓]${RESET} BurpSuite launched (PID: $!)"
            else
                echo -e "${RED}[!]${RESET} BurpSuite not installed"
                return 1
            fi
            ;;
            
        msfconsole)
            if command -v msfconsole &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching Metasploit Console..."
                if [ ! -z "$target" ]; then
                    echo "setg RHOSTS $target" > /tmp/msf_rc.rc
                    echo "setg RHOST $target" >> /tmp/msf_rc.rc
                    gnome-terminal -- msfconsole -r /tmp/msf_rc.rc &
                else
                    gnome-terminal -- msfconsole &
                fi
                echo -e "${GREEN}[✓]${RESET} Metasploit Console launched"
            else
                echo -e "${RED}[!]${RESET} Metasploit not installed"
                return 1
            fi
            ;;
            
        zaproxy)
            if command -v zaproxy &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching OWASP ZAP..."
                zaproxy &
                echo -e "${GREEN}[✓]${RESET} OWASP ZAP launched (PID: $!)"
            else
                echo -e "${RED}[!]${RESET} OWASP ZAP not installed"
                return 1
            fi
            ;;
            
        ghidra)
            if command -v ghidra &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching Ghidra..."
                ghidra &
                echo -e "${GREEN}[✓]${RESET} Ghidra launched (PID: $!)"
            else
                echo -e "${RED}[!]${RESET} Ghidra not installed"
                return 1
            fi
            ;;
            
        sqlmap)
            if command -v sqlmap &> /dev/null; then
                echo -e "${GREEN}[+]${RESET} Launching sqlmap..."
                if [ ! -z "$target" ]; then
                    gnome-terminal -- sqlmap -u "$target" --batch
                else
                    gnome-terminal -- sqlmap
                fi
                echo -e "${GREEN}[✓]${RESET} sqlmap launched"
            else
                echo -e "${RED}[!]${RESET} sqlmap not installed"
                return 1
            fi
            ;;
            
        *)
            echo -e "${RED}[!]${RESET} Unknown tool: $tool"
            return 1
            ;;
    esac
}

# If called directly
if [ ! -z "$TOOL_NAME" ]; then
    launch_tool "$TOOL_NAME" "$TARGET"
fi
