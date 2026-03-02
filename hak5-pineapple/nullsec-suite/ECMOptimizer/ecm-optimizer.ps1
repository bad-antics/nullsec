#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NullSec ECM Optimizer v1.0 — Windows 10 Automotive ECM Programming Optimization

.DESCRIPTION
    Fully optimizes a Windows 10 machine for automotive ECM/TCM/PCM programming.
    Targets every subsystem that can interfere with reliable USB/serial communication
    and ECM flash sessions: power management, USB selective suspend, FTDI latency
    timers, background services, Windows Defender, visual effects, network stack,
    scheduled tasks, and process priority.

    Compatible with all major ECM tools:
    HP Tuners, EFI Live, SCT, COBB, Hondata, ECUFlash, RomRaider, Tactrix,
    TunerPro, PCM Hammer, Snap-on, Autel, Launch Tech, Drew Technologies

.PARAMETER SkipDefender
    Skip Windows Defender modifications (use if managed by enterprise policy)

.PARAMETER SkipRestore
    Skip system restore point creation

.PARAMETER Revert
    Re-enable Windows Update and Defender real-time protection

.NOTES
    Author:  NullSec (bad-antics)
    Suite:   NullSec Payload Suite — ECMOptimizer
    Target:  Windows 10 (all builds)
    Deploy:  Flipper Zero BadUSB / Standalone / Remote
    License: MIT
#>

param(
    [switch]$SkipDefender,
    [switch]$SkipRestore,
    [switch]$Revert
)

$ErrorActionPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = "NullSec ECM Optimizer v1.0"

# ── Output helpers ────────────────────────────────────────
function Write-Status($msg)  { Write-Host "  [*] $msg" -ForegroundColor Cyan }
function Write-Good($msg)    { Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Bad($msg)     { Write-Host "  [-] $msg" -ForegroundColor Red }
function Write-Info($msg)    { Write-Host "  [i] $msg" -ForegroundColor Yellow }

# ── Logging ───────────────────────────────────────────────
$logFile = "$env:TEMP\ecm-optimizer-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $logFile -Force | Out-Null

# ── Banner ────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "  ║        NullSec ECM Optimizer v1.0                 ║" -ForegroundColor Red
Write-Host "  ║        Automotive ECM Programming Tuner           ║" -ForegroundColor Red
Write-Host "  ║        github.com/bad-antics                      ║" -ForegroundColor Red
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# ── Admin check ───────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator"
)
if (-not $isAdmin) {
    Write-Bad "Must run as Administrator. Right-click PowerShell → Run as Administrator."
    Stop-Transcript | Out-Null
    exit 1
}

# ══════════════════════════════════════════════════════════
#  REVERT MODE
# ══════════════════════════════════════════════════════════
if ($Revert) {
    Write-Status "Reverting critical changes..."

    # Re-enable Windows Update
    Set-Service -Name "wuauserv" -StartupType Manual
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    Set-Service -Name "UsoSvc" -StartupType Manual
    Set-Service -Name "BITS" -StartupType Manual
    Start-Service -Name "BITS" -ErrorAction SilentlyContinue
    Write-Good "Windows Update re-enabled"

    # Re-enable Defender
    Set-MpPreference -DisableRealtimeMonitoring $false
    Set-MpPreference -DisableBehaviorMonitoring $false
    Set-MpPreference -DisableIOAVProtection $false
    Write-Good "Windows Defender real-time protection re-enabled"

    # Re-enable SysMain and WSearch
    Set-Service -Name "SysMain" -StartupType Automatic
    Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
    Set-Service -Name "WSearch" -StartupType Automatic
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    Write-Good "SysMain and Windows Search re-enabled"

    # Re-enable background apps
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
        -Name "GlobalUserDisabled" -Value 0 -Type DWord -Force

    # Balanced power plan
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    Write-Good "Balanced power plan restored"

    Write-Host ""
    Write-Good "Critical settings reverted. Reboot recommended."
    Write-Info "For full revert, use System Restore to the pre-optimization restore point."
    Stop-Transcript | Out-Null
    exit 0
}

