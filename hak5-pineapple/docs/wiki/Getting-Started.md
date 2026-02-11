# Getting Started

## Prerequisites

- WiFi Pineapple (Mark VII or Nano/Tetra)
- Ethernet cable or WiFi connection
- Computer with SSH client

## Connecting

### Method 1: Ethernet
```bash
# Connect Pineapple via USB/Ethernet
# Default IP: 172.16.42.1
ssh root@172.16.42.1
```

### Method 2: WiFi
```bash
# Connect to Pineapple's management AP
# SSID: Pineapple_XXXX
# Then SSH
ssh root@172.16.42.1
```

### Method 3: NullSec Quick Connect
```bash
git clone https://github.com/bad-antics/nullsec
cd nullsec
./connect-pineapple.sh
```

## Installing Payloads

### Quick Upload (All Payloads)
```bash
./upload-payloads.sh
```

### Individual Payload
```bash
scp -r nullsec-suite/DeauthStorm/ root@172.16.42.1:/root/payloads/
```

### Via Web Interface
1. Open `http://172.16.42.1:1471` in browser
2. Navigate to Payloads
3. Upload individual payload folders

## First Payload Run

```bash
# SSH into Pineapple
ssh root@172.16.42.1

# Run a scan
cd /root/payloads/QuickScan
./payload.sh
```
