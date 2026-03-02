---
name: nullsec-recon
description: Network reconnaissance and OSINT skill for security assessments. Use when you need to discover hosts, enumerate services, map attack surfaces, or gather open-source intelligence on targets. Provides automated scanning workflows, passive and active recon techniques, and result analysis patterns.
metadata: {"openclaw":{"emoji":"🔍","requires":{"anyBins":["nmap","amass","subfinder","theHarvester","whois"]},"os":["linux","darwin"],"primaryEnv":"","install":[]}}
---

# NullSec Recon — Network Reconnaissance & OSINT

Comprehensive reconnaissance skill covering passive OSINT, active scanning, subdomain enumeration, and attack surface mapping. Built for speed and thoroughness.

## When to Use

- Starting reconnaissance on a new target
- Need to discover all subdomains for a domain
- Mapping network infrastructure and services
- Gathering OSINT before an engagement
- Need to identify the technology stack of a target
- Building an attack surface inventory

## Quick Reference

| Technique | Tool | Speed |
|-----------|------|-------|
| Subdomain enum | amass, subfinder | 5-15 min |
| Port scan (fast) | nmap -T4 --top-ports 1000 | 2-5 min |
| Port scan (full) | nmap -p- -T4 | 15-45 min |
| Web tech detect | whatweb, wappalyzer | 1-2 min |
| OSINT harvest | theHarvester | 5-10 min |
| DNS recon | dig, dnsrecon | 2-5 min |
| Cert transparency | crt.sh API | 1 min |

---

## Passive Reconnaissance

### Domain Intelligence
```bash
# WHOIS — registration, nameservers, contacts
whois example.com

# DNS records — full enumeration
dig example.com ANY +noall +answer
dig example.com MX +short
dig example.com NS +short
dig example.com TXT +short
dig example.com SOA +short

# Reverse DNS
dig -x 93.184.216.34

# DNS zone transfer attempt
dig axfr @ns1.example.com example.com

# DNSRecon comprehensive
dnsrecon -d example.com -t std,brt,axfr
```

### Subdomain Enumeration
```bash
# Amass — passive enum (best coverage)
amass enum -passive -d example.com -o amass-subs.txt

# Subfinder — fast passive enum
subfinder -d example.com -all -o subfinder-subs.txt

# Certificate Transparency logs
curl -s "https://crt.sh/?q=%.example.com&output=json" | \
  jq -r '.[].name_value' | sort -u > crt-subs.txt

# Merge and deduplicate
cat amass-subs.txt subfinder-subs.txt crt-subs.txt | sort -u > all-subs.txt
echo "[*] Total unique subdomains: $(wc -l < all-subs.txt)"

# Resolve live hosts
cat all-subs.txt | httpx -silent -status-code -title -tech-detect -o live-subs.txt
```

### OSINT Harvesting
```bash
# theHarvester — emails, subdomains, IPs
theHarvester -d example.com -b all -f harvest-report

# Google dorking patterns
# site:example.com filetype:pdf
# site:example.com filetype:xlsx
# site:example.com filetype:doc
# site:example.com inurl:admin
# site:example.com inurl:login
# site:example.com intitle:"index of"
# site:example.com ext:sql | ext:db | ext:log
# "example.com" password | secret | credential

# Wayback Machine — historical URLs
waybackurls example.com | sort -u > wayback-urls.txt
cat wayback-urls.txt | grep -E "\.(js|json|xml|config|env|bak|sql)" > interesting-urls.txt

# GitHub dorking
# org:example "password"
# org:example "api_key"
# org:example "secret"
# org:example filename:.env
```

### Technology Detection
```bash
# WhatWeb — web technology fingerprint
whatweb -v example.com

# Wappalyzer CLI
wappalyzer https://example.com

# HTTP headers analysis
curl -sI https://example.com | head -30

# robots.txt and sitemap
curl -s https://example.com/robots.txt
curl -s https://example.com/sitemap.xml | head -50
```

---

## Active Reconnaissance

