# Hak5 Pineapple Toolkit Installation

## Clone
```bash
git clone https://github.com/bad-antics/nullsec
cd nullsec
```

## Connect to Pineapple
```bash
./connect-pineapple.sh
# Or manually: ssh root@172.16.42.1
```

## Upload All Payloads
```bash
./upload-payloads.sh
# Uploads all 96+ payloads to /root/payloads/
```

## Upload Specific Payload
```bash
./quick-upload.sh nullsec-suite/DeauthStorm
```

## Dual Network Setup
```bash
./dual-network.sh
# Configures internet sharing to Pineapple
```

## Custom Firmware
```bash
cd nullsec-firmware
./build-firmware.sh
# Builds custom firmware with NullSec tools pre-installed
```

## Toolkit Scripts

| Script | Purpose |
|--------|---------|
| `connect-pineapple.sh` | SSH connection helper |
| `upload-payloads.sh` | Bulk payload upload |
| `quick-upload.sh` | Single payload upload |
| `dual-network.sh` | Internet sharing setup |
| `build-firmware.sh` | Custom firmware builder |
| `pineapple-c2.sh` | Cloud C2 integration |
| `hak5-toolkit.sh` | Master toolkit menu |
| `pineapple-quick.sh` | Quick operations menu |
| `download-packages.sh` | Package downloader |
| `nullsec-connect.sh` | NullSec framework connect |
