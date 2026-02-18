# ============================================================================
# NullSec Mesh Cluster - Windows Auto-Join Script
# Run as Administrator - handles EVERYTHING automatically
# Pure ASCII - no Unicode characters
# ============================================================================

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# CONFIG - Edit these if your cluster changes
# ---------------------------------------------------------------------------
$GATEWAY_IP      = "192.168.1.1"
$CLUSTER_SUBNET  = "192.168.1.0/24"
$MESH_SUBNET     = "10.10.10.0/24"
$SSH_PORT         = 22
$SSH_PUBKEY       = "ssh-ed25519 AAAA_YOUR_PUBKEY_HERE nullsec-node@nullsec"
$CLUSTER_NAME     = "NullSec"
$USB_PATH         = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------------------------------------
function Log-OK    { param([string]$msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Log-Warn  { param([string]$msg) Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Log-Err   { param([string]$msg) Write-Host "  [XX] $msg" -ForegroundColor Red }
function Log-Info  { param([string]$msg) Write-Host "  [--] $msg" -ForegroundColor Cyan }
function Log-Phase { param([int]$num, [string]$msg)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor White
    Write-Host "  PHASE $num : $msg" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor White
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# PRE-FLIGHT
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Magenta
Write-Host "       NullSec Mesh Cluster - Auto Join" -ForegroundColor Magenta
Write-Host ("=" * 60) -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Admin)) {
    Log-Err "NOT RUNNING AS ADMINISTRATOR"
    Log-Err "Right-click the .bat file and select 'Run as administrator'"
    Write-Host ""
    pause
    exit 1
}
Log-OK "Running as Administrator"

$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
Log-Info "Hostname: $hostname"
Log-Info "Username: $username"
Log-Info "USB Path: $USB_PATH"

# Detect our IP address (prefer gateway subnet, fallback to any)
$myIP = $null
$gwSubnet = ($GATEWAY_IP -replace '\.[0-9]+$', '.')
$adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." }
foreach ($a in $adapters) {
    if ($a.IPAddress -match [regex]::Escape($gwSubnet)) {
        $myIP = $a.IPAddress
        break
    }
}
if (-not $myIP -and $adapters) {
    $myIP = $adapters[0].IPAddress
}
Log-Info "IP Address: $myIP"

# ============================================================================
# PHASE 1: DISABLE WINDOWS FIREWALL COMPLETELY
# ============================================================================
Log-Phase 1 "DISABLE WINDOWS FIREWALL"

# Method 1: PowerShell cmdlet
try {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction Stop
    Log-OK "Firewall disabled via Set-NetFirewallProfile"
} catch {
    Log-Warn "PowerShell method failed, trying netsh..."
}

# Method 2: netsh (belt and suspenders)
$profiles = @("domainprofile", "privateprofile", "publicprofile", "allprofiles")
foreach ($p in $profiles) {
    netsh advfirewall set $p state off 2>$null | Out-Null
}
Log-OK "Firewall disabled via netsh (all profiles)"

# Method 3: Also set firewall policy to allow everything (in case it re-enables)
netsh advfirewall set allprofiles firewallpolicy allowinbound,allowoutbound 2>$null | Out-Null
Log-OK "Firewall policy set to allow all inbound/outbound"

# ALSO add explicit rules in case firewall gets re-enabled by Windows Update
$rules = @(
    @{Name="NullSec-SSH-In";     Dir="in";  Proto="TCP"; Port="22";   Action="allow"},
    @{Name="NullSec-SSH-Out";    Dir="out"; Proto="TCP"; Port="22";   Action="allow"},
    @{Name="NullSec-ICMP-In";   Dir="in";  Proto="ICMPv4"; Port="";  Action="allow"},
    @{Name="NullSec-ICMP-Out";  Dir="out"; Proto="ICMPv4"; Port="";  Action="allow"},
    @{Name="NullSec-Mesh-In";   Dir="in";  Proto="TCP"; Port="1-65535"; Action="allow"},
    @{Name="NullSec-Mesh-Out";  Dir="out"; Proto="TCP"; Port="1-65535"; Action="allow"}
)

# Nuke any old NullSec rules
netsh advfirewall firewall delete rule name="NullSec-SSH-In" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="NullSec-SSH-Out" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="NullSec-ICMP-In" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="NullSec-ICMP-Out" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="NullSec-Mesh-In" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="NullSec-Mesh-Out" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="OpenSSH Server (sshd)" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="SSH" 2>$null | Out-Null

foreach ($r in $rules) {
    if ($r.Proto -eq "ICMPv4") {
        netsh advfirewall firewall add rule name=$r.Name dir=$r.Dir action=$r.Action protocol=$r.Proto 2>$null | Out-Null
    } else {
        netsh advfirewall firewall add rule name=$r.Name dir=$r.Dir action=$r.Action protocol=$r.Proto localport=$r.Port 2>$null | Out-Null
    }
}
Log-OK "Backup firewall rules created (SSH, ICMP, all TCP)"

# Set all network profiles to Private
try {
    Get-NetConnectionProfile -ErrorAction SilentlyContinue | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
    Log-OK "Network profiles set to Private"
} catch {
    Log-Warn "Could not set network profile"
}

# Disable any third-party firewall services we know about
$thirdParty = @("MpsSvc", "SharedAccess", "BFE")
# Don't disable BFE/MpsSvc as it can break networking, but log them
$avServices = @(
    "NortonSecurity", "Norton Security", "navapsvc", "nsWscSvc",
    "McAfeeFramework", "McShield", "mfevtp", "masvc",
    "avast! Antivirus", "AvastSvc", "aswBcc",
    "AVGSvc", "avgwd",
    "KasperskySecurity", "AVP", "kavfs"
)
foreach ($svc in $avServices) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        Log-Warn "Third-party AV detected: $svc (Status: $($s.Status))"
        Log-Warn "You may need to disable this manually for SSH to work"
    }
}

