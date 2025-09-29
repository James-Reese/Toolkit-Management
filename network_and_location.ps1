# ─────────────────────────────────────────────────────────────────────────────
# Script: Export-MachineNetworkReport.ps1
# Description: Gathers current location, host info & network stats. 
#              Exports report as CSV + TXT to a temp subfolder and opens it.
# ─────────────────────────────────────────────────────────────────────────────

# 1. Prepare temporary output folder
$baseTemp = Join-Path $env:TEMP 'MachineNetworkReport'
New-Item -Path $baseTemp -ItemType Directory -Force | Out-Null

# 2. Gather system/location info
$sysInfo = [PSCustomObject]@{
    TimeStamp    = (Get-Date).ToString('u')
    ComputerName = $env:COMPUTERNAME
    UserName     = $env:USERNAME
    Directory    = (Get-Location).Path
}

# 3. Gather network configuration
$netConfigs = Get-NetIPConfiguration | ForEach-Object {
    [PSCustomObject]@{
        InterfaceAlias  = $_.InterfaceAlias
        Description     = $_.InterfaceDescription
        IPv4Address     = ($_.IPv4Address | Select-Object -ExpandProperty IPAddress) -join ', '
        IPv6Address     = ($_.IPv6Address | Select-Object -ExpandProperty IPAddress) -join ', '
        DefaultGateway  = ($_.IPv4DefaultGateway | Select-Object -ExpandProperty NextHop) -join ', '
        DNSServers      = ($_.DNSServer.ServerAddresses) -join ', '
        DhcpEnabled     = if ($_.IPv4Address.Dhcp) { 'Yes' } else { 'No' }
    }
}

# 4. Export as CSV with calculated properties
$csvPath = Join-Path $baseTemp 'MachineNetworkReport.csv'
$netConfigs |
    Select-Object `
        InterfaceAlias, Description, IPv4Address, IPv6Address, DefaultGateway, DNSServers, DhcpEnabled, `
        @{Name='TimeStamp';    Expression={ $sysInfo.TimeStamp    }}, `
        @{Name='ComputerName'; Expression={ $sysInfo.ComputerName }}, `
        @{Name='UserName';     Expression={ $sysInfo.UserName     }}, `
        @{Name='Directory';    Expression={ $sysInfo.Directory    }} |
    Export-Csv -Path $csvPath -NoTypeInformation

# 5. Export as plain-text
$txtPath = Join-Path $baseTemp 'MachineNetworkReport.txt'
"===== System & Location ====="   | Out-File $txtPath
$sysInfo | Format-List           | Out-File $txtPath -Append
""                               | Out-File $txtPath -Append
"===== Network Configuration =====" | Out-File $txtPath -Append
$netConfigs | Format-Table -AutoSize | Out-File $txtPath -Append

# 6. Open the output folder in File Explorer
Start-Process explorer.exe -ArgumentList $baseTemp

# 7. Final feedback
Write-Host "Report exported to:`n  $csvPath`n  $txtPath`nFolder opened in Explorer." -ForegroundColor Green