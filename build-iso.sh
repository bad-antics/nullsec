#!/bin/bash
#
# NullSec Linux - Build Fresh ISO with All v2.0 Enhancements
# Run this script to create the ISO in the background
#

echo "===="
echo "|          Building NullSec Linux ISO with All Enhancements             |"
echo "===="
echo ""
echo "This will:"
echo "  • Create a fresh NullSec Linux 1.0 ISO"
echo "  • Include all 188 modules"
echo "  • Include desktop menu integration"
echo "  • Include resource library"
echo "  • Include log encryption system"
echo ""
echo "Time required: 30-60 minutes"
echo "Disk space required: ~20GB"
echo ""

# Kill any existing stopped process
sudo pkill -9 -f create-nullsec-iso 2>/dev/null

cd ~/nullsec

# Run in screen session for resilience
if command -v screen &> /dev/null; then
    echo "Starting ISO build in screen session..."
    echo "To monitor: screen -r iso-build"
    screen -dmS iso-build bash -c "echo 'yes' | sudo bash create-nullsec-iso.sh; echo 'ISO BUILD COMPLETE!' ; read"
    echo ""
    echo "✓ ISO build started in background (screen session: iso-build)"
    echo ""
    echo "Monitor with:"
    echo "  screen -r iso-build"
    echo ""
    echo "Or check progress:"
    echo "  watch -n 5 'du -sh /home/antics/nullsec-iso/work/'"
else
    # Fallback without screen
    echo "Starting ISO build..."
    nohup bash -c "echo 'yes' | sudo bash create-nullsec-iso.sh > ~/nullsec/iso-build.log 2>&1" &
    echo ""
    echo "✓ ISO build started in background"
    echo ""
    echo "Monitor with:"
    echo "  tail -f ~/nullsec/iso-build.log"
fi

echo ""
echo "When complete, the ISO will be at:"
echo "  /home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso"
echo ""
echo "Then run:"
echo "  sudo bash ~/nullsec/copy-iso-to-lulzboat.sh"
echo ""
