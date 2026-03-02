# NullSec Screensaver v5.1 — Fixed paint handler scoping
# Single process, one fullscreen form per monitor
# All shared state in $script: scope so event handlers can access it
# Paint handler uses $sender.Tag for per-screen index (no [scriptblock]::Create)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Double-buffered panel (flicker-free) ---
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

# ============================================================
# ALL shared variables in $script: scope so paint handlers work
# ============================================================

# --- Config ---
$script:RAIN_FONT_SIZE  = 14
$script:RAIN_SPACING    = 28
$script:RAIN_TRAIL      = 7
$script:RAIN_INTERVAL   = 120
$script:LOGO_FONT_SIZE  = 13
$script:LOGO_LINE_H     = 20
$script:HEX_CHARS       = "0123456789ABCDEF".ToCharArray()
$script:rng             = [System.Random]::new()

# --- Logo: all lines exactly 37 chars (1 border + 35 content + 1 border) ---
$hostname = $env:COMPUTERNAME
$B  = [char]0x2551   # pipe border
$CW = 35

function LogoLine([string]$content) {
    return [string]$B + $content.PadRight($CW).Substring(0, $CW) + [string]$B
}

$script:logo = @(
    [char]0x2554 + ([string][char]0x2550 * $CW) + [char]0x2557,
    (LogoLine ""),
    (LogoLine "  NULLSEC SECURITY CLUSTER"),
    (LogoLine ""),
    (LogoLine "    N U L L S E C"),
    (LogoLine ""),
    (LogoLine "  NODE: $hostname"),
    (LogoLine "  STATUS: MESH ACTIVE"),
    (LogoLine ""),
    [char]0x255A + ([string][char]0x2550 * $CW) + [char]0x255D
)

# --- GDI resources ---
$script:rainFont   = New-Object System.Drawing.Font("Consolas", $script:RAIN_FONT_SIZE, [System.Drawing.FontStyle]::Regular)
$script:logoFont   = New-Object System.Drawing.Font("Consolas", $script:LOGO_FONT_SIZE, [System.Drawing.FontStyle]::Bold)
$script:whiteBrush = [System.Drawing.Brushes]::White
$script:blackBrush = [System.Drawing.Brushes]::Black

$script:greenBrushes = @()
for ($t = 0; $t -lt $script:RAIN_TRAIL; $t++) {
    $fade = [math]::Max(30, 255 - $t * 35)
    $script:greenBrushes += New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $fade, 0))
}
$script:borderPenColor = [System.Drawing.Color]::FromArgb(0, 80, 0)

# --- Measure logo pixel size ---
$tmpBmp = New-Object System.Drawing.Bitmap(1, 1)
$tmpG   = [System.Drawing.Graphics]::FromImage($tmpBmp)
$tmpG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$script:logoPixelW = 0
foreach ($line in $script:logo) {
    $sz = $tmpG.MeasureString($line, $script:logoFont)
    if ($sz.Width -gt $script:logoPixelW) { $script:logoPixelW = $sz.Width }
}
$script:logoPixelH = $script:logo.Count * $script:LOGO_LINE_H
$tmpG.Dispose()
$tmpBmp.Dispose()

$boxPadding  = 20
$script:boxW = [int]($script:logoPixelW + $boxPadding * 2)
$script:boxH = [int]($script:logoPixelH + $boxPadding * 2)

# --- Per-screen data ---
$script:rainData   = @()
$script:panels     = @()
$script:forms      = @()
$script:frame      = 0
$script:mouseStart = @{}

# ===========================================
# PAINT HANDLER — single closure, reads Tag
# ===========================================
$script:paintHandler = {
    param($sender, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $sd = $script:rainData[$sender.Tag]
    if ($null -eq $sd) { return }

    # --- Matrix rain ---
    for ($c = 0; $c -lt $sd.Cols; $c++) {
        $hy = $sd.Drops[$c] * $script:RAIN_FONT_SIZE
        for ($t = 0; $t -lt $script:RAIN_TRAIL; $t++) {
            $y = $hy - $t * $script:RAIN_FONT_SIZE
            if ($y -ge (-$script:RAIN_FONT_SIZE) -and $y -lt $sd.H) {
                $ch = [string]$script:HEX_CHARS[$script:rng.Next($script:HEX_CHARS.Length)]
                $x  = $c * $script:RAIN_SPACING
                if ($t -eq 0) {
                    $g.DrawString($ch, $script:rainFont, $script:whiteBrush, $x, $y)
                } else {
                    $g.DrawString($ch, $script:rainFont, $script:greenBrushes[$t], $x, $y)
                }
            }
        }
    }

    # --- Logo box background ---
    $g.FillRectangle($script:blackBrush, $sd.BoxX, $sd.BoxY, $script:boxW, $script:boxH)
    $pen = New-Object System.Drawing.Pen($script:borderPenColor, 2)
    $g.DrawRectangle($pen, $sd.BoxX, $sd.BoxY, $script:boxW, $script:boxH)
    $pen.Dispose()

    # --- Logo text (pulsing green) ---
    $pulse = [math]::Max(100, [math]::Min(220, 160 + [int](60 * [math]::Sin($script:frame * 0.04))))
    $logoBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $pulse, 0))
    for ($i = 0; $i -lt $script:logo.Count; $i++) {
        $g.DrawString($script:logo[$i], $script:logoFont, $logoBrush, [float]$sd.LogoX, [float]($sd.LogoY + $i * $script:LOGO_LINE_H))
    }
    $logoBrush.Dispose()
}