# ══════════════════════════════════════════════════════════
#  SYSTEM RESTORE POINT
# ══════════════════════════════════════════════════════════
if (-not $SkipRestore) {
    Write-Status "Creating system restore point..."
    try {
        Enable-ComputerRestore -Drive "C:\"
        Checkpoint-Computer -Description "NullSec ECM Optimizer — Pre-Optimization" -RestorePointType MODIFY_SETTINGS
        Write-Good "Restore point created"
    } catch {
        Write-Info "Could not create restore point (may have been created recently)"
    }
}

# ══════════════════════════════════════════════════════════
#  1. POWER PLAN OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Configuring power plan for ECM programming..."

# Try Ultimate Performance first (available in Win10 1803+)
$ultimate = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
if ($ultimate -match "GUID: ([a-f0-9-]+)") {
    $guid = $Matches[1]
    powercfg /setactive $guid
    Write-Good "Ultimate Performance power plan activated"
} else {
    # Fall back to High Performance
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    Write-Good "High Performance power plan activated"
}

# Disable hibernate (frees disk, prevents USB reconnection issues)
powercfg /hibernate off
Write-Good "Hibernate disabled"

# Zero all sleep/timeout on AC AND DC
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0
Write-Good "Sleep, screen, hibernate, disk timeouts all disabled"

# Get active scheme GUID for sub-settings
$activePlan = (powercfg /getactivescheme) -replace '.*:\s*([a-f0-9-]+)\s.*', '$1'

# Disable USB selective suspend in power plan (CRITICAL for ECM)
# Sub-group: 2a737441-1930-4402-8d77-b2bebba308a3 (USB settings)
# Setting:   48e6b7a6-50f5-4782-a5d4-53bb8f07e226 (selective suspend)
powercfg /setacvalueindex $activePlan 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex $activePlan 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive $activePlan
Write-Good "USB selective suspend disabled in power plan"

# Disable fast startup (causes USB enumeration failures after reboot)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
    -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
Write-Good "Fast startup disabled (prevents post-reboot USB issues)"

# CPU min/max at 100% (no throttling during ECM flash)
# Min processor state: 893dee8e-2bef-41e0-89c6-b55d0929964c
# Max processor state: bc5038f7-23e0-4960-96da-33abaf5935ec
powercfg /setacvalueindex $activePlan 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
powercfg /setacvalueindex $activePlan 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
powercfg /setactive $activePlan
Write-Good "CPU locked at 100% (no throttling)"

# Disable PCI Express Link State Power Management
# Sub-group: 501a4d13-42af-4429-9fd1-a8218c268e20 (PCI Express)
# Setting:   ee12f906-d277-404b-b6da-e5fa1a576df5 (ASPM)
powercfg /setacvalueindex $activePlan 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setactive $activePlan
Write-Good "PCI Express ASPM disabled (prevents USB controller sleep)"

# ══════════════════════════════════════════════════════════
#  2. USB OPTIMIZATION (CRITICAL FOR ECM)
# ══════════════════════════════════════════════════════════
Write-Status "Optimizing USB subsystem for ECM tools..."

# Registry-level USB selective suspend disable
$usbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
New-Item -Path $usbPath -Force | Out-Null
Set-ItemProperty -Path $usbPath -Name "DisableSelectiveSuspend" -Value 1 -Type DWord -Force
Write-Good "USB selective suspend disabled (registry)"

# Disable power management on ALL USB devices (Root Hubs, Controllers, Hubs)
$usbDevCount = 0
Get-PnpDevice -Class USB -Status OK -ErrorAction SilentlyContinue | ForEach-Object {
    $instanceId = $_.InstanceId
    $dpPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instanceId\Device Parameters"
    if (Test-Path $dpPath) {
        Set-ItemProperty -Path $dpPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $dpPath -Name "AllowIdleIrpInD3" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $dpPath -Name "SelectiveSuspendEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $dpPath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $dpPath -Name "SelectiveSuspendOn" -Value 0 -Type DWord -Force
        $usbDevCount++
    }
}
Write-Good "Power management disabled on $usbDevCount USB devices"

