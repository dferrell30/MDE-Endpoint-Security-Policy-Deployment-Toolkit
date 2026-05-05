#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

$PolicyPrefix = "MDE"
$script:LastResults = @()

function New-MDEPolicyResult {
    param([string]$Name,[string]$Status,[string]$Details)
    [pscustomobject]@{ Name=$Name; Status=$Status; Details=$Details; Time=Get-Date }
}

function Get-MDEPolicyName {
    param([string]$Name)
    "$PolicyPrefix - $Name"
}

function Assert-Mg {
    if (-not (Get-MgContext)) {
        throw "Not connected to Microsoft Graph. Click Initialize Graph first."
    }
}

function Get-MDEFolder {
    param([string]$Name)
    $path = Join-Path $PSScriptRoot $Name
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Get-MDELogFolder { Get-MDEFolder "Logs" }
function Get-MDEReportFolder { Get-MDEFolder "Reports" }
function Get-MDEBackupFolder { Get-MDEFolder "Backups" }

function Write-MDELogFile {
    param([string]$Message)

    try {
        $logPath = Join-Path (Get-MDELogFolder) "deployment.log"
        Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    }
    catch { }
}

function Get-MDEJsonBody {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "JSON file is empty: $Path"
    }

    $raw | ConvertFrom-Json
}

function Test-MDEJsonPolicyFile {
    param([string]$JsonPath)

    $name = Split-Path $JsonPath -Leaf

    try {
        $json = Get-MDEJsonBody -Path $JsonPath

        if (-not ($json.PSObject.Properties.Name -contains "settings")) {
            return New-MDEPolicyResult $name "Invalid" "Missing settings array"
        }

        if (-not $json.settings -or $json.settings.Count -lt 1) {
            return New-MDEPolicyResult $name "Invalid" "Settings array is empty"
        }

        return New-MDEPolicyResult $name "Valid" "JSON passed basic validation"
    }
    catch {
        return New-MDEPolicyResult $name "Invalid" $_.Exception.Message
    }
}

function Get-MDEConfigPolicy {
    param([string]$PolicyDisplayName)

    Assert-Mg

    $escaped = $PolicyDisplayName.Replace("'","''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"
    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $result.value -or $result.value.Count -eq 0) {
        return $null
    }

    return $result.value[0]
}

function Test-MDEConfigPolicyExists {
    param([string]$Name)

    $displayName = Get-MDEPolicyName $Name
    $policy = Get-MDEConfigPolicy -PolicyDisplayName $displayName
    return [bool]$policy
}

