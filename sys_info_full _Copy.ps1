# ─────────────────────────────────────────────────────────────────────────────
# Script: Export-FullMachineReport.ps1
# Description: Collects exhaustive system, hardware, storage, software,
#              network, PnP devices (Bluetooth, sensors), location settings,
#              Windows Security features (Defender, Firewall, BitLocker),
#              and process count. Exports detailed CSVs + a neatly aligned
#              TXT report into a timestamped folder under %TEMP%, then opens it.
# ─────────────────────────────────────────────────────────────────────────────

# 1. Build output directory
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outputDir = Join-Path $env:TEMP "FullMachineReport_$timestamp"
New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

# 2. System & OS info
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
    OS_Arch         = $os.OSArchitecture
    TotalPhysGB     = [math]::Round($cs.TotalPhysicalMemory/1GB,2)
    LastBootUp      = $os.LastBootUpTime
    UptimeDays      = [math]::Round($uptime.TotalDays,2)
    UserName        = $env:USERNAME
}

# 3. CPU info
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
    # Link speed in Mbps
    $speed = 'N/A'
    if ($adapter -and $adapter.LinkSpeed) {
        if ($adapter.LinkSpeed -match '([\d\.]+)\s*Gbps') { $speed = [math]::Round($Matches[1]*1000) }
        elseif ($adapter.LinkSpeed -match '([\d\.]+)\s*Mbps') { $speed = [math]::Round($Matches[1]) }
    }
    [PSCustomObject]@{
        InterfaceAlias   = $alias
        Description      = $_.InterfaceDescription
        MACAddress       = $_.MacAddress
        LinkSpeedMbps    = $speed
        IPv4Address      = ($_.IPv4Address | Select -Expand IPAddress) -join ', '
        IPv4PrefixLength = ($_.IPv4Address | Select -Expand PrefixLength) -join ', '
        IPv6Address      = ($_.IPv6Address | Select -Expand IPAddress) -join ', '
        DefaultGateway   = ($_.IPv4DefaultGateway | Select -Expand NextHop) -join ', '
        DNSServers       = ($_.DNSServer.ServerAddresses) -join ', '
        DhcpEnabled      = if ($_.IPv4Address.Dhcp) {'Yes'} else {'No'}
        Status           = if ($adapter) { $adapter.Status } else { 'Unknown' }
    }
}

# 7. Installed software from registry
$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$installedSoftware = $uninstallPaths |
    ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation

# 8. PnP devices: Bluetooth & Sensors
$bluetoothDevices = Get-PnpDevice -Class Bluetooth |
    Select-Object FriendlyName, Manufacturer, Status, InstanceId
$sensorDevices = Get-PnpDevice -Class Sensor |
    Select-Object FriendlyName, Class, Status, InstanceId

# 9. Location service & consent
$locationService = Get-Service -Name lfsvc -ErrorAction SilentlyContinue |
                   Select-Object Name, Status, StartType