# ============================================================================
# PHASE 2: INSTALL OPENSSH SERVER
# ============================================================================
Log-Phase 2 "INSTALL OPENSSH SERVER"

$sshdInstalled = $false

# Check if already installed
$sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshService) {
    Log-OK "OpenSSH Server already installed"
    $sshdInstalled = $true
}

if (-not $sshdInstalled) {
    # Method 1: Windows Capability (Windows 10 1809+ / Windows 11)
    Log-Info "Trying Method 1: Add-WindowsCapability..."
    try {
        $cap = Get-WindowsCapability -Online -Name "OpenSSH.Server*" -ErrorAction Stop
        if ($cap.State -ne "Installed") {
            $result = Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" -ErrorAction Stop
            if ($result.RestartNeeded) {
                Log-Warn "Restart may be needed after install"
            }
            $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
            if ($sshService) {
                Log-OK "Installed via WindowsCapability"
                $sshdInstalled = $true
            }
        } else {
            Log-OK "WindowsCapability shows already installed"
            $sshdInstalled = $true
        }
    } catch {
        Log-Warn "Method 1 failed: $($_.Exception.Message)"
    }
}

if (-not $sshdInstalled) {
    # Method 2: Optional Feature (older Windows 10)
    Log-Info "Trying Method 2: DISM Optional Feature..."
    try {
        $dismResult = dism /Online /Get-FeatureInfo /FeatureName:OpenSSH-Server 2>&1
        if ($dismResult -match "State : Enabled") {
            Log-OK "Already enabled via DISM"
            $sshdInstalled = $true
        } else {
            dism /Online /Add-Feature /FeatureName:OpenSSH-Server /All 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
            if ($sshService) {
                Log-OK "Installed via DISM"
                $sshdInstalled = $true
            }
        }
    } catch {
        Log-Warn "Method 2 failed"
    }
}

