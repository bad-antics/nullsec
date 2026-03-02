# ECMOptimizer — NullSec Payload Suite

> Fully optimizes a Windows 10 machine for automotive ECM/TCM/PCM programming.
> Eliminates every background process, power state, and USB issue that can interfere
> with a reliable ECM flash session.

## The Problem

Automotive ECM programming is timing-critical. A single glitch during a flash can
brick a $2,000+ ECU. Windows 10 out of the box will:

- **USB selective suspend** — kernel sleeps the USB port mid-flash
- **FTDI latency timer at 16ms** — 16x slower than needed for J2534 comms
- **Windows Update** — reboots the machine during a 45-minute reflash
- **Defender real-time scan** — intercepts every serial packet for virus scanning
- **Background services** — 30+ services competing for CPU/disk/network
- **Power management** — CPU throttling, sleep states, hibernate interrupts
- **Nagle's algorithm** — buffers network packets (kills network-based ECM tools)

This payload fixes **all of it** in one shot.

## Deployment Options

### Option 1: Flipper Zero BadUSB (plug & go)

1. Copy `payload.txt` to your Flipper Zero SD card under `SD Card/badusb/`
2. Plug Flipper into the target Windows 10 machine
3. Navigate to **Bad USB** → select `payload.txt` → **Run**
4. Payload opens admin PowerShell, runs all optimizations (~60 seconds)
5. Reboot when done

### Option 2: Standalone PowerShell Script

```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
.\ecm-optimizer.ps1
```

### Option 3: One-liner (download & run)

```powershell
# If hosted on your own server
iex (irm 'https://your-server.com/ecm-optimizer.ps1')
```

## What It Optimizes

| Category | Before | After |
|----------|--------|-------|
| Power Plan | Balanced (throttles CPU) | Ultimate Performance / CPU locked 100% |
| Sleep/Hibernate | Enabled (machine sleeps mid-flash) | All disabled |
| USB Selective Suspend | Enabled (drops USB mid-comm) | **Disabled** at power plan + registry + WMI |
| FTDI Latency Timer | 16ms default | **1ms** (16x faster serial response) |
| FTDI Buffer Size | 4KB default | **64KB** |
| CH340/CP210x Adapters | Default | Latency optimized |
| Fast Startup | Enabled (causes USB enumeration bugs) | **Disabled** |
| PCI Express ASPM | Enabled (USB controller sleeps) | **Disabled** |
| Windows Update | Auto (can reboot mid-flash) | **Paused** |
| Defender Real-time | On (scans every serial packet) | **Off** + ECM exclusions |
| Services | 30+ unnecessary running | **Disabled** |
| Visual Effects | Fancy animations | **Best Performance** |
| Game Bar/DVR | Running | **Disabled** |
| Background Apps | All running | **Disabled** |
| Cortana | Running | **Disabled** |
| Telemetry | Sending data | **Disabled** |
| OneDrive | Syncing | **Disabled** |
| Nagle's Algorithm | Buffering packets | **Disabled** |
| Network Throttling | Enabled | **Disabled** |
| Memory Paging | Paging drivers to disk | **Disabled** (drivers stay in RAM) |
| Process Priority | Normal | **Foreground programs prioritized** |
| Scheduled Tasks | Running diagnostics | **Disabled** |
| Notifications | Interrupting | **Disabled** |

## Supported ECM Tools

Defender exclusions pre-configured for:

- **HP Tuners** (VCM Suite, VCM Scanner, VCM Editor, MPVI2)
- **EFI Live** (FlashScan, AutoCal, Scan Tool, Tune Tool)
- **SCT** (Advantage III, BDX)
- **COBB** (Accesstuner, Accessport)
- **Hondata** (FlashPro, s300)
- **ECUFlash / RomRaider** (Tactrix OpenPort)
- **TunerPro / TunerPro RT**
- **PCM Hammer / Universal Patcher**
- **FORScan**
- **GM Tech2Win / GDS2 / MDI Manager**
- **Ford IDS / FDRS**
- **Chrysler DRB III / wiTECH**
- **Drew Technologies** (J2534 Toolbox, CarDAQ)
- **Snap-on / Launch Tech / Autel**

## ECM File Extensions Excluded

`.bin` `.hex` `.s19` `.s28` `.s37` `.mot` `.srec` `.cal` `.hpt` `.tun`
`.map` `.rom` `.ecu` `.dsg` `.j2534` `.ols` `.kess` `.ktag` `.ori` `.mod`
`.dpf` `.egr` `.dtc` `.a2l` `.elf` `.out` `.ctz` `.ctf`

## Revert Changes

### Quick revert (standalone script)

```powershell
.\ecm-optimizer.ps1 -Revert
```

This re-enables:
- Windows Update
- Windows Defender real-time protection
- SysMain and Windows Search
- Background apps
- Balanced power plan

### Full revert

Use **System Restore** to roll back to the restore point created before optimization.

### Manual revert commands

```powershell
# Re-enable Windows Update
Set-Service wuauserv -StartupType Manual
Start-Service wuauserv

# Re-enable Defender
Set-MpPreference -DisableRealtimeMonitoring $false

# Balanced power plan
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-SkipDefender` | Don't modify Windows Defender (use if enterprise-managed) |
| `-SkipRestore` | Don't create a system restore point |
| `-Revert` | Undo critical changes (Update, Defender, power plan) |

## J2534 PassThru

The script automatically detects and lists any J2534 PassThru devices registered
in the Windows registry (both 32-bit and 64-bit). If none are found, install your
ECM tool's drivers first.

## Important Notes

- **Always reboot** after running for full effect
- **Unplug and replug** your ECM USB tool after reboot
- **Verify FTDI latency** in Device Manager → COM port → Properties → Port Settings → Advanced → Latency Timer (should show 1ms)
- **Windows Update is paused** — re-enable after your ECM session
- **Defender is off** — re-enable after your session or use `-Revert`
- Some ECM tools need **unsigned drivers** — if driver install fails, run `bcdedit /set testsigning on` (requires Secure Boot off in BIOS)

## Author

**NullSec** (bad-antics) — [github.com/bad-antics](https://github.com/bad-antics)

Part of the NullSec Payload Suite.
