============================================================
     NullSec Mesh Cluster - USB Join Tool
============================================================

INSTRUCTIONS:
  1. Plug this USB into any Windows machine
  2. Open the USB drive in File Explorer
  3. Double-click:  nullsec-join.bat
  4. Click "Yes" when Windows asks for admin permission
  5. Wait for the script to finish
  6. Note the IP address shown at the end

WHAT IT DOES:
  - Disables Windows Firewall (all profiles)
  - Installs OpenSSH Server (tries 4 different methods)
  - Configures sshd for cluster use
  - Deploys the NullSec SSH key for passwordless access
  - Enables Remote Desktop, file sharing, ping
  - Disables sleep/hibernate (always-on compute node)
  - Creates keepalive tasks so sshd stays running
  - Writes cluster identity to C:\ProgramData\NullSec\

AFTER RUNNING:
  From the gateway (192.168.40.129), connect with:
    ssh <username>@<ip-shown-on-screen>

FILES ON THIS USB:
  nullsec-join.bat     - Double-click launcher (auto-elevates)
  nullsec-join.ps1     - Main setup script (PowerShell)
  OpenSSH-Win64.zip    - Offline OpenSSH installer (no internet needed)
  README.txt           - This file

REQUIREMENTS:
  - Windows 10 or Windows 11
  - Administrator access
  - Network connection (wired or wireless)
  - No internet required (offline OpenSSH included)

============================================================
  NullSec Cluster | github.com/nullsec
============================================================