function Export-MDEConfigPolicyJsonById {
    param(
        [string]$PolicyId,
        [string]$OutputPath
    )

    Assert-Mg

    $policyUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId"
    $p = Invoke-MgGraphRequest -Method GET -Uri $policyUri -OutputType PSObject

    $settingsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId/settings"
    $settings = Invoke-MgGraphRequest -Method GET -Uri $settingsUri -OutputType PSObject

    $body = [ordered]@{
        name            = $p.name
        description     = $p.description
        platforms       = $p.platforms
        technologies    = $p.technologies
        roleScopeTagIds = @($p.roleScopeTagIds)
        settings        = @($settings.value)
    }

    if ($p.PSObject.Properties.Name -contains "templateReference" -and $p.templateReference) {
        $body.templateReference = $p.templateReference
    }

    $folder = Split-Path $OutputPath -Parent
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $body | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function Backup-MDELocalJson {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $source = Join-Path $PSScriptRoot "Config\SettingsCatalog"
    $dest = Join-Path (Get-MDEBackupFolder) "LocalJson-$timestamp"

    if (-not (Test-Path -LiteralPath $source)) {
        throw "SettingsCatalog folder not found: $source"
    }

    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path (Join-Path $source "*.json") -Destination $dest -Force

    return $dest
}

function Backup-MDECloudPolicy {
    param([string]$PolicyDisplayName)

    $policy = Get-MDEConfigPolicy -PolicyDisplayName $PolicyDisplayName

    if (-not $policy) {
        return $null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeName = $PolicyDisplayName.ToLower() -replace '\s+','-' -replace '[\\/:*?""<>|]',''
    $folder = Join-Path (Get-MDEBackupFolder) "CloudPolicy-$timestamp"

    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    $path = Join-Path $folder "$safeName.json"
    Export-MDEConfigPolicyJsonById -PolicyId $policy.id -OutputPath $path

    return $path
}

function Remove-MDEConfigPolicy {
    param([string]$PolicyDisplayName)

    $policy = Get-MDEConfigPolicy -PolicyDisplayName $PolicyDisplayName

    if (-not $policy) {
        return $false
    }

    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)"
    Invoke-MgGraphRequest -Method DELETE -Uri $uri | Out-Null
    return $true
}

function New-MDEConfigPolicyFromJson {
    param(
        [string]$Name,
        [string]$JsonPath,
        [switch]$WhatIf,
        [switch]$UpdateExisting
    )

    Assert-Mg

    $displayName = Get-MDEPolicyName $Name

    try {
        $existing = Get-MDEConfigPolicy -PolicyDisplayName $displayName

        if ($existing -and -not $UpdateExisting) {
            return New-MDEPolicyResult $displayName "Skipped" "Policy already exists"
        }

        if ($existing -and $UpdateExisting) {
            if ($WhatIf) {
                return New-MDEPolicyResult $displayName "WhatIf" "Would backup, remove, and recreate existing policy"
            }

            $backupPath = Backup-MDECloudPolicy -PolicyDisplayName $displayName
            Remove-MDEConfigPolicy -PolicyDisplayName $displayName | Out-Null
            Write-MDELogFile "Backed up existing cloud policy [$displayName] to [$backupPath]"
        }

        $body = Get-MDEJsonBody -Path $JsonPath
        $body.name = $displayName
        $json = $body | ConvertTo-Json -Depth 100 -Compress

        if ($WhatIf) {
            return New-MDEPolicyResult $displayName "WhatIf" "Validated JSON only: $JsonPath"
        }

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
            -Body $json `
            -ContentType "application/json" | Out-Null

        if ($existing -and $UpdateExisting) {
            return New-MDEPolicyResult $displayName "Success" "Updated policy by backup, remove, and recreate"
        }

        return New-MDEPolicyResult $displayName "Success" "Created configuration policy"
    }
    catch {
        return New-MDEPolicyResult $displayName "Failed" $_.Exception.Message
    }
}

function Export-MDEConfigPolicyJson {
    param(
        [string]$PolicyName,
        [string]$OutputPath
    )

    Assert-Mg

    try {
        $policy = Get-MDEConfigPolicy -PolicyDisplayName $PolicyName

        if (-not $policy) {
            throw "Policy not found: $PolicyName"
        }

        Export-MDEConfigPolicyJsonById -PolicyId $policy.id -OutputPath $OutputPath
        return New-MDEPolicyResult $PolicyName "Success" "Exported to $OutputPath"
    }
    catch {
        return New-MDEPolicyResult $PolicyName "Failed" $_.Exception.Message
    }
}

function Get-MDEJsonPolicyCatalog {
    @(
        [pscustomobject]@{ Name="Antivirus"; Category="Settings Catalog"; JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\antivirus.json") }
        [pscustomobject]@{ Name="Firewall"; Category="Settings Catalog"; JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\firewall.json") }
        [pscustomobject]@{ Name="ASR"; Category="Settings Catalog"; JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\asr.json") }
        [pscustomobject]@{ Name="EDR"; Category="Settings Catalog"; JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\edr.json") }
        [pscustomobject]@{ Name="Windows Security Experience"; Category="Settings Catalog"; JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\windows-security-experience.json") }
        [pscustomobject]@{ Name="AVC Update Controls"; Category="Settings Catalog"; JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\avc-update-controls.json") }
    )
}

function Get-MDESettingValue {
    param($Setting)

    $instance = $Setting.settingInstance
    if (-not $instance) { return "" }

    if ($instance.PSObject.Properties.Name -contains "choiceSettingValue") {
        return [string]$instance.choiceSettingValue.value
    }

    if ($instance.PSObject.Properties.Name -contains "simpleSettingValue") {
        return [string]$instance.simpleSettingValue.value
    }

    if ($instance.PSObject.Properties.Name -contains "simpleSettingCollectionValue") {
        return ($instance.simpleSettingCollectionValue | ConvertTo-Json -Depth 20 -Compress)
    }

    return ""
}

function Show-MDEPolicySettingsSummary {
    param($Policy)

    if (-not (Test-Path -LiteralPath $Policy.JsonPath)) {
        Add-Result $Policy.Name "Missing" "JSON file not found: $($Policy.JsonPath)"
        return
    }

    try {
        $json = Get-MDEJsonBody -Path $Policy.JsonPath
        Add-Result $Policy.Name "Summary" "Settings count: $($json.settings.Count)"

        foreach ($setting in $json.settings) {
            $instance = $setting.settingInstance
            if (-not $instance) { continue }

            $settingId = $instance.settingDefinitionId
            $value = Get-MDESettingValue -Setting $setting

            if ([string]::IsNullOrWhiteSpace($value)) {
                $value = "(no direct value / child settings)"
            }

            Add-Result $Policy.Name "Setting" "$settingId = $value"
        }
    }
    catch {
        Add-Result $Policy.Name "Failed" $_.Exception.Message
    }
}

function New-MDEDeploymentReport {
    param([array]$Results)

    $reportPath = Join-Path (Get-MDEReportFolder) "deployment-report.html"
    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $rows = foreach ($r in $Results) {
        $statusClass = switch ($r.Status) {
            "Success" { "success" }
            "Valid" { "success" }
            "Summary" { "whatif" }
            "Setting" { "default" }
            "WhatIf" { "whatif" }
            "Skipped" { "skipped" }
            "Missing" { "skipped" }
            "Failed" { "failed" }
            "Invalid" { "failed" }
            default { "default" }
        }

        "<tr class='$statusClass'><td>$($r.Time)</td><td>$($r.Name)</td><td>$($r.Status)</td><td>$($r.Details)</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>MDE Deployment Report</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; background: #111827; color: #e5e7eb; margin: 30px; }
h1 { color: #ffffff; }
.badge { display:inline-block; padding:6px 12px; background:#1f2937; border-radius:8px; margin-bottom:20px; }
table { width:100%; border-collapse:collapse; background:#1f2937; }
th { background:#374151; color:#fff; text-align:left; padding:10px; }
td { padding:10px; border-bottom:1px solid #374151; vertical-align:top; }
tr.success td { background:#14532d; }
tr.whatif td { background:#1e3a8a; }
tr.skipped td { background:#713f12; }
tr.failed td { background:#7f1d1d; }
tr.default td { background:#1f2937; }
.footer { margin-top:20px; font-size:12px; color:#9ca3af; }
</style>
</head>
<body>
<h1>Microsoft Defender for Endpoint Deployment Report</h1>
<div class="badge">Generated: $generated</div>
<table>
<thead>
<tr><th>Time</th><th>Name</th><th>Status</th><th>Details</th></tr>
</thead>
<tbody>
$($rows -join "`n")
</tbody>
</table>
<div class="footer">Generated by MDE Deployment Tool</div>
</body>
</html>
"@

    $html | Set-Content -LiteralPath $reportPath -Encoding UTF8
    return $reportPath
}

$Theme = @{
    Back     = [System.Drawing.Color]::FromArgb(18,18,24)
    Panel    = [System.Drawing.Color]::FromArgb(30,30,38)
    PanelAlt = [System.Drawing.Color]::FromArgb(38,38,48)
    Button   = [System.Drawing.Color]::FromArgb(55,65,81)
    Accent   = [System.Drawing.Color]::FromArgb(0,120,215)
    Text     = [System.Drawing.Color]::White
    Muted    = [System.Drawing.Color]::FromArgb(200,200,210)
    Border   = [System.Drawing.Color]::FromArgb(70,70,85)
}

function New-DarkButton {
    param([string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H)

    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X,$Y)
    $b.Size = New-Object System.Drawing.Size($W,$H)
    $b.FlatStyle = "Flat"
    $b.BackColor = $Theme.Button
    $b.ForeColor = $Theme.Text
    $b.FlatAppearance.BorderColor = $Theme.Border
    return $b
}

function Add-Log {
    param([string]$Message)
    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
    Write-MDELogFile -Message $Message
}

function Add-Result {
    param([string]$Name,[string]$Status,[string]$Details)

    $resultObject = New-MDEPolicyResult -Name $Name -Status $Status -Details $Details
    $script:LastResults += $resultObject

    $row = $gridResults.Rows.Add($Name,$Status,$Details)

    switch ($Status) {
        "Success" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Valid" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Summary" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,64,175) }
        "Setting" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(31,41,55) }
        "WhatIf" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,64,175) }
        "Skipped" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Missing" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Failed" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        "Invalid" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        "BackedUp" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
    }

    $gridResults.Rows[$row].DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    Add-Log "${Name}: $Status - $Details"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Microsoft Defender for Endpoint Deployment Tool"