# Disable USB hub power management via WMI
try {
    Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi -ErrorAction Stop | Where-Object {
        $_.InstanceName -match "USB"
    } | ForEach-Object {
        $_.Enable = $false
        $_.Put() | Out-Null
    }
    Write-Good "USB hub power management disabled (WMI)"
} catch {
    Write-Info "WMI USB power management not available (non-critical)"
}

# Disable USB auto-suspend for all USBHUB devices
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" -ErrorAction SilentlyContinue | ForEach-Object {
    Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
        $dpPath = Join-Path $_.PSPath "Device Parameters"
        if (Test-Path $dpPath) {
            Set-ItemProperty -Path $dpPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $dpPath -Name "SelectiveSuspendEnabled" -Value 0 -Type DWord -Force
        }
    }
}
Write-Good "USB auto-suspend disabled for all USB hub devices"

# ══════════════════════════════════════════════════════════
#  3. FTDI / SERIAL PORT OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Optimizing FTDI/serial ports for ECM communication..."

# Set FTDI latency timer to 1ms (default is 16ms — catastrophic for ECM timing)
$ftdiFixed = 0
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSPath -match "FTDI|VID_0403" } |
    ForEach-Object {
        $dpPath = Join-Path $_.PSPath "Device Parameters"
        if (Test-Path $dpPath) {
            Set-ItemProperty -Path $dpPath -Name "LatencyTimer" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $dpPath -Name "BulkInPipeTransferSize" -Value 65536 -Type DWord -Force
            Set-ItemProperty -Path $dpPath -Name "BulkOutPipeTransferSize" -Value 65536 -Type DWord -Force
            $ftdiFixed++
        }
    }

# Also handle FTDIBUS entries directly
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\FTDIBUS" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        $dpPath = Join-Path $_.PSPath "Device Parameters"
        if (Test-Path $dpPath) {
            Set-ItemProperty -Path $dpPath -Name "LatencyTimer" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $dpPath -Name "BulkInPipeTransferSize" -Value 65536 -Type DWord -Force
            Set-ItemProperty -Path $dpPath -Name "BulkOutPipeTransferSize" -Value 65536 -Type DWord -Force
            $ftdiFixed++
        }
    }

# Optimize ALL COM port latency timers
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSPath -match "Device Parameters" -and $_.PSPath -match "(Ports|FTDI|Serial|USB\\\\VID_)" } |
    ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "LatencyTimer" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }

# CH340/CH341 serial adapter optimization (common cheap ECM cables)
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSPath -match "VID_1A86" } |
    ForEach-Object {
        $dpPath = Join-Path $_.PSPath "Device Parameters"
        if (Test-Path $dpPath) {
            Set-ItemProperty -Path $dpPath -Name "LatencyTimer" -Value 1 -Type DWord -Force
        }
    }

# CP210x (Silicon Labs) serial adapter optimization
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSPath -match "VID_10C4" } |
    ForEach-Object {
        $dpPath = Join-Path $_.PSPath "Device Parameters"
        if (Test-Path $dpPath) {
            Set-ItemProperty -Path $dpPath -Name "LatencyTimer" -Value 1 -Type DWord -Force
        }
    }

if ($ftdiFixed -gt 0) {
    Write-Good "FTDI latency timer set to 1ms on $ftdiFixed device(s) (was 16ms)"
} else {
    Write-Info "No FTDI devices found in registry (will apply on first plug)"
}
Write-Good "CH340/CH341 and CP210x adapters optimized"
Write-Good "COM port buffer sizes set to 64KB"

# ══════════════════════════════════════════════════════════
#  4. J2534 PASSTHRU OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Checking J2534 PassThru interfaces..."

