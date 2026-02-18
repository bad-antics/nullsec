# ==============================================================================
# NullSec Cluster -- Windows Auto-Join Script
# Run via: nullsec-join-mesh.bat (double-click, auto-elevates)
# Or: powershell -ExecutionPolicy Bypass -File nullsec-join-mesh.ps1
# ==============================================================================

$ErrorActionPreference = "Continue"
$GATEWAY_IP = "192.168.1.1"
$SSH_PUBKEY = "ssh-ed25519 AAAA_YOUR_PUBKEY_HERE nullsec-node@nullsec"
$CLUSTER_USER = $env:USERNAME
$ERRORS = @()

function Log-OK    { param($msg) Write-Host "    $msg" -ForegroundColor Green }
function Log-Warn  { param($msg) Write-Host "    $msg" -ForegroundColor Yellow }
function Log-Err   { param($msg) Write-Host "    [!] $msg" -ForegroundColor Red; $script:ERRORS += $msg }
function Log-Phase { param($msg) Write-Host "  $msg" -ForegroundColor Cyan }

# -- Banner --
Write-Host ""
Write-Host "  ======================================================" -ForegroundColor Cyan
Write-Host "    NullSec Cluster -- Windows Auto-Join                 " -ForegroundColor Cyan
Write-Host "  ======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Machine:  $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  User:     $CLUSTER_USER" -ForegroundColor White
Write-Host "  Gateway:  $GATEWAY_IP" -ForegroundColor White
try { Write-Host "  OS:       $((Get-CimInstance Win32_OperatingSystem).Caption)" -ForegroundColor White } catch {}
Write-Host ""

# -- Check Admin --
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [!] ERROR: Must run as Administrator!" -ForegroundColor Red
    Write-Host "  Right-click this script -> Run with PowerShell (as Admin)" -ForegroundColor Yellow
    Read-Host "  Press Enter to exit"
    exit 1
}

# ==============================================================================
# PHASE 1: Install & Configure OpenSSH Server
# ==============================================================================
Write-Host "  [1/7] Installing OpenSSH Server..." -ForegroundColor Cyan

$sshInstalled = $false
try {
    # Method 1: Windows Capability (Win10 1809+)
    $sshCapability = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object Name -like 'OpenSSH.Server*'
    if ($sshCapability.State -ne 'Installed') {
        Write-Host "    Installing via Windows Capability..." -ForegroundColor Yellow
        $result = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
        if ($result.RestartNeeded) {
            Write-Host "    [!] Reboot required after install -- will continue setup" -ForegroundColor Yellow
        }
        Log-OK "OpenSSH Server installed (Capability)"
    } else {
        Log-OK "OpenSSH Server already installed"
    }
    $sshInstalled = $true
} catch {
    Write-Host "    Capability method failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    Trying alternative install methods..." -ForegroundColor Yellow
}

if (-not $sshInstalled) {
    try {
        # Method 2: Optional Feature (older Win10)
        $feature = Get-WindowsOptionalFeature -Online -FeatureName OpenSSH.Server -ErrorAction Stop
        if ($feature.State -ne 'Enabled') {
            Enable-WindowsOptionalFeature -Online -FeatureName OpenSSH.Server -NoRestart -ErrorAction Stop | Out-Null
        }
        Log-OK "OpenSSH Server installed (Optional Feature)"
        $sshInstalled = $true
    } catch {
        Write-Host "    Optional Feature method failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $sshInstalled) {
    try {
        # Method 3: Download from GitHub (works on any Windows)
        Write-Host "    Downloading OpenSSH from GitHub..." -ForegroundColor Yellow
        $sshPath = "$env:ProgramFiles\OpenSSH-Win64"
        if (-not (Test-Path "$sshPath\sshd.exe")) {
            $url = "https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip"
            $zip = "$env:TEMP\OpenSSH-Win64.zip"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
            Expand-Archive -Path $zip -DestinationPath $env:ProgramFiles -Force
            Remove-Item $zip -Force
            & "$sshPath\install-sshd.ps1"
        }
        Log-OK "OpenSSH Server installed (GitHub)"
        $sshInstalled = $true
    } catch {
        Write-Host "    [!] FAILED: Could not install OpenSSH: $($_.Exception.Message)" -ForegroundColor Red
        $ERRORS += "OpenSSH install failed"
    }
}

if ($sshInstalled) {
    # Start and auto-start SSH
    try {
        Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
        Start-Service sshd -ErrorAction Stop
        Log-OK "SSH service: auto-start, running"
    } catch {
        # Service might need a moment after fresh install
        Write-Host "    Waiting for sshd service to register..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        try {
            Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
            Start-Service sshd -ErrorAction Stop
            Log-OK "SSH service: auto-start, running"
        } catch {
            Write-Host "    [!] FAILED to start sshd: $($_.Exception.Message)" -ForegroundColor Red
            $ERRORS += "sshd service failed to start"
        }
    }
}

