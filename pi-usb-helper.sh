#!/bin/bash
#===============================================================================
#  NULLSEC - RASPBERRY PI USB BOOT MODE HELPER
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║         RASPBERRY PI 4 - USB MASS STORAGE MODE                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}To flash your Pi 4 SD card, you have several options:${NC}"
echo ""
echo -e "${CYAN}OPTION 1: Use an SD Card Reader (Recommended)${NC}"
echo "  1. Remove the SD card from your Pi"
echo "  2. Insert it into a USB SD card reader"
echo "  3. Connect the reader to this computer"
echo "  4. Run: sudo ./build-nullsec-pi.sh build"
echo "  5. Then: sudo ./build-nullsec-pi.sh flash /dev/sdX"
echo ""
echo -e "${CYAN}OPTION 2: Raspberry Pi Imager USB Boot${NC}"
echo "  1. Hold BOOTSEL button while powering on Pi"
echo "  2. Connect Pi to PC via USB-C (use the USB-C power port)"
echo "  3. The Pi should appear as a USB drive"
echo "  4. If not working, update the EEPROM first"
echo ""
echo -e "${CYAN}OPTION 3: Network Boot (PXE)${NC}"
echo "  1. Set up a TFTP/NFS server on this machine"
echo "  2. Configure Pi to boot from network"
echo ""
echo -e "${CYAN}OPTION 4: Pre-flash on existing Raspberry Pi OS${NC}"
echo "  If your Pi already boots, SSH in and run:"
echo "    curl -sSL [url] | sudo bash"
echo ""

echo -e "${GREEN}Checking for connected devices...${NC}"
echo ""

# Check for any new USB devices
lsblk -o NAME,SIZE,TYPE,MODEL,TRAN | grep -E "disk|NAME"

echo ""
echo -e "${YELLOW}Watching for new USB devices... (Ctrl+C to stop)${NC}"
echo "Insert your SD card reader now..."
echo ""

# Watch for new devices
inotifywait -m /dev -e create 2>/dev/null | while read dir action file; do
    if [[ "$file" =~ ^sd[a-z]$ ]]; then
        echo -e "${GREEN}[+] New device detected: /dev/$file${NC}"
        sleep 1
        lsblk "/dev/$file" -o NAME,SIZE,TYPE,MODEL
        echo ""
        echo -e "${CYAN}To flash, run:${NC}"
        echo "  sudo ./build-nullsec-pi.sh flash /dev/$file"
    fi
done
