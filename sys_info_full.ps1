# ─────────────────────────────────────────────────────────────────────────────
# Script: Export-FullMachineReport.ps1
# Description: Collects system, hardware, storage, network & process data,
#              exports detailed CSVs plus a neatly aligned TXT report into
#              a timestamped folder under %TEMP%, then opens that folder.
# ─────────────────────────────────────────────────────────────────────────────

# 1. Build output directory
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outputDir = Join-Path $env:TEMP "FullMachineReport_$timestamp"
New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

# 2. Gather system & OS info
$os     = Get-CimInstance Win32_OperatingSystem
$cs     = Get-CimInstance Win32_ComputerSystem
$bios   = Get-CimInstance Win32_BIOS
$uptime = (Get-Date) - $os.LastBootUpTime

$sysInfo = [PSCustomObject]@{
    TimeStamp       = (Get-Date).ToString('u')
    ComputerName    = $env:COMPUTERNAME
    Manufacturer    = $cs.Manufacturer
    Model           = $cs.Model
    SerialNumber    = $bios.SerialNumber
    OS_Caption      = $os.Caption
    OS_Version      = $os.Version
    OS_Build        = $os.BuildNumber
    OS_Architecture = $os.OSArchitecture
    TotalPhysGB     = [math]::Round($cs.TotalPhysicalMemory/1GB,2)
    LastBootUp      = $os.LastBootUpTime
    UptimeDays      = [math]::Round($uptime.TotalDays,2)
    UserName        = $env:USERNAME
}

# 3. CPU info (first processor)
$cpu    = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuInfo = [PSCustomObject]@{
    Name              = $cpu.Name.Trim()
    Cores             = $cpu.NumberOfCores
    LogicalProcessors = $cpu.NumberOfLogicalProcessors
    MaxClockMHz       = $cpu.MaxClockSpeed
}

# 4. Memory usage
$freeMB = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue
$memInfo = [PSCustomObject]@{
    TotalMB = [math]::Round($cs.TotalPhysicalMemory/1MB,2)
    FreeMB  = [math]::Round($freeMB,2)
    UsedMB  = [math]::Round(($cs.TotalPhysicalMemory/1MB) - $freeMB,2)
    FreePct = [math]::Round(100 * $freeMB/($cs.TotalPhysicalMemory/1MB),2)
    UsedPct = [math]::Round(100 - (100 * $freeMB/($cs.TotalPhysicalMemory/1MB)),2)
}

