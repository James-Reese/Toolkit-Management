# Author: James Reese III
# Version: ALPHA 1.1 (Optimized)
# Date: 09/28/2025

# Hide the PowerShell console window
Add-Type -Name Win32ShowWindowAsync -Namespace Win32Functions -MemberDefinition @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
"@
$consolePtr = [Win32Functions.Win32ShowWindowAsync]::GetConsoleWindow()
[Win32Functions.Win32ShowWindowAsync]::ShowWindowAsync($consolePtr, 0)

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Functions ---
function Add-Label {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [System.Drawing.Font]$Font = $null,
        [System.Drawing.Size]$Size = [System.Drawing.Size]::Empty
    )
    $label = [System.Windows.Forms.Label]@{
        Text     = $Text
        Location = $Location
        AutoSize = $true
    }
    if ($Font) { $label.Font = $Font }
    if ($Size -ne [System.Drawing.Size]::Empty) {
        $label.AutoSize = $false
        $label.Size = $Size
    }
    $form.Controls.Add($label)
}

function New-ActionButton {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [string]$ScriptPath,
        [string]$ToolTipText,
        [switch]$Exit
    )
    $btn = [System.Windows.Forms.Button]@{
        Text     = $Text
        Size     = [System.Drawing.Size]::new(100, 35)
        Location = $Location
    }
    if ($Exit) {
        $btn.Add_Click({ $form.Close() })
    } else {
        $btn.Add_Click({
            if (Test-Path $ScriptPath) {
                Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`""
            } else {
                [System.Windows.Forms.MessageBox]::Show("Script not found:`n$ScriptPath", "Error", "OK", "Error")
            }
        })
    }
    $form.Controls.Add($btn)
    $toolTip.SetToolTip($btn, $ToolTipText)
}

function Apply-Theme {
    param ($mode)

    $themes = @{
        Dark   = @{ Back = [System.Drawing.Color]::FromArgb(30,30,30); Fore = [System.Drawing.Color]::White; Drop = [System.Drawing.Color]::FromArgb(45,45,45) }
        Light  = @{ Back = [System.Drawing.Color]::White; Fore = [System.Drawing.Color]::Black; Drop = [System.Drawing.Color]::White }
        System = @{ Back = [System.Drawing.SystemColors]::Window; Fore = [System.Drawing.SystemColors]::WindowText; Drop = [System.Drawing.SystemColors]::Window }
    }

    $t = $themes[$mode]
    $form.BackColor = $t.Back

    foreach ($ctrl in $form.Controls) {
        $ctrl.ForeColor = $t.Fore
        if ($ctrl -is [System.Windows.Forms.ComboBox]) {
            $ctrl.BackColor = $t.Drop
            $ctrl.FlatStyle = 'Flat'
        } elseif ($ctrl -is [System.Windows.Forms.Button] -or
                  $ctrl -is [System.Windows.Forms.CheckBox] -or
                  $ctrl -is [System.Windows.Forms.RadioButton]) {
            $ctrl.BackColor = $t.Back
            $ctrl.FlatStyle = 'Flat'
        }
    }
}

# --- Form Setup ---
$form = [System.Windows.Forms.Form]@{
    Text          = "Toolkit Utility"
    Size          = [System.Drawing.Size]::new(600, 560)
    StartPosition = "CenterScreen"
    BackColor     = [System.Drawing.Color]::White
}

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.ShowAlways = $true

# --- Header ---
Add-Label "Toolkit Utility Script" ([System.Drawing.Point]::new(20, 20)) ([System.Drawing.Font]::new("Segoe UI", 14, [System.Drawing.FontStyle]::Bold))
Add-Label "Version: 1.1.0" ([System.Drawing.Point]::new(20, 60))
Add-Label "Last Updated: $(Get-Date -Format 'MMMM dd, yyyy')" ([System.Drawing.Point]::new(20, 85))
Add-Label "This utility allows for the upkeep and organization of the Toolkit environment." ([System.Drawing.Point]::new(20, 110)) $null ([System.Drawing.Size]::new(540, 50))
# --- Scan Button ---
$scanBtn = New-Object System.Windows.Forms.Button
$scanBtn.Text = "Scan"
$scanBtn.Size = [System.Drawing.Size]::new(100, 35)
$scanBtn.Location = [System.Drawing.Point]::new(20, 180)
$scanBtn.Add_Click({
    $target = "C:\Users\Jimmy\OneDrive\My Toolkit\Scripts\Windows\PowerShell\Toolkit Management\Resources\Scripts\exscan.ps1"
    if (Test-Path $target) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$target`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("Script not found:`n$target", "Error", "OK", "Error")
    }
})
$form.Controls.Add($scanBtn)
$toolTip.SetToolTip($scanBtn, "Scan your Toolkit environment for executables.")

