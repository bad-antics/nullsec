# ============================================================================
# NullSec Cluster Keepalive - Windows Nodes
# Runs every 5 minutes via Scheduled Task
# Ensures SSH stays running and gateway is reachable
# ============================================================================

$ErrorActionPreference = "SilentlyContinue"
$LogFile = "C:\ProgramData\NullSec\keepalive.log"
$Gateway = "192.168.1.1"
$GatewayPort = 22

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] $Message"
    Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue
    # Trim log to last 500 lines
    if (Test-Path $LogFile) {
        $lines = Get-Content $LogFile -ErrorAction SilentlyContinue
        if ($lines.Count -gt 500) {
            $lines[-500..-1] | Set-Content $LogFile -ErrorAction SilentlyContinue
        }
    }
}

function Ensure-SSHRunning {
    $sshd = Get-Service sshd -ErrorAction SilentlyContinue
    if ($null -eq $sshd) {
        Write-Log "WARN: sshd service not found - attempting reinstall"
        # Try to start sshd.exe directly as fallback
        $sshdPath = "$env:SystemRoot\System32\OpenSSH\sshd.exe"
        if (-not (Test-Path $sshdPath)) {
            $sshdPath = "$env:ProgramFiles\OpenSSH-Win64\sshd.exe"
        }
        if (Test-Path $sshdPath) {
            $running = Get-Process sshd -ErrorAction SilentlyContinue
            if (-not $running) {
                Write-Log "Starting sshd.exe directly: $sshdPath"
                Start-Process -FilePath $sshdPath -WindowStyle Hidden
            } else {
                Write-Log "OK: sshd process running (no service)"
            }
        } else {
            Write-Log "ERROR: Cannot find sshd.exe anywhere"
        }
        return
    }

    if ($sshd.Status -ne "Running") {
        Write-Log "WARN: sshd stopped - restarting"
        try {
            Start-Service sshd
            Set-Service sshd -StartupType Automatic
            Write-Log "OK: sshd restarted"
        } catch {
            Write-Log "ERROR: Failed to restart sshd - $($_.Exception.Message)"
            # Fallback: start process directly
            $sshdPath = "$env:SystemRoot\System32\OpenSSH\sshd.exe"
            if (Test-Path $sshdPath) {
                Start-Process -FilePath $sshdPath -WindowStyle Hidden
                Write-Log "OK: sshd started via direct process launch"
            }
        }
    }
}

function Ensure-FirewallOff {
    $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    foreach ($p in $profiles) {
        if ($p.Enabled) {
            Write-Log "WARN: Firewall profile $($p.Name) is enabled - disabling"
            Set-NetFirewallProfile -Name $p.Name -Enabled False -ErrorAction SilentlyContinue
        }
    }
    # Also via netsh as backup
    $state = netsh advfirewall show allprofiles state 2>$null | Select-String "ON"
    if ($state) {
        netsh advfirewall set allprofiles state off 2>$null
        Write-Log "WARN: Disabled firewall via netsh"
    }
}

function Ensure-Port22Open {
    $listening = netstat -an 2>$null | Select-String ":22 " | Select-String "LISTENING"
    if (-not $listening) {
        Write-Log "WARN: Port 22 not listening - restarting sshd"
        Ensure-SSHRunning
        Start-Sleep -Seconds 3
        $listening2 = netstat -an 2>$null | Select-String ":22 " | Select-String "LISTENING"
        if ($listening2) {
            Write-Log "OK: Port 22 now listening after restart"
        } else {
            Write-Log "ERROR: Port 22 still not listening after restart"
        }
    }
}

function Test-GatewayReachable {
    $ping = Test-Connection -ComputerName $Gateway -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $ping) {
        Write-Log "WARN: Gateway $Gateway unreachable via ping"
        # Try TCP connect to SSH port
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.ConnectAsync($Gateway, $GatewayPort).Wait(3000) | Out-Null
            if ($tcp.Connected) {
                Write-Log "OK: Gateway reachable via TCP:22 (ICMP blocked)"
                $tcp.Close()
                return $true
            }
        } catch {}
        Write-Log "ERROR: Gateway completely unreachable"

        # Try to fix network
        Repair-Network
        return $false
    }
    return $true
}

function Repair-Network {
    Write-Log "Attempting network repair..."

    # Release/renew DHCP if using DHCP
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notmatch "Virtual|VPN|TAP|Hyper-V" }
    foreach ($adapter in $adapters) {
        $ipconfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
        if ($ipconfig) {
            # Check if DHCP
            $dhcp = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($dhcp.PrefixOrigin -eq "Dhcp") {
                Write-Log "Renewing DHCP on $($adapter.Name)"
                ipconfig /release $adapter.Name 2>$null
                Start-Sleep -Seconds 2
                ipconfig /renew $adapter.Name 2>$null
            }
        }
    }

    # Flush DNS and ARP
    ipconfig /flushdns 2>$null
    arp -d * 2>$null

    Write-Log "Network repair attempted"
}

function Ensure-SSHKeys {
    # Make sure authorized_keys still has our key
    $keyFile = "$env:USERPROFILE\.ssh\authorized_keys"
    $nullsecKey = "AAAA_YOUR_PUBKEY"
    if (Test-Path $keyFile) {
        $content = Get-Content $keyFile -ErrorAction SilentlyContinue
        if ($content -notmatch $nullsecKey) {
            Write-Log "WARN: NullSec SSH key missing from authorized_keys"
        }
    } else {
        Write-Log "WARN: authorized_keys file missing"
    }
}

function Register-KeepAliveTask {
    $taskName = "NullSec-Keepalive"
    $existing = schtasks /query /tn $taskName 2>$null
    if (-not $existing) {
        Write-Log "Registering $taskName scheduled task"
        $scriptPath = "C:\ProgramData\NullSec\nullsec-keepalive.ps1"

        # Copy self to ProgramData
        if (-not (Test-Path $scriptPath)) {
            Copy-Item -Path $PSCommandPath -Destination $scriptPath -Force -ErrorAction SilentlyContinue
        }

        schtasks /create /tn $taskName /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" /sc MINUTE /mo 5 /ru SYSTEM /rl HIGHEST /f 2>$null
        Write-Log "OK: Scheduled task created - runs every 5 minutes"
    }
}

function Register-StartupTask {
    $taskName = "NullSec-Startup"
    $existing = schtasks /query /tn $taskName 2>$null
    if (-not $existing) {
        $scriptPath = "C:\ProgramData\NullSec\nullsec-keepalive.ps1"
        schtasks /create /tn $taskName /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" /sc ONSTART /delay 0000:30 /ru SYSTEM /rl HIGHEST /f 2>$null
        Write-Log "OK: Startup task created - runs 30s after boot"
    }
}

# ============================================================================
# Main
# ============================================================================

New-Item -ItemType Directory -Path "C:\ProgramData\NullSec" -Force | Out-Null

Write-Log "--- Keepalive check starting ---"

# 1. Make sure SSH is running
Ensure-SSHRunning

# 2. Make sure firewall is off
Ensure-FirewallOff

# 3. Check port 22
Ensure-Port22Open

# 4. Check SSH keys
Ensure-SSHKeys

# 5. Check gateway connectivity
$gwOk = Test-GatewayReachable
if ($gwOk) {
    Write-Log "OK: All checks passed - node healthy"
} else {
    Write-Log "WARN: Gateway unreachable - node may be isolated"
}

# 6. Ensure tasks are registered
Register-KeepAliveTask
Register-StartupTask

Write-Log "--- Keepalive check complete ---"
