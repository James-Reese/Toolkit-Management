# Elevate to admin if not already
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = 'SilentlyContinue'

# Prompt user for directory to search
$RootFolder = Read-Host "Enter the full path of the folder to search for .exe files"

# Validate the path
if (!(Test-Path $RootFolder)) {
    Write-Host "The specified path does not exist. Exiting." -ForegroundColor Red
    exit
}

# Use user's AppData\Local\Temp folder for output
$OutputFolder = Join-Path $env:LOCALAPPDATA "Temp\ExeLog"

# Ensure the output folder exists
if (!(Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

# Define base file name
$BaseFileName = "ExeLog"

# Find the highest existing log number and increment
$ExistingFiles = Get-ChildItem -Path $OutputFolder -Filter "$BaseFileName*.txt" |
    Where-Object { $_.Name -match "$BaseFileName(\d+)\.txt" } |
    Sort-Object { [int]($_.Name -replace "$BaseFileName(\d+)\.txt", '$1') } -Descending

$LogNumber = if ($ExistingFiles) {
    [int]($ExistingFiles[0].BaseName -replace "$BaseFileName") + 1
} else {
    1
}

# Define the full log file path
$LogFile = Join-Path $OutputFolder "$BaseFileName$LogNumber.txt"

# Get all .exe files recursively and output their full paths
$ExeFiles = Get-ChildItem -Path $RootFolder -Filter "*.exe" -Recurse -Force |
    Select-Object -ExpandProperty FullName

# Save results to the log file
$ExeFiles | Out-File -FilePath $LogFile -Encoding UTF8

# Notify the user
Write-Host "`n[✓] Exe file paths saved to:`n$LogFile" -ForegroundColor Green

# Open the output folder in File Explorer
Start-Process "explorer.exe" $OutputFolder
