# Fast PowerShell port scanner

function Invoke-PortScan {
    param(
        [string]$Target,
        [int[]]$Ports = (1..1024)
    )
    
    $Results = @()
    
    foreach ($Port in $Ports) {
        $Socket = New-Object System.Net.Sockets.TcpClient
        $Connect = $Socket.BeginConnect($Target, $Port, $null, $null)
        $Wait = $Connect.AsyncWaitHandle.WaitOne(100, $false)
        
        if ($Wait -and !$Socket.Connected) {
            $Socket.Close()
        }
        elseif ($Socket.Connected) {
            Write-Host "[+] Port $Port is open" -ForegroundColor Green
            $Results += $Port
            $Socket.Close()
        }
    }
    
    return $Results
}

# Example usage
if ($args.Count -gt 0) {
    $OpenPorts = Invoke-PortScan -Target $args[0]
    Write-Host "`nFound $($OpenPorts.Count) open ports"
}
