# Shodan Intelligence Browser - Console Edition

## Overview
The Shodan Intelligence Browser is now integrated directly into the NULLSEC command execution console, providing seamless target discovery and reconnaissance without leaving your workflow.

## Access

### Quick Access
```bash
# Launch NULLSEC
./nullsec-launcher.py

# Enter Execute Console
Press [E]

# Launch Shodan Browser
nullsec@exec > shodan
```

## Features

### Real-Time Search Capabilities
- **Device Search** - Find internet-connected devices worldwide
- **Host Intelligence** - Detailed information about specific IPs
- **Statistics** - Count results and analyze trends
- **Exploit Discovery** - Search for known exploits
- **Public IP Info** - Get your own IP information

### Integrated Actions
- **Export Targets** - Automatically save targets to `.shodan_target`
- **Quick Scanning** - Launch nmap directly from browser
- **Save Results** - Export search results to JSON
- **Seamless Workflow** - No need to leave NULLSEC console

## Command Reference

### Search Commands

#### `search <query>`
Search the Shodan database for devices matching your query.

**Examples:**
```bash
shodan@browser > search apache country:US
shodan@browser > search product:MySQL
shodan@browser > search port:22
shodan@browser > search webcam
shodan@browser > search "default password"
shodan@browser > search ssl:"self signed"
```

**Query Filters:**
- `country:` - Filter by country code (US, CN, RU, etc.)
- `port:` - Filter by port number
- `product:` - Filter by product name
- `org:` - Filter by organization
- `city:` - Filter by city
- `ssl:` - Filter by SSL certificate
- `hostname:` - Filter by hostname

#### `host <ip>`
Get detailed information about a specific IP address.

**Example:**
```bash
shodan@browser > host 8.8.8.8
```

**Returns:**
- IP address and hostnames
- Geographic location (country, city)
- ISP and organization
- Open ports
- Vulnerabilities (if any)
- Services running

**Automatic Export:**
Results are automatically exported to `.shodan_target` for use with attack modules.

#### `count <query>`
Count the number of results for a query without fetching all data.

**Examples:**
```bash
shodan@browser > count port:3389
shodan@browser > count apache country:US
shodan@browser > count product:MongoDB
```

#### `exploits <query>`
Search for known exploits (future feature).

**Example:**
```bash
shodan@browser > exploits apache 2.4
```

#### `myip`
Get information about your public IP address.

**Example:**
```bash
shodan@browser > myip
```

**Returns:**
- Your public IP
- Country and city
- ISP information
- Organization
- Open ports (if any)

#### `stats <query>`
Get statistics for a search query (future feature).

### Action Commands

#### `export <ip>`
Export an IP address to the `.shodan_target` file for use with NULLSEC modules.

**Example:**
```bash
shodan@browser > export 192.168.1.100

# Later in Execute Console
nullsec@exec > exec nmap -sV $(cat .shodan_target | grep TARGET | cut -d= -f2)
```

#### `scan <ip>`
Perform a quick nmap scan on a target IP.

**Example:**
```bash
shodan@browser > scan 192.168.1.100
```

**Scan Details:**
- Version detection (-sV)
- Fast timing (-T4)
- Top 100 ports
- Automatic nmap installation if missing

#### `save <filename>`
Save the last search results to a JSON file.

**Examples:**
```bash
shodan@browser > save results.json
shodan@browser > save apache_servers.json
```

### Navigation Commands

#### `help`
Display the help menu with all available commands.

#### `clear`
Clear the screen.

#### `exit`
Return to the main command execution console.

## Workflow Examples

### Example 1: Find and Scan Vulnerable Systems

```bash
# Launch Shodan browser
nullsec@exec > shodan

# Search for systems with port 445 open (SMB)
shodan@browser > search port:445 country:RU

# Get detailed info on first result
shodan@browser > host 203.0.113.50

# Export target
shodan@browser > export 203.0.113.50

# Quick scan
shodan@browser > scan 203.0.113.50

# Exit to console
shodan@browser > exit

# Run full exploit
nullsec@exec > run /opt/exploits/smb-exploit.py
```

### Example 2: Find Webcams

```bash
shodan@browser > search webcam

# Shows list of exposed webcams with IPs and locations

shodan@browser > host 198.51.100.25

# Get detailed information

shodan@browser > export 198.51.100.25

# Save for later analysis
shodan@browser > save webcam_results.json
```

### Example 3: Database Discovery

```bash
# Count MongoDB instances
shodan@browser > count product:MongoDB

# Search for MongoDB in specific country
shodan@browser > search product:MongoDB country:US

# Get info on specific instance
shodan@browser > host 192.0.2.100

# Export and scan
shodan@browser > export 192.0.2.100
shodan@browser > scan 192.0.2.100
```

### Example 4: Your IP Intelligence

```bash
# Check your public IP
shodan@browser > myip

# Returns your IP with ISP, location, and open ports
```

### Example 5: Apache Server Research

```bash
# Search for Apache servers
shodan@browser > search apache country:US

# Count total results
shodan@browser > count apache country:US

# Save results for documentation
shodan@browser > save apache_us_servers.json
```

## API Integration

