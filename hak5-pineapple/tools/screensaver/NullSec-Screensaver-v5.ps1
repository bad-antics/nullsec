# NullSec Screensaver v6.0 — Static pre-rendered bitmap approach
# NO paint handlers, NO timers, NO animation, NO scoping issues
# Draws everything to a Bitmap upfront, sets as BackgroundImage
# Exit on any key press, mouse click, or mouse move >10px

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === CONFIG ===
$RAIN_FONT_SIZE  = 14
$RAIN_SPACING    = 28
$RAIN_TRAIL      = 7
$LOGO_FONT_SIZE  = 13
$LOGO_LINE_H     = 20
$HEX_CHARS       = "0123456789ABCDEF".ToCharArray()
$rng             = [System.Random]::new()

# === LOGO ===
$hostname = $env:COMPUTERNAME
$B  = [char]0x2551
$CW = 35

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

# === GDI RESOURCES ===
$rainFont   = New-Object System.Drawing.Font("Consolas", $RAIN_FONT_SIZE)
$logoFont   = New-Object System.Drawing.Font("Consolas", $LOGO_FONT_SIZE, [System.Drawing.FontStyle]::Bold)
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$blackBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
$logoBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 180, 0))

$greenBrushes = @()
for ($t = 0; $t -lt $RAIN_TRAIL; $t++) {
    $fade = [math]::Max(30, 255 - $t * 35)
    $greenBrushes += New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, $fade, 0))
}
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 80, 0), 2)

# === Measure logo pixel size ===
$tmpBmp = New-Object System.Drawing.Bitmap(1, 1)
$tmpG   = [System.Drawing.Graphics]::FromImage($tmpBmp)
$tmpG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$logoPixelW = 0
foreach ($line in $logo) {
    $sz = $tmpG.MeasureString($line, $logoFont)
    if ($sz.Width -gt $logoPixelW) { $logoPixelW = $sz.Width }
}
$logoPixelH = $logo.Count * $LOGO_LINE_H
$tmpG.Dispose()
$tmpBmp.Dispose()

$boxPad = 20
$boxW   = [int]($logoPixelW + $boxPad * 2)
$boxH   = [int]($logoPixelH + $boxPad * 2)

# =============================================================
# FUNCTION: Render one screen's bitmap (matrix rain + logo box)
# =============================================================
function Render-Screen([int]$W, [int]$H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    # Black background
    $g.Clear([System.Drawing.Color]::Black)

    # --- Draw matrix rain columns ---
    $cols = [math]::Floor($W / $RAIN_SPACING)
    for ($c = 0; $c -lt $cols; $c++) {
        $x = $c * $RAIN_SPACING
        # Random head position for this column
        $headRow = $rng.Next(0, [math]::Floor($H / $RAIN_FONT_SIZE) + 10)
        for ($t = 0; $t -lt $RAIN_TRAIL; $t++) {
            $row = $headRow - $t
            $y   = $row * $RAIN_FONT_SIZE
            if ($y -ge (-$RAIN_FONT_SIZE) -and $y -lt $H) {
                $ch = [string]$HEX_CHARS[$rng.Next($HEX_CHARS.Length)]
                if ($t -eq 0) {
                    $g.DrawString($ch, $rainFont, $whiteBrush, $x, $y)
                } else {
                    $g.DrawString($ch, $rainFont, $greenBrushes[$t], $x, $y)
                }
            }
        }
        # Also draw some random scattered green chars for density
        $extraChars = $rng.Next(3, [math]::Floor($H / $RAIN_FONT_SIZE / 2))
        for ($e = 0; $e -lt $extraChars; $e++) {
            $ey = $rng.Next(0, $H)
            $ch = [string]$HEX_CHARS[$rng.Next($HEX_CHARS.Length)]
            $fadeIdx = $rng.Next(2, $RAIN_TRAIL)
            $g.DrawString($ch, $rainFont, $greenBrushes[$fadeIdx], $x, $ey)
        }
    }

    # --- Logo box (centered on this screen) ---
    $bx = [int](($W - $boxW) / 2)
    $by = [int](($H - $boxH) / 2)

    # Solid black background for the box
    $g.FillRectangle($blackBrush, $bx, $by, $boxW, $boxH)
    # Border
    $g.DrawRectangle($borderPen, $bx, $by, $boxW, $boxH)

    # Logo text
    $lx = $bx + $boxPad
    $ly = $by + $boxPad
    for ($i = 0; $i -lt $logo.Count; $i++) {
        $g.DrawString($logo[$i], $logoFont, $logoBrush, [float]$lx, [float]($ly + $i * $LOGO_LINE_H))
    }

    $g.Dispose()
    return $bmp
}

# =============================================================
# BUILD FORMS — one per monitor, static bitmap as background
# =============================================================
$allScreens = [System.Windows.Forms.Screen]::AllScreens
$forms      = [System.Collections.ArrayList]::new()
$mouseStart = @{}

foreach ($screen in $allScreens) {
    $W = $screen.Bounds.Width
    $H = $screen.Bounds.Height
    $X = $screen.Bounds.X
    $Y = $screen.Bounds.Y

    # Pre-render the bitmap for this screen
    $bmp = Render-Screen $W $H

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text              = "NullSec"
    $form.FormBorderStyle   = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition     = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location          = New-Object System.Drawing.Point($X, $Y)
    $form.Size              = New-Object System.Drawing.Size($W, $H)
    $form.BackColor         = [System.Drawing.Color]::Black
    $form.BackgroundImage   = $bmp
    $form.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::None
    $form.TopMost           = $true
    $form.ShowInTaskbar     = $false
    $form.KeyPreview        = $true
    $form.Cursor            = [System.Windows.Forms.Cursors]::Arrow

    $null = $forms.Add($form)
}

# =============================================================
# EXIT HANDLER
# =============================================================
$exitAll = {
    [System.Windows.Forms.Cursor]::Show()
    foreach ($f in $forms) { try { $f.Close() } catch {} }
}

# Wire input events on each form
foreach ($form in $forms) {
    $form.Add_KeyDown($exitAll)
    $form.Add_MouseDown($exitAll)
    $form.Add_MouseMove({
        param($s, $e)
        $key = $s.GetHashCode()
        if (-not $mouseStart.ContainsKey($key)) {
            $mouseStart[$key] = $e.Location
            return
        }
        $ms = $mouseStart[$key]
        if ([math]::Abs($e.X - $ms.X) -gt 10 -or [math]::Abs($e.Y - $ms.Y) -gt 10) {
            & $exitAll
        }
    })
}

# =============================================================
# LAUNCH
# =============================================================
[System.Windows.Forms.Cursor]::Hide()

# Show secondary forms
for ($i = 1; $i -lt $forms.Count; $i++) {
    $forms[$i].Show()
}

# Primary form
$forms[0].Add_Shown({
    foreach ($f in $forms) { $f.TopMost = $true; $f.BringToFront() }
    $forms[0].Activate()
    $forms[0].Focus()
})

[System.Windows.Forms.Application]::Run($forms[0])
