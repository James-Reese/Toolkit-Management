param (
  [string]$CIDR,
  [int]$BatchSize = 128,
  [int]$TimeoutMs = 750,
  [switch]$ExportCsv,
  [string]$Path = ".\network-devices.csv"
)

function Get-PrimaryCIDR {
  $config = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address }
  if (-not $config) { throw "No active interface with gateway found." }
  "{0}/{1}" -f $config.IPv4Address.IPAddress, $config.IPv4Address.PrefixLength
}

function ConvertTo-UInt32([string]$ip) {
  $bytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
  [Array]::Reverse($bytes)
  [BitConverter]::ToUInt32($bytes,0)
}

function ConvertFrom-UInt32([uint32]$n) {
  $bytes = [BitConverter]::GetBytes($n)
  [Array]::Reverse($bytes)
  [System.Net.IPAddress]::new($bytes).ToString()
}

function Get-IPsFromCIDR([string]$cidr) {
  $parts = $cidr -split '/'
  $ip = $parts[0]; $maskLen = [int]$parts[1]
  $ipN = ConvertTo-UInt32 $ip
  $mask = [uint32]::MaxValue -shl (32 - $maskLen)
  $net = $ipN -band $mask
  $bcast = $net -bor (-bnot $mask)
  $start = $net + 1
  $end = $bcast - 1
  $list = @()
  for ($i = $start; $i -le $end; $i++) {
    $list += ConvertFrom-UInt32 $i
  }
  $list
}

function Test-HostsAlive-Batch {
  param($IPs, $BatchSize, $TimeoutMs)
  $alive = @()
  for ($i = 0; $i -lt $IPs.Count; $i += $BatchSize) {
    $batch = $IPs[$i..([math]::Min($i + $BatchSize - 1, $IPs.Count - 1))]
    $jobs = @()
    foreach ($ip in $batch) {
      $jobs += Start-Job -ScriptBlock {
        param($ip, $timeout)
        try {
          $ping = New-Object System.Net.NetworkInformation.Ping
          $reply = $ping.Send($ip, $timeout)
          if ($reply.Status -eq 'Success') { return $ip }
        } catch {}
      } -ArgumentList $ip, $TimeoutMs
    }
    $jobs | Wait-Job
    foreach ($job in $jobs) {
      $result = Receive-Job $job
      if ($result) { $alive += $result }
      Remove-Job $job
    }
  }
  return $alive
}

if (-not $CIDR) { $CIDR = Get-PrimaryCIDR }
Write-Host "[+] Scanning $CIDR with batch size $BatchSize..." -ForegroundColor Cyan

$ips = Get-IPsFromCIDR $CIDR
$alive = Test-HostsAlive-Batch -IPs $ips -BatchSize $BatchSize -TimeoutMs $TimeoutMs

# Refresh ARP cache (optional ping)
foreach ($ip in $alive) {
  try { [void](New-Object System.Net.NetworkInformation.Ping).Send($ip, 250) } catch {}
}

$macMap = @{}
Get-NetNeighbor -AddressFamily IPv4 |
  Where-Object { $_.LinkLayerAddress -and $_.IPAddress -in $alive } |
  ForEach-Object { $macMap[$_.IPAddress] = $_.LinkLayerAddress.ToUpper() }

$rows = foreach ($ip in $alive) {
  $name = $null
  try {
    $ptr = Resolve-DnsName -Name $ip -Type PTR -ErrorAction Stop
    $name = $ptr.NameHost
  } catch {
    try { $name = ([System.Net.Dns]::GetHostEntry($ip)).HostName } catch {}
  }
  [pscustomobject]@{
    IP       = $ip
    MAC      = $macMap[$ip]
    Hostname = $name
  }
}

$rows = $rows | Sort-Object { ConvertTo-UInt32 $_.IP }
$rows | Format-Table -AutoSize

if ($ExportCsv) {
  $rows | Export-Csv $Path -NoTypeInformation -Encoding UTF8
  Write-Host "[+] Exported to $Path" -ForegroundColor Green
}