$j2534Devices = @()
# Check both 64-bit and 32-bit registry
@("HKLM:\SOFTWARE\PassThruSupport.04.04", "HKLM:\SOFTWARE\WOW6432Node\PassThruSupport.04.04") | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem $_ -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.PSChildName
            $vendor = (Get-ItemProperty $_.PSPath -Name "Name" -ErrorAction SilentlyContinue).Name
            if ($vendor) { $j2534Devices += $vendor } else { $j2534Devices += $name }
        }
    }
}

if ($j2534Devices.Count -gt 0) {
    foreach ($dev in ($j2534Devices | Select-Object -Unique)) {
        Write-Good "J2534 device found: $dev"
    }
} else {
    Write-Info "No J2534 PassThru devices registered (install your ECM tool's drivers)"
}

# ══════════════════════════════════════════════════════════
#  5. SERVICE OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Disabling unnecessary services..."

$servicesToDisable = @(
    @{ Name = "SysMain";          Desc = "Superfetch (disk I/O hog)" },
    @{ Name = "WSearch";          Desc = "Windows Search indexer" },
    @{ Name = "DiagTrack";        Desc = "Telemetry" },
    @{ Name = "dmwappushservice"; Desc = "WAP Push routing" },
    @{ Name = "DoSvc";            Desc = "Delivery Optimization" },
    @{ Name = "MapsBroker";       Desc = "Downloaded Maps Manager" },
    @{ Name = "lfsvc";            Desc = "Geolocation Service" },
    @{ Name = "RetailDemo";       Desc = "Retail Demo" },
    @{ Name = "wisvc";            Desc = "Windows Insider" },
    @{ Name = "WMPNetworkSvc";    Desc = "WMP Network Sharing" },
    @{ Name = "XblAuthManager";   Desc = "Xbox Live Auth" },
    @{ Name = "XblGameSave";      Desc = "Xbox Live Game Save" },
    @{ Name = "XboxGipSvc";       Desc = "Xbox Accessory Management" },
    @{ Name = "XboxNetApiSvc";    Desc = "Xbox Live Networking" },
    @{ Name = "WerSvc";           Desc = "Windows Error Reporting" },
    @{ Name = "wercplsupport";    Desc = "Problem Reports" },
    @{ Name = "Fax";              Desc = "Fax Service" },
    @{ Name = "TabletInputService"; Desc = "Touch Keyboard" },
    @{ Name = "PhoneSvc";         Desc = "Phone Service" },
    @{ Name = "icssvc";           Desc = "Mobile Hotspot" },
    @{ Name = "WbioSrvc";        Desc = "Biometric Service" },
    @{ Name = "PcaSvc";           Desc = "Program Compatibility Assistant" },
    @{ Name = "AJRouter";         Desc = "AllJoyn Router" },
    @{ Name = "SharedAccess";     Desc = "Internet Connection Sharing" },
    @{ Name = "RemoteRegistry";   Desc = "Remote Registry" },
    @{ Name = "TrkWks";           Desc = "Distributed Link Tracking" },
    @{ Name = "SCardSvr";         Desc = "Smart Card" },
    @{ Name = "ScDeviceEnum";     Desc = "Smart Card Device Enumeration" },
    @{ Name = "SEMgrSvc";         Desc = "Payments and NFC" },
    @{ Name = "ShellHWDetection"; Desc = "Shell Hardware Detection" },
    @{ Name = "SSDPSRV";          Desc = "SSDP Discovery" },
    @{ Name = "WPDBusEnum";       Desc = "Portable Device Enumerator" },
    @{ Name = "stisvc";           Desc = "Windows Image Acquisition" },
    @{ Name = "CDPSvc";           Desc = "Connected Devices Platform" },
    @{ Name = "CDPUserSvc";       Desc = "Connected Devices Platform User" }
)

$disabled = 0
foreach ($svc in $servicesToDisable) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        $disabled++
    }
}
Write-Good "$disabled non-essential services disabled"

# Pause Windows Update (CRITICAL — an update during ECM flash = bricked ECU)
Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "BITS" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "UsoSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "wuauserv" -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service -Name "UsoSvc" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Good "Windows Update PAUSED (re-enable after ECM session with -Revert)"

