# ─────────────────────────────────────────────────────────────────────────────
# Script: Export-MachineNetworkReport.ps1
# Description: Gathers current location, host info & network stats.
#              Exports both CSV & TXT into a new timestamped folder under %TEMP%
#              Then opens that folder in Explorer.
# ─────────────────────────────────────────────────────────────────────────────

# 1. Build a new temp directory with timestamp
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$baseTemp  = Join-Path $env:TEMP "MachineNetworkReport_$timestamp"
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
        InterfaceAlias = $_.InterfaceAlias
        Description    = $_.InterfaceDescription
        IPv4Address    = ($_.IPv4Address | ForEach-Object IPAddress) -join ', '
        IPv6Address    = ($_.IPv6Address | ForEach-Object IPAddress) -join ', '
        Gateway        = ($_.IPv4DefaultGateway | ForEach-Object NextHop)    -join ', '
        DNSServers     = ($_.DNSServer.ServerAddresses)                     -join ', '
        DhcpEnabled    = if ($_.IPv4Address.Dhcp) { 'Yes' } else { 'No' }
    }
}

# 4. Export CSV
$csvPath = Join-Path $baseTemp 'MachineNetworkReport.csv'
$netConfigs |
    Select-Object InterfaceAlias, Description, IPv4Address, IPv6Address, Gateway, DNSServers, DhcpEnabled,
        @{Name='TimeStamp';    Expression={ $sysInfo.TimeStamp    }},
        @{Name='ComputerName'; Expression={ $sysInfo.ComputerName }},
        @{Name='UserName';     Expression={ $sysInfo.UserName     }},
        @{Name='Directory';    Expression={ $sysInfo.Directory    }} |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# 5. Export TXT
$txtPath = Join-Path $baseTemp 'MachineNetworkReport.txt'
"===== System & Location ====="                                         | Out-File $txtPath -Encoding UTF8
$sysInfo | Format-List                                              | Out-File $txtPath -Append -Encoding UTF8
""                                                                  | Out-File $txtPath -Append -Encoding UTF8
"===== Network Configuration ====="                                  | Out-File $txtPath -Append -Encoding UTF8
$netConfigs | Format-Table -AutoSize                                | Out-File $txtPath -Append -Encoding UTF8

# 6. Open the folder in Explorer
Start-Process explorer.exe -ArgumentList $baseTemp

# 7. Final feedback
Write-Host "Export complete. Files saved under $baseTemp" -ForegroundColor Green