#!/bin/bash
# Flipper Zero CLI Interface
# bad-antics Development Team

FLIPPER_DEV="/dev/ttyACM0"
FLIPPER_DIR="/home/antics/flipper"
SCRIPTS_DIR="$FLIPPER_DIR/scripts"
FIRMWARE_DIR="$FLIPPER_DIR/firmware"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

banner() {
    echo -e "${PURPLE}"
    echo "  ███████▓██▓     ██▓██████▓ ██████▓ ███████▓██████▓ "
    echo "  ██▓━━━━▓███     █████▓━━██▓██▓━━██▓██▓━━━━▓██▓━━██▓"
    echo "  █████▓  ███     █████████▓▓██████▓▓█████▓  ██████▓▓"
    echo "  ██▓━━▓  ███     █████▓━━━▓ ██▓━━━▓ ██▓━━▓  ██▓━━██▓"
    echo "  ███     ███████▓██████     ███     ███████▓███  ███"
    echo "  ▓━▓     ▓━━━━━━▓▓━▓▓━▓     ▓━▓     ▓━━━━━━▓▓━▓  ▓━▓"
    echo -e "${CYAN}       Flipper Zero CLI - bad-antics${NC}"
    echo ""
}

# Initialize directories
flipper_init() {
    mkdir -p "$SCRIPTS_DIR" "$FIRMWARE_DIR"
    mkdir -p "$SCRIPTS_DIR/badusb"
    mkdir -p "$SCRIPTS_DIR/subghz"
    mkdir -p "$SCRIPTS_DIR/nfc"
    mkdir -p "$SCRIPTS_DIR/infrared"
    mkdir -p "$SCRIPTS_DIR/ibutton"
    mkdir -p "$SCRIPTS_DIR/rfid"
    echo -e "${GREEN}[+] Flipper directories initialized${NC}"
}

# Check if Flipper is connected
flipper_check() {
    if [ -e "$FLIPPER_DEV" ]; then
        echo -e "${GREEN}[+] Flipper Zero detected at $FLIPPER_DEV${NC}"
        return 0
    else
        echo -e "${RED}[-] Flipper Zero not found. Check USB connection.${NC}"
        return 1
    fi
}

# Send command to Flipper via serial
flipper_cmd() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: flipper_cmd <command>${NC}"
        return 1
    fi
    echo -e "${CYAN}[*] Sending: $1${NC}"
    echo "$1" > "$FLIPPER_DEV"
    sleep 0.5
    timeout 2 cat "$FLIPPER_DEV" 2>/dev/null || true
}

# Get Flipper device info
flipper_info() {
    echo -e "${CYAN}[*] Flipper Zero Device Info:${NC}"
    flipper_cmd "device_info"
}

# List storage contents
flipper_ls() {
    local path="${1:-/ext}"
    echo -e "${CYAN}[*] Listing $path:${NC}"
    flipper_cmd "storage list $path"
}

# Upload file to Flipper
flipper_upload() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${YELLOW}Usage: flipper_upload <local_file> <flipper_path>${NC}"
        echo -e "${YELLOW}Example: flipper_upload script.txt /ext/badusb/script.txt${NC}"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}[-] Local file not found: $1${NC}"
        return 1
    fi
    
    echo -e "${CYAN}[*] Uploading $1 to Flipper:$2${NC}"
    
    # Use Python for reliable file transfer
    python3 << EOF
import serial
import time
import os

try:
    ser = serial.Serial('$FLIPPER_DEV', 230400, timeout=1)
    time.sleep(0.5)
    
    # Read file content
    with open('$1', 'rb') as f:
        data = f.read()
    
    # Send storage write command
    cmd = f'storage write $2\r\n'
    ser.write(cmd.encode())
    time.sleep(0.2)
    
    # Send file data
    ser.write(data)
    ser.write(b'\x03')  # Ctrl+C to end
    time.sleep(0.5)
    
    # Read response
    response = ser.read(1024).decode('utf-8', errors='ignore')
    print(response)
    
    ser.close()
    print('\033[0;32m[+] Upload complete!\033[0m')
except Exception as e:
    print(f'\033[0;31m[-] Error: {e}\033[0m')