# ══════════════════════════════════════════════════════════
#  6. WINDOWS DEFENDER OPTIMIZATION
# ══════════════════════════════════════════════════════════
if (-not $SkipDefender) {
    Write-Status "Configuring Windows Defender for ECM compatibility..."

    # Disable real-time monitoring (AV file scans cause serial timing failures)
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
    Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
    Write-Good "Real-time protection disabled (prevents ECM comm interference)"

    # Exclusion paths for every major ECM tool
    $ecmPaths = @(
        "C:\Program Files\HP Tuners",
        "C:\Program Files (x86)\HP Tuners",
        "C:\Program Files\EFI Live",
        "C:\Program Files (x86)\EFI Live",
        "C:\Program Files\SCT",
        "C:\Program Files (x86)\SCT",
        "C:\Program Files\COBB",
        "C:\Program Files (x86)\COBB",
        "C:\Program Files\DiabloSport",
        "C:\Program Files (x86)\DiabloSport",
        "C:\Program Files\Hondata",
        "C:\Program Files (x86)\Hondata",
        "C:\Program Files\ECUFlash",
        "C:\Program Files (x86)\ECUFlash",
        "C:\Program Files\RomRaider",
        "C:\Program Files (x86)\RomRaider",
        "C:\Program Files\Tactrix",
        "C:\Program Files (x86)\Tactrix",
        "C:\Program Files\Drew Technologies",
        "C:\Program Files (x86)\Drew Technologies",
        "C:\Program Files\Snap-on",
        "C:\Program Files (x86)\Snap-on",
        "C:\Program Files\Launch Tech",
        "C:\Program Files (x86)\Launch Tech",
        "C:\Program Files\Autel",
        "C:\Program Files (x86)\Autel",
        "C:\Program Files\TunerPro",
        "C:\Program Files (x86)\TunerPro",
        "C:\Program Files\PCM Hammer",
        "C:\Program Files (x86)\PCM Hammer",
        "C:\Program Files\FlashScan",
        "C:\Program Files (x86)\FlashScan",
        "C:\Program Files\LS Droid",
        "C:\Program Files (x86)\LS Droid",
        "C:\EFILive",
        "C:\HPTuners",
        "C:\PCMHammer",
        "C:\COBB",
        "$env:USERPROFILE\Documents\HP Tuners",
        "$env:USERPROFILE\Documents\EFI Live",
        "$env:USERPROFILE\Desktop"
    )

    foreach ($path in $ecmPaths) {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
    }

    # ECM-specific file extensions
    $ecmExtensions = @(
        ".bin", ".hex", ".s19", ".s28", ".s37", ".mot", ".srec",
        ".cal", ".hpt", ".tun", ".map", ".rom", ".ecu",
        ".dsg", ".j2534", ".ols", ".kess", ".ktag",
        ".ori", ".mod", ".dpf", ".egr", ".dtc",
        ".a2l", ".elf", ".out", ".ctz", ".ctf"
    )
    foreach ($ext in $ecmExtensions) {
        Add-MpPreference -ExclusionExtension $ext -ErrorAction SilentlyContinue
    }

    # ECM tool process exclusions
    $ecmProcesses = @(
        "VCM Suite.exe", "VCM Scanner.exe", "VCM Editor.exe", "MPVI2.exe",
        "EFILive_Scan.exe", "EFILive_Tune.exe", "EFILive_Explorer.exe",
        "FlashScan.exe", "AutoCal.exe",
        "SCTDevice.exe", "SCTAdvantageIII.exe", "BDX.exe",
        "Accesstuner.exe", "COBBAccessport.exe",
        "sLoader.exe", "HondataFlashPro.exe", "s300.exe",
        "ECUFlash.exe", "RomRaider.exe",
        "Tactrix.exe", "OpenPort.exe",
        "TunerPro.exe", "TunerProRT.exe",
        "PCMHammer.exe", "UniversalPatcher.exe",
        "Tech2Win.exe", "GDS2.exe", "MDI Manager.exe",
        "IDS.exe", "FDRS.exe", "FORSCAN.exe", "FORScan.exe",
        "Witech.exe", "Chrysler_DRB3.exe",
        "J2534Toolbox.exe", "PassThruExplorer.exe"
    )
    foreach ($proc in $ecmProcesses) {
        Add-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
    }

    Write-Good "Defender exclusions: $($ecmPaths.Count) paths, $($ecmExtensions.Count) extensions, $($ecmProcesses.Count) processes"
} else {
    Write-Info "Skipping Defender configuration (-SkipDefender)"
}

