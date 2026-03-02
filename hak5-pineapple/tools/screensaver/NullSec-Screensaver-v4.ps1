# NullSec Screensaver v4.0 - Per-Monitor WinForms/GDI+ (one form per screen)
# Spawns a separate fullscreen form on each monitor with independent rain + centered logo
param(
    [int]$MonitorIndex = -1  # -1 = spawn all monitors, 0+ = single monitor mode
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Double-buffered panel for flicker-free rendering
Add-Type @"
using System;
using System.Windows.Forms;
public class BufferedPanel : Panel {
    public BufferedPanel() {
        this.DoubleBuffered = true;
        this.SetStyle(
            ControlStyles.AllPaintingInWmPaint |
            ControlStyles.UserPaint |
            ControlStyles.OptimizedDoubleBuffer, true);
        this.UpdateStyles();
    }
}
"@

$allScreens = [System.Windows.Forms.Screen]::AllScreens

# If multi-monitor and no specific index, spawn child processes for each monitor
if ($MonitorIndex -eq -1 -and $allScreens.Count -gt 1) {
    $myPath = $MyInvocation.MyCommand.Path
    $children = @()
    for ($i = 0; $i -lt $allScreens.Count; $i++) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$myPath`" -MonitorIndex $i"
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $children += [System.Diagnostics.Process]::Start($psi)
    }
    # Wait for any child to exit (user activity), then kill all
    while ($true) {
        Start-Sleep -Milliseconds 500
        $exited = $false
        foreach ($c in $children) {
            if ($c.HasExited) { $exited = $true; break }
        }
        if ($exited) {
            foreach ($c in $children) {
                if (-not $c.HasExited) { try { $c.Kill() } catch {} }
            }
            break
        }
    }
    exit
}

# Single monitor mode (or only 1 monitor)
if ($MonitorIndex -ge 0 -and $MonitorIndex -lt $allScreens.Count) {
    $screen = $allScreens[$MonitorIndex]
} else {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
}

$W = $screen.Bounds.Width
$H = $screen.Bounds.Height
$X = $screen.Bounds.X
$Y = $screen.Bounds.Y

$form = New-Object System.Windows.Forms.Form
$form.Text = "NullSec Screensaver"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Location = New-Object System.Drawing.Point($X, $Y)
$form.ClientSize = New-Object System.Drawing.Size($W, $H)
$form.BackColor = [System.Drawing.Color]::Black
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.KeyPreview = $true
[System.Windows.Forms.Cursor]::Hide()

$panel = New-Object BufferedPanel
$panel.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel.BackColor = [System.Drawing.Color]::Black
$form.Controls.Add($panel)

# --- Rain parameters ---
$fontSize = 16
$spacing = 36
$cols = [math]::Floor($W / $spacing)
$trail = 7
$hexChars = "0123456789ABCDEF".ToCharArray()
$rng = [System.Random]::new()

$drops = New-Object int[] $cols
for ($c = 0; $c -lt $cols; $c++) { $drops[$c] = $rng.Next(-20, 0) }

# --- Pre-create GDI+ resources ---
$rainFont = New-Object System.Drawing.Font("Consolas", ($fontSize - 2), [System.Drawing.FontStyle]::Regular)
$logoFont = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$nodeFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
$whiteBrush = [System.Drawing.Brushes]::White
$blackBrush = [System.Drawing.Brushes]::Black

$greenBrushes = @()
for ($t = 0; $t -lt $trail; $t++) {
    $fade = [math]::Max(30, 255 - $t * 35)
    $greenBrushes += New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $fade, 0))
}

# --- Logo (properly measured for centering) ---
$hostname = $env:COMPUTERNAME
$logoLines = @(
    [char]0x2554 + ([string][char]0x2550) * 33 + [char]0x2557,
    [char]0x2551 + "                                 " + [char]0x2551,
    [char]0x2551 + "   NULLSEC SECURITY CLUSTER      " + [char]0x2551,
    [char]0x2551 + "                                 " + [char]0x2551,
    [char]0x2551 + "   " + [char]0x2588+[char]0x2588+[char]0x2588 + " " + [char]0x2588+[char]0x2588 + " " + [char]0x2588+[char]0x2588+[char]0x2588 + "                  " + [char]0x2551,
    [char]0x2551 + "   " + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + "                    " + [char]0x2551,
    [char]0x2551 + "   " + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + "  " + [char]0x2588+[char]0x2588+[char]0x2588 + "                 " + [char]0x2551,
    [char]0x2551 + "                                 " + [char]0x2551,
    [char]0x2551 + "   NODE: $($hostname.PadRight(24))" + [char]0x2551,
    [char]0x2551 + "   NULLSEC MESH ACTIVE           " + [char]0x2551,
    [char]0x2551 + "                                 " + [char]0x2551,
    [char]0x255A + ([string][char]0x2550) * 33 + [char]0x255D
)

# Measure logo width for true centering
$measureBmp = New-Object System.Drawing.Bitmap(1, 1)
$measureG = [System.Drawing.Graphics]::FromImage($measureBmp)
$maxLogoWidth = 0
foreach ($line in $logoLines) {
    $sz = $measureG.MeasureString($line, $logoFont)
    if ($sz.Width -gt $maxLogoWidth) { $maxLogoWidth = $sz.Width }
}
$logoHeight = $logoLines.Count * 18
$measureG.Dispose()
$measureBmp.Dispose()

# Logo box dimensions (centered on this monitor's form)
$boxW = [int]($maxLogoWidth + 30)
$boxH = [int]($logoHeight + 30)
$boxX = [int](($W - $boxW) / 2)
$boxY = [int](($H - $boxH) / 2)
$logoStartX = [int](($W - $maxLogoWidth) / 2)
$logoStartY = [int](($H - $logoHeight) / 2)

$script:frame = 0
$script:mouseStart = $null

# --- Paint handler ---
$panel.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    # Draw rain columns
    for ($c = 0; $c -lt $cols; $c++) {
        $hy = $drops[$c] * $fontSize
        for ($t = 0; $t -lt $trail; $t++) {
            $y = $hy - $t * $fontSize
            if ($y -ge -$fontSize -and $y -lt $H) {
                $ch = [string]$hexChars[$rng.Next($hexChars.Length)]
                $x = $c * $spacing
                if ($t -eq 0) {
                    $g.DrawString($ch, $rainFont, $whiteBrush, $x, $y)
                } else {
                    $g.DrawString($ch, $rainFont, $greenBrushes[$t], $x, $y)
                }
            }
        }
    }

    # Logo background box (centered)
    $g.FillRectangle($blackBrush, $boxX, $boxY, $boxW, $boxH)
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 51, 0), 2)
    $g.DrawRectangle($borderPen, $boxX, $boxY, $boxW, $boxH)
    $borderPen.Dispose()

    # Logo text with pulse (centered)
    $pulse = [math]::Max(100, [math]::Min(220, 140 + [int](50 * [math]::Sin($script:frame * 0.05))))
    $logoBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $pulse, 0))
    for ($i = 0; $i -lt $logoLines.Count; $i++) {
        $g.DrawString($logoLines[$i], $logoFont, $logoBrush, [float]$logoStartX, [float]($logoStartY + $i * 18))
    }
    $logoBrush.Dispose()
})

# --- Animation timer ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
    $script:frame++
    for ($c = 0; $c -lt $cols; $c++) {
        $drops[$c]++
        if ($drops[$c] * $fontSize -gt $H + $trail * $fontSize) {
            $drops[$c] = $rng.Next(-15, -1)
        }
    }
    $panel.Invalidate()
})

# --- Exit on any input ---
$exitAction = {
    $timer.Stop()
    [System.Windows.Forms.Cursor]::Show()
    $form.Close()
}

$form.Add_KeyDown($exitAction)
$panel.Add_MouseDown($exitAction)
$panel.Add_MouseMove({
    param($s, $e)
    if ($null -eq $script:mouseStart) { $script:mouseStart = $e.Location; return }
    if ([math]::Abs($e.X - $script:mouseStart.X) -gt 10 -or
        [math]::Abs($e.Y - $script:mouseStart.Y) -gt 10) {
        $timer.Stop()
        [System.Windows.Forms.Cursor]::Show()
        $form.Close()
    }
})

# --- Launch ---
$form.Add_Shown({
    $form.Activate()
    $form.BringToFront()
    $panel.Focus()
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($form)
