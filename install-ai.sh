#!/bin/bash
#
# NullSec Linux - NULLSEC AI v3.0 Installation Script v1.1
# Installs Ollama and recommended AI models for pentesting
# Part of NullSec Linux 1.0 (void)
# Repository: https://github.com/bad-antics/nullsec
#

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

clear
echo -e "${RED}"
cat << 'BANNER'
 ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄  
 ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█  
▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄ 
▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
BANNER
echo -e "${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}         NullSec Linux - NULLSEC AI v3.0 INSTALLER${RESET}"
echo -e "${DIM}            NO API KEYS REQUIRED - 100% Offline AI${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""

# Check if Ollama is already installed
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}[+] Ollama is already installed!${RESET}"
    OLLAMA_INSTALLED=1
else
    echo -e "${YELLOW}[!] Ollama not found${RESET}"
    OLLAMA_INSTALLED=0
fi

echo ""
echo -e "${CYAN}Installation Options:${RESET}"
echo ""
echo -e "  ${GREEN}[1]${RESET} Install Ollama + Recommended Model (DeepSeek Coder 6.7B)"
echo -e "      ${DIM}Size: ~4GB | Best for: Exploit development, shellcode${RESET}"
echo ""
echo -e "  ${GREEN}[2]${RESET} Install Ollama + Multiple Models (Pentesting Suite)"
echo -e "      ${DIM}Size: ~15GB | Includes: DeepSeek, CodeLlama, Mistral${RESET}"
echo ""
echo -e "  ${GREEN}[3]${RESET} Install Ollama + ALL Models (Complete Collection)"
echo -e "      ${DIM}Size: ~50GB | All 10 specialized models${RESET}"
echo ""
echo -e "  ${GREEN}[4]${RESET} Just Install Ollama (Manual model selection later)"
echo ""
echo -e "  ${GREEN}[5]${RESET} Skip Installation (Use expert system only)"
echo ""
echo -e "  ${GREEN}[6]${RESET} Show Model Comparison & Exit"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""
read -p "$(echo -e ${WHITE}'Select option [1-6]: '${RESET})" CHOICE

