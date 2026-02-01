#!/bin/bash
# GitHub Preparation and Upload System for NULLSEC
# Developed by bad-antics

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

GITHUB_USER="bad-antics"
GITHUB_EMAIL="your_email@example.com"  # Update this with your email

echo -e "${RED}"
cat << "EOF"

   ▄████  ██▓▄▄▄█████▓ ██░ ██  █    ██  ▄▄▄▄   
  ██▒ ▀█▒▓██▒▓  ██▒ ▓▒▓██░ ██▒ ██  ▓██▒▓█████▄ 
 ▒██░▄▄▄░▒██▒▒ ▓██░ ▒░▒██▀▀██░▓██  ▒██░▒██▒ ▄██
 ░▓█  ██▓░██░░ ▓██▓ ░ ░▓█ ░██ ▓▓█  ░██░▒██░█▀  
 ░▒▓███▀▒░██░  ▒██▒ ░ ░▓█▒░██▓▒▒█████▓ ░▓█  ▀█▓
  ░▒   ▒ ░▓    ▒ ░░    ▒ ░░▒░▒░▒▓▒ ▒ ▒ ░▒▓███▀▒
   ░   ░  ▒ ░    ░     ▒ ░▒░ ░░░▒░ ░ ░ ▒░▒   ░ 
 ░ ░   ░  ▒ ░  ░       ░  ░░ ░ ░░░ ░ ░  ░    ░ 
       ░  ░            ░  ░  ░   ░      ░      
EOF
echo -e "${CYAN}"
cat << "EOF"
 ██▓███   ██▀███  ▓█████  ██▓███   ▄▄▄       ██▀███   ▄▄▄      ▄▄▄█████▓ ██▓ ▒█████   ███▄    █ 
▓██░  ██▒▓██ ▒ ██▒▓█   ▀ ▓██░  ██▒▒████▄    ▓██ ▒ ██▒▒████▄    ▓  ██▒ ▓▒▓██▒▒██▒  ██▒ ██ ▀█   █ 
▓██░ ██▓▒▓██ ░▄█ ▒▒███   ▓██░ ██▓▒▒██  ▀█▄  ▓██ ░▄█ ▒▒██  ▀█▄  ▒ ▓██░ ▒░▒██▒▒██░  ██▒▓██  ▀█ ██▒
▒██▄█▓▒ ▒▒██▀▀█▄  ▒▓█  ▄ ▒██▄█▓▒ ▒░██▄▄▄▄██ ▒██▀▀█▄  ░██▄▄▄▄██ ░ ▓██▓ ░ ░██░▒██   ██░▓██▒  ▐▌██▒
▒██▒ ░  ░░██▓ ▒██▒░▒████▒▒██▒ ░  ░ ▓█   ▓██▒░██▓ ▒██▒ ▓█   ▓██▒  ▒██▒ ░ ░██░░ ████▓▒░▒██░   ▓██░
▒▓▒░ ░  ░░ ▒▓ ░▒▓░░░ ▒░ ░▒▓▒░ ░  ░ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒   ▓▒█░  ▒ ░░   ░▓  ░ ▒░▒░▒░ ░ ▒░   ▒ ▒ 
░▒ ░       ░▒ ░ ▒░ ░ ░  ░░▒ ░       ▒   ▒▒ ░  ░▒ ░ ▒░  ▒   ▒▒ ░    ░     ▒ ░  ░ ▒ ▒░ ░ ░░   ░ ▒░
░░         ░░   ░    ░   ░░         ░   ▒     ░░   ░   ░   ▒     ░       ▒ ░░ ░ ░ ▒     ░   ░ ░ 
            ░        ░  ░               ░  ░   ░           ░  ░          ░      ░ ░           ░ 
EOF
echo -e "${YELLOW}"
cat << "EOF"
                    ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
                               ☠  BAD-ANTICS DEV TEAM  ☠                  
                         NULLSEC Encrypted Repository System               
                    ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
                                                                           
                      🔐 AES-256-CBC    📦 70+ Modules    🌐 GitHub Private
                                                                           
                       ENCRYPT ━━▶ PACKAGE ━━▶ GIT INIT ━━▶ PUSH ━━▶ DONE  
                                                                           
                              github.com/bad-antics                        
                    ╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