$form.Size = New-Object System.Drawing.Size(1120,760)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Theme.Back
$form.ForeColor = $Theme.Text
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Defender for Endpoint Deployment Tool"
$title.Location = New-Object System.Drawing.Point(20,15)
$title.Size = New-Object System.Drawing.Size(650,32)
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold",16,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = $Theme.Text
$title.BackColor = $Theme.Back
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Single-file JSON-driven Settings Catalog deployment"
$subtitle.Location = New-Object System.Drawing.Point(22,48)
$subtitle.Size = New-Object System.Drawing.Size(650,24)
$subtitle.ForeColor = $Theme.Muted
$subtitle.BackColor = $Theme.Back
$form.Controls.Add($subtitle)

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = "WhatIf / Validate only"
$chkWhatIf.Location = New-Object System.Drawing.Point(700,20)
$chkWhatIf.Size = New-Object System.Drawing.Size(180,24)
$chkWhatIf.ForeColor = $Theme.Text
$chkWhatIf.BackColor = $Theme.Back
$form.Controls.Add($chkWhatIf)

$chkUpdateExisting = New-Object System.Windows.Forms.CheckBox
$chkUpdateExisting.Text = "Update existing policies"
$chkUpdateExisting.Location = New-Object System.Drawing.Point(700,48)
$chkUpdateExisting.Size = New-Object System.Drawing.Size(180,24)
$chkUpdateExisting.ForeColor = $Theme.Text
$chkUpdateExisting.BackColor = $Theme.Back
$form.Controls.Add($chkUpdateExisting)

