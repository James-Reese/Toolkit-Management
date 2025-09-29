# Launch Guard: Prevent direct execution without elevation
$parentProcess = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId
$parentName = (Get-Process -Id $parentProcess -ErrorAction SilentlyContinue).Name

if ($parentName -match "explorer|notepad|powershell_ise") {
    Clear-Host
    $border = "+" + ("=" * 60) + "+"
    $message = @"
$border
|                                                            |
|   This script should not be run directly!                  | 
|                                                            | 
|                                                            | 
|   Please run the batch file instead: 'Run.bat'             | 
|                                                            |
|   This ensures proper elevation and compatibility.         |
|                                                            |
|   Script execution halted.                                 |
|                                                            |
$border
"@
    Write-Host $message -ForegroundColor Yellow
    Start-Sleep -Seconds 8
    exit
}
$ErrorActionPreference = 'SilentlyContinue'

# Elevation check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator."
    Read-Host "Press Enter to exit"
    exit
}

$userTemp = [System.IO.Path]::GetTempPath()
$windowsTemp = "C:\Temp"  # Explicitly target C:\Temp

$logPath = "$env:Temp\clean_temp_log.txt"
Start-Transcript -Path $logPath -Append

function Clear-Folder {
    param (
        [string]$Path,
        [string]$Label
    )
    Write-Host "Clearing $Label folder: $Path"
    if (Test-Path $Path) {
        try {
            Remove-Item "$Path\*" -Force -Recurse
            Write-Host "$Label folder cleared.`n"
        } catch {
            Write-Host "Could not clear $Label folder: $($_.Exception.Message)"
        }
    } else {
        Write-Host "$Label folder not found.`n"
    }
}

Clear-Folder -Path $userTemp -Label "User Temp"
Clear-Folder -Path $windowsTemp -Label "Windows Temp"

Stop-Transcript

Write-Host "Cleanup complete."
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")