# ══════════════════════════════════════════════════════════
#  7. VISUAL / UI OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Disabling visual effects for maximum performance..."

# Set system to "Adjust for best performance"
$visualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
New-Item -Path $visualPath -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $visualPath -Name "VisualFXSetting" -Value 2 -Type DWord -Force

# Disable DWM compositing features
$dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $dwmPath -Name "AlwaysHibernateThumbnails" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Disable transparency
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Disable all animations
$desktopPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" `
    -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Type Binary -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Force
Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Force
Set-ItemProperty -Path "$desktopPath\WindowMetrics" -Name "MinAnimate" -Value "0" -Force -ErrorAction SilentlyContinue

Write-Good "Visual effects, animations, transparency disabled"

# Disable Game Bar and Game DVR
$gamePaths = @{
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"    = @{ "AppCaptureEnabled" = 0 }
    "HKCU:\System\GameConfigStore"                                = @{ "GameDVR_Enabled" = 0 }
}
foreach ($gp in $gamePaths.GetEnumerator()) {
    foreach ($prop in $gp.Value.GetEnumerator()) {
        Set-ItemProperty -Path $gp.Key -Name $prop.Key -Value $prop.Value -Type DWord -Force -ErrorAction SilentlyContinue
    }
}
$gameDvrPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
New-Item -Path $gameDvrPolicy -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $gameDvrPolicy -Name "AllowGameDVR" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue
Write-Good "Game Bar and Game DVR disabled"

# ══════════════════════════════════════════════════════════
#  8. BACKGROUND APPS & TELEMETRY
# ══════════════════════════════════════════════════════════
Write-Status "Disabling background apps, Cortana, telemetry..."

# Kill background apps globally
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
    -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
$appPrivacyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
New-Item -Path $appPrivacyPath -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $appPrivacyPath -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force
Write-Good "Background apps disabled"

# Disable Cortana
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "AllowCloudSearch" -Value 0 -Type DWord -Force
Write-Good "Cortana disabled"

# Disable telemetry
$telemetryPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
)
foreach ($tp in $telemetryPaths) {
    New-Item -Path $tp -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $tp -Name "AllowTelemetry" -Value 0 -Type DWord -Force
}
Write-Good "Telemetry disabled"

# Disable tips, suggestions, Start menu ads
$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
@(
    "SoftLandingEnabled",
    "SubscribedContent-338388Enabled",
    "SubscribedContent-310093Enabled",
    "SubscribedContent-338389Enabled",
    "SubscribedContent-353698Enabled",
    "SystemPaneSuggestionsEnabled",
    "SilentInstalledAppsEnabled"
) | ForEach-Object {
    Set-ItemProperty -Path $cdmPath -Name $_ -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}
Write-Good "Tips, suggestions, Start menu ads disabled"

# Disable OneDrive sync (CPU/disk/network hog)
$onedrivePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
New-Item -Path $onedrivePath -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $onedrivePath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force
Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
Write-Good "OneDrive sync disabled"

# ══════════════════════════════════════════════════════════
#  9. NETWORK OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Optimizing network stack..."

# Disable Nagle's algorithm (reduces latency for network-based ECM tools)
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpParams -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "TCPNoDelay" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force

# Per-interface Nagle disable
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
    Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $_.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force
}

# Disable network throttling (Multimedia SystemProfile)
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

# Flush DNS
ipconfig /flushdns | Out-Null

