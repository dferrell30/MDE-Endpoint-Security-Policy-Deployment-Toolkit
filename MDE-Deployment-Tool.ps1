#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

Import-Module "$PSScriptRoot\Modules\Common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.Json.psm1" -Force -DisableNameChecking

$script:Theme = @{
    Back      = [System.Drawing.Color]::FromArgb(18,18,24)
    Panel     = [System.Drawing.Color]::FromArgb(30,30,38)
    PanelAlt  = [System.Drawing.Color]::FromArgb(38,38,48)
    Button    = [System.Drawing.Color]::FromArgb(55,65,81)
    Accent    = [System.Drawing.Color]::FromArgb(0,120,215)
    Text      = [System.Drawing.Color]::White
    Muted     = [System.Drawing.Color]::FromArgb(200,200,210)
    Border    = [System.Drawing.Color]::FromArgb(70,70,85)
}

function Add-Log {
    param([string]$Message)

    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
}

function New-DarkButton {
    param($Text,$X,$Y,$W,$H)

    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X,$Y)
    $b.Size = New-Object System.Drawing.Size($W,$H)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $script:Theme.Button
    $b.ForeColor = $script:Theme.Text
    $b.FlatAppearance.BorderColor = $script:Theme.Border
    return $b
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Microsoft Defender for Endpoint Deployment Tool"
$form.Size = New-Object System.Drawing.Size(1100,720)
$form.StartPosition = "CenterScreen"
$form.BackColor = $script:Theme.Back
$form.ForeColor = $script:Theme.Text
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Defender for Endpoint Deployment Tool"
$title.Location = New-Object System.Drawing.Point(20,15)
$title.Size = New-Object System.Drawing.Size(600,32)
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold",16,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = $script:Theme.Text
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "JSON-driven Endpoint Security and Settings Catalog policy deployment"
$subtitle.Location = New-Object System.Drawing.Point(22,48)
$subtitle.Size = New-Object System.Drawing.Size(650,24)
$subtitle.ForeColor = $script:Theme.Muted
$form.Controls.Add($subtitle)

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = "WhatIf / Validate only"
$chkWhatIf.Location = New-Object System.Drawing.Point(760,25)
$chkWhatIf.Size = New-Object System.Drawing.Size(180,24)
$chkWhatIf.ForeColor = $script:Theme.Text
$chkWhatIf.BackColor = $script:Theme.Back
$form.Controls.Add($chkWhatIf)

$btnInit = New-DarkButton "Initialize Graph" 940 20 120 34
$form.Controls.Add($btnInit)

$gridPolicies = New-Object System.Windows.Forms.DataGridView
$gridPolicies.Location = New-Object System.Drawing.Point(20,90)
$gridPolicies.Size = New-Object System.Drawing.Size(650,430)
$gridPolicies.BackgroundColor = $script:Theme.Panel
$gridPolicies.GridColor = $script:Theme.Border
$gridPolicies.ForeColor = $script:Theme.Text
$gridPolicies.DefaultCellStyle.BackColor = $script:Theme.PanelAlt
$gridPolicies.DefaultCellStyle.ForeColor = $script:Theme.Text
$gridPolicies.DefaultCellStyle.SelectionBackColor = $script:Theme.Accent
$gridPolicies.ColumnHeadersDefaultCellStyle.BackColor = $script:Theme.Button
$gridPolicies.ColumnHeadersDefaultCellStyle.ForeColor = $script:Theme.Text
$gridPolicies.EnableHeadersVisualStyles = $false
$gridPolicies.RowHeadersVisible = $false
$gridPolicies.AllowUserToAddRows = $false
$gridPolicies.SelectionMode = 'FullRowSelect'
$gridPolicies.MultiSelect = $true
$gridPolicies.AutoSizeColumnsMode = 'Fill'

[void]$gridPolicies.Columns.Add("Name","Policy")
[void]$gridPolicies.Columns.Add("Category","Category")
[void]$gridPolicies.Columns.Add("JsonPath","JSON Path")
[void]$gridPolicies.Columns.Add("Exists","JSON Exists")

$form.Controls.Add($gridPolicies)

$gridResults = New-Object System.Windows.Forms.DataGridView
$gridResults.Location = New-Object System.Drawing.Point(690,90)
$gridResults.Size = New-Object System.Drawing.Size(370,250)
$gridResults.BackgroundColor = $script:Theme.Panel
$gridResults.GridColor = $script:Theme.Border
$gridResults.ForeColor = $script:Theme.Text
$gridResults.DefaultCellStyle.BackColor = $script:Theme.PanelAlt
$gridResults.DefaultCellStyle.ForeColor = $script:Theme.Text
$gridResults.DefaultCellStyle.SelectionBackColor = $script:Theme.Accent
$gridResults.ColumnHeadersDefaultCellStyle.BackColor = $script:Theme.Button
$gridResults.ColumnHeadersDefaultCellStyle.ForeColor = $script:Theme.Text
$gridResults.EnableHeadersVisualStyles = $false
$gridResults.RowHeadersVisible = $false
$gridResults.AllowUserToAddRows = $false
$gridResults.AutoSizeColumnsMode = 'Fill'