# 5. Disk volumes
$diskInfos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
    Select-Object `
        @{Name='Drive';Expression={$_.DeviceID}}, 
        @{Name='FileSystem';Expression={$_.FileSystem}}, 
        @{Name='SizeGB';Expression={[math]::Round($_.Size/1GB,2)}},
        @{Name='FreeGB';Expression={[math]::Round($_.FreeSpace/1GB,2)}},
        @{Name='UsedGB';Expression={[math]::Round(($_.Size - $_.FreeSpace)/1GB,2)}},
        @{Name='FreePct';Expression={[math]::Round(100 * $_.FreeSpace/$_.Size,2)}}

# 6. Network configuration
$netConfigs = Get-NetIPConfiguration | ForEach-Object {
    $alias   = $_.InterfaceAlias
    $adapter = Get-NetAdapter -Name $alias -ErrorAction SilentlyContinue

    $speed = 'N/A'
    if ($adapter -and $adapter.LinkSpeed) {
        if ($adapter.LinkSpeed -match '([\d\.]+)\s*Gbps') {
            $speed = [math]::Round($Matches[1] * 1000)
        } elseif ($adapter.LinkSpeed -match '([\d\.]+)\s*Mbps') {
            $speed = [math]::Round($Matches[1])
        }
    }

    [PSCustomObject]@{
        InterfaceAlias   = $alias
        Description      = $_.InterfaceDescription
        MACAddress       = $_.MacAddress
        LinkSpeedMbps    = $speed
        IPv4Address      = ($_.IPv4Address | Select-Object -ExpandProperty IPAddress) -join ', '
        IPv4PrefixLength = ($_.IPv4Address | Select-Object -ExpandProperty PrefixLength) -join ', '
        IPv6Address      = ($_.IPv6Address | Select-Object -ExpandProperty IPAddress) -join ', '
        DefaultGateway   = ($_.IPv4DefaultGateway | Select-Object -ExpandProperty NextHop) -join ', '
        DNSServers       = ($_.DNSServer.ServerAddresses) -join ', '
        DhcpEnabled      = if ($_.IPv4Address.Dhcp) {'Yes'} else {'No'}
        Status           = if ($adapter) { $adapter.Status } else { 'Unknown' }
    }
}

# 7. Process count
$processCount = (Get-Process).Count

# 8. Export detailed CSVs
$sysInfo    | Export-Csv (Join-Path $outputDir 'SystemInfo.csv')   -NoTypeInformation -Encoding UTF8
$cpuInfo    | Export-Csv (Join-Path $outputDir 'CPUInfo.csv')      -NoTypeInformation -Encoding UTF8
$memInfo    | Export-Csv (Join-Path $outputDir 'MemoryInfo.csv')   -NoTypeInformation -Encoding UTF8
$diskInfos  | Export-Csv (Join-Path $outputDir 'DiskInfo.csv')     -NoTypeInformation -Encoding UTF8
$netConfigs | Export-Csv (Join-Path $outputDir 'NetworkInfo.csv')  -NoTypeInformation -Encoding UTF8

# 9. Build and export consolidated TXT
$txtPath = Join-Path $outputDir 'FullMachineReport.txt'
$report  = [Collections.Generic.List[string]]::new()

$report.Add("===== Full Machine Report =====")
$report.Add("Generated  : $($sysInfo.TimeStamp)")
$report.Add("")

function Add-Block {
    param($title, $props)
    $report.Add("---- $title ----")
    foreach ($p in $props) {
        $val = if ($p.Value -is [Array]) { $p.Value -join ', ' } else { $p.Value }
        $report.Add($p.Name.PadRight(20) + ': ' + $val)
    }
    $report.Add("")
}

Add-Block -title 'System & OS'  -props $sysInfo.PSObject.Properties
Add-Block -title 'CPU'          -props $cpuInfo.PSObject.Properties
Add-Block -title 'Memory (MB)'  -props $memInfo.PSObject.Properties

$report.Add("---- Disks ----")
foreach ($d in $diskInfos) {
    $report.Add(
        "Drive $($d.Drive) - Used: $($d.UsedGB)GB of $($d.SizeGB)GB ($($d.FreePct)% free)"
    )
}
$report.Add("")

$report.Add("---- Network ----")
foreach ($n in $netConfigs) {
    $report.Add("Interface : " + $n.InterfaceAlias)
    $report.Add("  Desc    : " + $n.Description)
    $report.Add("  MAC     : " + $n.MACAddress)
    $report.Add("  Speed   : " + $n.LinkSpeedMbps + " Mbps")
    $report.Add("  IPv4    : " + $n.IPv4Address + '/' + $n.IPv4PrefixLength)
    $report.Add("  IPv6    : " + $n.IPv6Address)
    $report.Add("  Gateway : " + $n.DefaultGateway)
    $report.Add("  DNS     : " + $n.DNSServers)
    $report.Add("  DHCP    : " + $n.DhcpEnabled)
    $report.Add("  Status  : " + $n.Status)
    $report.Add("")
}

$report.Add("---- Processes ----")
$report.Add("Total Running Processes: " + $processCount)

# Write the TXT file
$report | Set-Content -Path $txtPath -Encoding UTF8

# 10. Open output folder in Explorer
Start-Process explorer.exe -ArgumentList $outputDir

Write-Host "Full report generated at:" -ForegroundColor Green
Write-Host "  $outputDir" -ForegroundColor Cyan