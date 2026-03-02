# NullSec Screensaver v4.1 - Single-process multi-form (one form per screen)
# Creates all forms in the SAME process to avoid child-process rendering bugs
# Works on 1, 2, or 3+ monitors

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
$hostname = $env:COMPUTERNAME

# --- Shared resources ---
$fontSize = 16
$spacing = 36
$trail = 7
$hexChars = "0123456789ABCDEF".ToCharArray()
$rng = [System.Random]::new()
$script:frame = 0

$rainFont = New-Object System.Drawing.Font("Consolas", ($fontSize - 2), [System.Drawing.FontStyle]::Regular)
$logoFont = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$whiteBrush = [System.Drawing.Brushes]::White
$blackBrush = [System.Drawing.Brushes]::Black

$greenBrushes = @()
for ($t = 0; $t -lt $trail; $t++) {
    $fade = [math]::Max(30, 255 - $t * 35)
    $greenBrushes += New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $fade, 0))
}

# --- Logo lines ---
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

# Measure logo for centering
$measureBmp = New-Object System.Drawing.Bitmap(1, 1)
$measureG = [System.Drawing.Graphics]::FromImage($measureBmp)
$maxLogoWidth = 0
foreach ($line in $logoLines) {
    $sz = $measureG.MeasureString($line, $logoFont)
    if ($sz.Width -gt $maxLogoWidth) { $maxLogoWidth = $sz.Width }
}
$logoLineH = 18
$logoHeight = $logoLines.Count * $logoLineH
$measureG.Dispose()
$measureBmp.Dispose()

# --- Build forms for each screen ---
$forms = @()
$panels = @()
$screenData = @()

foreach ($screen in $allScreens) {
    $W = $screen.Bounds.Width
    $H = $screen.Bounds.Height
    $X = $screen.Bounds.X
    $Y = $screen.Bounds.Y

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NullSec"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location = New-Object System.Drawing.Point($X, $Y)
    $form.ClientSize = New-Object System.Drawing.Size($W, $H)
    $form.BackColor = [System.Drawing.Color]::Black
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.KeyPreview = $true

    $panel = New-Object BufferedPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.BackColor = [System.Drawing.Color]::Black
    $form.Controls.Add($panel)

    # Per-screen rain data
    $cols = [math]::Floor($W / $spacing)
    $drops = New-Object int[] $cols
    for ($c = 0; $c -lt $cols; $c++) { $drops[$c] = $rng.Next(-20, 0) }

    # Per-screen logo centering
    $boxW = [int]($maxLogoWidth + 30)
    $boxH = [int]($logoHeight + 30)
    $boxX = [int](($W - $boxW) / 2)
    $boxY = [int](($H - $boxH) / 2)
    $logoStartX = [int](($W - $maxLogoWidth) / 2)
    $logoStartY = [int](($H - $logoHeight) / 2)

    $sd = @{
        W = $W; H = $H; Cols = $cols; Drops = $drops
        BoxX = $boxX; BoxY = $boxY; BoxW = $boxW; BoxH = $boxH
        LogoStartX = $logoStartX; LogoStartY = $logoStartY
    }

    $forms += $form
    $panels += $panel
    $screenData += $sd
}

# --- Shared exit logic ---
$script:mouseStarts = @{}

$exitAll = {
    $timer.Stop()
    [System.Windows.Forms.Cursor]::Show()
    foreach ($f in $forms) { try { $f.Close() } catch {} }
}

# --- Wire up paint + input for each form ---
for ($idx = 0; $idx -lt $forms.Count; $idx++) {
    $f = $forms[$idx]
    $p = $panels[$idx]
    $sd = $screenData[$idx]

    # Capture per-screen data via closure wrapper
    $paintHandler = [scriptblock]::Create(@"
        param(`$sender, `$e)
        `$g = `$e.Graphics
        `$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        `$localSD = `$screenData[$idx]
        `$localCols = `$localSD.Cols
        `$localDrops = `$localSD.Drops
        `$localW = `$localSD.W
        `$localH = `$localSD.H

        # Rain
        for (`$c = 0; `$c -lt `$localCols; `$c++) {
            `$hy = `$localDrops[`$c] * $fontSize
            for (`$t = 0; `$t -lt $trail; `$t++) {
                `$y = `$hy - `$t * $fontSize
                if (`$y -ge -$fontSize -and `$y -lt `$localH) {
                    `$ch = [string]`$hexChars[`$rng.Next(`$hexChars.Length)]
                    `$x = `$c * $spacing
                    if (`$t -eq 0) {
                        `$g.DrawString(`$ch, `$rainFont, `$whiteBrush, `$x, `$y)
                    } else {
                        `$g.DrawString(`$ch, `$rainFont, `$greenBrushes[`$t], `$x, `$y)
                    }
                }
            }
        }

        # Logo box
        `$g.FillRectangle(`$blackBrush, `$localSD.BoxX, `$localSD.BoxY, `$localSD.BoxW, `$localSD.BoxH)
        `$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 51, 0), 2)
        `$g.DrawRectangle(`$borderPen, `$localSD.BoxX, `$localSD.BoxY, `$localSD.BoxW, `$localSD.BoxH)
        `$borderPen.Dispose()

        # Logo text with pulse
        `$pulse = [math]::Max(100, [math]::Min(220, 140 + [int](50 * [math]::Sin(`$script:frame * 0.05))))
        `$logoBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, `$pulse, 0))
        for (`$i = 0; `$i -lt `$logoLines.Count; `$i++) {
            `$g.DrawString(`$logoLines[`$i], `$logoFont, `$logoBrush, [float]`$localSD.LogoStartX, [float](`$localSD.LogoStartY + `$i * $logoLineH))
        }
        `$logoBrush.Dispose()
"@)
    $p.Add_Paint($paintHandler)

    # Exit handlers
    $f.Add_KeyDown($exitAll)
    $p.Add_MouseDown($exitAll)

    $moveIdx = $idx
    $p.Add_MouseMove({
        param($s, $e)
        $key = "panel_$moveIdx"
        if (-not $script:mouseStarts.ContainsKey($key)) {
            $script:mouseStarts[$key] = $e.Location
            return
        }
        $start = $script:mouseStarts[$key]
        if ([math]::Abs($e.X - $start.X) -gt 10 -or [math]::Abs($e.Y - $start.Y) -gt 10) {
            & $exitAll
        }
    })
}

# --- Single timer drives all screens ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
    $script:frame++
    for ($si = 0; $si -lt $screenData.Count; $si++) {
        $sd = $screenData[$si]
        for ($c = 0; $c -lt $sd.Cols; $c++) {
            $sd.Drops[$c]++
            if ($sd.Drops[$c] * $fontSize -gt $sd.H + $trail * $fontSize) {
                $sd.Drops[$c] = $rng.Next(-15, -1)
            }
        }
        $panels[$si].Invalidate()
    }
})

# --- Launch: show all forms, run primary ---
[System.Windows.Forms.Cursor]::Hide()

# Show secondary forms first
for ($i = 1; $i -lt $forms.Count; $i++) {
    $forms[$i].Show()
}

# Primary form drives the message loop
$forms[0].Add_Shown({
    $forms[0].Activate()
    $forms[0].BringToFront()
    $panels[0].Focus()
    # Bring all forms to front
    foreach ($f in $forms) {
        $f.TopMost = $true
        $f.BringToFront()
    }
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($forms[0])