### Host Discovery
```bash
# Ping sweep
nmap -sn 192.168.1.0/24 -oG - | grep "Up" | awk '{print $2}' > alive.txt

# ARP scan (local network)
arp-scan --localnet

# Multi-protocol discovery
nmap -sn -PE -PP -PM -PS21,22,23,25,80,443,445,3389 -PU53,161 192.168.1.0/24
```

### Port Scanning Strategies
```bash
# Quick scan — top 1000 ports with scripts
nmap -sC -sV -T4 -oA quick-scan TARGET

# Full TCP — all 65535 ports
nmap -p- -T4 --min-rate 1000 -oA full-tcp TARGET

# Full TCP with service detection on found ports
PORTS=$(grep -oP '\d+/open' full-tcp.gnmap | cut -d/ -f1 | tr '\n' ',')
nmap -sC -sV -p "$PORTS" -oA detailed TARGET

# UDP — top 100
sudo nmap -sU --top-ports 100 -T4 -oA udp-scan TARGET

# Stealth scan
nmap -sS -T2 -f --data-length 24 -oA stealth TARGET

# Version-intensive scan
nmap -sV --version-intensity 5 -p- TARGET
```

### Web Enumeration
```bash
# Directory brute-force
gobuster dir -u http://TARGET -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
  -x php,asp,aspx,jsp,html,txt -t 50 -o dirs.txt

# Virtual host enumeration
gobuster vhost -u http://TARGET -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt

# API endpoint discovery
ffuf -u http://TARGET/api/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt \
  -mc 200,201,301,302,403 -o api-endpoints.json

# Parameter discovery
arjun -u http://TARGET/page -o params.json
```

---

## Result Analysis

### Quick Wins to Look For
1. **Anonymous FTP** (port 21) — check for file upload
2. **Open SMB shares** (port 445) — `smbclient -L //target -N`
3. **Default credentials** — admin:admin, root:root, admin:password
4. **Outdated software** — check versions against CVE databases
5. **Directory listings** — `/icons/`, `/uploads/`, `/backup/`
6. **Exposed admin panels** — `/admin`, `/wp-admin`, `/manager`
7. **Information disclosure** — server headers, error pages, debug modes
8. **Self-signed/expired SSL** — weak crypto, missing HSTS

### Priority Ports
| Port | Service | Action |
|------|---------|--------|
| 21 | FTP | Check anonymous login |
| 22 | SSH | Banner grab, version check |
| 23 | Telnet | Default creds, sniff traffic |
| 25 | SMTP | Open relay test |
| 53 | DNS | Zone transfer attempt |
| 80/443 | HTTP/S | Full web scan |
| 110/143 | POP3/IMAP | Default creds |
| 135 | MSRPC | Enumerate endpoints |
| 139/445 | SMB | Share enum, EternalBlue |
| 161 | SNMP | Community string brute |
| 389/636 | LDAP | Anonymous bind |
| 1433 | MSSQL | Default SA account |
| 3306 | MySQL | Remote root login |
| 3389 | RDP | BlueKeep, brute force |
| 5432 | PostgreSQL | Default postgres user |
| 5900 | VNC | Auth bypass, weak password |
| 6379 | Redis | No-auth access |
| 8080 | HTTP alt | Web app, proxy |
| 27017 | MongoDB | No-auth access |

---

## Automation Script

The bundled `nullsec-recon.sh` script automates the full recon workflow:

```bash
./scripts/nullsec-recon.sh example.com
# Runs: subdomain enum → host discovery → port scan → service detection → web enum
# Output: recon-example.com/ directory with all results
```

---

## Tips

- Start passive, go active — minimize detection
- Always save raw output (`-oA` for nmap, `-o` for others)
- Cross-reference results between tools for completeness
- Check both HTTP and HTTPS — different content is common
- Don't forget UDP — SNMP, DNS, and TFTP are gold
- Time your scans — full port scans can take 30+ minutes
- Use `tmux` or `screen` for long-running scans

## NullSec Resources

- **690+ repos** at [github.com/bad-antics](https://github.com/bad-antics)
- **NullSec Linux** — Pre-built security distro: [bad-antics.github.io/nullsec-linux](https://bad-antics.github.io/nullsec-linux/)
- **Contact:** badxantics@gmail.com