$btnInit = New-DarkButton "Initialize Graph" 940 15 150 28
$form.Controls.Add($btnInit)

$gridPolicies = New-Object System.Windows.Forms.DataGridView
$gridPolicies.Location = New-Object System.Drawing.Point(20,90)
$gridPolicies.Size = New-Object System.Drawing.Size(650,430)
$gridPolicies.BackgroundColor = $Theme.Panel
$gridPolicies.GridColor = $Theme.Border
$gridPolicies.DefaultCellStyle.BackColor = $Theme.PanelAlt
$gridPolicies.DefaultCellStyle.ForeColor = $Theme.Text
$gridPolicies.DefaultCellStyle.SelectionBackColor = $Theme.Accent
$gridPolicies.ColumnHeadersDefaultCellStyle.BackColor = $Theme.Button
$gridPolicies.ColumnHeadersDefaultCellStyle.ForeColor = $Theme.Text
$gridPolicies.EnableHeadersVisualStyles = $false
$gridPolicies.RowHeadersVisible = $false
$gridPolicies.AllowUserToAddRows = $false
$gridPolicies.SelectionMode = "FullRowSelect"
$gridPolicies.MultiSelect = $true
$gridPolicies.AutoSizeColumnsMode = "Fill"
[void]$gridPolicies.Columns.Add("Name","Policy")
[void]$gridPolicies.Columns.Add("Category","Category")
[void]$gridPolicies.Columns.Add("JsonPath","JSON Path")
[void]$gridPolicies.Columns.Add("Exists","JSON Exists")
$form.Controls.Add($gridPolicies)

$gridResults = New-Object System.Windows.Forms.DataGridView
$gridResults.Location = New-Object System.Drawing.Point(690,90)
$gridResults.Size = New-Object System.Drawing.Size(400,250)
$gridResults.BackgroundColor = $Theme.Panel
$gridResults.GridColor = $Theme.Border
$gridResults.DefaultCellStyle.BackColor = $Theme.PanelAlt
$gridResults.DefaultCellStyle.ForeColor = $Theme.Text
$gridResults.DefaultCellStyle.SelectionBackColor = $Theme.Accent
$gridResults.ColumnHeadersDefaultCellStyle.BackColor = $Theme.Button
$gridResults.ColumnHeadersDefaultCellStyle.ForeColor = $Theme.Text
$gridResults.EnableHeadersVisualStyles = $false
$gridResults.RowHeadersVisible = $false
$gridResults.AllowUserToAddRows = $false
$gridResults.AutoSizeColumnsMode = "Fill"
[void]$gridResults.Columns.Add("Name","Name")
[void]$gridResults.Columns.Add("Status","Status")
[void]$gridResults.Columns.Add("Details","Details")
$form.Controls.Add($gridResults)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20,540)
$txtLog.Size = New-Object System.Drawing.Size(1070,145)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(12,12,16)
$txtLog.ForeColor = $Theme.Text
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtLog)

$btnRefresh = New-DarkButton "Refresh JSON List" 690 360 170 34
$btnDeploy = New-DarkButton "Deploy Selected" 890 360 200 34
$btnExport = New-DarkButton "Export Existing Policy" 690 402 170 34
$btnOpenConfig = New-DarkButton "Open Config Folder" 890 402 200 34
$btnOpenLogs = New-DarkButton "Open Logs Folder" 690 444 170 34
$btnValidate = New-DarkButton "Validate JSON" 890 444 200 34
$btnBackup = New-DarkButton "Backup JSON" 690 486 170 34
$btnSummary = New-DarkButton "Show Settings Summary" 890 486 200 34
$btnReport = New-DarkButton "Generate Report" 690 528 170 34
$btnOpenReports = New-DarkButton "Open Reports Folder" 890 528 200 34