# Firewall rule for SSH -- nuke ALL existing SSH rules and create a clean one
Write-Host "    Configuring firewall..." -ForegroundColor Yellow
try {
    # Remove any existing SSH rules (stale, disabled, or misconfigured)
    Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -like "*SSH*" -or $_.DisplayName -like "*sshd*" -or $_.Name -like "*SSH*"
    } | Remove-NetFirewallRule -ErrorAction SilentlyContinue

    # Create fresh rule
    New-NetFirewallRule -Name "NullSec-SSH-Allow" -DisplayName "NullSec SSH (port 22)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 `
        -Profile Any | Out-Null
    Log-OK "Firewall: SSH port 22 open (all profiles)"
} catch {
    Write-Host "    PowerShell firewall failed, using netsh..." -ForegroundColor Yellow
    # Fallback: netsh -- works on ALL Windows versions
    netsh advfirewall firewall delete rule name="NullSec SSH (port 22)" 2>$null
    netsh advfirewall firewall delete rule name="OpenSSH Server (sshd)" 2>$null
    netsh advfirewall firewall add rule name="NullSec SSH (port 22)" dir=in action=allow protocol=TCP localport=22 profile=any
    if ($LASTEXITCODE -eq 0) {
        Log-OK "Firewall: SSH port 22 open (netsh)"
    } else {
        Write-Host "    [!] FAILED to create firewall rule" -ForegroundColor Red
        $ERRORS += "Firewall rule creation failed"
    }
}

# Also ensure Windows Defender Firewall is not blocking the sshd.exe binary itself
try {
    $sshdExe = (Get-Command sshd.exe -ErrorAction SilentlyContinue).Source
    if (-not $sshdExe) { $sshdExe = "$env:SystemRoot\System32\OpenSSH\sshd.exe" }
    if (Test-Path $sshdExe) {
        netsh advfirewall firewall delete rule name="NullSec sshd binary" 2>$null
        netsh advfirewall firewall add rule name="NullSec sshd binary" dir=in action=allow program="$sshdExe" enable=yes profile=any 2>$null
        Log-OK "Firewall: sshd.exe binary allowed"
    }
} catch {}

# Verify SSH is actually listening
Start-Sleep -Seconds 2
$listening = Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Where-Object State -eq 'Listen'
if ($listening) {
    Log-OK "Verified: sshd listening on port 22"
} else {
    Write-Host "    [!] WARNING: sshd not listening on port 22!" -ForegroundColor Red
    Write-Host "    Attempting restart..." -ForegroundColor Yellow
    Restart-Service sshd -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $listening = Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Where-Object State -eq 'Listen'
    if ($listening) {
        Log-OK "Verified after restart: sshd listening"
    } else {
        Write-Host "    [!] FAILED: sshd still not listening" -ForegroundColor Red
        $ERRORS += "sshd not listening on port 22"
    }
}

# ==============================================================================
# PHASE 2: SSH Key Authentication
# ==============================================================================
Write-Host "  [2/7] Setting up SSH key authentication..." -ForegroundColor Cyan

# For regular users
$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
$authKeysFile = "$sshDir\authorized_keys"

# Add key if not already there
$existingKeys = ""
if (Test-Path $authKeysFile) { $existingKeys = Get-Content $authKeysFile -Raw -ErrorAction SilentlyContinue }
if ($existingKeys -notlike "*YOUR_PUBKEY_HERE*") {
    Add-Content -Path $authKeysFile -Value $SSH_PUBKEY
    Log-OK "Key added to user authorized_keys"
} else {
    Log-OK "Key already in user authorized_keys"
}

