# NullSec Screensaver v5.0 — Clean rewrite
# Single process, one fullscreen form per monitor
# Monospaced ASCII logo with exact character-count centering

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

# === CONFIG ===
$RAIN_FONT_SIZE  = 14
$RAIN_SPACING    = 28
$RAIN_TRAIL      = 7
$RAIN_INTERVAL   = 120
$LOGO_FONT_SIZE  = 13
$LOGO_LINE_H     = 20
$HEX_CHARS       = "0123456789ABCDEF".ToCharArray()
$rng             = [System.Random]::new()

# === LOGO — all lines exactly 37 chars: 1 border + 35 content + 1 border ===
$hostname = $env:COMPUTERNAME
$B = [char]0x2551   # ║ border char
$CW = 35            # content width between borders

# Helper: wrap content in border chars, pad to exact width
function LogoLine([string]$content) {
    return [string]$B + $content.PadRight($CW).Substring(0, $CW) + [string]$B
}

$logo = @(
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

# === SHARED GDI RESOURCES ===
$rainFont   = New-Object System.Drawing.Font("Consolas", $RAIN_FONT_SIZE, [System.Drawing.FontStyle]::Regular)
$logoFont   = New-Object System.Drawing.Font("Consolas", $LOGO_FONT_SIZE, [System.Drawing.FontStyle]::Bold)
$whiteBrush = [System.Drawing.Brushes]::White
$blackBrush = [System.Drawing.Brushes]::Black

$greenBrushes = @()
for ($t = 0; $t -lt $RAIN_TRAIL; $t++) {
    $fade = [math]::Max(30, 255 - $t * 35)
    $greenBrushes += New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $fade, 0))
}
$borderPenColor = [System.Drawing.Color]::FromArgb(0, 80, 0)

# === Measure logo pixel size using the actual font ===
$tmpBmp = New-Object System.Drawing.Bitmap(1, 1)
$tmpG   = [System.Drawing.Graphics]::FromImage($tmpBmp)
$tmpG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
# Measure the widest line (they should all be the same with monospace + same char count)
$logoPixelW = 0
foreach ($line in $logo) {
    $sz = $tmpG.MeasureString($line, $logoFont)
    if ($sz.Width -gt $logoPixelW) { $logoPixelW = $sz.Width }
}
$logoPixelH = $logo.Count * $LOGO_LINE_H
$tmpG.Dispose()
$tmpBmp.Dispose()

$boxPadding = 20
$boxW = [int]($logoPixelW + $boxPadding * 2)
$boxH = [int]($logoPixelH + $boxPadding * 2)

# === BUILD ONE FORM PER MONITOR ===
$allScreens = [System.Windows.Forms.Screen]::AllScreens
$forms       = @()
$panels      = @()
$rainData    = @()

$script:frame      = 0
$script:mouseStart = @{}

foreach ($screen in $allScreens) {
    $W = $screen.Bounds.Width
    $H = $screen.Bounds.Height
    $X = $screen.Bounds.X
    $Y = $screen.Bounds.Y

    # --- Form ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text              = "NullSec"
    $form.FormBorderStyle   = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition     = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location          = New-Object System.Drawing.Point($X, $Y)
    $form.Size              = New-Object System.Drawing.Size($W, $H)
    $form.BackColor         = [System.Drawing.Color]::Black
    $form.TopMost           = $true
    $form.ShowInTaskbar     = $false
    $form.KeyPreview        = $true

    # --- Panel ---
    $panel = New-Object BufferedPanel
    $panel.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $panel.BackColor = [System.Drawing.Color]::Black
    $form.Controls.Add($panel)

    # --- Rain state for this screen ---
    $cols  = [math]::Floor($W / $RAIN_SPACING)
    $drops = New-Object int[] $cols
    for ($c = 0; $c -lt $cols; $c++) { $drops[$c] = $rng.Next(-20, 0) }

    # --- Logo centering for this screen (relative to form, which is 0,0 → W,H) ---
    $bx = [int](($W - $boxW) / 2)
    $by = [int](($H - $boxH) / 2)
    $lx = [int]($bx + $boxPadding)
    $ly = [int]($by + $boxPadding)

    $rainData += @{
        W = $W; H = $H; Cols = $cols; Drops = $drops
        BoxX = $bx; BoxY = $by; LogoX = $lx; LogoY = $ly
    }

    $forms  += $form
    $panels += $panel
}