case $CHOICE in
    1)
        echo ""
        echo -e "${CYAN}[*] Installing Ollama and DeepSeek Coder...${RESET}"
        
        if [ $OLLAMA_INSTALLED -eq 0 ]; then
            echo -e "${YELLOW}[*] Downloading Ollama installer...${RESET}"
            curl -fsSL https://ollama.com/install.sh | sh
        fi
        
        echo -e "${YELLOW}[*] Pulling DeepSeek Coder 6.7B (~4GB download)...${RESET}"
        ollama pull deepseek-coder:6.7b
        
        echo -e "${GREEN}[+] Installation complete!${RESET}"
        echo ""
        echo -e "${CYAN}Test it now:${RESET}"
        echo -e "  ${WHITE}python3 /home/antics/nullsec/nullsec-ai.py${RESET}"
        ;;
    
    2)
        echo ""
        echo -e "${CYAN}[*] Installing Ollama and Pentesting Suite...${RESET}"
        
        if [ $OLLAMA_INSTALLED -eq 0 ]; then
            echo -e "${YELLOW}[*] Downloading Ollama installer...${RESET}"
            curl -fsSL https://ollama.com/install.sh | sh
        fi
        
        echo -e "${YELLOW}[*] Pulling models (this will take a while)...${RESET}"
        
        echo -e "${DIM}[1/3] DeepSeek Coder 6.7B - Exploit development...${RESET}"
        ollama pull deepseek-coder:6.7b
        
        echo -e "${DIM}[2/3] CodeLlama 13B - General purpose...${RESET}"
        ollama pull codellama:13b
        
        echo -e "${DIM}[3/3] Mistral 7B - Fast responses...${RESET}"
        ollama pull mistral:7b
        
        echo -e "${GREEN}[+] Pentesting suite installed!${RESET}"
        ;;
    
    3)
        echo ""
        echo -e "${CYAN}[*] Installing Ollama and ALL models...${RESET}"
        echo -e "${YELLOW}[!] Warning: This will download ~50GB of data${RESET}"
        read -p "$(echo -e ${WHITE}'Continue? (y/N): '${RESET})" CONFIRM
        
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[!] Installation cancelled${RESET}"
            exit 0
        fi
        
        if [ $OLLAMA_INSTALLED -eq 0 ]; then
            echo -e "${YELLOW}[*] Downloading Ollama installer...${RESET}"
            curl -fsSL https://ollama.com/install.sh | sh
        fi
        
        MODELS=(
            "deepseek-coder:6.7b"
            "codellama:13b"
            "wizardcoder:15b"
            "mistral:7b"
            "mixtral:8x7b"
            "openhermes:7b"
            "solar:10.7b"
            "phi:2.7b"
            "orca2:13b"
            "neural-chat:7b"
        )
        
        TOTAL=${#MODELS[@]}
        CURRENT=1
        
        for MODEL in "${MODELS[@]}"; do
            echo -e "${DIM}[$CURRENT/$TOTAL] Installing $MODEL...${RESET}"
            ollama pull "$MODEL"
            ((CURRENT++))
        done
        
        echo -e "${GREEN}[+] All models installed!${RESET}"
        ;;
    
    4)
        echo ""
        echo -e "${CYAN}[*] Installing Ollama only...${RESET}"
        
        if [ $OLLAMA_INSTALLED -eq 0 ]; then
            curl -fsSL https://ollama.com/install.sh | sh
            echo -e "${GREEN}[+] Ollama installed!${RESET}"
        else
            echo -e "${GREEN}[+] Ollama already installed!${RESET}"
        fi
        
        echo ""
        echo -e "${CYAN}To install models manually:${RESET}"
        echo -e "  ${WHITE}ollama pull deepseek-coder:6.7b${RESET}    # Recommended"
        echo -e "  ${WHITE}ollama pull codellama:13b${RESET}          # General purpose"
        echo -e "  ${WHITE}ollama pull mistral:7b${RESET}             # Fast & efficient"
        echo ""
        echo -e "View all models: ${WHITE}https://ollama.com/library${RESET}"
        ;;
    
    5)
        echo ""
        echo -e "${YELLOW}[!] Skipping installation${RESET}"
        echo ""
        echo -e "${CYAN}NULLSEC AI will use the offline expert system.${RESET}"
        echo -e "You'll still get pentesting commands and methodologies!"
        echo ""
        echo -e "To install AI later, run: ${WHITE}$0${RESET}"
        ;;
    
    6)
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
        echo -e "${WHITE}                          MODEL COMPARISON${RESET}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
        echo ""
        echo -e "${GREEN}SMALL & FAST (2-7B)${RESET}"
        echo -e "  ${CYAN}phi:2.7b${RESET}           - Smallest, fastest, good for low-spec systems"
        echo -e "  ${CYAN}mistral:7b${RESET}         - Excellent balance of speed and quality"
        echo -e "  ${CYAN}openhermes:7b${RESET}      - Great for detailed explanations"
        echo -e "  ${CYAN}neural-chat:7b${RESET}     - Best for conversational interaction"
        echo ""
        echo -e "${YELLOW}MEDIUM (6-13B)${RESET}"
        echo -e "  ${CYAN}deepseek-coder:6.7b${RESET} - ⭐ RECOMMENDED - Code & exploit specialist"
        echo -e "  ${CYAN}codellama:13b${RESET}       - Meta's code model, very capable"
        echo -e "  ${CYAN}orca2:13b${RESET}           - Strong reasoning abilities"
        echo ""
        echo -e "${MAGENTA}LARGE & POWERFUL (15B+)${RESET}"
        echo -e "  ${CYAN}wizardcoder:15b${RESET}    - Enhanced code generation"
        echo -e "  ${CYAN}solar:10.7b${RESET}        - Advanced reasoning"
        echo -e "  ${CYAN}mixtral:8x7b${RESET}       - Expert mixture, most capable (huge)"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
        echo ""
        echo -e "${WHITE}RECOMMENDATIONS:${RESET}"
        echo -e "  ${GREEN}Best Overall:${RESET}      deepseek-coder:6.7b"
        echo -e "  ${GREEN}Fastest:${RESET}           phi:2.7b or mistral:7b"
        echo -e "  ${GREEN}Most Powerful:${RESET}     mixtral:8x7b (requires good hardware)"
        echo -e "  ${GREEN}Best Value:${RESET}        codellama:13b"
        echo ""
        exit 0
        ;;
    
    *)
        echo -e "${RED}[!] Invalid choice${RESET}"
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}                    INSTALLATION COMPLETE! ✓${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${WHITE}Quick Start:${RESET}"
echo -e "  ${CYAN}# Launch NULLSEC AI${RESET}"
echo -e "  ${WHITE}python3 /home/antics/nullsec/nullsec-ai.py${RESET}"
echo ""
echo -e "  ${CYAN}# View installed models${RESET}"
echo -e "  ${WHITE}ollama list${RESET}"
echo ""
echo -e "  ${CYAN}# Install additional models${RESET}"
echo -e "  ${WHITE}ollama pull <model-name>${RESET}"
echo ""
echo -e "${WHITE}Documentation:${RESET}"
echo -e "  ${DIM}/home/antics/nullsec/NULLSEC_AI_V3_GUIDE.md${RESET}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""
