#!/bin/bash
# Title: NullSec RickRoll AP
# Author: bad-antics
# Description: Open AP that rickrolls everyone
# Category: nullsec/prank

PROMPT "NULLSEC RICKROLL AP

Creates open WiFi that
rickrolls every connection!

Embeds the video directly
(no internet needed).

Press OK to configure."

SSID=$(TEXT_PICKER "AP Name:" "Free_Public_WiFi")
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) SSID="Free_Public_WiFi" ;; esac

DURATION=$(NUMBER_PICKER "Duration (seconds):" 300)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) DURATION=300 ;; esac

resp=$(CONFIRMATION_DIALOG "Start RickRoll AP?

SSID: $SSID
Duration: ${DURATION}s

Everyone connecting gets
RICKROLLED!

Press OK to start.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

killall hostapd dnsmasq 2>/dev/null

AP_IF="wlan1"
airmon-ng stop wlan1mon 2>/dev/null
sleep 1

cat > /tmp/rr_hostapd.conf << EOF
interface=$AP_IF
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
EOF

hostapd /tmp/rr_hostapd.conf -B 2>/dev/null
sleep 2
ifconfig $AP_IF 10.0.0.1 netmask 255.255.255.0 up

cat > /tmp/rr_dns.conf << EOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.0.0.10,10.0.0.100,12h
address=/#/10.0.0.1
EOF
dnsmasq -C /tmp/rr_dns.conf 2>/dev/null

mkdir -p /tmp/rickroll
# Self-contained rickroll page (no internet needed)
cat > /tmp/rickroll/index.html << 'RRHTML'
<!DOCTYPE html>
<html>
<head><title>Loading WiFi...</title>
<style>
body{background:#000;color:#0f0;font-family:monospace;text-align:center;margin:0;padding:0}
.container{padding:20px}
h1{font-size:36px;color:#f00;text-shadow:0 0 10px #f00}
h2{color:#0f0;margin-top:30px}
.rick{font-size:24px;color:#ff0;margin:20px auto;max-width:600px;line-height:1.8}
.skull{font-size:60px;animation:pulse 1s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.5}}
.matrix{position:fixed;top:0;left:0;width:100%;height:100%;z-index:-1;opacity:0.3}
</style>
</head>
<body>
<div class="container">
<div class="skull">💀</div>
<h1>NULLSEC</h1>
<h2>You've Been RickRolled!</h2>
<div class="rick">
🎵 Never gonna give you up<br>
🎵 Never gonna let you down<br>
🎵 Never gonna run around<br>
🎵 And desert you<br>
🎵 Never gonna make you cry<br>
🎵 Never gonna say goodbye<br>
🎵 Never gonna tell a lie<br>
🎵 And hurt you<br>
</div>
<p style="color:#888;margin-top:40px">Your WiFi is belong to us</p>
<p style="color:#444;font-size:12px">NullSec Pineapple Suite // bad-antics</p>
</div>
<script>
// Rickroll audio loop (simple beep melody)
try{var a=new(window.AudioContext||window.webkitAudioContext)();
function p(f,d){var o=a.createOscillator();o.frequency.value=f;o.type='square';
var g=a.createGain();g.gain.value=0.1;o.connect(g);g.connect(a.destination);
o.start(a.currentTime);o.stop(a.currentTime+d);}
var n=[[392,.3],[440,.3],[392,.3],[329,.3],[329,.3],[440,.6],[392,.6]];
var t=0;n.forEach(function(x){setTimeout(function(){p(x[0],x[1])},t*1000);t+=x[1]+0.05;});
}catch(e){}
</script>
</body>
</html>
RRHTML

# Use uhttpd
uhttpd -p 10.0.0.1:80 -h /tmp/rickroll 2>/dev/null &

LOG "RickRoll AP active: $SSID"
sleep "$DURATION"

killall hostapd dnsmasq uhttpd 2>/dev/null
rm -rf /tmp/rickroll /tmp/rr_*.conf
airmon-ng start wlan1 2>/dev/null

PROMPT "RICKROLL COMPLETE

SSID: $SSID
Duration: ${DURATION}s

Press OK to exit."