# ===========================================
# EXIT HANDLER
# ===========================================
$script:exitAll = {
    $script:timer.Stop()
    [System.Windows.Forms.Cursor]::Show()
    foreach ($f in $script:forms) { try { $f.Close() } catch {} }
}

# ===========================================
# BUILD ONE FORM PER MONITOR
# ===========================================
$allScreens = [System.Windows.Forms.Screen]::AllScreens

for ($idx = 0; $idx -lt $allScreens.Count; $idx++) {
    $screen = $allScreens[$idx]
    $W = $screen.Bounds.Width
    $H = $screen.Bounds.Height
    $X = $screen.Bounds.X
    $Y = $screen.Bounds.Y

    # --- Form ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "NullSec"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location        = New-Object System.Drawing.Point($X, $Y)
    $form.Size            = New-Object System.Drawing.Size($W, $H)
    $form.BackColor       = [System.Drawing.Color]::Black
    $form.TopMost         = $true
    $form.ShowInTaskbar   = $false
    $form.KeyPreview      = $true

    # --- Panel (Tag = screen index for paint handler) ---
    $panel = New-Object BufferedPanel
    $panel.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $panel.BackColor = [System.Drawing.Color]::Black
    $panel.Tag       = $idx
    $form.Controls.Add($panel)

    # --- Rain state ---
    $cols  = [math]::Floor($W / $script:RAIN_SPACING)
    $drops = New-Object int[] $cols
    for ($c = 0; $c -lt $cols; $c++) { $drops[$c] = $script:rng.Next(-20, 0) }

    # --- Logo centering (relative to form origin 0,0) ---
    $bx = [int](($W - $script:boxW) / 2)
    $by = [int](($H - $script:boxH) / 2)
    $lx = [int]($bx + $boxPadding)
    $ly = [int]($by + $boxPadding)

    $script:rainData += @{
        W = $W; H = $H; Cols = $cols; Drops = $drops
        BoxX = $bx; BoxY = $by; LogoX = $lx; LogoY = $ly
    }

    # --- Wire paint handler ---
    $panel.Add_Paint($script:paintHandler)

    # --- Exit on key/click ---
    $form.Add_KeyDown($script:exitAll)
    $panel.Add_MouseDown($script:exitAll)

    # --- Exit on mouse move (>10px threshold) ---
    $panel.Add_MouseMove({
        param($s, $e)
        $key = "m" + $s.Tag
        if (-not $script:mouseStart.ContainsKey($key)) {
            $script:mouseStart[$key] = $e.Location
            return
        }
        $ms = $script:mouseStart[$key]
        if ([math]::Abs($e.X - $ms.X) -gt 10 -or [math]::Abs($e.Y - $ms.Y) -gt 10) {
            & $script:exitAll
        }
    })

    $script:forms  += $form
    $script:panels += $panel
}

# ===========================================
# ANIMATION TIMER (single, drives all screens)
# ===========================================
$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = $script:RAIN_INTERVAL
$script:timer.Add_Tick({
    $script:frame++
    for ($si = 0; $si -lt $script:rainData.Count; $si++) {
        $sd = $script:rainData[$si]
        for ($c = 0; $c -lt $sd.Cols; $c++) {
            $sd.Drops[$c]++
            if ($sd.Drops[$c] * $script:RAIN_FONT_SIZE -gt $sd.H + $script:RAIN_TRAIL * $script:RAIN_FONT_SIZE) {
                $sd.Drops[$c] = $script:rng.Next(-15, -1)
            }
        }
        $script:panels[$si].Invalidate()
    }
})

# ===========================================
# LAUNCH
# ===========================================
[System.Windows.Forms.Cursor]::Hide()

# Show secondary forms first
for ($i = 1; $i -lt $script:forms.Count; $i++) {
    $script:forms[$i].Show()
}

# Primary form: start timer + run message loop
$script:forms[0].Add_Shown({
    foreach ($f in $script:forms) { $f.TopMost = $true; $f.BringToFront() }
    $script:forms[0].Activate()
    $script:panels[0].Focus()
    $script:timer.Start()
})

[System.Windows.Forms.Application]::Run($script:forms[0])