# For admin users, Windows SSH uses ProgramData\ssh\administrators_authorized_keys
$adminAuthKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
$adminExisting = ""
if (Test-Path $adminAuthKeys) { $adminExisting = Get-Content $adminAuthKeys -Raw -ErrorAction SilentlyContinue }
if ($adminExisting -notlike "*YOUR_PUBKEY_HERE*") {
    Add-Content -Path $adminAuthKeys -Value $SSH_PUBKEY
    # Fix permissions -- must be owned by SYSTEM/Administrators only
    icacls $adminAuthKeys /inheritance:r /grant "SYSTEM:(F)" /grant "Administrators:(F)" | Out-Null
    Log-OK "Key added to admin authorized_keys"
} else {
    Log-OK "Key already in admin authorized_keys"
}

# Configure sshd for pubkey auth and fix the admin key file path
$sshdConfig = "$env:ProgramData\ssh\sshd_config"
if (Test-Path $sshdConfig) {
    $sshdContent = Get-Content $sshdConfig -Raw
    $modified = $false

    # Enable pubkey auth
    if ($sshdContent -notmatch "(?m)^PubkeyAuthentication yes") {
        $sshdContent = $sshdContent -replace "(?m)^#?\s*PubkeyAuthentication.*", "PubkeyAuthentication yes"
        $modified = $true
    }

    # CRITICAL: Comment out the Match Group administrators block that redirects admin keys
    # This is the #1 reason SSH key auth fails on Windows -- it forces admin users to use
    # administrators_authorized_keys instead of their own ~/.ssh/authorized_keys
    if ($sshdContent -match "(?m)^Match Group administrators") {
        $sshdContent = $sshdContent -replace "(?m)^(Match Group administrators)", "#`$1"
        $sshdContent = $sshdContent -replace "(?m)^(\s+AuthorizedKeysFile.*__PROGRAMDATA__)", "#`$1"
        $modified = $true
        Log-OK "Disabled admin group key redirect"
    }

    if ($modified) {
        Set-Content -Path $sshdConfig -Value $sshdContent
        Restart-Service sshd -ErrorAction SilentlyContinue
        Log-OK "sshd_config: PubkeyAuthentication enabled"
    }
} else {
    Write-Host "    [!] sshd_config not found -- sshd may not be installed" -ForegroundColor Red
    $ERRORS += "sshd_config not found"
}

# ==============================================================================
# PHASE 3: Enable Ping (ICMP)
# ==============================================================================
Log-Phase "[3/7] Enabling ping (ICMP)..."

try {
    $icmpRule = Get-NetFirewallRule -DisplayName "Allow ICMPv4" -ErrorAction SilentlyContinue
    if (-not $icmpRule) {
        New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 `
            -Direction Inbound -Action Allow -Enabled True | Out-Null
    }
    Log-OK "ICMP ping allowed"
} catch {
    # Fallback to netsh
    netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:8,any dir=in action=allow 2>$null
    Log-OK "ICMP ping allowed (netsh)"
}

# ==============================================================================
# PHASE 4: Power Settings -- Never Sleep
# ==============================================================================
Log-Phase "[4/7] Configuring power: never sleep..."

try {
    powercfg /change standby-timeout-ac 0 2>$null
    powercfg /change hibernate-timeout-ac 0 2>$null
    powercfg /change monitor-timeout-ac 0 2>$null
    powercfg /hibernate off 2>$null
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    Log-OK "Sleep disabled, hibernate off, high performance"
} catch {
    Log-Warn "Some power settings may not have applied: $($_.Exception.Message)"
}

# ==============================================================================
# PHASE 5: Disable Auto-Reboot & Fast Startup
# ==============================================================================
Log-Phase "[5/7] Disabling auto-reboot & fast startup..."

try {
    $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
    Set-ItemProperty -Path $auPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -ErrorAction SilentlyContinue

    $powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $powerPath -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    Log-OK "Auto-reboot blocked, fast startup off"
} catch {
    Log-Warn "Some reboot settings may not have applied: $($_.Exception.Message)"
}

# ==============================================================================
# PHASE 6: Network -- Keep Connected
# ==============================================================================
Log-Phase "[6/7] Hardening network connection..."

try {
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        try {
            Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
        } catch {}
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy-Efficient Ethernet" `
                -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        } catch {}
    }

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -Name "KeepConn" -Value 3600 -Type DWord -ErrorAction SilentlyContinue

    Log-OK "Network adapters hardened"
} catch {
    Log-Warn "Some network settings may not have applied: $($_.Exception.Message)"
}