$locationConsent = Get-ItemProperty `
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' |
    Select-Object *

# 10. Windows Security & Defender
$defenderStatus = Get-MpComputerStatus |
    Select-Object AMEngineVersion, AMProductVersion, AntivirusSignatureVersion,
                  RealTimeProtectionEnabled, BehaviorMonitorEnabled,
                  IoavProtectionEnabled, AntiSpywareEnabled, IsTamperProtected
$defenderPrefs = Get-MpPreference |
    Select-Object -Property MalwareDefaultAction, NetworkProtectionDefaultAction,
                  ExclusionPath, ExclusionProcess, ExclusionExtension,
                  ThreatDefaultAction
$firewallProfiles = Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
$bitlockerVolumes = Get-BitLockerVolume |
    Select-Object MountPoint, VolumeType, EncryptionPercentage, ProtectionStatus

# 11. Process count
$processCount = (Get-Process).Count

# 12. Export CSVs
$sysInfo             | Export-Csv (Join-Path $outputDir 'SystemInfo.csv')     -NoTypeInformation -Encoding UTF8
$cpuInfo             | Export-Csv (Join-Path $outputDir 'CPUInfo.csv')        -NoTypeInformation -Encoding UTF8
$memInfo             | Export-Csv (Join-Path $outputDir 'MemoryInfo.csv')     -NoTypeInformation -Encoding UTF8
$diskInfos           | Export-Csv (Join-Path $outputDir 'DiskInfo.csv')       -NoTypeInformation -Encoding UTF8
$netConfigs          | Export-Csv (Join-Path $outputDir 'NetworkInfo.csv')    -NoTypeInformation -Encoding UTF8
$installedSoftware   | Export-Csv (Join-Path $outputDir 'InstalledSoftware.csv') -NoTypeInformation -Encoding UTF8
$bluetoothDevices    | Export-Csv (Join-Path $outputDir 'BluetoothDevices.csv')  -NoTypeInformation -Encoding UTF8
$sensorDevices       | Export-Csv (Join-Path $outputDir 'SensorDevices.csv')     -NoTypeInformation -Encoding UTF8
$locationService     | Export-Csv (Join-Path $outputDir 'LocationService.csv')   -NoTypeInformation -Encoding UTF8
$locationConsent     | Export-Csv (Join-Path $outputDir 'LocationConsent.csv')   -NoTypeInformation -Encoding UTF8
$defenderStatus      | Export-Csv (Join-Path $outputDir 'DefenderStatus.csv')    -NoTypeInformation -Encoding UTF8
$defenderPrefs       | Export-Csv (Join-Path $outputDir 'DefenderPrefs.csv')     -NoTypeInformation -Encoding UTF8
$firewallProfiles    | Export-Csv (Join-Path $outputDir 'FirewallProfiles.csv')  -NoTypeInformation -Encoding UTF8
$bitlockerVolumes    | Export-Csv (Join-Path $outputDir 'BitLockerVolumes.csv') -NoTypeInformation -Encoding UTF8

# 13. Build consolidated TXT
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
        $report.Add($p.Name.PadRight(25) + ': ' + $val)
    }
    $report.Add("")
}

Add-Block -title 'System & OS'         -props $sysInfo.PSObject.Properties
Add-Block -title 'CPU'                 -props $cpuInfo.PSObject.Properties
Add-Block -title 'Memory (MB)'         -props $memInfo.PSObject.Properties

$report.Add("---- Disks ----")
foreach ($d in $diskInfos) {
    $report.Add("Drive " + $d.Drive + " - Used: " + $d.UsedGB +
                "GB / " + $d.SizeGB + "GB (" + $d.FreePct + "% free)")
}
$report.Add("")

Add-Block -title 'Network Adapters'    -props $netConfigs[0].PSObject.Properties  # just headers
foreach ($n in $netConfigs) {
    $report.Add("Interface : " + $n.InterfaceAlias)
    $report.Add("  Desc    : " + $n.Description)
    $report.Add("  MAC     : " + $n.MACAddress)
    $report.Add("  Speed   : " + $n.LinkSpeedMbps + " Mbps")
    $report.Add("  IPv4    : " + $n.IPv4Address + "/" + $n.IPv4PrefixLength)
    $report.Add("  IPv6    : " + $n.IPv6Address)
    $report.Add("  Gateway : " + $n.DefaultGateway)
    $report.Add("  DNS     : " + $n.DNSServers)
    $report.Add("  DHCP    : " + $n.DhcpEnabled)
    $report.Add("  Status  : " + $n.Status)
    $report.Add("")
}

$report.Add("---- Installed Software ----")
foreach ($s in $installedSoftware) {
    $report.Add($s.DisplayName + " | " + $s.DisplayVersion +
                " | " + $s.Publisher +
                " | Installed: " + $s.InstallDate +
                " | Loc: " + $s.InstallLocation)
}
$report.Add("")

$report.Add("---- Bluetooth Devices ----")
foreach ($b in $bluetoothDevices) {
    $report.Add($b.FriendlyName + " | " + $b.Manufacturer +
                " | Status: " + $b.Status +
                " | ID: " + $b.InstanceId)
}
$report.Add("")

$report.Add("---- Sensor Devices ----")
foreach ($s in $sensorDevices) {
    $report.Add($s.FriendlyName + " | Class: " + $s.Class +
                " | Status: " + $s.Status)
}
$report.Add("")

$report.Add("---- Location Service ----")
foreach ($l in $locationService) {
    $report.Add($l.Name.PadRight(25) + ": " + $l.Status + " (" + $l.StartType + ")")
}
$report.Add("")

$report.Add("---- Location Consent Keys ----")
$locationConsent.PSObject.Properties | ForEach-Object {
    $report.Add($_.Name.PadRight(25) + ": " + ($_.Value -join ', '))
}
$report.Add("")

Add-Block -title 'Defender Status'     -props $defenderStatus.PSObject.Properties
Add-Block -title 'Defender Preferences'-props $defenderPrefs.PSObject.Properties

$report.Add("---- Firewall Profiles ----")
foreach ($f in $firewallProfiles) {
    $report.Add($f.Name + " | Enabled: " + $f.Enabled +
                " | In: " + $f.DefaultInboundAction +
                " | Out: " + $f.DefaultOutboundAction)
}
$report.Add("")

$report.Add("---- BitLocker Volumes ----")
foreach ($v in $bitlockerVolumes) {
    $report.Add($v.MountPoint + " | " + $v.VolumeType +
                " | " + $v.EncryptionPercentage + "% encrypted" +
                " | Prot: " + $v.ProtectionStatus)
}
$report.Add("")

$report.Add("---- Processes ----")
$report.Add("Total Running Processes: " + $processCount)

# Write TXT file
$report | Set-Content -Path $txtPath -Encoding UTF8

# 14. Open output folder in Explorer
Start-Process explorer.exe -ArgumentList $outputDir

Write-Host "Full report generated at:`n$outputDir" -ForegroundColor Green
