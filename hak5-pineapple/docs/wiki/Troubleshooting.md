# Troubleshooting

## Connection Issues

### Can't connect via SSH
- Check USB cable (data capable, not charge-only)
- Verify IP: `ip addr show` — look for 172.16.42.x
- Try `172.16.42.1` or `192.168.1.1`
- Reset Pineapple (hold reset button 10 seconds)
- Use `./connect-pineapple.sh` for auto-configuration

### Web interface not loading
- Try `http://172.16.42.1:1471`
- Clear browser cache
- Try different browser (some have strict HTTPS policies)
- Check firewall rules on your machine

## Payload Issues

### Payload won't execute
```bash
# Check permissions
chmod +x /root/payloads/MyPayload/payload.sh

# Check dependencies
opkg update && opkg install <missing-package>

# Check logs
cat /tmp/payload.log

# Run manually for debug output
bash -x /root/payloads/MyPayload/payload.sh
```

### Monitor mode fails
```bash
# Check interface support
iw phy | grep -A 5 "monitor"

# Kill conflicting processes
airmon-ng check kill

# Enable monitor mode
airmon-ng start wlan1

# Verify
iwconfig wlan1mon
```

### Deauth not working
- Ensure monitor mode is active
- Check you're on the correct channel
- Verify target MAC address
- Some clients ignore deauth frames (802.11w protected)

## Storage Issues

### SD card not detected
- Format as ext4 (not FAT32)
- Check with `fdisk -l`
- Try different SD card (some brands incompatible)

### Out of space
```bash
# Check space
df -h

# Clean up
rm -rf /tmp/logs/*
rm -rf /root/loot/old-*
opkg remove --autoremove <unused-package>
```

## Firmware Issues

### Firmware update fails
- Use Ethernet connection (not WiFi)
- Ensure stable power supply
- Don't interrupt the process
- Factory reset if bricked: hold reset during power-on for 10+ seconds

### Custom firmware not booting
- Verify checksum of firmware image
- Try reflashing with original Hak5 firmware first
- Check serial console output for boot errors
