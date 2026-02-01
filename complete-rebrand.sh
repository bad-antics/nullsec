#!/bin/bash
# NullSec Linux - Complete ASCII Header Replacement

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${RED}====${NC}"
echo -e "${RED}|        NullSec Linux - ASCII Header Replacement Script               |${NC}"
echo -e "${RED}====${NC}"

BACKUP_DIR="/home/antics/nullsec/ascii-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}[+] Replacing MOTD ASCII header...${NC}"

sudo cp /usr/share/base-files/motd "$BACKUP_DIR/motd.bak"

sudo tee /usr/share/base-files/motd > /dev/null << 'NEWMOTD'
 ███==   ██==██==   ██==██==     ██==     ███████==███████== ██████==
 ████==  ██|██|   ██|██|     ██|     ██====██====██====
 ██==██== ██|██|   ██|██|     ██|     ███████==█████==  ██|     
 ██|==██==██|██|   ██|██|     ██|     ==██|██====  ██|     
 ██| ==████|==██████====███████==███████==███████|███████====██████==
 ====  ==== ==== ================ ====
                                                              
         L I N U X   1.0  -  O F F E N S I V E   S E C       


The programs included with NullSec Linux are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

NullSec Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
NEWMOTD

echo -e "${GREEN}  ✓ Replaced /usr/share/base-files/motd${NC}"

# Replace in any shell scripts with the old header
echo -e "${GREEN}[+] Searching for Parrot ASCII headers in scripts...${NC}"

COUNT=0
sudo find /usr/share /etc -type f \( -name "*.sh" -o -name "*.py" -o -name "motd*" \) 2>/dev/null | while read file; do
    if sudo grep -q "____.*Parrot\|ParrotSec" "$file" 2>/dev/null; then
        sudo sed -i 's/Parrot Security/NullSec Linux/g; s/ParrotSec/NullSec/g; s/Parrot GNU\/Linux/NullSec Linux/g' "$file"
        echo "  Updated: $file"
        ((COUNT++))
    fi
done

echo -e "${GREEN}[+] Replacing Parrot references in desktop files...${NC}"
sudo find /usr/share -name "*.desktop" -type f 2>/dev/null | xargs sudo sed -i 's/Parrot Security/NullSec Linux/g; s/ParrotSec/NullSec/g' 2>/dev/null || true

echo ""
echo -e "${GREEN}====${NC}"
echo -e "${GREEN}|                    REPLACEMENT COMPLETE!                              |${NC}"
echo -e "${GREEN}====${NC}"
echo ""
echo -e "${CYAN}Changed:${NC}"
echo -e "  ✓ /usr/share/base-files/motd - NullSec ASCII header"
echo -e "  ✓ All Parrot references replaced with NullSec Linux"
echo ""
echo -e "${CYAN}Backup: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