if (-not $sshdInstalled) {
    # Method 3: Offline install from USB (OpenSSH-Win64.zip)
    # Fully manual: extract, register service with sc.exe, generate host keys
    Log-Info "Trying Method 3: Offline install from USB..."
    $zipPath = Join-Path $USB_PATH "OpenSSH-Win64.zip"
    if (Test-Path $zipPath) {
        $installDir = "C:\Program Files\OpenSSH-Win64"
        try {
            # Clean previous install
            sc.exe stop sshd 2>$null | Out-Null
            sc.exe delete sshd 2>$null | Out-Null
            sc.exe stop ssh-agent 2>$null | Out-Null
            sc.exe delete ssh-agent 2>$null | Out-Null
            Start-Sleep -Seconds 1
            if (Test-Path $installDir) {
                Remove-Item -Recurse -Force $installDir -ErrorAction SilentlyContinue
            }

            # Extract
            Log-Info "Extracting OpenSSH-Win64.zip..."
            Expand-Archive -Path $zipPath -DestinationPath "C:\Program Files" -Force -ErrorAction Stop

            # Verify sshd.exe exists
            if (-not (Test-Path "$installDir\sshd.exe")) {
                Log-Err "sshd.exe not found at $installDir after extraction"
                Log-Info "Contents of C:\Program Files\OpenSSH-Win64:"
                Get-ChildItem "$installDir" -ErrorAction SilentlyContinue | ForEach-Object { Log-Info "  $($_.Name)" }
            } else {
                Log-OK "Extracted sshd.exe to $installDir"
            }

            # Add to system PATH
            $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($machinePath -notlike "*OpenSSH*") {
                [Environment]::SetEnvironmentVariable("PATH", "$machinePath;$installDir", "Machine")
                $env:PATH = "$env:PATH;$installDir"
                Log-OK "Added to system PATH"
            }

            # Create ProgramData\ssh directory for config and host keys
            $sshDataDir = "$env:ProgramData\ssh"
            if (-not (Test-Path $sshDataDir)) {
                New-Item -ItemType Directory -Path $sshDataDir -Force | Out-Null
            }

            # Generate host keys if they don't exist
            Log-Info "Generating SSH host keys..."
            $keyTypes = @("rsa", "ecdsa", "ed25519")
            foreach ($kt in $keyTypes) {
                $keyFile = "$sshDataDir\ssh_host_${kt}_key"
                if (-not (Test-Path $keyFile)) {
                    $kgArgs = @("-t", $kt, "-f", $keyFile, "-N", "", "-q")
                    & "$installDir\ssh-keygen.exe" @kgArgs 2>&1 | Out-Null
                    # Fallback: try with echo piped
                    if (-not (Test-Path $keyFile)) {
                        "" | & "$installDir\ssh-keygen.exe" -t $kt -f $keyFile -q 2>&1 | Out-Null
                    }
                    if (Test-Path $keyFile) {
                        Log-OK "Generated host key: ssh_host_${kt}_key"
                    } else {
                        Log-Warn "Failed to generate host key: $kt"
                    }
                } else {
                    Log-OK "Host key already exists: ssh_host_${kt}_key"
                }
            }

            # Set proper permissions on host keys
            foreach ($f in (Get-ChildItem "$sshDataDir\ssh_host_*" -ErrorAction SilentlyContinue)) {
                icacls $f.FullName /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F" 2>$null | Out-Null
            }

            # Try install-sshd.ps1 first
            Log-Info "Trying install-sshd.ps1..."
            $installScript = "$installDir\install-sshd.ps1"
            if (Test-Path $installScript) {
                $scriptContent = Get-Content $installScript -Raw
                try {
                    Push-Location $installDir
                    & $installScript 2>&1 | ForEach-Object { Log-Info "  $_" }
                    Pop-Location
                    Start-Sleep -Seconds 2
                } catch {
                    Log-Warn "install-sshd.ps1 threw error: $($_.Exception.Message)"
                }
            }

            # Check if service exists now
            $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
            if (-not $sshService) {
                # Manual service registration with sc.exe
                Log-Info "install-sshd.ps1 didn't work, registering service manually with sc.exe..."
                $sshdExe = "$installDir\sshd.exe"
                $agentExe = "$installDir\ssh-agent.exe"

                # Register ssh-agent
                sc.exe create ssh-agent binPath= "`"$agentExe`"" DisplayName= "OpenSSH Authentication Agent" start= auto 2>&1 | ForEach-Object { Log-Info "  agent: $_" }

                # Register sshd
                sc.exe create sshd binPath= "`"$sshdExe`"" DisplayName= "OpenSSH SSH Server" start= auto depend= ssh-agent 2>&1 | ForEach-Object { Log-Info "  sshd: $_" }

                # Also try without dependency
                $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
                if (-not $sshService) {
                    sc.exe delete sshd 2>$null | Out-Null
                    sc.exe create sshd binPath= "`"$sshdExe`"" DisplayName= "OpenSSH SSH Server" start= auto 2>&1 | ForEach-Object { Log-Info "  sshd (no dep): $_" }
                }
            }

            # Final check
            Start-Sleep -Seconds 1
            $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
            if ($sshService) {
                Log-OK "OpenSSH Server service registered successfully"
                $sshdInstalled = $true
            } else {
                Log-Err "Failed to register sshd service"
                Log-Info "Attempting last resort: run sshd.exe directly..."
                # Create a wrapper to run sshd directly
                $wrapperPath = "$installDir\start-sshd.cmd"
                Set-Content -Path $wrapperPath -Value "@`"$installDir\sshd.exe`" -D" -Encoding ASCII
                sc.exe create sshd binPath= "`"$installDir\sshd.exe`" -D" DisplayName= "OpenSSH SSH Server" start= auto type= own 2>&1 | ForEach-Object { Log-Info "  last-resort: $_" }
                Start-Sleep -Seconds 1
                $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
                if ($sshService) {
                    Log-OK "Service registered (last resort method)"
                    $sshdInstalled = $true
                } else {
                    Log-Err "ALL registration methods failed"
                }
            }
        } catch {
            Log-Err "Offline install failed: $($_.Exception.Message)"
        }
    } else {
        Log-Warn "No OpenSSH-Win64.zip found on USB at: $zipPath"
    }
}

if (-not $sshdInstalled) {
    # Method 4: Download from GitHub
    Log-Info "Trying Method 4: Download from GitHub..."
    $dlUrl = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.8.1.0p1-Preview/OpenSSH-Win64.zip"
    $dlPath = "$env:TEMP\OpenSSH-Win64.zip"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $dlUrl -OutFile $dlPath -UseBasicParsing -ErrorAction Stop
        $installDir = "C:\Program Files\OpenSSH-Win64"
        if (Test-Path $installDir) { Remove-Item -Recurse -Force $installDir }
        Expand-Archive -Path $dlPath -DestinationPath "C:\Program Files" -Force
        $sub = Get-ChildItem "C:\Program Files\OpenSSH-Win64" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sub -and (Test-Path "$($sub.FullName)\sshd.exe")) {
            Move-Item "$($sub.FullName)\*" $installDir -Force
            Remove-Item $sub.FullName -Force -ErrorAction SilentlyContinue
        }
        $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($machinePath -notlike "*OpenSSH*") {
            [Environment]::SetEnvironmentVariable("PATH", "$machinePath;$installDir", "Machine")
            $env:PATH = "$env:PATH;$installDir"
        }
        Push-Location $installDir
        powershell.exe -ExecutionPolicy Bypass -File "$installDir\install-sshd.ps1" 2>&1 | Out-Null
        Pop-Location
        Start-Sleep -Seconds 2
        $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
        if ($sshService) {
            Log-OK "Installed from GitHub download"
            $sshdInstalled = $true
        }
    } catch {
        Log-Err "GitHub download failed: $($_.Exception.Message)"
    }
}

if (-not $sshdInstalled) {
    Log-Err "ALL OPENSSH INSTALL METHODS FAILED"
    Log-Err "Manual installation required"
    Write-Host ""
    pause
    exit 1
}

# ============================================================================
# PHASE 3: CONFIGURE SSHD
# ============================================================================
Log-Phase 3 "CONFIGURE SSHD"

# Find sshd_config
$sshdConfig = $null
$configPaths = @(
    "$env:ProgramData\ssh\sshd_config",
    "C:\ProgramData\ssh\sshd_config",
    "C:\Program Files\OpenSSH-Win64\sshd_config",
    "$env:SystemRoot\System32\OpenSSH\sshd_config"
)
foreach ($p in $configPaths) {
    if (Test-Path $p) {
        $sshdConfig = $p
        break
    }
}

if (-not $sshdConfig) {
    # Create default config
    $sshdDir = "$env:ProgramData\ssh"
    if (-not (Test-Path $sshdDir)) {
        New-Item -ItemType Directory -Path $sshdDir -Force | Out-Null
    }
    $sshdConfig = "$sshdDir\sshd_config"
    Log-Info "Creating new sshd_config at $sshdConfig"
}

# Find where sshd.exe actually lives for the Subsystem path
$sshdExePath = (Get-Command sshd.exe -ErrorAction SilentlyContinue).Source
if (-not $sshdExePath) {
    $sshdExePath = "C:\Program Files\OpenSSH-Win64\sshd.exe"
}
$sshBinDir = Split-Path $sshdExePath -Parent
$sftpPath = Join-Path $sshBinDir "sftp-server.exe"
if (-not (Test-Path $sftpPath)) {
    # Try system OpenSSH location
    $sftpPath = "C:\Windows\System32\OpenSSH\sftp-server.exe"
}
$sshDataDir2 = "$env:ProgramData\ssh"

# Write a clean sshd_config optimized for cluster use
$sshdContent = @"
# NullSec Cluster - sshd_config
# Generated by nullsec-join.ps1

Port 22
ListenAddress 0.0.0.0

# Host Keys
HostKey $sshDataDir2/ssh_host_rsa_key
HostKey $sshDataDir2/ssh_host_ecdsa_key
HostKey $sshDataDir2/ssh_host_ed25519_key

# Authentication
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin no

# Performance - keep connections alive
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 10
MaxSessions 20

# Subsystem
Subsystem sftp $sftpPath

# CRITICAL: Do NOT use Match Group for administrators
# The default config breaks key auth for admin users
AuthorizedKeysFile .ssh/authorized_keys
"@

Set-Content -Path $sshdConfig -Value $sshdContent -Encoding ASCII -Force
Log-OK "sshd_config written: $sshdConfig"

# Remove the administrators_authorized_keys file if it exists (breaks key auth)
$adminKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
if (Test-Path $adminKeys) {
    Remove-Item $adminKeys -Force -ErrorAction SilentlyContinue
    Log-OK "Removed administrators_authorized_keys (was breaking key auth)"
}

# ============================================================================
# PHASE 4: DEPLOY SSH KEY
# ============================================================================
Log-Phase 4 "DEPLOY SSH KEYS"

# Deploy for current user
$userSSHDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $userSSHDir)) {
    New-Item -ItemType Directory -Path $userSSHDir -Force | Out-Null
}
$authKeysFile = "$userSSHDir\authorized_keys"

# Check if key already exists
$keyExists = $false
if (Test-Path $authKeysFile) {
    $content = Get-Content $authKeysFile -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains("YOUR_PUBKEY_HERE")) {
        $keyExists = $true
        Log-OK "NullSec key already present for $username"
    }
}
if (-not $keyExists) {
    Add-Content -Path $authKeysFile -Value $SSH_PUBKEY -Encoding ASCII
    Log-OK "SSH key deployed for $username"
}

# Set permissions (Windows ACL)
try {
    icacls $authKeysFile /inheritance:r /grant "${username}:F" /grant "SYSTEM:F" 2>$null | Out-Null
    icacls $userSSHDir /inheritance:r /grant "${username}:F" /grant "SYSTEM:F" 2>$null | Out-Null
    Log-OK "SSH key permissions set"
} catch {
    Log-Warn "Could not set strict permissions (SSH may still work)"
}

# Also deploy to administrators_authorized_keys (some OpenSSH versions need this for admin users)
$pgmDataSSH = "$env:ProgramData\ssh"
if (-not (Test-Path $pgmDataSSH)) {
    New-Item -ItemType Directory -Path $pgmDataSSH -Force | Out-Null
}
$adminAuthKeys = "$pgmDataSSH\administrators_authorized_keys"
Set-Content -Path $adminAuthKeys -Value $SSH_PUBKEY -Encoding ASCII -Force
icacls $adminAuthKeys /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F" 2>$null | Out-Null
Log-OK "SSH key also deployed to administrators_authorized_keys"

# Deploy for all other user profiles too
$profilesDir = Split-Path $env:USERPROFILE -Parent
$profiles = Get-ChildItem $profilesDir -Directory -ErrorAction SilentlyContinue
foreach ($prof in $profiles) {
    if ($prof.Name -match "^(Public|Default|Default User|All Users)$") { continue }
    $profSSH = Join-Path $prof.FullName ".ssh"
    $profKeys = Join-Path $profSSH "authorized_keys"
    if (-not (Test-Path $profSSH)) {
        New-Item -ItemType Directory -Path $profSSH -Force | Out-Null
    }
    $profKeyExists = $false
    if (Test-Path $profKeys) {
        $c = Get-Content $profKeys -Raw -ErrorAction SilentlyContinue
        if ($c -and $c.Contains("YOUR_PUBKEY_HERE")) { $profKeyExists = $true }
    }
    if (-not $profKeyExists) {
        Add-Content -Path $profKeys -Value $SSH_PUBKEY -Encoding ASCII
        icacls $profKeys /inheritance:r /grant "$($prof.Name):F" /grant "SYSTEM:F" 2>$null | Out-Null
        Log-OK "SSH key deployed for user: $($prof.Name)"
    }
}

# ============================================================================
# PHASE 5: START SSHD SERVICE
# ============================================================================
Log-Phase 5 "START SSHD SERVICE"

# Stop first if running (to pick up new config)
Stop-Service sshd -ErrorAction SilentlyContinue -Force
Start-Sleep -Seconds 1

# Set to automatic start
Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue

# Also set ssh-agent
$sshAgent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($sshAgent) {
    Set-Service -Name ssh-agent -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service ssh-agent -ErrorAction SilentlyContinue
}

# Pre-flight: make sure host keys exist and have correct permissions
Log-Info "Verifying host keys before starting sshd..."
$sshDataCheck = "$env:ProgramData\ssh"
if (-not (Test-Path $sshDataCheck)) {
    New-Item -ItemType Directory -Path $sshDataCheck -Force | Out-Null
}

# Find ssh-keygen
$sshKeygen = $null
foreach ($kgPath in @("C:\Program Files\OpenSSH-Win64\ssh-keygen.exe", "C:\Windows\System32\OpenSSH\ssh-keygen.exe")) {
    if (Test-Path $kgPath) { $sshKeygen = $kgPath; break }
}
if (-not $sshKeygen) {
    $sshKeygen = (Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue).Source
}

$keyTypes2 = @("rsa", "ecdsa", "ed25519")
foreach ($kt2 in $keyTypes2) {
    $kf = "$sshDataCheck\ssh_host_${kt2}_key"
    if (-not (Test-Path $kf)) {
        Log-Warn "Missing host key: ssh_host_${kt2}_key - generating..."
        if ($sshKeygen) {
            $genArgs = @("-t", $kt2, "-f", $kf, "-N", "", "-q")
            & $sshKeygen @genArgs 2>&1 | Out-Null
            if (-not (Test-Path $kf)) {
                "" | & $sshKeygen -t $kt2 -f $kf -q 2>&1 | Out-Null
            }
        }
        if (Test-Path $kf) {
            Log-OK "Generated missing host key: $kt2"
        } else {
            Log-Err "Could not generate host key: $kt2"
        }
    }
    # Fix permissions on host keys
    if (Test-Path $kf) {
        icacls $kf /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F" 2>$null | Out-Null
    }
}

# Fix permissions on the ssh directory
icacls $sshDataCheck /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F" 2>$null | Out-Null

# Validate sshd config before starting
Log-Info "Validating sshd_config..."
$sshdExeVal = (Get-Command sshd.exe -ErrorAction SilentlyContinue).Source
if ($sshdExeVal) {
    $configTest = & $sshdExeVal -t 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log-Err "sshd_config validation FAILED:"
        $configTest | ForEach-Object { Log-Err "  $_" }
        Log-Info "Falling back to default sshd_config..."
        # Write minimal config that is guaranteed to work
        $minConfig = "Port 22`nPasswordAuthentication yes`nPubkeyAuthentication yes`nSubsystem sftp sftp-server.exe"
        $cfgPath = "$env:ProgramData\ssh\sshd_config"
        Set-Content -Path $cfgPath -Value $minConfig -Encoding ASCII -Force
        Log-OK "Wrote minimal fallback sshd_config"
    } else {
        Log-OK "sshd_config validation passed"
    }
} else {
    Log-Warn "Cannot find sshd.exe to validate config"
}

# Start sshd
Start-Service sshd -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshService.Status -eq "Running") {
    Log-OK "sshd is RUNNING"
} else {
    Log-Err "sshd failed to start (Status: $($sshService.Status))"

    # Get the real error
    Log-Info "Checking System Event Log for sshd errors..."
    $sysEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=(Get-Date).AddMinutes(-5)} -MaxEvents 10 -ErrorAction SilentlyContinue
    foreach ($e in $sysEvents) {
        if ($e.Message -match "sshd|OpenSSH|7034|7031") {
            Log-Info "  EVENT: $($e.Message.Substring(0, [Math]::Min(200, $e.Message.Length)))"
        }
    }
    $sshEvents = Get-WinEvent -LogName "OpenSSH/Operational" -MaxEvents 5 -ErrorAction SilentlyContinue
    if ($sshEvents) {
        foreach ($e in $sshEvents) {
            Log-Info "  SSH EVENT: $($e.TimeCreated): $($e.Message)"
        }
    }

    # Try net start for better error message
    Log-Info "Retrying with net start..."
    $netResult = net start sshd 2>&1
    $netResult | ForEach-Object { Log-Info "  $_" }

    # If still not running, skip debug and just launch directly
    if ((Get-Service sshd -ErrorAction SilentlyContinue).Status -ne "Running") {
        # Kill any stale sshd processes
        Get-Process sshd -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1

        # Start sshd.exe directly as a background process
        Log-Info "Starting sshd.exe directly as background process..."
        if ($sshdExeVal) {
            Start-Process -FilePath $sshdExeVal -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            $portNow = netstat -an | Select-String ":22 " | Select-String "LISTEN"
            if ($portNow) {
                Log-OK "sshd running as background process (port 22 open)"
                # Create a startup scheduled task to keep it running
                $bgTask = "NullSec-SSHD-Direct"
                schtasks /Delete /TN $bgTask /F 2>$null | Out-Null
                schtasks /Create /TN $bgTask /TR "`"$sshdExeVal`"" /SC ONSTART /RU SYSTEM /RL HIGHEST /F 2>$null | Out-Null
                Log-OK "Created startup task to run sshd.exe on boot"
            } else {
                Log-Err "Even direct execution failed - checking error..."
                # Run with -e to log to stderr, capture briefly
                $proc = Start-Process -FilePath $sshdExeVal -ArgumentList "-e" -RedirectStandardError "$env:TEMP\sshd_error.log" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                if ($proc -and -not $proc.HasExited) { $proc.Kill() }
                if (Test-Path "$env:TEMP\sshd_error.log") {
                    $errLog = Get-Content "$env:TEMP\sshd_error.log" -ErrorAction SilentlyContinue | Select-Object -First 10
                    $errLog | ForEach-Object { Log-Err "  $_" }
                }
            }
        }
    }
}

# Verify port 22 is listening
Start-Sleep -Seconds 1
$listening = netstat -an | Select-String ":22 " | Select-String "LISTEN"
if ($listening) {
    Log-OK "Port 22 is LISTENING"
    $listening | ForEach-Object { Log-Info "  $($_.Line.Trim())" }
} else {
    Log-Err "Port 22 is NOT listening"
    Log-Info "All sshd-related ports:"
    netstat -an | Select-String "sshd" | ForEach-Object { Log-Info "  $($_.Line.Trim())" }
}

# ============================================================================
# PHASE 6: ENABLE REMOTE MANAGEMENT
# ============================================================================
Log-Phase 6 "ENABLE REMOTE MANAGEMENT"

# Enable ping (ICMP)
netsh advfirewall firewall add rule name="NullSec-ICMPv4" protocol=icmpv4:8,any dir=in action=allow 2>$null | Out-Null
Log-OK "ICMP ping enabled"

# Enable PowerShell Remoting (WinRM) for cluster management
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue 2>$null
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
    Log-OK "PowerShell Remoting (WinRM) enabled"
} catch {
    Log-Warn "WinRM setup had issues (non-critical)"
}

# Enable Remote Desktop
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction SilentlyContinue
    netsh advfirewall firewall set rule group="remote desktop" new enable=yes 2>$null | Out-Null
    Log-OK "Remote Desktop enabled"
} catch {
    Log-Warn "Could not enable RDP (non-critical)"
}

# Enable File/Printer Sharing (SMB - useful for cluster file transfer)
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes 2>$null | Out-Null
Log-OK "File and Printer Sharing enabled"

# Disable sleep/hibernate so cluster node stays online
powercfg -change -standby-timeout-ac 0 2>$null
powercfg -change -hibernate-timeout-ac 0 2>$null
powercfg -change -monitor-timeout-ac 0 2>$null
powercfg -h off 2>$null
Log-OK "Sleep/hibernate disabled (always-on mode)"

# ============================================================================
# PHASE 7: CLUSTER IDENTITY
# ============================================================================
Log-Phase 7 "CLUSTER IDENTITY"

# Create cluster config directory
$clusterDir = "$env:ProgramData\NullSec"
if (-not (Test-Path $clusterDir)) {
    New-Item -ItemType Directory -Path $clusterDir -Force | Out-Null
}

# Write cluster identity
$clusterConf = @"
CLUSTER_NAME=$CLUSTER_NAME
CLUSTER_ROLE=worker
CLUSTER_GATEWAY=$GATEWAY_IP
MESH_SUBNET=$MESH_SUBNET
HOSTNAME=$hostname
USERNAME=$username
IP_ADDRESS=$myIP
MAC_ADDRESS=$((Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).MacAddress)
JOINED=$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
OS=$([System.Environment]::OSVersion.VersionString)
ARCH=$env:PROCESSOR_ARCHITECTURE
CPU=$((Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name)
RAM_GB=$([math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1))
CORES=$((Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property NumberOfCores -Sum).Sum)
THREADS=$((Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum)
"@

Set-Content -Path "$clusterDir\cluster.conf" -Value $clusterConf -Encoding ASCII -Force
Log-OK "Cluster identity written to $clusterDir\cluster.conf"

# Create a scheduled task to keep sshd alive (in case Windows kills it)
$taskName = "NullSec-SSHD-Keepalive"
schtasks /Delete /TN $taskName /F 2>$null | Out-Null
$taskCmd = "powershell.exe -NoProfile -Command `"if ((Get-Service sshd -ErrorAction SilentlyContinue).Status -ne 'Running') { Start-Service sshd }`""
schtasks /Create /TN $taskName /TR $taskCmd /SC MINUTE /MO 5 /RU SYSTEM /RL HIGHEST /F 2>$null | Out-Null
Log-OK "SSHD keepalive scheduled task created (every 5 min)"

# Create startup task to ensure sshd starts on boot and firewall stays off
$startupName = "NullSec-Startup"
schtasks /Delete /TN $startupName /F 2>$null | Out-Null
$startupCmd = "powershell.exe -NoProfile -Command `"Start-Service sshd -ErrorAction SilentlyContinue; Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue`""
schtasks /Create /TN $startupName /TR $startupCmd /SC ONSTART /RU SYSTEM /RL HIGHEST /F 2>$null | Out-Null
Log-OK "Startup task created (sshd + firewall off on every boot)"

# ============================================================================
# PHASE 8: SELF-TEST
# ============================================================================
Log-Phase 8 "SELF-TEST"

$testsPassed = 0
$testsFailed = 0

# Test 1: sshd running
$svc = Get-Service sshd -ErrorAction SilentlyContinue
if ($svc.Status -eq "Running") {
    Log-OK "TEST 1/6: sshd service is running"
    $testsPassed++
} else {
    Log-Err "TEST 1/6: sshd service NOT running ($($svc.Status))"
    $testsFailed++
}

# Test 2: Port 22 listening
$portCheck = netstat -an | Select-String ":22 " | Select-String "LISTEN"
if ($portCheck) {
    Log-OK "TEST 2/6: Port 22 is listening"
    $testsPassed++
} else {
    Log-Err "TEST 2/6: Port 22 NOT listening"
    $testsFailed++
}

# Test 3: SSH key deployed
if (Test-Path $authKeysFile) {
    $keyContent = Get-Content $authKeysFile -Raw -ErrorAction SilentlyContinue
    if ($keyContent -and $keyContent.Contains("YOUR_PUBKEY_HERE")) {
        Log-OK "TEST 3/6: SSH key is deployed"
        $testsPassed++
    } else {
        Log-Err "TEST 3/6: SSH key file exists but key not found"
        $testsFailed++
    }
} else {
    Log-Err "TEST 3/6: authorized_keys file missing"
    $testsFailed++
}

# Test 4: Firewall off
$fwStatus = (Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true })
if (-not $fwStatus) {
    Log-OK "TEST 4/6: Firewall is disabled (all profiles)"
    $testsPassed++
} else {
    $enabledProfiles = ($fwStatus | ForEach-Object { $_.Name }) -join ", "
    Log-Err "TEST 4/6: Firewall still enabled on: $enabledProfiles"
    $testsFailed++
}

# Test 5: Cluster config exists
if (Test-Path "$clusterDir\cluster.conf") {
    Log-OK "TEST 5/6: Cluster identity file exists"
    $testsPassed++
} else {
    Log-Err "TEST 5/6: Cluster identity file missing"
    $testsFailed++
}

# Test 6: Can ping gateway
$pingResult = Test-Connection -ComputerName $GATEWAY_IP -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($pingResult) {
    Log-OK "TEST 6/6: Can reach gateway at $GATEWAY_IP"
    $testsPassed++
} else {
    Log-Warn "TEST 6/6: Cannot reach gateway at $GATEWAY_IP (may be on different subnet)"
    $testsFailed++
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Magenta
if ($testsFailed -eq 0) {
    Write-Host "  ALL TESTS PASSED ($testsPassed/$($testsPassed + $testsFailed))" -ForegroundColor Green
    Write-Host "  $hostname has joined the NullSec cluster!" -ForegroundColor Green
} else {
    Write-Host "  RESULTS: $testsPassed passed, $testsFailed failed" -ForegroundColor Yellow
    Write-Host "  Some features may need manual attention" -ForegroundColor Yellow
}
Write-Host ("=" * 60) -ForegroundColor Magenta
Write-Host ""
Write-Host "  Machine Info:" -ForegroundColor Cyan
Write-Host "    Hostname : $hostname" -ForegroundColor White
Write-Host "    Username : $username" -ForegroundColor White
Write-Host "    IP       : $myIP" -ForegroundColor White
Write-Host "    SSH Port : $SSH_PORT" -ForegroundColor White
Write-Host ""
Write-Host "  From the gateway ($GATEWAY_IP), run:" -ForegroundColor Cyan
Write-Host "    ssh $username@$myIP" -ForegroundColor Yellow
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Magenta
Write-Host ""
pause
