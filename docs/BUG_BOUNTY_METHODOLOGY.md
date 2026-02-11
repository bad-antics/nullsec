# Bug Bounty Methodology — NullSec Toolkit

> Personal recon-to-report workflow using custom NullSec tools alongside industry standards.

## Phase 1: Reconnaissance

### 1.1 Subdomain Enumeration
```bash
# Passive subdomain discovery
subfinder -d target.com -all -o subs.txt

# Active brute-force with custom wordlist
nullsec-wordlists/nullsec-subdomains.txt
puredns bruteforce nullsec-subdomains.txt target.com -r resolvers.txt -w brute.txt

# Merge and deduplicate
cat subs.txt brute.txt | sort -u > all-subs.txt
echo "$(wc -l < all-subs.txt) unique subdomains"
```

### 1.2 Live Host Detection
```bash
# HTTP probing
httpx -l all-subs.txt -ports 80,443,8080,8443 -status-code -title -tech-detect -o live.txt

# Screenshot for visual review
gowitness file -f live.txt --screenshot-path screenshots/
```

### 1.3 Port Scanning
```bash
# Quick scan with netprobe
netprobe -iL all-subs.txt --top-ports 1000 -sV -o ports.json

# Full scan on interesting targets
nmap -sS -sV -p- -T4 --script=default,vuln target.com -oA full-scan
```

### 1.4 Technology Fingerprinting
```bash
# Identify tech stacks
whatweb -i live.txt --log-json tech.json

# Check for WAF
wafw00f target.com
```

## Phase 2: Content Discovery

### 2.1 Directory & File Fuzzing
```bash
# Fast directory fuzzing
ffuf -w nullsec-dirs.txt -u https://target.com/FUZZ -mc 200,301,302,403 -o dirs.json

# Parameter discovery
ffuf -w nullsec-params.txt -u "https://target.com/page?FUZZ=test" -mc 200 -o params.json

# Backup file hunting
ffuf -w backup-extensions.txt -u https://target.com/FUZZ -mc 200,403
```

### 2.2 JavaScript Analysis
```bash
# Extract JS files
cat live.txt | getJS --complete | sort -u > js-files.txt

# Find sensitive endpoints in JS
cat js-files.txt | while read url; do
    curl -s "$url" | grep -oP '(api|admin|internal|dev|staging)[^"]*' >> endpoints.txt
done

# Extract secrets from JS
nuclei -l js-files.txt -t exposures/tokens/
```

### 2.3 Google Dorking
```
site:target.com filetype:pdf
site:target.com inurl:admin
site:target.com intitle:"index of"
site:target.com ext:sql | ext:db | ext:log
"target.com" password | secret | api_key
```

## Phase 3: Vulnerability Scanning

### 3.1 Automated Scanning
```bash
# Nuclei with all templates
nuclei -l live.txt -t nuclei-templates/ -severity critical,high,medium -o nuclei-results.txt

# Oracle ML-powered scan (custom tool)
oracle scan --targets live.txt --depth deep --models cve_predictor,pattern_match --output oracle-results.json

# OWASP ZAP baseline
zap-cli quick-scan -s xss,sqli -f json https://target.com
```

### 3.2 Manual Testing Checklist

#### Authentication
- [ ] Default credentials
- [ ] Password reset flaws
- [ ] JWT vulnerabilities (none alg, weak secret)
- [ ] Session fixation / insufficient expiry
- [ ] OAuth misconfiguration
- [ ] 2FA bypass

#### Injection
- [ ] SQL injection (error, blind, time-based)
- [ ] XSS (reflected, stored, DOM)
- [ ] Command injection
- [ ] SSTI (Server-Side Template Injection)
- [ ] SSRF (Server-Side Request Forgery)
- [ ] XXE (XML External Entity)
- [ ] LDAP injection
- [ ] NoSQL injection

#### Authorization
- [ ] IDOR (Insecure Direct Object Reference)
- [ ] Privilege escalation (horizontal + vertical)
- [ ] Missing function-level access control
- [ ] CORS misconfiguration
- [ ] GraphQL introspection enabled

#### Business Logic
- [ ] Price manipulation
- [ ] Race conditions
- [ ] Rate limiting bypass
- [ ] Feature abuse / logic flaws

## Phase 4: Exploitation & Proof

### Rules of Engagement
- **NEVER** access data beyond proof-of-concept
- **NEVER** modify or delete production data
- **NEVER** perform DoS or degradation
- **ALWAYS** stop at first confirmed evidence
- **ALWAYS** use minimum-impact reproduction steps

### Proof-of-Concept Standards
```
For each finding:
1. Clear vulnerability description
2. Step-by-step reproduction
3. Impact assessment (CVSS score)
4. HTTP requests/responses (redacted)
5. Screenshots with timestamps
6. Affected endpoint + parameter
7. Remediation recommendation
```

## Phase 5: Reporting

### Report Template
```markdown
# Vulnerability Report

## Title
[Type] - [Location] - [Brief Description]

## Severity
CVSS: X.X (Critical/High/Medium/Low)

## Description
[What the vulnerability is and why it matters]

## Steps to Reproduce
1. Navigate to https://target.com/endpoint
2. Intercept request with Burp/ZAP
3. Modify parameter X to Y
4. Observe [vulnerable behavior]

## Impact
[What an attacker could achieve]

## Remediation
[Specific fix recommendations]

## References
- CWE-XXX: [Name]
- OWASP: [Relevant category]
```

## Tool Quick Reference

| Phase | Tool | Purpose |
|-------|------|---------|
| Recon | subfinder, amass | Subdomain enum |
| Recon | httpx | HTTP probing |
| Recon | netprobe | Port scanning |
| Content | ffuf | Fuzzing |
| Content | nuclei | Template scanning |
| Vuln | oracle | ML vuln detection |
| Vuln | sqlmap | SQL injection |
| Vuln | XSStrike | XSS testing |
| Report | vortex | Threat context |

## Platform-Specific Notes

### HackerOne
- Read program policy completely before testing
- Check scope — in-scope vs out-of-scope domains
- Use quality over quantity (5 good bugs > 50 dupes)
- Respond promptly to triage questions

### Bugcrowd
- Priority (P1-P4) determines payout
- VRT (Vulnerability Rating Taxonomy) for classification
- Researcher reputation affects program invites