EOF
}

# Download file from Flipper
flipper_download() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${YELLOW}Usage: flipper_download <flipper_path> <local_file>${NC}"
        return 1
    fi
    echo -e "${CYAN}[*] Downloading Flipper:$1 to $2${NC}"
    flipper_cmd "storage read $1" > "$2"
    echo -e "${GREEN}[+] Download complete!${NC}"
}

# Clone BadUSB payloads from popular repos
flipper_clone_badusb() {
    echo -e "${CYAN}[*] Cloning BadUSB payloads...${NC}"
    cd "$SCRIPTS_DIR"
    
    # Clone popular Flipper BadUSB repos
    git clone https://github.com/UberGuidoZ/Flipper.git UberGuidoZ 2>/dev/null || \
        (cd UberGuidoZ && git pull)
    
    git clone https://github.com/Hak5/usbrubberducky-payloads.git ducky-payloads 2>/dev/null || \
        (cd ducky-payloads && git pull)
    
    echo -e "${GREEN}[+] BadUSB payloads cloned to $SCRIPTS_DIR${NC}"
}

# Clone SubGHz files
flipper_clone_subghz() {
    echo -e "${CYAN}[*] Cloning SubGHz files...${NC}"
    cd "$SCRIPTS_DIR"
    
    git clone https://github.com/UberGuidoZ/Flipper-IRDB.git IRDB 2>/dev/null || \
        (cd IRDB && git pull)
    
    echo -e "${GREEN}[+] SubGHz/IR files cloned${NC}"
}

# Update Flipper firmware (using ufbt or qFlipper)
flipper_update_firmware() {
    echo -e "${CYAN}[*] Firmware Update Options:${NC}"
    echo -e "  1) Official Firmware (stable)"
    echo -e "  2) Unleashed Firmware"
    echo -e "  3) Momentum Firmware"
    echo -e "  4) Xtreme Firmware"
    echo -e "  5) RogueMaster Firmware"
    echo ""
    read -p "Select firmware [1-5]: " choice
    
    case $choice in
        1)
            echo -e "${CYAN}[*] Downloading Official Firmware...${NC}"
            cd "$FIRMWARE_DIR"
            wget -q https://update.flipperzero.one/builds/firmware/latest.tgz -O official.tgz
            echo -e "${GREEN}[+] Downloaded. Use qFlipper to install.${NC}"
            ;;
        2)
            echo -e "${CYAN}[*] Cloning Unleashed Firmware...${NC}"
            cd "$FIRMWARE_DIR"
            git clone https://github.com/DarkFlippers/unleashed-firmware.git unleashed 2>/dev/null || \
                (cd unleashed && git pull)
            echo -e "${GREEN}[+] Unleashed firmware cloned. Build with: cd unleashed && ./fbt${NC}"
            ;;
        3)
            echo -e "${CYAN}[*] Cloning Momentum Firmware...${NC}"
            cd "$FIRMWARE_DIR"
            git clone https://github.com/Next-Flip/Momentum-Firmware.git momentum 2>/dev/null || \
                (cd momentum && git pull)
            echo -e "${GREEN}[+] Momentum firmware cloned. Build with: cd momentum && ./fbt${NC}"
            ;;
        4)
            echo -e "${CYAN}[*] Cloning Xtreme Firmware...${NC}"
            cd "$FIRMWARE_DIR"
            git clone https://github.com/Flipper-XFW/Xtreme-Firmware.git xtreme 2>/dev/null || \
                (cd xtreme && git pull)
            echo -e "${GREEN}[+] Xtreme firmware cloned. Build with: cd xtreme && ./fbt${NC}"
            ;;
        5)
            echo -e "${CYAN}[*] Cloning RogueMaster Firmware...${NC}"
            cd "$FIRMWARE_DIR"
            git clone https://github.com/RogueMaster/flipperzero-firmware-wPlugins.git roguemaster 2>/dev/null || \
                (cd roguemaster && git pull)
            echo -e "${GREEN}[+] RogueMaster firmware cloned. Build with: cd roguemaster && ./fbt${NC}"
            ;;
        *)
            echo -e "${RED}[-] Invalid option${NC}"
            ;;
    esac
}

