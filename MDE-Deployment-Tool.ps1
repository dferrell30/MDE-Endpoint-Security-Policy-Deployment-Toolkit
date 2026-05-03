#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

Import-Module (Join-Path $PSScriptRoot 'Modules\Common.psm1') -Force -DisableNameChecking -Global
Import-Module (Join-Path $PSScriptRoot 'Modules\Policy.Json.psm1') -Force -DisableNameChecking -Global
Import-Module (Join-Path $PSScriptRoot 'Modules\Assignments.psm1') -Force -DisableNameChecking -Global

function Test-MDEJsonPolicyFile {
    param(
        [Parameter(Mandatory)]
        [string]$JsonPath
    )

    $name = Split-Path -Path $JsonPath -Leaf

    if (-not (Test-Path -LiteralPath $JsonPath)) {
        return New-MDEPolicyResult `
            -Name $name `
            -Status "Missing" `
            -Details "JSON file not found: $JsonPath"
    }

    try {
        $raw = Get-Content -LiteralPath $JsonPath -Raw

        if ([string]::IsNullOrWhiteSpace($raw)) {
            return New-MDEPolicyResult `
                -Name $name `
                -Status "Invalid" `
                -Details "JSON file is empty"
        }

        $json = $raw | ConvertFrom-Json

        if (-not ($json.PSObject.Properties.Name -contains 'settings')) {
            return New-MDEPolicyResult `
                -Name $name `
                -Status "Invalid" `
                -Details "Missing settings array"
        }

        if (-not $json.settings -or $json.settings.Count -lt 1) {
            return New-MDEPolicyResult `
                -Name $name `
                -Status "Invalid" `
                -Details "Settings array is empty"
        }

        return New-MDEPolicyResult `
            -Name $name `
            -Status "Valid" `
            -Details "JSON passed basic validation"
    }
    catch {
        return New-MDEPolicyResult `
            -Name $name `
            -Status "Invalid" `
            -Details $_.Exception.Message
    }
}

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
    param([string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H)

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

function Set-ResultRowColor {
    param([System.Windows.Forms.DataGridViewRow]$Row,[string]$Status)

    switch ($Status) {
        "Success"  { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Assigned" { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Valid"    { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "WhatIf"   { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,64,175) }
        "Skipped"  { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Missing"  { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Failed"   { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        "Invalid"  { $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
    }

    $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
}

function Add-Result {
    param([string]$Name,[string]$Status,[string]$Details)

    $rowIndex = $gridResults.Rows.Add($Name,$Status,$Details)
    Set-ResultRowColor -Row $gridResults.Rows[$rowIndex] -Status $Status
    Add-Log "${Name}: $Status - $Details"
}

function Invoke-PolicyDeployFromCatalogItem {
    param([Parameter(Mandatory)]$Policy)

    if (-not (Test-Path -LiteralPath $Policy.JsonPath)) {
        return New-MDEPolicyResult -Name $Policy.Name -Status "Skipped" -Details "Missing JSON file: $($Policy.JsonPath)"
    }

    $cmd = Get-Command $Policy.Function -ErrorAction Stop
    $result = & $cmd -WhatIf:$chkWhatIf.Checked

    if ($chkAssignAfterDeploy.Checked -and -not $chkWhatIf.Checked) {
        if ($result.Status -in @("Success","Skipped")) {
            $assignResult = Add-MDEAssignmentFromConfig -PolicyFriendlyName $Policy.Name
            Add-Result -Name $assignResult.Name -Status $assignResult.Status -Details $assignResult.Details
        }
    }

    return $result
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
$subtitle.Text = "JSON-driven Settings Catalog policy deployment"
$subtitle.Location = New-Object System.Drawing.Point(22,48)
$subtitle.Size = New-Object System.Drawing.Size(650,24)
$subtitle.ForeColor = $script:Theme.Muted
$form.Controls.Add($subtitle)

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = "WhatIf / Validate only"
$chkWhatIf.Location = New-Object System.Drawing.Point(700,25)
$chkWhatIf.Size = New-Object System.Drawing.Size(170,24)
$chkWhatIf.ForeColor = $script:Theme.Text
$chkWhatIf.BackColor = $script:Theme.Back
$form.Controls.Add($chkWhatIf)

$chkAssignAfterDeploy = New-Object System.Windows.Forms.CheckBox
$chkAssignAfterDeploy.Text = "Assign after deploy"
$chkAssignAfterDeploy.Location = New-Object System.Drawing.Point(700,50)
$chkAssignAfterDeploy.Size = New-Object System.Drawing.Size(170,24)
$chkAssignAfterDeploy.ForeColor = $script:Theme.Text
$chkAssignAfterDeploy.BackColor = $script:Theme.Back
$form.Controls.Add($chkAssignAfterDeploy)

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
$btnValidate = New-DarkButton "Validate JSON" 890 460 170 36
$btnDeployAll = New-DarkButton "Deploy All Valid" 890 510 170 36

$form.Controls.AddRange(@(
    $btnRefresh,
    $btnDeploy,
    $btnExport,
    $btnOpenConfig,
    $btnOpenLogs,
    $btnValidate,
    $btnDeployAll
))

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
            "Directory.Read.All",
            "Group.Read.All"
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

$btnValidate.Add_Click({
    $gridResults.Rows.Clear()
    $catalog = Get-MDEJsonPolicyCatalog

    foreach ($policy in $catalog) {
        if ($policy.Category -eq 'Editable Baseline') {
            if (Test-Path -LiteralPath $policy.JsonPath) {
                Add-Result -Name $policy.Name -Status "Valid" -Details "Baseline JSON exists"
            }
            else {
                Add-Result -Name $policy.Name -Status "Missing" -Details "Missing baseline JSON: $($policy.JsonPath)"
            }
        }
        else {
            $result = Test-MDEJsonPolicyFile -JsonPath $policy.JsonPath
            Add-Result -Name $result.Name -Status $result.Status -Details $result.Details
        }
    }
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
            $result = Invoke-PolicyDeployFromCatalogItem -Policy $policy
            Add-Result -Name $result.Name -Status $result.Status -Details $result.Details
        }
        catch {
            Add-Result -Name $policy.Name -Status "Failed" -Details $_.Exception.Message
        }
    }
})

$btnDeployAll.Add_Click({
    $gridResults.Rows.Clear()
    $catalog = Get-MDEJsonPolicyCatalog

    foreach ($policy in $catalog) {
        if (-not (Test-Path -LiteralPath $policy.JsonPath)) {
            Add-Log "Skipping $($policy.Name): missing JSON"
            continue
        }

        try {
            Add-Log "Deploying $($policy.Name)..."
            $result = Invoke-PolicyDeployFromCatalogItem -Policy $policy
            Add-Result -Name $result.Name -Status $result.Status -Details $result.Details
        }
        catch {
            Add-Result -Name $policy.Name -Status "Failed" -Details $_.Exception.Message
        }
    }
})

$btnExport.Add_Click({
    try {
        Add-Log "Reloading Common module before export..."

        Import-Module (Join-Path $PSScriptRoot 'Modules\Common.psm1') `
            -Force `
            -DisableNameChecking `
            -Global

        $exportCmd = Get-Command Export-MDEConfigPolicyJson -ErrorAction Stop
        Add-Log "Found export command: $($exportCmd.Name) from $($exportCmd.Source)"

        $policyName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the exact existing Intune Settings Catalog policy name to export:",
            "Export Policy JSON",
            ""
        )

        if ([string]::IsNullOrWhiteSpace($policyName)) {
            Add-Log "Export cancelled."
            return
        }

        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "JSON files (*.json)|*.json"
        $saveDialog.InitialDirectory = Join-Path $PSScriptRoot "Config\SettingsCatalog"
        $saveDialog.FileName = "firewall.json"

        if ($saveDialog.ShowDialog() -eq "OK") {
            Add-Log "Exporting [$policyName] to [$($saveDialog.FileName)]"

            $result = & $exportCmd `
                -PolicyName $policyName `
                -OutputPath $saveDialog.FileName

            Add-Result -Name $result.Name -Status $result.Status -Details $result.Details
            Load-PolicyGrid
        }
    }
    catch {
        Add-Result -Name "Export" -Status "Failed" -Details $_.Exception.Message
        Add-Log "Loaded modules:"
        Get-Module | ForEach-Object {
            Add-Log " - $($_.Name): $($_.Path)"
        }

        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Export Failed")
    }
})

$btnOpenConfig.Add_Click({
    $path = Join-Path $PSScriptRoot "Config"

    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    Start-Process $path
})

$btnOpenLogs.Add_Click({
    $path = Join-Path $PSScriptRoot "Logs"

    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    Start-Process $path
})

Load-PolicyGrid
[void]$form.ShowDialog()