# --- Clean Button ---
$cleanBtn = New-Object System.Windows.Forms.Button
$cleanBtn.Text = "Clean"
$cleanBtn.Size = [System.Drawing.Size]::new(100, 35)
$cleanBtn.Location = [System.Drawing.Point]::new(130, 180)
$cleanBtn.Add_Click({
    $target = "C:\Users\Jimmy\OneDrive\My Toolkit\Scripts\Windows\PowerShell\Clean Temp\run.bat"
    if (Test-Path $target) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$target`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("Script not found:`n$target", "Error", "OK", "Error")
    }
})
$form.Controls.Add($cleanBtn)
$toolTip.SetToolTip($cleanBtn, "Clean temporary or outdated Toolkit files.")

# --- Update Button ---
$updateBtn = New-Object System.Windows.Forms.Button
$updateBtn.Text = "Update"
$updateBtn.Size = [System.Drawing.Size]::new(100, 35)
$updateBtn.Location = [System.Drawing.Point]::new(240, 180)
$updateBtn.Add_Click({
    $target = "$PSScriptRoot\Scripts\Update.ps1"
    if (Test-Path $target) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$target`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("Script not found:`n$target", "Error", "OK", "Error")
    }
})
$form.Controls.Add($updateBtn)
$toolTip.SetToolTip($updateBtn, "Update the Toolkit to the latest version.")

# --- Exit Button ---
$exitBtn = New-Object System.Windows.Forms.Button
$exitBtn.Text = "Exit"
$exitBtn.Size = [System.Drawing.Size]::new(100, 35)
$exitBtn.Location = [System.Drawing.Point]::new(350, 180)
$exitBtn.Add_Click({ $form.Close() })
$form.Controls.Add($exitBtn)
$toolTip.SetToolTip($exitBtn, "Close the Toolkit Utility.")

# --- Dropdown & Run ---
$comboBox = [System.Windows.Forms.ComboBox]@{
    Location       = [System.Drawing.Point]::new(20, 240)
    Size           = [System.Drawing.Size]::new(250, 30)
    DropDownStyle  = 'DropDownList'
}
$comboBox.Items.AddRange(@("Toolkit A", "Toolkit B", "Toolkit C", "Run Scripts"))
$comboBox.SelectedIndex = 0
$form.Controls.Add($comboBox)

$runButton = [System.Windows.Forms.Button]@{
    Text     = "Run"
    Size     = [System.Drawing.Size]::new(80, 30)
    Location = [System.Drawing.Point]::new(290, 240)
}
$runButton.Add_Click({
    $scriptMap = @{
        "Toolkit A"   = "$PSScriptRoot\Scripts\ToolkitA.ps1"
        "Toolkit B"   = "$PSScriptRoot\Scripts\ToolkitB.ps1"
        "Toolkit C"   = "$PSScriptRoot\Scripts\ToolkitC.ps1"
        "Run Scripts" = "C:\Users\Jimmy\OneDrive\My Toolkit\Scripts\Windows\PowerShell\Toolkit Management\Main\index.ps1"
    }
    $selection = $comboBox.SelectedItem
    if ($scriptMap.ContainsKey($selection)) {
        $target = $scriptMap[$selection]
        if (Test-Path $target) {
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$target`""
            Start-Sleep -Milliseconds 300
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Script not found:`n$target", "Error", "OK", "Error")
        }
    }
})
$form.Controls.Add($runButton)

# --- Checkboxes ---
$checkboxes = @(
    @{ Text = "Enable Logging"; Location = [System.Drawing.Point]::new(20, 290) },
    @{ Text = "Verbose Mode";   Location = [System.Drawing.Point]::new(180, 290) }
)
foreach ($cb in $checkboxes) {
    $form.Controls.Add([System.Windows.Forms.CheckBox]@{
        Text     = $cb.Text
        Location = $cb.Location
    })
}

# --- Radio Buttons ---
$radioButtons = @(
    @{ Text = "Basic";    Location = [System.Drawing.Point]::new(20, 330) },
    @{ Text = "Advanced"; Location = [System.Drawing.Point]::new(180, 330) }
)
foreach ($rb in $radioButtons) {
    $form.Controls.Add([System.Windows.Forms.RadioButton]@{
        Text     = $rb.Text
        Location = $rb.Location
    })
}


# --- Theme Selector ---
$themeSelector = [System.Windows.Forms.ComboBox]@{
    Location      = [System.Drawing.Point]::new(20, 380)
    Size          = [System.Drawing.Size]::new(150, 30)
    DropDownStyle = 'DropDownList'
}
$themeSelector.Items.AddRange(@("Light", "Dark", "System"))
$themeSelector.SelectedItem = "Light"
$themeSelector.Add_SelectedIndexChanged({ Apply-Theme $themeSelector.SelectedItem })
$form.Controls.Add($themeSelector)

# Apply default theme
Apply-Theme "System"

# --- Show Form ---
$form.ShowDialog()