# Flash firmware to Flipper
flipper_flash() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: flipper_flash <firmware.dfu>${NC}"
        return 1
    fi
    echo -e "${CYAN}[*] Flashing firmware: $1${NC}"
    echo -e "${YELLOW}[!] Put Flipper in DFU mode (hold BACK + LEFT while connecting)${NC}"
    read -p "Press Enter when ready..."
    dfu-util -a 0 -s 0x08000000 -D "$1"
}

# Open serial console to Flipper
flipper_console() {
    echo -e "${CYAN}[*] Opening serial console to Flipper (Ctrl+A, then X to exit)${NC}"
    screen "$FLIPPER_DEV" 230400
}

# Sync scripts to Flipper
flipper_sync() {
    echo -e "${CYAN}[*] Syncing scripts to Flipper...${NC}"
    
    # Sync BadUSB scripts
    if [ -d "$SCRIPTS_DIR/badusb" ]; then
        for script in "$SCRIPTS_DIR/badusb"/*.txt; do
            if [ -f "$script" ]; then
                name=$(basename "$script")
                flipper_upload "$script" "/ext/badusb/$name"
            fi
        done
    fi
    
    echo -e "${GREEN}[+] Sync complete!${NC}"
}

# Create a BadUSB payload
flipper_create_badusb() {
    echo -e "${CYAN}[*] BadUSB Payload Creator${NC}"
    read -p "Payload name: " name
    
    cat > "$SCRIPTS_DIR/badusb/${name}.txt" << 'PAYLOAD'
REM BadUSB Payload - bad-antics
REM Modify this template for your needs

DELAY 1000
GUI r
DELAY 500
STRING cmd
ENTER
DELAY 500
STRING echo Hello from Flipper Zero!
ENTER
DELAY 500
STRING exit
ENTER
PAYLOAD

    echo -e "${GREEN}[+] Created: $SCRIPTS_DIR/badusb/${name}.txt${NC}"
    echo -e "${YELLOW}Edit the file and use flipper_sync to upload${NC}"
}

# Help menu
flipper_help() {
    banner
    echo -e "${GREEN}Available Commands:${NC}"
    echo -e "  ${YELLOW}flipper_check${NC}           - Check if Flipper is connected"
    echo -e "  ${YELLOW}flipper_info${NC}            - Get device info"
    echo -e "  ${YELLOW}flipper_console${NC}         - Open serial console"
    echo -e "  ${YELLOW}flipper_cmd${NC}             - Send raw command"
    echo -e "  ${YELLOW}flipper_ls${NC}              - List storage contents"
    echo -e "  ${YELLOW}flipper_upload${NC}          - Upload file to Flipper"
    echo -e "  ${YELLOW}flipper_download${NC}        - Download file from Flipper"
    echo -e "  ${YELLOW}flipper_sync${NC}            - Sync local scripts to Flipper"
    echo -e "  ${YELLOW}flipper_clone_badusb${NC}    - Clone BadUSB payload repos"
    echo -e "  ${YELLOW}flipper_clone_subghz${NC}    - Clone SubGHz/IR repos"
    echo -e "  ${YELLOW}flipper_create_badusb${NC}   - Create new BadUSB payload"
    echo -e "  ${YELLOW}flipper_update_firmware${NC} - Download/clone firmware"
    echo -e "  ${YELLOW}flipper_flash${NC}           - Flash firmware via DFU"
    echo -e "  ${YELLOW}flipper_help${NC}            - Show this help menu"
    echo ""
    echo -e "${CYAN}Directories:${NC}"
    echo -e "  Scripts: $SCRIPTS_DIR"
    echo -e "  Firmware: $FIRMWARE_DIR"
    echo ""
}

# Auto-run on source (but only once per session)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Prevent duplicate banner display on SSH or nested shells
    if [[ -z "$FLIPPER_CLI_LOADED" ]]; then
        export FLIPPER_CLI_LOADED=1
        flipper_init
        banner
        echo -e "${GREEN}[+] Flipper CLI loaded! Type 'flipper_help' for commands.${NC}"
        flipper_check
    fi