# ==============================================================================
# PHASE 7: Create Cluster Identity & Keepalive Task
# ==============================================================================
Write-Host "  [7/7] Creating cluster identity & keepalive..." -ForegroundColor Cyan

# Write cluster identity file
$nullsecDir = "$env:ProgramData\nullsec"
if (-not (Test-Path $nullsecDir)) { New-Item -ItemType Directory -Path $nullsecDir -Force | Out-Null }

$myIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" } | Select-Object -First 1).IPAddress
$cpuName = (Get-CimInstance Win32_Processor).Name
$cores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
$ramMB = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1024)
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name

$identityContent = @"
HOSTNAME=$env:COMPUTERNAME
IP=$myIP
USER=$CLUSTER_USER
ROLE=worker
CORES=$cores
RAM_MB=$ramMB
CPU=$cpuName
GPU=$gpu
GATEWAY=$GATEWAY_IP
JOINED=$(Get-Date -Format "yyyy-MM-dd")
"@
Set-Content "$nullsecDir\cluster.conf" $identityContent

Write-Host "    Identity: $env:COMPUTERNAME ($cores cores, ${ramMB}MB, $gpu)" -ForegroundColor White

# Create a scheduled task that pings the gateway every 5 min to stay in ARP table
$keepaliveContent = @"

# NullSec Keepalive -- runs every 5 minutes
ping -n 1 $GATEWAY_IP | Out-Null

# Verify SSH is running, restart if not
`$sshdStatus = Get-Service sshd -ErrorAction SilentlyContinue
if (`$sshdStatus -and `$sshdStatus.Status -ne 'Running') {
    Start-Service sshd -ErrorAction SilentlyContinue
}

# Ensure firewall rule still exists
`$rule = Get-NetFirewallRule -Name 'NullSec-SSH-Allow' -ErrorAction SilentlyContinue
if (-not `$rule) {
    New-NetFirewallRule -Name 'NullSec-SSH-Allow' -DisplayName 'NullSec SSH (port 22)' ``
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 ``
        -Profile Any -ErrorAction SilentlyContinue | Out-Null
}
"@
Set-Content "$nullsecDir\keepalive.ps1" $keepaliveContent

# Register scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$nullsecDir\keepalive.ps1`""
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RunOnlyIfNetworkAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "NullSec-Keepalive" -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Log-OK "Keepalive task: every 5 min"

# ==============================================================================
# DONE -- Summary
# ==============================================================================
Write-Host ""
if ($ERRORS.Count -gt 0) {
    Write-Host "  ======================================================" -ForegroundColor Red
    Write-Host "  [!] Completed with $($ERRORS.Count) error(s):" -ForegroundColor Red
    Write-Host "  ======================================================" -ForegroundColor Red
    foreach ($err in $ERRORS) {
        Write-Host "    - $err" -ForegroundColor Red
    }
    Write-Host ""
} else {
    Write-Host "  ======================================================" -ForegroundColor Green
    Write-Host "  [OK] Machine joined NullSec Cluster!" -ForegroundColor Green
    Write-Host "  ======================================================" -ForegroundColor Green
}
Write-Host ""
Write-Host "  Hostname:    $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  IP:          $myIP" -ForegroundColor White
Write-Host "  CPU:         $cpuName ($cores cores)" -ForegroundColor White
Write-Host "  RAM:         $ramMB MB" -ForegroundColor White
Write-Host "  GPU:         $gpu" -ForegroundColor White
try {
    $sshStatus = (Get-Service sshd -ErrorAction SilentlyContinue).Status
    Write-Host "  SSH:         $sshStatus" -ForegroundColor White
} catch { Write-Host "  SSH:         Unknown" -ForegroundColor Yellow }
try {
    $portCheck = Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Where-Object State -eq 'Listen'
    Write-Host "  Port 22:     $(if ($portCheck) {'Listening'} else {'NOT LISTENING'})" -ForegroundColor White
} catch { Write-Host "  Port 22:     Unknown" -ForegroundColor Yellow }
Write-Host "  Power:       Never sleep, no auto-reboot" -ForegroundColor White
Write-Host "  Keepalive:   Every 5 min to $GATEWAY_IP" -ForegroundColor White
Write-Host ""
Write-Host "  From the gateway ($GATEWAY_IP), run:" -ForegroundColor Cyan
Write-Host "  nullsec-cluster.sh add $myIP $CLUSTER_USER" -ForegroundColor Yellow
Write-Host ""
