# NULLSEC Command Execution System

## Overview
The NULLSEC framework now includes a powerful command execution system that allows you to run any external script or application directly from within the nullsec console, with automatic dependency checking and installation capabilities.

## Features

### 1. **Interactive Command Console** 
Access via `[E] Execute` from the main menu

The command console provides:
- Shell command execution
- External script runner
- Automatic dependency checking
- On-demand package installation
- Command history tracking
- Multi-interpreter support

### 2. **Automatic Dependency Management**

When you attempt to run a command or script that requires a tool not installed on your system, NULLSEC will:
1. Detect the missing dependency
2. Identify the correct package name
3. Prompt you to install it
4. Handle installation via appropriate package manager
5. Retry the command after installation

### 3. **Multi-Package Manager Support**

NULLSEC supports installation via:
- **apt** - Debian/Ubuntu packages
- **pip/pip3** - Python packages
- **npm** - Node.js packages
- **snap** - Snap packages
- **gem** - Ruby gems

## Command Console Usage

### Starting the Console
From the main NULLSEC menu, press `[E]` to enter the Execute console.

### Available Commands

#### `exec <command>`
Execute any shell command within the nullsec environment.

**Examples:**
```bash
exec nmap -sV 192.168.1.1
exec aircrack-ng -w /usr/share/wordlists/rockyou.txt capture.cap
exec hydra -L users.txt -P passwords.txt ssh://192.168.1.100
exec sqlmap -u "http://target.com/page?id=1" --dbs
```

#### `run <script>`
Run an external script with automatic interpreter detection.

**Supported Script Types:**
- `.sh` - Bash scripts
- `.py` - Python scripts
- `.pl` - Perl scripts
- `.rb` - Ruby scripts
- `.js` - Node.js scripts

**Examples:**
```bash
run /tmp/custom-exploit.py
run ./wifi-attack.sh
run ~/Desktop/scanner.pl
run /opt/tools/enumeration.rb
```

The system automatically:
- Detects the script type by extension
- Makes the script executable
- Selects the appropriate interpreter
- Handles shebang lines
- Installs missing interpreters

#### `install <package> [installer]`
Manually install a package.

**Examples:**
```bash
install nmap
install metasploit-framework
install shodan pip
install eslint npm
install code snap
```

#### `check <command>`
Check if a command/tool is available on the system.

**Examples:**
```bash
check nmap
check wireshark
check python3
check msfconsole
```

Output shows installation status and full path if installed.

#### `history`
Display the last 20 executed commands.

#### `clear`
Clear the console screen.

#### `help`
Display command reference.

#### `exit`
Return to the main NULLSEC menu.

## Automatic Package Resolution

NULLSEC maintains an internal mapping of common security tools to their package names:

| Command | Package | Installer |
|---------|---------|-----------|
| nmap | nmap | apt |
| wireshark | wireshark | apt |
| aircrack-ng | aircrack-ng | apt |
| hashcat | hashcat | apt |
| hydra | hydra | apt |
| john | john | apt |
| msfconsole | metasploit-framework | apt |
| ettercap | ettercap-text-only | apt |
| sqlmap | sqlmap | apt |
| burpsuite | burpsuite | apt |
| zaproxy | zaproxy | apt |
| ghidra | ghidra | apt |
| gobuster | gobuster | apt |
| ffuf | ffuf | apt |
| netcat | netcat-traditional | apt |
| hping3 | hping3 | apt |
| masscan | masscan | apt |
| proxychains | proxychains | apt |
| tor | tor | apt |
| openvpn | openvpn | apt |

...and 30+ more security tools!

## Integration with NULLSEC Modules

### Dependency Checking in Bash Scripts

All NULLSEC modules can now source the dependency checker:

```bash
#!/bin/bash
source "$(dirname "$0")/dep-check.sh"

# Check if nmap is installed, offer to install if not
smart_install nmap

# Check multiple dependencies
check_dependencies nmap wireshark tcpdump

# Manual check and install
check_and_install "hashcat" "hashcat" "apt"
```

### Using from Python Launcher

The Python launcher includes built-in execution functions:

```python
from nullsec_launcher import execute_external_command, run_external_script

# Execute a command with auto-dependency checking
execute_external_command("nmap -sV 192.168.1.1", "Scanning network")

# Run a script
run_external_script("/tmp/exploit.py")
```

## Workflow Examples

### Example 1: Running Nmap from Console
```
nullsec@exec > exec nmap -sV scanme.nmap.org

[*] Executing command
Command: nmap -sV scanme.nmap.org

Starting Nmap 7.94 ( https://nmap.org )
Nmap scan report for scanme.nmap.org (45.33.32.156)
...
[✓] Command completed successfully
```

