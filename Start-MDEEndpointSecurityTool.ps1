Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Import-Module "$PSScriptRoot\Modules\Bootstrapper.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Common.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policy.EDR.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policy.ApplicationControl.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policy.ASR.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policy.Antivirus.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policy.Firewall.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Policy.SecurityExperience.psm1" -Force

$form = New-Object System.Windows.Forms.Form
$form.Text = "MDE Endpoint Security Deployment Tool"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(980, 650)
$form.MinimumSize = New-Object System.Drawing.Size(980, 650)

$btnInit = New-Object System.Windows.Forms.Button
$btnInit.Text = "Initialize"
$btnInit.Location = New-Object System.Drawing.Point(20, 20)
$btnInit.Size = New-Object System.Drawing.Size(130, 35)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Create Selected"
$btnRun.Location = New-Object System.Drawing.Point(165, 20)
$btnRun.Size = New-Object System.Drawing.Size(150, 35)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = "Create All"
$btnAll.Location = New-Object System.Drawing.Point(330, 20)
$btnAll.Size = New-Object System.Drawing.Size(130, 35)

$btnLogs = New-Object System.Windows.Forms.Button
$btnLogs.Text = "Open Logs Folder"
$btnLogs.Location = New-Object System.Drawing.Point(475, 20)
$btnLogs.Size = New-Object System.Drawing.Size(140, 35)

$chkAV = New-Object System.Windows.Forms.CheckBox
$chkAV.Text = "Antivirus"
$chkAV.Location = New-Object System.Drawing.Point(20, 75)
$chkAV.AutoSize = $true

$chkSec = New-Object System.Windows.Forms.CheckBox
$chkSec.Text = "Windows Security Experience"
$chkSec.Location = New-Object System.Drawing.Point(130, 75)
$chkSec.AutoSize = $true

$chkASR = New-Object System.Windows.Forms.CheckBox
$chkASR.Text = "ASR"
$chkASR.Location = New-Object System.Drawing.Point(355, 75)
$chkASR.AutoSize = $true

$chkEDR = New-Object System.Windows.Forms.CheckBox
$chkEDR.Text = "EDR"
$chkEDR.Location = New-Object System.Drawing.Point(420, 75)
$chkEDR.AutoSize = $true

$chkFW = New-Object System.Windows.Forms.CheckBox
$chkFW.Text = "Firewall"
$chkFW.Location = New-Object System.Drawing.Point(485, 75)
$chkFW.AutoSize = $true

$chkApp = New-Object System.Windows.Forms.CheckBox
$chkApp.Text = "Application Control"
$chkApp.Location = New-Object System.Drawing.Point(565, 75)
$chkApp.AutoSize = $true

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready."
$lblStatus.Location = New-Object System.Drawing.Point(20, 105)
$lblStatus.Size = New-Object System.Drawing.Size(900, 20)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20, 135)
$listView.Size = New-Object System.Drawing.Size(920, 390)
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true

[void]$listView.Columns.Add("Policy Name", 240)
[void]$listView.Columns.Add("Status", 100)
[void]$listView.Columns.Add("Details", 430)
[void]$listView.Columns.Add("Time", 140)

$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Location = New-Object System.Drawing.Point(20, 540)
$txtSummary.Size = New-Object System.Drawing.Size(920, 60)
$txtSummary.Multiline = $true
$txtSummary.ScrollBars = "Vertical"
$txtSummary.ReadOnly = $true

function Add-ListRow {
    param(
        [Parameter(Mandatory)]
        $Result
    )

    $rowTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ($null -ne $Result -and $Result.PSObject.Properties['Time']) {
        if ($null -ne $Result.Time) {
            try {
                $rowTime = Get-Date -Date $Result.Time -Format 'yyyy-MM-dd HH:mm:ss'
            }
            catch {
                $rowTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            }
        }
    }

    $name = ''
    $status = ''
    $details = ''

    if ($null -ne $Result.PSObject.Properties['Name']) { $name = [string]$Result.Name }
    if ($null -ne $Result.PSObject.Properties['Status']) { $status = [string]$Result.Status }
    if ($null -ne $Result.PSObject.Properties['Details']) { $details = [string]$Result.Details }

    $item = New-Object System.Windows.Forms.ListViewItem($name)
    [void]$item.SubItems.Add($status)
    [void]$item.SubItems.Add($details)
    [void]$item.SubItems.Add($rowTime)
    [void]$listView.Items.Add($item)
}

function Invoke-SelectedPolicyCreation {
    $results = @()

    if ($chkAV.Checked)  { $results += New-MDEAntivirusPolicy }
    if ($chkSec.Checked) { $results += New-MDESecurityExperiencePolicy }
    if ($chkASR.Checked) { $results += New-MDEASRPolicy }
    if ($chkEDR.Checked) { $results += New-MDEEDRPolicy }
    if ($chkFW.Checked)  { $results += New-MDEFirewallPolicy }
    if ($chkApp.Checked) { $results += New-MDEApplicationControlPolicy }

    return $results
}

$btnInit.Add_Click({
    try {
        $btnInit.Enabled = $false
        $lblStatus.Text = "Initializing..."
        Initialize-MDEDeployment
        $ctx = Get-MgContext
        $lblStatus.Text = "Connected to Microsoft Graph as $($ctx.Account)"
    }
    catch {
        $lblStatus.Text = "Initialization failed."
        [System.Windows.Forms.MessageBox]::Show($_.Exception.ToString(), "Initialization Error") | Out-Null
    }
    finally {
        $btnInit.Enabled = $true
    }
})

$btnLogs.Add_Click({
    $logPath = Join-Path $PSScriptRoot 'Logs'
    if (-not (Test-Path -LiteralPath $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    Start-Process explorer.exe $logPath
})

$btnRun.Add_Click({
    try {
        $btnRun.Enabled = $false
        $btnAll.Enabled = $false
        $listView.Items.Clear()
        $txtSummary.Clear()
        $lblStatus.Text = "Creating selected policies..."

        $results = Invoke-SelectedPolicyCreation

        foreach ($r in $results) {
            Add-ListRow -Result $r
        }

        $summary = $results |
            Group-Object Status |
            Sort-Object Name |
            ForEach-Object {
                "{0}: {1}" -f $_.Name, $_.Count
            }

        $txtSummary.Text = ($summary -join [Environment]::NewLine)
        $lblStatus.Text = "Policy creation complete."
    }
    catch {
        $lblStatus.Text = "Policy creation failed."
        [System.Windows.Forms.MessageBox]::Show($_.Exception.ToString(), "Execution Error") | Out-Null
    }
    finally {
        $btnRun.Enabled = $true
        $btnAll.Enabled = $true
    }
})

$btnAll.Add_Click({
    $chkAV.Checked = $true
    $chkSec.Checked = $true
    $chkASR.Checked = $true
    $chkEDR.Checked = $true
    $chkFW.Checked = $true
    $chkApp.Checked = $true
    $btnRun.PerformClick()
})

$form.Controls.AddRange(@(
    $btnInit,
    $btnRun,
    $btnAll,
    $btnLogs,
    $chkAV,
    $chkSec,
    $chkASR,
    $chkEDR,
    $chkFW,
    $chkApp,
    $lblStatus,
    $listView,
    $txtSummary
))

[void]$form.ShowDialog()