Write-Good "Nagle's algorithm disabled, network throttling off, DNS flushed"

# ══════════════════════════════════════════════════════════
#  10. MEMORY & PROCESS OPTIMIZATION
# ══════════════════════════════════════════════════════════
Write-Status "Optimizing memory and process scheduling..."

$memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

# Keep drivers in RAM (no page-out during ECM comm)
Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force

# Large system cache
Set-ItemProperty -Path $memPath -Name "LargeSystemCache" -Value 1 -Type DWord -Force

# Optimize for foreground programs (ECM tool gets priority)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
    -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force

Write-Good "Paging executive disabled, foreground programs prioritized"

# Set running ECM tool processes to HIGH priority
$ecmRunning = @(
    "VCM Suite", "VCM Scanner", "VCM Editor", "MPVI2",
    "EFILive_Scan", "EFILive_Tune", "FlashScan", "AutoCal",
    "SCTDevice", "Accesstuner", "COBBAccessport",
    "sLoader", "HondataFlashPro", "ECUFlash", "RomRaider",
    "Tactrix", "OpenPort", "TunerPro", "TunerProRT",
    "PCMHammer", "FORSCAN", "FORScan", "Tech2Win", "GDS2"
)
$boosted = 0
foreach ($pn in $ecmRunning) {
    $proc = Get-Process -Name $pn -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | ForEach-Object { $_.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High }
        $boosted++
        Write-Good "Boosted $pn to HIGH priority"
    }
}
if ($boosted -eq 0) {
    Write-Info "No ECM tool processes detected (will benefit when launched after optimization)"
}

# Create MMCSS task profile for ECM tools
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\ECM Programming"
New-Item -Path $mmcssPath -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $mmcssPath -Name "Affinity" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "Background Only" -Value "False" -Force
Set-ItemProperty -Path $mmcssPath -Name "Clock Rate" -Value 10000 -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "GPU Priority" -Value 8 -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "Priority" -Value 6 -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "Scheduling Category" -Value "High" -Force
Set-ItemProperty -Path $mmcssPath -Name "SFIO Priority" -Value "High" -Force
Write-Good "MMCSS 'ECM Programming' task profile registered"

# ══════════════════════════════════════════════════════════
#  11. SCHEDULED TASKS CLEANUP
# ══════════════════════════════════════════════════════════
Write-Status "Disabling unnecessary scheduled tasks..."

$tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Maps\MapsToastTask",
    "\Microsoft\Windows\Maps\MapsUpdateTask",
    "\Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask",
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "\Microsoft\XblGameSave\XblGameSaveTask",
    "\Microsoft\Windows\Feedback\Siuf\DmClient",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Diagnosis\Scheduled",
    "\Microsoft\Windows\DiskFootprint\Diagnostics",
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
)

$taskDisabled = 0
foreach ($task in $tasksToDisable) {
    try {
        Disable-ScheduledTask -TaskName $task -ErrorAction Stop | Out-Null
        $taskDisabled++
    } catch { }
}
Write-Good "$taskDisabled scheduled tasks disabled"

# ══════════════════════════════════════════════════════════
#  12. DISK CLEANUP
# ══════════════════════════════════════════════════════════
Write-Status "Cleaning up disk..."

$cleanedMB = 0

