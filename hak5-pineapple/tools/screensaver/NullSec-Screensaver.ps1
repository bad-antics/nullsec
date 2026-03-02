# NullSec Screensaver v2.2 - Matrix rain for Windows (WPF) - Multi-Monitor
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Force software rendering to avoid GPU driver issues (AMD RX 550, etc.)
[System.Windows.Media.RenderOptions]::ProcessRenderMode = [System.Windows.Interop.RenderMode]::SoftwareOnly

# Detect multi-monitor setup
$monitorCount = [System.Windows.Forms.Screen]::AllScreens.Count
$isMultiMon = $monitorCount -gt 1

if ($isMultiMon) {
    $winState = "Normal"
} else {
    $winState = "Maximized"
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="False" Background="Black"
        WindowState="$winState" Topmost="True" Cursor="None"
        ShowInTaskbar="False" ResizeMode="NoResize"
        Title="NullSec Screensaver">
    <Canvas Name="MainCanvas" Background="Black"/>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$canvas = $window.FindName("MainCanvas")

if ($isMultiMon) {
    # Span all monitors using virtual screen bounds (WPF DIPs)
    $screenW = [System.Windows.SystemParameters]::VirtualScreenWidth
    $screenH = [System.Windows.SystemParameters]::VirtualScreenHeight
    $screenL = [System.Windows.SystemParameters]::VirtualScreenLeft
    $screenT = [System.Windows.SystemParameters]::VirtualScreenTop
    $window.Left   = $screenL
    $window.Top    = $screenT
    $window.Width  = $screenW
    $window.Height = $screenH
} else {
    # Single monitor - Maximized handles positioning
    $screenW = [System.Windows.SystemParameters]::PrimaryScreenWidth
    $screenH = [System.Windows.SystemParameters]::PrimaryScreenHeight
}

# Ensure window activates and renders in foreground
$window.Add_Loaded({
    $window.Activate()
    $window.Focus()
})

$fontSize = 16
$spacing = 36
$cols = [math]::Floor($screenW / $spacing)
$trail = 7
$hex = "0123456789ABCDEF".ToCharArray()
$rng = [System.Random]::new()

# Pre-create text blocks for rain
$drops = @()
$rainItems = @()
for ($c = 0; $c -lt $cols; $c++) {
    $drops += $rng.Next(-20, 0)
    $colItems = @()
    for ($t = 0; $t -lt $trail; $t++) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
        $tb.FontSize = $fontSize
        $tb.Text = "0"
        $fade = [math]::Max(30, 255 - $t * 35)
        $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(0, $fade, 0))
        $tb.Visibility = "Hidden"
        $canvas.Children.Add($tb) | Out-Null
        $colItems += $tb
    }
    $rainItems += ,($colItems)
}

# Logo
$hostname = $env:COMPUTERNAME
$logoLines = @(
    [char]0x2554 + ([string][char]0x2550) * 31 + [char]0x2557,
    [char]0x2551 + "  NULLSEC SECURITY CLUSTER   " + [char]0x2551,
    [char]0x2551 + "  " + [char]0x2588 + [char]0x2588 + [char]0x2588 + " " + [char]0x2588 + [char]0x2588 + " " + [char]0x2588 + [char]0x2588 + [char]0x2588 + "               " + [char]0x2551,
    [char]0x2551 + "  " + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + "                 " + [char]0x2551,
    [char]0x2551 + "  " + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + "  " + [char]0x2588 + [char]0x2588 + [char]0x2588 + "              " + [char]0x2551,
    [char]0x2551 + "                               " + [char]0x2551,
    [char]0x2551 + "  NODE: $hostname             " + [char]0x2551,
    [char]0x255A + ([string][char]0x2550) * 31 + [char]0x255D
)

$logoTBs = @()
$logoCX = $screenW / 2
$logoCY = $screenH / 2
for ($i = 0; $i -lt $logoLines.Count; $i++) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $tb.FontSize = 14
    $tb.FontWeight = "Bold"
    $tb.Text = $logoLines[$i]
    $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0, 187, 0))
    [System.Windows.Controls.Canvas]::SetLeft($tb, $logoCX - 140)
    [System.Windows.Controls.Canvas]::SetTop($tb, $logoCY - 70 + $i * 20)
    [System.Windows.Controls.Panel]::SetZIndex($tb, 100)
    $canvas.Children.Add($tb) | Out-Null
    $logoTBs += $tb
}

# Background for logo
$rect = New-Object System.Windows.Shapes.Rectangle
$rect.Width = 320; $rect.Height = 200
$rect.Fill = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Black)
$rect.Stroke = New-Object System.Windows.Media.SolidColorBrush(
    [System.Windows.Media.Color]::FromRgb(0, 51, 0))
$rect.StrokeThickness = 2
[System.Windows.Controls.Canvas]::SetLeft($rect, $logoCX - 160)
[System.Windows.Controls.Canvas]::SetTop($rect, $logoCY - 90)
[System.Windows.Controls.Panel]::SetZIndex($rect, 99)
$canvas.Children.Add($rect) | Out-Null

$frame = 0
$mouseStart = $null

# Exit handlers
$window.Add_KeyDown({ $window.Close() })
$window.Add_MouseDown({ $window.Close() })
$window.Add_MouseMove({
    param($s, $e)
    $pos = $e.GetPosition($window)
    if ($null -eq $script:mouseStart) { $script:mouseStart = $pos; return }
    if ([math]::Abs($pos.X - $script:mouseStart.X) -gt 10 -or
        [math]::Abs($pos.Y - $script:mouseStart.Y) -gt 10) { $window.Close() }
})

# Animation timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    $script:frame++
    for ($c = 0; $c -lt $cols; $c++) {
        $script:drops[$c]++
        $hy = $script:drops[$c] * $fontSize
        if ($hy -gt $screenH + $trail * $fontSize) {
            $script:drops[$c] = $rng.Next(-15, -1)
            for ($t = 0; $t -lt $trail; $t++) { $rainItems[$c][$t].Visibility = "Hidden" }
            continue
        }
        for ($t = 0; $t -lt $trail; $t++) {
            $y = $hy - $t * $fontSize
            $item = $rainItems[$c][$t]
            if ($y -ge 0 -and $y -lt $screenH) {
                [System.Windows.Controls.Canvas]::SetLeft($item, $c * $spacing)
                [System.Windows.Controls.Canvas]::SetTop($item, $y)
                if ($t -eq 0) {
                    $item.Text = [string]$hex[$rng.Next($hex.Length)]
                    $item.Foreground = [System.Windows.Media.Brushes]::White
                } else {
                    if ($rng.NextDouble() -gt 0.6) { $item.Text = [string]$hex[$rng.Next($hex.Length)] }
                    $fade = [math]::Max(30, 255 - $t * 35)
                    $item.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.Color]::FromRgb(0, $fade, 0))
                }
                $item.Visibility = "Visible"
            } else {
                $item.Visibility = "Hidden"
            }
        }
    }
    # Pulse logo
    if ($script:frame % 10 -eq 0) {
        $g = [math]::Max(100, [math]::Min(220, 140 + [int](50 * [math]::Sin($script:frame * 0.05))))
        $color = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(0, $g, 0))
        foreach ($tb in $logoTBs) { $tb.Foreground = $color }
    }
})
$timer.Start()
$window.ShowDialog() | Out-Null
