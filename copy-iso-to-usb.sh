#!/bin/bash
# Auto-copy NullSec ISO to USB when ready

ISO_FILE="/home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso"
USB_PATH="/mnt/lulzboat"
USB_ISO_PATH="$USB_PATH/nullsec-linux-1.0-amd64.iso"

echo "[*] Waiting for ISO creation to complete..."
echo "[*] ISO file: $ISO_FILE"
echo "[*] Destination: $USB_ISO_PATH"
echo ""

# Wait for ISO to exist
while [ ! -f "$ISO_FILE" ]; do
    echo -n "."
    sleep 10
done

echo ""
echo "[+] ISO file found! Starting copy..."

# Check if USB is mounted
if ! mountpoint -q "$USB_PATH"; then
    echo "[!] USB drive not mounted at $USB_PATH"
    echo "[*] Mounting USB drive..."
    sudo mkdir -p "$USB_PATH"
    sudo mount /dev/sda2 "$USB_PATH"
fi

# Copy with progress
rsync -ah --progress "$ISO_FILE" "$USB_ISO_PATH"

if [ $? -eq 0 ]; then
    ISO_SIZE=$(ls -lh "$ISO_FILE" | awk '{print $5}')
    echo ""
    echo "✓ ISO successfully copied to USB!"
    echo "  File: $USB_ISO_PATH"
    echo "  Size: $ISO_SIZE"
    echo ""
    echo "[*] Verifying copy..."
    SRC_MD5=$(md5sum "$ISO_FILE" | awk '{print $1}')
    DST_MD5=$(md5sum "$USB_ISO_PATH" | awk '{print $1}')
    
    if [ "$SRC_MD5" = "$DST_MD5" ]; then
        echo "✓ MD5 checksums match - copy verified!"
        echo "  MD5: $SRC_MD5"
    else
        echo "✗ MD5 checksum mismatch!"
        echo "  Source: $SRC_MD5"
        echo "  Dest:   $DST_MD5"
        exit 1
    fi
else
    echo "✗ Copy failed!"
    exit 1
fi
