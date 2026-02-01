#!/bin/bash

#############################################################################
#           NULLSEC LINUX - LOG ENCRYPTION INSTALLER v1.1                  #
#           Repository: https://github.com/bad-antics/nullsec             #
#############################################################################
# Installs log encryption utility and dependencies
#############################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
====
|         NULLSEC LINUX - LOG ENCRYPTION INSTALLER                      |
====
EOF
echo -e "${NC}"

echo -e "${GREEN}[+] Installing log encryption system...${NC}"

# Install Python dependencies
echo -e "${YELLOW}[*] Installing Python cryptography library...${NC}"
pip3 install --user cryptography 2>/dev/null || \
sudo pip3 install cryptography || \
python3 -m pip install --user cryptography

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓] Cryptography library installed${NC}"
else
    echo -e "${RED}[✗] Failed to install cryptography library${NC}"
    echo -e "${YELLOW}[*] Try: sudo apt-get install python3-cryptography${NC}"
    exit 1
fi

# Make log-encrypt.py executable
echo -e "${YELLOW}[*] Setting permissions...${NC}"
chmod +x ~/nullsec/log-encrypt.py

# Create encryption key directory
mkdir -p ~/.nullsec
chmod 700 ~/.nullsec

# Generate initial encryption key
echo -e "${YELLOW}[*] Generating encryption key...${NC}"
echo -e "${CYAN}You will be asked to create a password for log encryption.${NC}"
echo -e "${CYAN}This password will be required to decrypt logs later.${NC}\n"

python3 ~/nullsec/log-encrypt.py --generate-key

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}[✓] Encryption key generated${NC}"
else
    echo -e "\n${YELLOW}[!] Key generation skipped or failed${NC}"
fi

# Create symlink for easy access
echo -e "${YELLOW}[*] Creating command alias...${NC}"
if ! grep -q "alias log-encrypt" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# NullSec Log Encryption" >> ~/.bashrc
    echo "alias log-encrypt='python3 ~/nullsec/log-encrypt.py'" >> ~/.bashrc
    echo -e "${GREEN}[✓] Added 'log-encrypt' alias to ~/.bashrc${NC}"
else
    echo -e "${BLUE}[*] Alias already exists${NC}"
fi

echo -e "\n${GREEN}"
cat << "EOF"
====
|                    ✅ INSTALLATION COMPLETE                           |
====

🔐 LOG ENCRYPTION SYSTEM INSTALLED

📋 Features:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ AES-256 encryption for log files
  ✓ Password-based key derivation (PBKDF2)
  ✓ Automatic encryption option in framework
  ✓ Standalone encryption/decryption tools
  ✓ Directory-wide encryption support

🔧 Usage:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Encrypt a log file:
   log-encrypt --encrypt /path/to/logfile.log

2. Decrypt a log file:
   log-encrypt --decrypt /path/to/logfile.log.enc

3. Encrypt all logs in directory:
   log-encrypt --encrypt-dir ~/nullsec/logs

4. In framework modules:
   When asked "Encrypt logs after execution? [y/N]:" 
   Answer 'y' to automatically encrypt

5. Generate new key:
   log-encrypt --generate-key

📁 Files:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • ~/nullsec/log-encrypt.py - Main encryption utility
  • ~/.nullsec/encryption.key - Your encryption key
  • ~/.nullsec/encryption.salt - Salt for key derivation

⚠️  IMPORTANT:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Keep your password safe - it cannot be recovered!
  • Backup ~/.nullsec/ directory for key recovery
  • Encrypted logs cannot be decrypted without the password

🚀 Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Reload bashrc: source ~/.bashrc
  2. Test encryption: log-encrypt --help
  3. Enable in framework when running modules

EOF
echo -e "${NC}"

exit 0