$form.Controls.AddRange(@(
    $btnRefresh,
    $btnDeploy,
    $btnExport,
    $btnOpenConfig,
    $btnOpenLogs,
    $btnValidate,
    $btnBackup,
    $btnSummary,
    $btnReport,
    $btnOpenReports
))

function Load-PolicyGrid {
    $gridPolicies.Rows.Clear()
    foreach ($p in Get-MDEJsonPolicyCatalog) {
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
    }
    catch {
        Add-Result "Graph" "Failed" $_.Exception.Message
    }
})

$btnRefresh.Add_Click({ Load-PolicyGrid })

$btnValidate.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()

    foreach ($p in Get-MDEJsonPolicyCatalog) {
        $result = Test-MDEJsonPolicyFile -JsonPath $p.JsonPath
        Add-Result $result.Name $result.Status $result.Details
    }
})

$btnDeploy.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()

    if ($chkUpdateExisting.Checked -and -not $chkWhatIf.Checked) {
        try {
            $backupPath = Backup-MDELocalJson
            Add-Result "Local JSON Backup" "BackedUp" "Backed up local JSON to $backupPath"
        }
        catch {
            Add-Result "Local JSON Backup" "Failed" $_.Exception.Message
            return
        }
    }

    foreach ($row in $gridPolicies.SelectedRows) {
        $name = $row.Cells["Name"].Value
        $path = $row.Cells["JsonPath"].Value

        $result = New-MDEConfigPolicyFromJson `
            -Name $name `
            -JsonPath $path `
            -WhatIf:$chkWhatIf.Checked `
            -UpdateExisting:$chkUpdateExisting.Checked

        Add-Result $result.Name $result.Status $result.Details
    }

    if ($script:LastResults.Count -gt 0) {
        $reportPath = New-MDEDeploymentReport -Results $script:LastResults
        Add-Log "Deployment report generated: $reportPath"
    }
})

$btnExport.Add_Click({
    try {
        Assert-Mg

        $policyName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the exact existing Intune Settings Catalog policy name:",
            "Export Policy JSON",
            ""
        )

        if ([string]::IsNullOrWhiteSpace($policyName)) {
            Add-Log "Export cancelled."
            return
        }

        $safeName = ($policyName -replace '^MDE - ','') -replace '^SOURCE - ',''
        $safeName = $safeName.ToLower() -replace '\s+','-' -replace '[\\/:*?""<>|]',''

        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "JSON files (*.json)|*.json"
        $saveDialog.InitialDirectory = Join-Path $PSScriptRoot "Config\SettingsCatalog"
        $saveDialog.FileName = "$safeName.json"

        if ($saveDialog.ShowDialog() -eq "OK") {
            $result = Export-MDEConfigPolicyJson `
                -PolicyName $policyName `
                -OutputPath $saveDialog.FileName

            Add-Result $result.Name $result.Status $result.Details
            Load-PolicyGrid
        }
    }
    catch {
        Add-Result "Export" "Failed" $_.Exception.Message
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
    Start-Process (Get-MDELogFolder)
})

$btnBackup.Add_Click({
    try {
        $backupPath = Backup-MDELocalJson
        Add-Result "Local JSON Backup" "BackedUp" "Backed up local JSON to $backupPath"
    }
    catch {
        Add-Result "Local JSON Backup" "Failed" $_.Exception.Message
    }
})

$btnSummary.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()

    if ($gridPolicies.SelectedRows.Count -eq 0) {
        Add-Result "Summary" "Skipped" "Select one or more policies first."
        return
    }

    $catalog = Get-MDEJsonPolicyCatalog

    foreach ($row in $gridPolicies.SelectedRows) {
        $policyName = $row.Cells["Name"].Value
        $policy = $catalog | Where-Object { $_.Name -eq $policyName } | Select-Object -First 1

        if ($policy) {
            Show-MDEPolicySettingsSummary -Policy $policy
        }
    }
})

$btnReport.Add_Click({
    if ($script:LastResults.Count -eq 0) {
        Add-Result "Report" "Skipped" "No results available to report."
        return
    }

    $reportPath = New-MDEDeploymentReport -Results $script:LastResults
    Add-Result "Report" "Success" "Generated: $reportPath"
})

$btnOpenReports.Add_Click({
    Start-Process (Get-MDEReportFolder)
})

Load-PolicyGrid
[void]$form.ShowDialog()