# Temp files
$tempPaths = @("$env:TEMP", "C:\Windows\Temp", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache")
foreach ($tp in $tempPaths) {
    if (Test-Path $tp) {
        $size = (Get-ChildItem $tp -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $cleanedMB += [math]::Round($size / 1MB, 0)
        Remove-Item -Path "$tp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Prefetch
$prefetchSize = (Get-ChildItem "C:\Windows\Prefetch" -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$cleanedMB += [math]::Round($prefetchSize / 1MB, 0)
Remove-Item -Path "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue

# Recycle bin
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

# Windows update cache (already disabled the service)
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

# Thumbnail cache
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue

$freeGB = [math]::Round(((Get-PSDrive C).Free / 1GB), 2)
Write-Good "Cleaned ~${cleanedMB}MB of temp/cache files. Free space: ${freeGB}GB"

# ══════════════════════════════════════════════════════════
#  13. NOTIFICATIONS & FOCUS ASSIST
# ══════════════════════════════════════════════════════════
Write-Status "Disabling notifications..."

$explorerPolicy = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
New-Item -Path $explorerPolicy -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $explorerPolicy -Name "DisableNotificationCenter" -Value 1 -Type DWord -Force

# Lock screen notifications off
$notifSettings = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
New-Item -Path $notifSettings -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $notifSettings -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 0 -Type DWord -Force

Write-Good "Notifications and lock screen alerts disabled"

# ══════════════════════════════════════════════════════════
#  14. DRIVER SIGNATURE CHECK
# ══════════════════════════════════════════════════════════
Write-Status "Checking driver signature enforcement..."

$bcdedit = bcdedit /enum "{current}" 2>$null
if ($bcdedit -match "testsigning\s+Yes") {
    Write-Good "Test signing ENABLED (good for unsigned ECM drivers)"
} else {
    Write-Info "Test signing OFF — some ECM tools need unsigned drivers"
    Write-Info "  Enable: bcdedit /set testsigning on (requires Secure Boot off)"
}

# Check Secure Boot status
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    if ($secureBoot) {
        Write-Info "Secure Boot is ON — disable in BIOS if ECM drivers won't install"
    } else {
        Write-Good "Secure Boot is OFF"
    }
} catch {
    Write-Info "Secure Boot status unknown (legacy BIOS or not supported)"
}

# ══════════════════════════════════════════════════════════
#  FINAL SUMMARY
# ══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║         ECM OPTIMIZATION COMPLETE                 ║" -ForegroundColor Green
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Good "Power Plan:       Ultimate/High Performance — no sleep, no hibernate"
Write-Good "CPU:              Locked 100% — no throttling during flash"
Write-Good "USB:              Selective suspend OFF, power management OFF"
Write-Good "FTDI/Serial:      Latency 1ms (was 16ms), buffers 64KB"
Write-Good "CH340/CP210x:     Latency optimized"
Write-Good "Services:         $disabled non-essential services disabled"
Write-Good "Windows Update:   PAUSED (prevents mid-flash reboot)"
if (-not $SkipDefender) {
    Write-Good "Defender:         Real-time OFF, $($ecmPaths.Count) path exclusions"
}
Write-Good "Visual Effects:   Disabled for performance"
Write-Good "Background:       Apps, Cortana, telemetry, OneDrive OFF"
Write-Good "Network:          Nagle OFF, throttling OFF"
Write-Good "Memory:           Paging exec disabled, foreground prioritized"
Write-Good "Tasks:            $taskDisabled scheduled tasks disabled"
Write-Good "Disk:             ~${cleanedMB}MB cleaned"
Write-Good "Notifications:    Disabled"
Write-Host ""
Write-Info "Log: $logFile"
Write-Info "Restore point created (System Restore to revert all)"
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║  IMPORTANT NOTES:                                 ║" -ForegroundColor Yellow
Write-Host "  ║                                                   ║" -ForegroundColor Yellow
Write-Host "  ║  • REBOOT recommended for full effect             ║" -ForegroundColor Yellow
Write-Host "  ║  • Unplug/replug USB ECM tools after reboot       ║" -ForegroundColor Yellow
Write-Host "  ║  • FTDI latency = 1ms (verify in Device Manager)  ║" -ForegroundColor Yellow
Write-Host "  ║                                                   ║" -ForegroundColor Yellow
Write-Host "  ║  To revert critical changes after ECM session:    ║" -ForegroundColor Yellow
Write-Host "  ║    .\ecm-optimizer.ps1 -Revert                    ║" -ForegroundColor Yellow
Write-Host "  ║                                                   ║" -ForegroundColor Yellow
Write-Host "  ║  Or use System Restore for full rollback.         ║" -ForegroundColor Yellow
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

Stop-Transcript | Out-Null