# === EXIT ALL FORMS ===
$exitAll = {
    $timer.Stop()
    [System.Windows.Forms.Cursor]::Show()
    foreach ($f in $forms) { try { $f.Close() } catch {} }
}

# === WIRE PAINT + INPUT FOR EACH FORM ===
for ($idx = 0; $idx -lt $forms.Count; $idx++) {
    $f  = $forms[$idx]
    $p  = $panels[$idx]

    # Paint handler — uses $screenData[$idx] via dynamic scriptblock
    $paintCode = @"
    param(`$sender, `$e)
    `$g  = `$e.Graphics
    `$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    `$sd = `$rainData[$idx]

    # --- Rain ---
    for (`$c = 0; `$c -lt `$sd.Cols; `$c++) {
        `$hy = `$sd.Drops[`$c] * $RAIN_FONT_SIZE
        for (`$t = 0; `$t -lt $RAIN_TRAIL; `$t++) {
            `$y = `$hy - `$t * $RAIN_FONT_SIZE
            if (`$y -ge -$RAIN_FONT_SIZE -and `$y -lt `$sd.H) {
                `$ch = [string]`$HEX_CHARS[`$rng.Next(`$HEX_CHARS.Length)]
                `$x  = `$c * $RAIN_SPACING
                if (`$t -eq 0) { `$g.DrawString(`$ch, `$rainFont, `$whiteBrush, `$x, `$y) }
                else           { `$g.DrawString(`$ch, `$rainFont, `$greenBrushes[`$t], `$x, `$y) }
            }
        }
    }

    # --- Logo box background ---
    `$g.FillRectangle(`$blackBrush, `$sd.BoxX, `$sd.BoxY, $boxW, $boxH)
    `$pen = New-Object System.Drawing.Pen(`$borderPenColor, 2)
    `$g.DrawRectangle(`$pen, `$sd.BoxX, `$sd.BoxY, $boxW, $boxH)
    `$pen.Dispose()

    # --- Logo text (pulsing green) ---
    `$pulse = [math]::Max(100, [math]::Min(220, 160 + [int](60 * [math]::Sin(`$script:frame * 0.04))))
    `$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, `$pulse, 0))
    for (`$i = 0; `$i -lt `$logo.Count; `$i++) {
        `$g.DrawString(`$logo[`$i], `$logoFont, `$brush, [float]`$sd.LogoX, [float](`$sd.LogoY + `$i * $LOGO_LINE_H))
    }
    `$brush.Dispose()
"@
    $p.Add_Paint([scriptblock]::Create($paintCode))

    # --- Exit on key/click ---
    $f.Add_KeyDown($exitAll)
    $p.Add_MouseDown($exitAll)

    # --- Exit on mouse move (threshold) ---
    $capturedIdx = $idx
    $p.Add_MouseMove({
        param($s, $e)
        $key = "m$capturedIdx"
        if (-not $script:mouseStart.ContainsKey($key)) {
            $script:mouseStart[$key] = $e.Location
            return
        }
        $ms = $script:mouseStart[$key]
        if ([math]::Abs($e.X - $ms.X) -gt 10 -or [math]::Abs($e.Y - $ms.Y) -gt 10) {
            & $exitAll
        }
    })
}

# === ANIMATION TIMER (single, drives all screens) ===
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $RAIN_INTERVAL
$timer.Add_Tick({
    $script:frame++
    for ($si = 0; $si -lt $rainData.Count; $si++) {
        $sd = $rainData[$si]
        for ($c = 0; $c -lt $sd.Cols; $c++) {
            $sd.Drops[$c]++
            if ($sd.Drops[$c] * $RAIN_FONT_SIZE -gt $sd.H + $RAIN_TRAIL * $RAIN_FONT_SIZE) {
                $sd.Drops[$c] = $rng.Next(-15, -1)
            }
        }
        $panels[$si].Invalidate()
    }
})

# === LAUNCH ===
[System.Windows.Forms.Cursor]::Hide()

# Show secondary forms first (non-blocking)
for ($i = 1; $i -lt $forms.Count; $i++) {
    $forms[$i].Show()
}

# Primary form: activate, start timer, run message loop
$forms[0].Add_Shown({
    foreach ($f in $forms) { $f.TopMost = $true; $f.BringToFront() }
    $forms[0].Activate()
    $panels[0].Focus()
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($forms[0])
