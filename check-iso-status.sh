#!/bin/bash
# Quick ISO status checker

echo "═══════════════════════════════════════════════════════════════════"
echo "  NullSec Linux ISO Build Status"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check if process is running
if ps aux | grep -v grep | grep -q "create-nullsec-iso"; then
    echo "✓ ISO build is RUNNING"
    echo ""
    echo "Working directory size:"
    du -sh /home/antics/nullsec-iso/work/ 2>/dev/null || echo "  Not yet created"
    echo ""
    echo "Monitor live: screen -r iso-build"
else
    echo "○ ISO build process not detected"
    echo ""
fi

# Check if ISO exists
if [ -f /home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso ]; then
    echo "✅ ISO COMPLETE!"
    echo ""
    ISO_SIZE=$(ls -lh /home/antics/nullsec-iso/nullsec-linux-1.0-amd64.iso | awk '{print $5}')
    echo "  File: nullsec-linux-1.0-amd64.iso"
    echo "  Size: $ISO_SIZE"
    echo ""
    echo "Next step:"
    echo "  sudo bash ~/nullsec/copy-iso-to-lulzboat.sh"
else
    echo "⏳ ISO not yet created"
    echo ""
    echo "Check progress:"
    echo "  watch -n 5 'bash ~/nullsec/check-iso-status.sh'"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
