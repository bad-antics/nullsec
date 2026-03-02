# NullSec Idle Watcher v2.0 - Launches screensaver after 10 min idle
# Single-process multi-form screensaver (no child processes needed)
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleTime {
    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    public static uint GetIdleMs() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        GetLastInputInfo(ref info);
        return (uint)Environment.TickCount - info.dwTime;
    }
}
"@

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$screensaver = Join-Path $scriptDir "NullSec-Screensaver.ps1"
$idleTimeout = 600000  # 10 minutes in ms
$ssProcess = $null

# Helper: kill any orphaned screensaver processes
function Kill-OrphanScreensavers {
    Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | ForEach-Object {
        $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmd -like "*NullSec-Screensaver.ps1*" -and $cmd -notlike "*IdleWatch*") {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

while ($true) {
    $idle = [IdleTime]::GetIdleMs()

    if ($idle -ge $idleTimeout -and ($null -eq $ssProcess -or $ssProcess.HasExited)) {
        # Kill any orphans before launching
        Kill-OrphanScreensavers
        Start-Sleep -Milliseconds 500

        # Launch screensaver with UseShellExecute for proper desktop context
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$screensaver`""
        $psi.UseShellExecute = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $ssProcess = [System.Diagnostics.Process]::Start($psi)
    }

    if ($idle -lt 5000 -and $null -ne $ssProcess -and -not $ssProcess.HasExited) {
        # v4.1 is single-process, just kill it directly
        try { $ssProcess.Kill() } catch {}
        $ssProcess = $null
        # Kill any strays too
        Start-Sleep -Milliseconds 200
        Kill-OrphanScreensavers
    }

    Start-Sleep -Seconds 2
}