EOF
echo -e "${RESET}"

# Function to encrypt a file
encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local password="$3"
    
    echo -e "${YELLOW}[*] Encrypting: ${input_file}${RESET}"
    
    # Use OpenSSL AES-256-CBC encryption
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$input_file" -out "$output_file" -k "$password"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Encrypted: ${output_file}${RESET}"
        return 0
    else
        echo -e "${RED}[✗] Encryption failed: ${input_file}${RESET}"
        return 1
    fi
}

# Function to create individual repo structure
create_repo_structure() {
    local script_name="$1"
    local script_path="$2"
    local repo_base="$3"
    
    local repo_name=$(basename "$script_name" .sh | sed 's/_/-/g')
    local repo_dir="${repo_base}/${repo_name}"
    
    mkdir -p "$repo_dir"
    
    # Copy and encrypt the script
    if [ -f "$script_path" ]; then
        encrypt_file "$script_path" "${repo_dir}/${script_name}.enc" "$ENCRYPTION_KEY"
        
        # Create README for the repo
        cat > "${repo_dir}/README.md" << EOFREADME
# ${repo_name}

Part of the NULLSEC Framework - Offensive Security Operations

## Installation

\`\`\`bash
# Decrypt the script
openssl enc -aes-256-cbc -d -pbkdf2 -in ${script_name}.enc -out ${script_name}

# Make executable
chmod +x ${script_name}
\`\`\`

## Usage

See main NULLSEC documentation.

## ⚠️ Legal Notice

This tool is for authorized security testing only. Unauthorized access to computer systems is illegal.

---

*Developed by bad-antics | github.com/bad-antics*
EOFREADME
        
        # Initialize git repo
        cd "$repo_dir"
        git init
        git add .
        git commit -m "Initial commit: Encrypted ${script_name}"
        cd - > /dev/null
        
        echo -e "${GREEN}[✓] Created repo: ${repo_name}${RESET}"
    fi
}

# Main execution
echo -e "${WHITE}This script will:${RESET}"
echo -e "  ${CYAN}1.${RESET} Encrypt all NULLSEC scripts"
echo -e "  ${CYAN}2.${RESET} Create individual repository structures"
echo -e "  ${CYAN}3.${RESET} Generate GitHub upload commands"
echo ""

read -p "$(echo -e ${YELLOW}'Continue? (y/n): '${RESET})" CONTINUE
if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted.${RESET}"
    exit 1
fi

# Get encryption password
echo ""
echo -e "${YELLOW}Enter encryption password (will be used for all files):${RESET}"
read -s ENCRYPTION_KEY
echo ""
echo -e "${YELLOW}Confirm password:${RESET}"
read -s ENCRYPTION_KEY_CONFIRM
echo ""

if [ "$ENCRYPTION_KEY" != "$ENCRYPTION_KEY_CONFIRM" ]; then
    echo -e "${RED}[!] Passwords do not match!${RESET}"
    exit 1
fi

# Create base directory for repos
REPOS_BASE="/home/antics/github-repos"
mkdir -p "$REPOS_BASE"

echo -e "${GREEN}[*] Starting preparation...${RESET}"
echo ""

# Process all NULLSEC scripts
SCRIPT_COUNT=0
for script in nullsecurity/*.sh; do
    if [ -f "$script" ]; then
        create_repo_structure "$(basename $script)" "$script" "$REPOS_BASE"
        ((SCRIPT_COUNT++))
    fi
done

# Create main NULLSEC launcher repo
echo -e "${CYAN}[*] Creating main launcher repository...${RESET}"
LAUNCHER_DIR="${REPOS_BASE}/nullsec-launcher"
mkdir -p "$LAUNCHER_DIR"

# Encrypt main launcher
encrypt_file "nullsec-launcher.py" "${LAUNCHER_DIR}/nullsec-launcher.py.enc" "$ENCRYPTION_KEY"

# Create launcher README
cat > "${LAUNCHER_DIR}/README.md" << 'EOFLAUNCH'
# NULLSEC Launcher

Main launcher for the NULLSEC Offensive Security Operations Framework

## Features

- 62 Custom Attack Modules
- Metasploit Integration
- Shodan API Integration
- Command Execution Console
- Security Tools Launcher

## Installation

```bash
# Decrypt the launcher
openssl enc -aes-256-cbc -d -pbkdf2 -in nullsec-launcher.py.enc -out nullsec-launcher.py

# Make executable
chmod +x nullsec-launcher.py

# Run
./nullsec-launcher.py
```

## ⚠️ Legal Notice

**FOR AUTHORIZED SECURITY TESTING ONLY**

This framework is designed for professional penetration testers and red team operators. Unauthorized access to computer systems is illegal.

## Version

nullsec-Linux (v1.1)

---

*Developed by bad-antics | github.com/bad-antics*
EOFLAUNCH

cd "$LAUNCHER_DIR"
git init
git add .
git commit -m "Initial commit: NULLSEC Launcher (encrypted)"
cd - > /dev/null

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}Preparation Complete!${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${CYAN}Statistics:${RESET}"
echo -e "  • Scripts encrypted: ${WHITE}${SCRIPT_COUNT}${RESET}"
echo -e "  • Repositories created: ${WHITE}$((SCRIPT_COUNT + 1))${RESET}"
echo -e "  • Base directory: ${WHITE}${REPOS_BASE}${RESET}"
echo ""

# Generate upload script
UPLOAD_SCRIPT="${REPOS_BASE}/upload-to-github.sh"
cat > "$UPLOAD_SCRIPT" << 'EOFUPLOAD'
#!/bin/bash
# Auto-generated GitHub upload script

GITHUB_USER="bad-antics"
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

echo -e "${CYAN}GitHub Upload Script${RESET}"
echo ""

# Check if GitHub CLI is available
if command -v gh &> /dev/null; then
    echo -e "${GREEN}[✓] GitHub CLI found${RESET}"
    USE_GH_CLI=true
else
    echo -e "${YELLOW}[!] GitHub CLI not found, using git commands${RESET}"
    USE_GH_CLI=false
fi

cd "$(dirname "$0")"

for repo_dir in */; do
    repo_name="${repo_dir%/}"
    
    echo ""
    echo -e "${CYAN}Processing: ${repo_name}${RESET}"
    
    cd "$repo_name"
    
    if [ "$USE_GH_CLI" = true ]; then
        # Create repo using GitHub CLI
        gh repo create "${GITHUB_USER}/${repo_name}" --private --source=. --remote=origin --push
    else
        # Manual git commands
        echo -e "${YELLOW}Run these commands manually:${RESET}"
        echo "  cd $(pwd)"
        echo "  # Create repo on GitHub web interface first"
        echo "  git remote add origin https://github.com/${GITHUB_USER}/${repo_name}.git"
        echo "  git branch -M main"
        echo "  git push -u origin main"
        echo ""
    fi
    
    cd ..
done

echo ""
echo -e "${GREEN}Upload process complete!${RESET}"
EOFUPLOAD

chmod +x "$UPLOAD_SCRIPT"

echo -e "${YELLOW}Next Steps:${RESET}"
echo ""
echo -e "${WHITE}1. Review encrypted files:${RESET}"
echo -e "   cd ${REPOS_BASE}"
echo -e "   ls -la"
echo ""
echo -e "${WHITE}2. Install GitHub CLI (recommended):${RESET}"
echo -e "   sudo apt install gh"
echo -e "   gh auth login"
echo ""
echo -e "${WHITE}3. Upload to GitHub:${RESET}"
echo -e "   cd ${REPOS_BASE}"
echo -e "   ./upload-to-github.sh"
echo ""
echo -e "${WHITE}Alternative - Manual upload per repo:${RESET}"
echo -e "   # On GitHub, create new private repository"
echo -e "   # Then for each repo:"
echo -e "   cd ${REPOS_BASE}/repo-name"
echo -e "   git remote add origin https://github.com/${GITHUB_USER}/repo-name.git"
echo -e "   git branch -M main"
echo -e "   git push -u origin main"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}All files have been encrypted and prepared!${RESET}"
echo -e "${YELLOW}Password required to decrypt: [your encryption password]${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
