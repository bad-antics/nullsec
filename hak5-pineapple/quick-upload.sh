#!/bin/bash
# Quick payload upload for NullSec Pineapple Suite
# Run this when Pineapple is connected

PINEAPPLE_IP="${1:-172.16.42.1}"

echo "Uploading to $PINEAPPLE_IP..."

# Create directories
ssh root@$PINEAPPLE_IP "mkdir -p /root/payloads/user/nullsec /mmc/nullsec/lib" 2>/dev/null

# Upload all payloads
scp payloads/*_payload.sh root@$PINEAPPLE_IP:/root/payloads/user/nullsec/

# Upload libraries
scp lib/*.sh root@$PINEAPPLE_IP:/mmc/nullsec/lib/

# Set permissions
ssh root@$PINEAPPLE_IP "chmod +x /root/payloads/user/nullsec/*.sh /mmc/nullsec/lib/*.sh"

echo "Done! Check Payloads → User → nullsec on your Pager"
