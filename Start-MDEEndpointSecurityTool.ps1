Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Import-Module "$PSScriptRoot\Modules\Bootstrapper.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policies.psm1" -Force

$form = New-Object System.Windows.Forms.Form
$form.Text = "MDE Endpoint Security Deployment Tool"
$form.Size = New-Object System.Drawing.Size(900, 620)
$form.StartPosition = "CenterScreen"

# Buttons
$btnInit = New-Object System.Windows.Forms.Button
$btnInit.Text = "Initialize"
$btnInit.Location = "20,20"
$btnInit.Size = "130,35"

$btnDeploy = New-Object System.Windows.Forms.Button
$btnDeploy.Text = "Create Selected Policies"
$btnDeploy.Location = "165,20"
$btnDeploy.Size = "180,35"

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = "Create All"
$btnAll.Location = "360,20"
$btnAll.Size = "130,35"

$btnLogs = New-Object System.Windows.Forms.Button
$btnLogs.Text = "Open Logs"
$btnLogs.Location = "505,20"
$btnLogs.Size = "130,35"

# Checkboxes
$chkAV = New-Object System.Windows.Forms.CheckBox
$chkAV.Text = "Antivirus"
$chkAV.Location = "20,70"
$chkAV.Checked = $true

$chkSec = New-Object System.Windows.Forms.CheckBox
$chkSec.Text = "Windows Security Experience"
$chkSec.Location = "150,70"
$chkSec.Checked = $true

$chkASR = New-Object System.Windows.Forms.CheckBox
$chkASR.Text = "ASR"
$chkASR.Location = "380,70"
$chkASR.Checked = $true

$chkEDR = New-Object System.Windows.Forms.CheckBox
$chkEDR.Text = "EDR"
$chkEDR.Location = "450,70"
$chkEDR.Checked = $true

$chkFW = New-Object System.Windows.Forms.CheckBox
$chkFW.Text = "Firewall"
$chkFW.Location = "520,70"
$chkFW.Checked = $true

$chkApp = New-Object System.Windows.Forms.CheckBox
$chkApp.Text = "Application Control"
$chkApp.Location = "600,70"
$chkApp.Checked = $true

# Status
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready."
$lblStatus.Location = "20,100"
$lblStatus.Size = "800,20"

# ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = "20,130"
$listView.Size = "840,330"
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true

$listView.Columns.Add("Policy",150)
$listView.Columns.Add("Status",100)
$listView.Columns.Add("Details",450)
$listView.Columns.Add("Time",120)

# Summary
$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Location = "20,470"
$txtSummary.Size = "840,90"
$txtSummary.Multiline = $true
$txtSummary.ReadOnly = $true

function Add-Row($name,$status,$details) {
    $item = New-Object System.Windows.Forms.ListViewItem($name)
    $item.SubItems.Add($status)
    $item.SubItems.Add($details)
    $item.SubItems.Add((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
    $listView.Items.Add($item) | Out-Null
}

# INIT
$btnInit.Add_Click({
    try {
        $lblStatus.Text = "Initializing..."
        Invoke-MDEBootstrap
        $lblStatus.Text = "Connected to Graph."
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message)
    }
})

# DEPLOY SELECTED
$btnDeploy.Add_Click({
    $listView.Items.Clear()
    $txtSummary.Clear()

    $results = @()

    if ($chkAV.Checked) { $results += New-MDEAntivirusPolicy }
    if ($chkSec.Checked) { $results += New-MDESecurityExperiencePolicy }
    if ($chkASR.Checked) { $results += New-MDEASRPolicy }
    if ($chkEDR.Checked) { $results += New-MDEEDRPolicy }
    if ($chkFW.Checked) { $results += New-MDEFirewallPolicy }
    if ($chkApp.Checked) { $results += New-MDEAppControlPolicy }

    foreach ($r in $results) {
        Add-Row $r.Name $r.Status $r.Details
    }

    $txtSummary.Text = ($results | Group Status | ForEach-Object {
        "$($_.Name): $($_.Count)"
    }) -join "`n"

    $lblStatus.Text = "Complete."
})

# CREATE ALL
$btnAll.Add_Click({
    $chkAV.Checked = $true
    $chkSec.Checked = $true
    $chkASR.Checked = $true
    $chkEDR.Checked = $true
    $chkFW.Checked = $true
    $chkApp.Checked = $true
    $btnDeploy.PerformClick()
})

# LOGS
$btnLogs.Add_Click({
    $path = "$PSScriptRoot\Logs"
    if (!(Test-Path $path)) { New-Item -ItemType Directory $path | Out-Null }
    explorer.exe $path
})

$form.Controls.AddRange(@(
    $btnInit,$btnDeploy,$btnAll,$btnLogs,
    $chkAV,$chkSec,$chkASR,$chkEDR,$chkFW,$chkApp,
    $lblStatus,$listView,$txtSummary
))

$form.ShowDialog()
