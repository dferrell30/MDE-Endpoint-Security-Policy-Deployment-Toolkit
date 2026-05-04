#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

$PolicyPrefix = "MDE"

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

function Test-MDEConfigPolicyExists {
    param([string]$Name)

    Assert-Mg

    $displayName = Get-MDEPolicyName $Name
    $escaped = $displayName.Replace("'","''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"

    try {
        $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        return [bool]($result.value -and $result.value.Count -gt 0)
    }
    catch {
        return $false
    }
}

function New-MDEConfigPolicyFromJson {
    param(
        [string]$Name,
        [string]$JsonPath,
        [switch]$WhatIf
    )

    Assert-Mg

    $displayName = Get-MDEPolicyName $Name

    try {
        if (Test-MDEConfigPolicyExists -Name $Name) {
            return New-MDEPolicyResult $displayName "Skipped" "Policy already exists"
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
        $escaped = $PolicyName.Replace("'","''")
        $policyUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"
        $policy = Invoke-MgGraphRequest -Method GET -Uri $policyUri -OutputType PSObject

        if (-not $policy.value -or $policy.value.Count -eq 0) {
            throw "Policy not found: $PolicyName"
        }

        $p = $policy.value[0]
        $settingsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($p.id)/settings"
        $settings = Invoke-MgGraphRequest -Method GET -Uri $settingsUri -OutputType PSObject

        if (-not $settings.value -or $settings.value.Count -eq 0) {
            throw "Policy found, but no settings were returned: $PolicyName"
        }

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

        return New-MDEPolicyResult $PolicyName "Success" "Exported to $OutputPath"
    }
    catch {
        return New-MDEPolicyResult $PolicyName "Failed" $_.Exception.Message
    }
}

function Get-MDEJsonPolicyCatalog {
    @(
        [pscustomobject]@{
            Name="Antivirus"
            Category="Settings Catalog"
            JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\antivirus.json")
        }
        [pscustomobject]@{
            Name="Firewall"
            Category="Settings Catalog"
            JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\firewall.json")
        }
        [pscustomobject]@{
            Name="ASR"
            Category="Settings Catalog"
            JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\asr.json")
        }
        [pscustomobject]@{
            Name="EDR"
            Category="Settings Catalog"
            JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\edr.json")
        }
        [pscustomobject]@{
            Name="Windows Security Experience"
            Category="Settings Catalog"
            JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\windows-security-experience.json")
        }
        [pscustomobject]@{
            Name="AVC Update Controls"
            Category="Settings Catalog"
            JsonPath=(Join-Path $PSScriptRoot "Config\SettingsCatalog\avc-update-controls.json")
        }
    )
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
}

function Add-Result {
    param([string]$Name,[string]$Status,[string]$Details)

    $row = $gridResults.Rows.Add($Name,$Status,$Details)

    switch ($Status) {
        "Success" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Valid"   { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "WhatIf"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,64,175) }
        "Skipped" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Missing" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Failed"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        "Invalid" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
    }

    $gridResults.Rows[$row].DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    Add-Log "${Name}: $Status - $Details"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Microsoft Defender for Endpoint Deployment Tool"
$form.Size = New-Object System.Drawing.Size(1100,720)
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
$chkWhatIf.Location = New-Object System.Drawing.Point(720,25)
$chkWhatIf.Size = New-Object System.Drawing.Size(180,24)
$chkWhatIf.ForeColor = $Theme.Text
$chkWhatIf.BackColor = $Theme.Back
$form.Controls.Add($chkWhatIf)

$btnInit = New-DarkButton "Initialize Graph" 940 20 120 34
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
$gridResults.Size = New-Object System.Drawing.Size(370,250)
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
$txtLog.Size = New-Object System.Drawing.Size(1040,120)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(12,12,16)
$txtLog.ForeColor = $Theme.Text
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtLog)

$btnRefresh = New-DarkButton "Refresh JSON List" 690 360 170 36
$btnDeploy = New-DarkButton "Deploy Selected" 890 360 170 36
$btnExport = New-DarkButton "Export Existing Policy" 690 410 170 36
$btnOpenConfig = New-DarkButton "Open Config Folder" 890 410 170 36
$btnValidate = New-DarkButton "Validate JSON" 890 460 170 36
$form.Controls.AddRange(@($btnRefresh,$btnDeploy,$btnExport,$btnOpenConfig,$btnValidate))

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
    foreach ($p in Get-MDEJsonPolicyCatalog) {
        $result = Test-MDEJsonPolicyFile -JsonPath $p.JsonPath
        Add-Result $result.Name $result.Status $result.Details
    }
})

$btnDeploy.Add_Click({
    $gridResults.Rows.Clear()

    foreach ($row in $gridPolicies.SelectedRows) {
        $name = $row.Cells["Name"].Value
        $path = $row.Cells["JsonPath"].Value

        $result = New-MDEConfigPolicyFromJson `
            -Name $name `
            -JsonPath $path `
            -WhatIf:$chkWhatIf.Checked

        Add-Result $result.Name $result.Status $result.Details
    }
})

$btnExport.Add_Click({
    $policyName = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the exact existing Intune Settings Catalog policy name:",
        "Export Policy JSON",
        ""
    )

    if ([string]::IsNullOrWhiteSpace($policyName)) {
        return
    }

    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "JSON files (*.json)|*.json"
    $saveDialog.InitialDirectory = Join-Path $PSScriptRoot "Config\SettingsCatalog"
    $saveDialog.FileName = "firewall.json"

    if ($saveDialog.ShowDialog() -eq "OK") {
        $result = Export-MDEConfigPolicyJson -PolicyName $policyName -OutputPath $saveDialog.FileName
        Add-Result $result.Name $result.Status $result.Details
        Load-PolicyGrid
    }
})

$btnOpenConfig.Add_Click({
    Start-Process (Join-Path $PSScriptRoot "Config")
})

Load-PolicyGrid
[void]$form.ShowDialog()