### Automatic API Key Management
The Shodan browser automatically loads API keys from the Shodan search module:
- 20 rotating API keys
- Automatic key selection
- Fallback to limited mode if no keys found

### API Endpoints Used
- `/shodan/host/search` - Search for devices
- `/shodan/host/{ip}` - Get host information
- `/shodan/host/count` - Count search results
- `/tools/myip` - Get your public IP

## Output Format

### Search Results
```
[✓] Found 1,234 results (showing first 10)

  [1] 203.0.113.50:22
      Country: US | Org: Example ISP
      Product: OpenSSH 7.4
      Banner: SSH-2.0-OpenSSH_7.4...

  [2] 198.51.100.25:80
      Country: CN | Org: China Telecom
      Product: Apache httpd 2.4.6
      Banner: HTTP/1.1 200 OK...
```

### Host Information
```
[✓] Host Information:
    IP: 203.0.113.50
    Hostnames: example.com, www.example.com
    Country: United States (US)
    City: New York
    ISP: Example ISP
    Organization: Example Corp
    Open Ports: 22, 80, 443
    Vulnerabilities: CVE-2021-1234, CVE-2022-5678

[✓] Target exported to .shodan_target
```

## Integration with NULLSEC Features

### With Execute Console
```bash
# Find target in Shodan
nullsec@exec > shodan
shodan@browser > search port:22
shodan@browser > export 203.0.113.50
shodan@browser > exit

# Use target in commands
nullsec@exec > exec nmap -sV -sC 203.0.113.50
nullsec@exec > run /opt/ssh-exploit.py
```

### With Attack Modules
```bash
# Export target from Shodan
shodan@browser > host 192.0.2.100
shodan@browser > exit

# Target is auto-loaded in modules
nullsec@exec > exec bash nullsecurity/port-scanner.sh
# Module reads from .shodan_target
```

### With Tool Launcher
```bash
# Find target
shodan@browser > export 198.51.100.25
shodan@browser > exit

# Launch Wireshark with target
nullsec@exec > exit
# From main menu, press [T] for Tools
# Wireshark will auto-filter for target IP
```

## Best Practices

### 1. Start with Counts
```bash
# Check how many results before searching
shodan@browser > count port:3389
```

### 2. Use Specific Queries
```bash
# Too broad
shodan@browser > search apache

# Better - specific location and version
shodan@browser > search apache 2.4 country:US
```

### 3. Save Results
```bash
# Always save for documentation
shodan@browser > save scan_results_2026-01-12.json
```

### 4. Export Before Scanning
```bash
# Export first, then scan
shodan@browser > export 192.0.2.100
shodan@browser > scan 192.0.2.100
```

### 5. Check Your Own IP
```bash
# Verify your anonymity
shodan@browser > myip
```

## Security Considerations

### Legal Usage
- **Only search** - Viewing Shodan data is legal
- **Authorization required** - Scanning/exploiting requires permission
- **Documentation** - Save results for authorized testing records
- **Responsible disclosure** - Report vulnerabilities properly

### API Rate Limits
- Free tier: 100 queries/month
- With API key: Varies by subscription
- Multiple keys: Automatic rotation helps avoid limits

### Privacy
- Your searches are logged by Shodan
- Use VPN for anonymity
- Check your own IP with `myip` command

## Troubleshooting

### "Shodan API key required"
**Solution:** Ensure API keys are configured in `nullsecurity/shodan-search.sh`

### "No results found"
**Solution:** 
- Try broader search terms
- Remove country filters
- Check API key validity

### "Invalid response from Shodan"
**Solution:**
- Check internet connection
- Verify API key is valid
- Try again after a moment (rate limit)

### "Failed to fetch host info"
**Solution:**
- Verify IP address is correct
- Check if host exists in Shodan database
- Some IPs may not be indexed

## Advanced Usage

### Combining Filters
```bash
shodan@browser > search apache port:443 country:US city:"New York"
```

### Using Quotes
```bash
shodan@browser > search "default password" product:router
```

### Negative Filters
```bash
shodan@browser > search port:22 -country:US
```

### Regular Expressions
```bash
shodan@browser > search hostname:/^admin\./
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+C | Interrupt search |
| Ctrl+D | Exit browser |
| Up Arrow | Command history (if enabled) |

## Future Enhancements

Planned features:
- Exploit database search
- Statistics visualization
- Pagination for large results
- Filter refinement
- Bulk export
- Custom output formats
- Integration with Metasploit
- Automated vulnerability scanning

---

## Quick Reference

```
SHODAN BROWSER - QUICK REFERENCE

SEARCH
  search <query>       Search Shodan
  host <ip>            Host details
  count <query>        Count results
  myip                 Your public IP

ACTIONS
  export <ip>          Export to file
  scan <ip>            Quick nmap scan
  save <file>          Save results

NAVIGATION
  help                 Show help
  clear                Clear screen
  exit                 Return to console

EXAMPLES
  search apache country:US
  host 8.8.8.8
  count port:3389
  export 192.168.1.100
  scan 192.168.1.100
```

---

**Developed by bad-antics | github.com/bad-antics**  
**nullsec-Linux (v1.1) - Shodan Intelligence Browser**