### Example 2: Missing Dependency Auto-Install
```
nullsec@exec > exec hashcat -m 0 hashes.txt wordlist.txt

[!] hashcat is not installed
[?] Would you like to install it? (y/n): y

[*] Installing hashcat...
Reading package lists... Done
...
[✓] hashcat installed successfully

[*] Executing command
hashcat (v6.2.5) starting...
```

### Example 3: Running Custom Exploit Script
```
nullsec@exec > run /tmp/exploit.py

[*] Running external script: exploit.py

[!] python3 not found
[?] Would you like to install it? (y/n): y

[*] Installing python3...
[✓] python3 installed successfully

[*] Executing: python3 /tmp/exploit.py
...
[✓] Script completed successfully
```

### Example 4: Check Tool Availability
```
nullsec@exec > check wireshark

[✓] wireshark is installed: /usr/bin/wireshark

nullsec@exec > check msfconsole

[✗] msfconsole not found

nullsec@exec > install metasploit-framework

[*] Installing metasploit-framework...
...
[✓] metasploit-framework installed successfully
```

## Advanced Usage

### Running Scripts with Arguments
```bash
run /opt/scanner.py --target 192.168.1.0/24 --ports 1-1000
```

### Chaining Commands
```bash
exec nmap -sn 192.168.1.0/24 | grep "Nmap scan report"
```

### Using Environment Variables
```bash
exec TARGET=192.168.1.1 PORT=22 /tmp/exploit.sh
```

### Background Processes
For long-running tasks, use `&` or run in a separate terminal:
```bash
exec aircrack-ng -w wordlist.txt capture.cap &
```

## Security Considerations

### Sudo Privileges
Some tools require root access. The system will:
1. Detect when sudo is needed
2. Prompt for password if necessary
3. Execute with appropriate privileges

### Command Validation
All commands are validated before execution to prevent:
- Empty commands
- Malformed syntax
- Path injection attempts

### Installation Safety
- Package names are validated
- Official repositories are used
- User confirmation required before installation

## Troubleshooting

### "Command not found" after installation
- Refresh your PATH: `exec hash -r`
- Check installation: `check <command>`
- Manual verification: `exec which <command>`

### Permission Denied
- Run with sudo: `exec sudo <command>`
- Check file permissions: `exec ls -la script.sh`
- Make executable: `exec chmod +x script.sh`

### Script interpreter not working
- Verify shebang line in script
- Manually specify interpreter: `run` auto-detects by extension
- Install interpreter: `install python3` or `install perl`

### Package installation fails
- Update package lists: `install apt update`
- Check internet connection
- Verify package name: Try alternative package manager
- Manual install: Use system package manager outside NULLSEC

## Integration with Existing Features

### Works with Shodan Integration
```bash
# Export target from Shodan search, then:
exec nmap -sV $(cat .shodan_target)
```

### Works with Tool Launcher
Commands can prepare data for security tools:
```bash
exec echo "192.168.1.100" > .shodan_target
# Then launch Wireshark from Tools menu
```

### Works with MSF Integration
```bash
exec msfconsole -r /tmp/custom.rc
```

## Best Practices

1. **Always check dependencies first**
   ```bash
   check nmap
   check wireshark
   ```

2. **Use test mode for reconnaissance**
   ```bash
   exec nmap -sn 192.168.1.0/24  # Discovery only
   ```

3. **Keep command history for auditing**
   ```bash
   history  # Review recent commands
   ```

4. **Install tools before operations**
   ```bash
   install metasploit-framework
   install aircrack-ng
   install hashcat
   ```

5. **Verify script safety before running**
   ```bash
   exec cat suspicious-script.sh  # Review first
   run suspicious-script.sh       # Then execute
   ```

## Command Console Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+C | Interrupt current operation |
| Ctrl+D | Exit console (same as 'exit') |
| Up Arrow | Command history (if enabled) |
| Tab | Auto-completion (if enabled) |

## Future Enhancements

Planned features for future releases:
- Command auto-completion
- Command history with up/down arrows
- Alias support for frequent commands
- Script templates library
- Integrated code editor
- Remote script execution
- Parallel command execution
- Output logging and export

---

## Quick Reference Card

```
NULLSEC COMMAND CONSOLE - QUICK REFERENCE

EXECUTION
  exec <command>           Run shell command
  run <script>            Execute script file

MANAGEMENT  
  install <pkg> [method]  Install package
  check <command>         Check availability
  
NAVIGATION
  history                 Show command log
  clear                  Clear screen
  help                   Show help
  exit                   Return to menu

EXAMPLES
  exec nmap -sV 192.168.1.1
  run /tmp/exploit.py
  install metasploit-framework
  check wireshark
```

---

**Developed by bad-antics | github.com/bad-antics**