[void]$gridResults.Columns.Add("Name","Name")
[void]$gridResults.Columns.Add("Status","Status")
[void]$gridResults.Columns.Add("Details","Details")

$form.Controls.Add($gridResults)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20,540)
$txtLog.Size = New-Object System.Drawing.Size(1040,120)
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(12,12,16)
$txtLog.ForeColor = $script:Theme.Text
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtLog)

$btnRefresh = New-DarkButton "Refresh JSON List" 690 360 170 36
$btnDeploy = New-DarkButton "Deploy Selected" 890 360 170 36
$btnExport = New-DarkButton "Export Existing Policy" 690 410 170 36
$btnOpenConfig = New-DarkButton "Open Config Folder" 890 410 170 36
$btnOpenLogs = New-DarkButton "Open Logs Folder" 690 460 170 36

$form.Controls.AddRange(@($btnRefresh,$btnDeploy,$btnExport,$btnOpenConfig,$btnOpenLogs))

function Load-PolicyGrid {
    $gridPolicies.Rows.Clear()

    $catalog = Get-MDEJsonPolicyCatalog

    foreach ($p in $catalog) {
        $exists = Test-Path -LiteralPath $p.JsonPath
        [void]$gridPolicies.Rows.Add($p.Name,$p.Category,$p.JsonPath,$exists)
    }

    Add-Log "Loaded policy catalog."
}

$btnInit.Add_Click({
    try {
        Connect-MgGraph -Scopes @(
            "DeviceManagementConfiguration.ReadWrite.All",
            "DeviceManagementManagedDevices.Read.All",
            "Directory.Read.All"
        ) -NoWelcome

        Add-Log "Connected to Microsoft Graph."
        [System.Windows.Forms.MessageBox]::Show("Connected to Microsoft Graph.","Graph Connected")
    }
    catch {
        Add-Log "Graph connection failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Graph Error")
    }
})

$btnRefresh.Add_Click({
    Load-PolicyGrid
})

$btnDeploy.Add_Click({
    $gridResults.Rows.Clear()

    if ($gridPolicies.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Select one or more policies first.","No Selection")
        return
    }

    $catalog = Get-MDEJsonPolicyCatalog

    foreach ($row in $gridPolicies.SelectedRows) {
        $policyName = $row.Cells["Name"].Value
        $policy = $catalog | Where-Object { $_.Name -eq $policyName } | Select-Object -First 1

        if (-not $policy) {
            continue
        }

        try {
            Add-Log "Processing $($policy.Name)..."

            if (-not (Test-Path -LiteralPath $policy.JsonPath)) {
                $result = New-MDEPolicyResult `
                    -Name $policy.Name `
                    -Status "Skipped" `
                    -Details "Missing JSON file: $($policy.JsonPath)"
            }
            else {
                $cmd = Get-Command $policy.Function -ErrorAction Stop
                $result = & $cmd -WhatIf:$chkWhatIf.Checked
            }

            [void]$gridResults.Rows.Add($result.Name,$result.Status,$result.Details)
            Add-Log "$($result.Name): $($result.Status) - $($result.Details)"
        }
        catch {
            [void]$gridResults.Rows.Add($policy.Name,"Failed",$_.Exception.Message)
            Add-Log "$($policy.Name): Failed - $($_.Exception.Message)"
        }
    }
})

$btnExport.Add_Click({
    try {
        $policyName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the exact existing Intune policy name to export:",
            "Export Policy JSON",
            ""
        )

        if ([string]::IsNullOrWhiteSpace($policyName)) {
            return
        }

        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "JSON files (*.json)|*.json"
        $saveDialog.InitialDirectory = Join-Path $PSScriptRoot "Config"
        $saveDialog.FileName = "$($policyName -replace '[\\/:*?""<>|]', '-')`.json"

        if ($saveDialog.ShowDialog() -eq "OK") {
            $result = Export-MDEConfigPolicyJson `
                -PolicyName $policyName `
                -OutputPath $saveDialog.FileName

            [void]$gridResults.Rows.Add($result.Name,$result.Status,$result.Details)
            Add-Log "$($result.Name): $($result.Status) - $($result.Details)"
            Load-PolicyGrid
        }
    }
    catch {
        Add-Log "Export failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Export Failed")
    }
})

$btnOpenConfig.Add_Click({
    Start-Process (Join-Path $PSScriptRoot "Config")
})

$btnOpenLogs.Add_Click({
    Start-Process (Join-Path $PSScriptRoot "Logs")
})

Load-PolicyGrid

[void]$form.ShowDialog()
