#!/bin/bash
#===============================================================================
#  NullSec Network Sharing Setup
#  Configures Samba, Avahi, and mDNS for full network discovery and file sharing
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           NullSec Network Sharing Setup                    ║"
    echo "║     Samba • Avahi • mDNS • Full Network Discovery          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Get the actual user (not root when using sudo)
get_real_user() {
    if [[ -n "$SUDO_USER" ]]; then
        REAL_USER="$SUDO_USER"
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        REAL_USER="$USER"
        REAL_HOME="$HOME"
    fi
    print_info "Configuring for user: $REAL_USER"
}

# Install required packages
install_packages() {
    print_info "Installing required packages..."
    apt-get update -qq
    apt-get install -y -qq samba samba-common avahi-daemon avahi-utils nfs-common wsdd 2>/dev/null || true
    print_status "Packages installed"
}

# Create share directories
create_directories() {
    print_info "Creating share directories..."
    
    # Public share
    mkdir -p "$REAL_HOME/Public"
    chmod 777 "$REAL_HOME/Public"
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/Public"
    
    # Downloads share
    mkdir -p "$REAL_HOME/Downloads"
    chmod 755 "$REAL_HOME/Downloads"
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/Downloads"
    
    print_status "Directories created"
}

# Configure Samba
configure_samba() {
    print_info "Configuring Samba..."
    
    # Backup existing config
    [[ -f /etc/samba/smb.conf ]] && cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
    
    cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = WORKGROUP
   server string = NullSec File Server
   netbios name = NULLSEC
   
   # Network discovery - be the master browser
   wins support = yes
   local master = yes
   preferred master = yes
   os level = 65
   name resolve order = bcast host lmhosts wins
   
   # Security - allow guest for public shares
   security = user
   map to guest = Bad User
   guest account = nobody
   
   # Protocol compatibility (wide range for all devices)
   client min protocol = NT1
   server min protocol = NT1
   ntlm auth = yes
   
   # macOS/iOS compatibility
   min protocol = SMB2
   vfs objects = fruit streams_xattr
   fruit:metadata = stream
   fruit:model = MacSamba
   fruit:posix_rename = yes
   fruit:veto_appledouble = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes
   
   # Performance
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
   read raw = yes
   write raw = yes
   use sendfile = yes
   aio read size = 16384
   aio write size = 16384
   
   # Logging
   log file = /var/log/samba/log.%m
   max log size = 1000
   log level = 1

# ===== SHARES =====

# Public share - anyone can read/write (no password)
[Public]
   comment = Public Files - No Password Required
   path = $REAL_HOME/Public
   browseable = yes
   writable = yes
   guest ok = yes
   public = yes
   create mask = 0775
   directory mask = 0775
   force user = $REAL_USER

# Downloads folder
[Downloads]
   comment = Downloads Folder
   path = $REAL_HOME/Downloads
   browseable = yes
   writable = yes
   guest ok = yes
   public = yes
   create mask = 0775
   directory mask = 0775
   force user = $REAL_USER

# User home directory (password protected)
[Home]
   comment = $REAL_USER Home Directory
   path = $REAL_HOME
   browseable = yes
   writable = yes
   valid users = $REAL_USER
   create mask = 0700
   directory mask = 0700

# NullSec project share (password protected)
[NullSec]
   comment = NullSec Project Files
   path = $REAL_HOME/nullsec
   browseable = yes
   writable = yes
   valid users = $REAL_USER
   create mask = 0755
   directory mask = 0755
EOF

    print_status "Samba configured"
}

# Configure Avahi for mDNS/Bonjour discovery
configure_avahi() {
    print_info "Configuring Avahi (mDNS/Bonjour)..."
    
    # Main Avahi config
    cat > /etc/avahi/avahi-daemon.conf << 'EOF'
[server]
host-name=nullsec
domain-name=local
use-ipv4=yes
use-ipv6=yes
allow-interfaces=eth0,wlan0,enp0s3,ens33
enable-dbus=yes
disallow-other-stacks=yes

[wide-area]
enable-wide-area=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes
publish-aaaa-on-ipv4=yes
publish-a-on-ipv6=no

[reflector]
enable-reflector=no

[rlimits]
EOF

    # Advertise Samba/SMB service
    cat > /etc/avahi/services/smb.service << 'EOF'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h - Samba/CIFS</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
</service-group>
EOF

    # Advertise AFP for older Macs
    cat > /etc/avahi/services/afp.service << 'EOF'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h - AFP</name>
  <service>
    <type>_afpovertcp._tcp</type>
    <port>548</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=Xserve</txt-record>
  </service>
</service-group>
EOF

    # Advertise SSH
    cat > /etc/avahi/services/ssh.service << 'EOF'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h - SSH</name>
  <service>
    <type>_ssh._tcp</type>
    <port>22</port>
  </service>
</service-group>
EOF

    # Advertise SFTP
    cat > /etc/avahi/services/sftp.service << 'EOF'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h - SFTP</name>
  <service>
    <type>_sftp-ssh._tcp</type>
    <port>22</port>
  </service>
</service-group>
EOF

    print_status "Avahi configured"
}

