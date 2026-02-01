#!/bin/bash
#
# Copy NullSec Linux ISO to "The Lulz Boat" USB Drive
#

set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISO_FILE="/home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso"
USB_DEVICE="/dev/sda2"  # The Lulz Boat partition
MOUNT_POINT="/tmp/lulzboat-mount"

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Copy ISO to The Lulz Boat USB Drive${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if ISO exists
if [ ! -f "$ISO_FILE" ]; then
    echo -e "${RED}[!] ISO file not found: $ISO_FILE${NC}"
    echo -e "${YELLOW}[*] Please wait for ISO creation to complete first${NC}"
    exit 1
fi

ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
echo -e "${GREEN}[+] Found ISO: $ISO_FILE ($ISO_SIZE)${NC}"

# Check if USB device exists
if [ ! -b "$USB_DEVICE" ]; then
    echo -e "${RED}[!] USB device not found: $USB_DEVICE${NC}"
    echo -e "${YELLOW}[*] Available devices:${NC}"
    lsblk -o NAME,SIZE,LABEL,TYPE,MOUNTPOINT
    exit 1
fi

echo -e "${GREEN}[+] Found USB: The Lulz Boat${NC}"

# Create mount point
sudo mkdir -p "$MOUNT_POINT"

# Check if already mounted
if mount | grep -q "$USB_DEVICE"; then
    echo -e "${CYAN}[*] USB already mounted${NC}"
    USB_MOUNT=$(mount | grep "$USB_DEVICE" | awk '{print $3}')
else
    # Mount the USB
    echo -e "${CYAN}[*] Mounting USB...${NC}"
    sudo mount "$USB_DEVICE" "$MOUNT_POINT"
    USB_MOUNT="$MOUNT_POINT"
fi

echo -e "${GREEN}[+] USB mounted at: $USB_MOUNT${NC}"

# Check free space
FREE_SPACE=$(df -BG "$USB_MOUNT" | awk 'NR==2 {print $4}' | sed 's/G//')
ISO_SIZE_GB=$(du -BG "$ISO_FILE" | cut -f1 | sed 's/G//')

echo -e "${CYAN}[*] USB free space: ${FREE_SPACE}GB${NC}"
echo -e "${CYAN}[*] ISO size: ${ISO_SIZE_GB}GB${NC}"

if [ "$FREE_SPACE" -lt "$ISO_SIZE_GB" ]; then
    echo -e "${RED}[!] Insufficient space on USB${NC}"
    sudo umount "$MOUNT_POINT" 2>/dev/null || true
    exit 1
fi

# Copy ISO
echo -e "${CYAN}[*] Copying ISO to USB (this may take several minutes)...${NC}"
sudo rsync -avh --progress "$ISO_FILE" "$USB_MOUNT/nullsec-linux-1.0-amd64.iso"

# Create info file
echo -e "${CYAN}[*] Creating info file...${NC}"
sudo tee "$USB_MOUNT/NULLSEC_ISO_INFO.txt" > /dev/null << EOF
NullSec Linux 1.0 ISO Information
==================================

ISO File: nullsec-linux-1.0-amd64.iso
Version: 1.0 (void)
Build Date: $(date)
Size: $ISO_SIZE

Contents:
- NullSec Framework v2.0 (188 modules)
- NULLSEC AI v3.0 (12 AI models)
- Enhanced Module Browser
- Desktop Menu Integration (⚡ NullSec Tools)
- Resource Library (wordlists, scripts, payloads)
- Log Encryption System (AES-256)
- All v2.0 enhancements included

Installation:
1. Write ISO to USB using Rufus (Windows) or dd (Linux)
2. Boot from USB
3. Select "Live Mode" for testing or "Install" for permanent installation

Credentials (Live Mode):
Username: antics
Password: [as configured]

For more information, see TESTER_GUIDE.md

Built: $(date)
EOF

# Sync and unmount
echo -e "${CYAN}[*] Syncing data...${NC}"
sudo sync

if [ "$USB_MOUNT" = "$MOUNT_POINT" ]; then
    echo -e "${CYAN}[*] Unmounting USB...${NC}"
    sudo umount "$MOUNT_POINT"
    sudo rmdir "$MOUNT_POINT"
fi

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ ISO Successfully Copied to The Lulz Boat!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Location: The Lulz Boat USB Drive${NC}"
echo -e "${CYAN}File: nullsec-linux-1.0-amd64.iso ($ISO_SIZE)${NC}"
echo ""
echo -e "${YELLOW}The USB can now be safely ejected.${NC}"
echo ""
