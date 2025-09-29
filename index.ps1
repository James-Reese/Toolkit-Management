# Author: James Reese
# Date Created: 9/27/2025
# Last Updated: 9/27/2025

Add-Type -AssemblyName System.Windows.Forms

# Define the script directory relative to this launcher
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$scriptDirectory = Join-Path (Split-Path $basePath -Parent) 'Resources\Scripts'

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Toolkit Script Launcher"
$form.Size = '400,300'
$form.StartPosition = "CenterScreen"

# Create the list box
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = '10,10'
$listBox.Size = '360,200'
$form.Controls.Add($listBox)

# Create the Run button
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Run Selected Script"
$runButton.Location = '10,220'
$runButton.Size = '360,30'
$form.Controls.Add($runButton)

# Populate the list box with .ps1 files
$ps1Files = Get-ChildItem -Path $scriptDirectory -Filter *.ps1 -File
foreach ($file in $ps1Files) {
    $listBox.Items.Add($file.Name)
}

# Run selected script on button click
$runButton.Add_Click({
    $selected = $listBox.SelectedItem
    if ($selected) {
        $scriptPath = Join-Path $scriptDirectory $selected
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        $form.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a script to run.","No Selection",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

# Show the form
[void]$form.ShowDialog()