# Configure WSDD for Windows 10+ discovery
configure_wsdd() {
    print_info "Configuring WSDD (Windows Discovery)..."
    
    # Create systemd service if wsdd is installed
    if command -v wsdd &> /dev/null; then
        cat > /etc/systemd/system/wsdd.service << 'EOF'
[Unit]
Description=Web Services Dynamic Discovery host daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/wsdd -n NULLSEC -w WORKGROUP
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        print_status "WSDD configured"
    else
        print_warning "WSDD not installed - Windows 10+ discovery may be limited"
    fi
}

# Configure firewall
configure_firewall() {
    print_info "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw allow samba 2>/dev/null || true
        ufw allow 5353/udp comment 'mDNS' 2>/dev/null || true
        ufw allow 3702/udp comment 'WSDD' 2>/dev/null || true
        ufw allow ssh 2>/dev/null || true
        print_status "Firewall rules added"
    else
        print_warning "UFW not found - manually open ports 139, 445, 5353, 3702"
    fi
}

# Start services
start_services() {
    print_info "Starting services..."
    
    # Enable and start Samba
    systemctl enable smbd nmbd 2>/dev/null
    systemctl restart smbd nmbd
    print_status "Samba started"
    
    # Enable and start Avahi
    systemctl enable avahi-daemon 2>/dev/null
    systemctl restart avahi-daemon
    print_status "Avahi started"
    
    # Enable and start WSDD if available
    if [[ -f /etc/systemd/system/wsdd.service ]]; then
        systemctl enable wsdd 2>/dev/null
        systemctl restart wsdd 2>/dev/null || true
        print_status "WSDD started"
    fi
}

# Set Samba password
set_samba_password() {
    print_info "Setting Samba password for $REAL_USER..."
    echo -e "${YELLOW}"
    echo "You'll need to set a password for network access to protected shares."
    echo "This can be different from your login password."
    echo -e "${NC}"
    smbpasswd -a "$REAL_USER"
    print_status "Samba password set"
}

# Show connection info
show_info() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    Setup Complete!                         ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Your machine is now discoverable as:${NC}"
    echo "  • Hostname:  nullsec / nullsec.local"
    echo "  • IP:        $IP"
    echo ""
    echo -e "${CYAN}Connect from other devices:${NC}"
    echo ""
    echo "  ${YELLOW}Windows:${NC}"
    echo "    File Explorer → \\\\nullsec or \\\\$IP"
    echo ""
    echo "  ${YELLOW}macOS:${NC}"
    echo "    Finder → Go → Connect to Server"
    echo "    smb://nullsec.local or smb://$IP"
    echo ""
    echo "  ${YELLOW}Linux:${NC}"
    echo "    File Manager → smb://nullsec.local or smb://$IP"
    echo "    Terminal: smbclient -L //$IP -U guest"
    echo ""
    echo "  ${YELLOW}iOS/Android:${NC}"
    echo "    Use any SMB file manager app"
    echo "    Server: nullsec.local or $IP"
    echo ""
    echo -e "${CYAN}Available Shares:${NC}"
    echo "  • Public     - No password (guest access)"
    echo "  • Downloads  - No password (guest access)"
    echo "  • Home       - Password required"
    echo "  • NullSec    - Password required"
    echo ""
    echo -e "${CYAN}Discover network devices from this machine:${NC}"
    echo "  avahi-browse -art           # All services"
    echo "  avahi-browse _smb._tcp      # SMB/Samba shares"
    echo "  smbclient -L //hostname -N  # List shares on host"
    echo ""
}

# Scan for other devices
scan_network() {
    echo -e "${CYAN}Scanning for network devices...${NC}"
    echo ""
    
    # mDNS scan
    echo -e "${YELLOW}=== mDNS/Bonjour Devices ===${NC}"
    timeout 5 avahi-browse -apt 2>/dev/null | head -20 || echo "  (scanning...)"
    
    echo ""
    echo -e "${YELLOW}=== SMB/CIFS Shares ===${NC}"
    timeout 5 avahi-browse -apt 2>/dev/null | grep -i smb | head -10 || echo "  (none found yet)"
    
    echo ""
}

# Main
main() {
    print_banner
    check_root
    get_real_user
    
    echo ""
    echo -e "${YELLOW}This script will:${NC}"
    echo "  1. Install Samba, Avahi, and WSDD"
    echo "  2. Create Public and Downloads shares"
    echo "  3. Configure network discovery (mDNS, NetBIOS, WSDD)"
    echo "  4. Set up firewall rules"
    echo "  5. Set a Samba password for protected shares"
    echo ""
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        install_packages
        create_directories
        configure_samba
        configure_avahi
        configure_wsdd
        configure_firewall
        start_services
        set_samba_password
        show_info
        
        read -p "Scan for other network devices? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            scan_network
        fi
    else
        print_warning "Setup cancelled"
    fi
}

main "$@"
