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

function Get-MDELogFolder {
    $path = Join-Path $PSScriptRoot "Logs"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Get-MDEReportFolder {
    $path = Join-Path $PSScriptRoot "Reports"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

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

function Get-MDEConfigPolicyId {
    param([string]$PolicyDisplayName)

    Assert-Mg

    $escaped = $PolicyDisplayName.Replace("'","''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"

    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $result.value -or $result.value.Count -eq 0) {
        throw "Policy not found: $PolicyDisplayName"
    }

    return $result.value[0].id
}

function Get-MDEGroupIdByName {
    param([string]$GroupName)

    Assert-Mg

    $escaped = $GroupName.Replace("'","''")
    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escaped'"

    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $result.value -or $result.value.Count -eq 0) {
        throw "Group not found: $GroupName"
    }

    if ($result.value.Count -gt 1) {
        throw "Multiple groups found with name: $GroupName"
    }

    return $result.value[0].id
}

function Add-MDEConfigPolicyAssignment {
    param(
        [string]$PolicyDisplayName,
        [string]$GroupName
    )

    Assert-Mg

    try {
        $policyId = Get-MDEConfigPolicyId -PolicyDisplayName $PolicyDisplayName
        $groupId = Get-MDEGroupIdByName -GroupName $GroupName

        $body = @{
            assignments = @(
                @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $groupId
                    }
                }
            )
        } | ConvertTo-Json -Depth 20 -Compress

        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assign"

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri $uri `
            -Body $body `
            -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult $PolicyDisplayName "Assigned" "Assigned to group: $GroupName"
    }
    catch {
        return New-MDEPolicyResult $PolicyDisplayName "Failed" $_.Exception.Message
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

function Get-MDEFriendlyPolicyNameFromFile {
    param([string]$FileName)

    switch ($FileName.ToLower()) {
        "antivirus.json"                   { return "Antivirus" }
        "firewall.json"                    { return "Firewall" }
        "asr.json"                         { return "ASR" }
        "edr.json"                         { return "EDR" }
        "windows-security-experience.json" { return "Windows Security Experience" }
        "avc-update-controls.json"         { return "AVC Update Controls" }
        default {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
            return (($base -replace '-', ' ') -replace '_', ' ')
        }
    }
}

function Get-MDEJsonPolicyCatalog {
    $folder = Join-Path $PSScriptRoot "Config\SettingsCatalog"

    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    Get-ChildItem -Path $folder -Filter "*.json" | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Name     = Get-MDEFriendlyPolicyNameFromFile -FileName $_.Name
            Category = "Settings Catalog"
            JsonPath = $_.FullName
        }
    }
}

function Get-MDESettingValue {
    param($Setting)

    $instance = $Setting.settingInstance

    if (-not $instance) {
        return ""
    }

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

function Get-MDESettingsInventory {
    $inventory = @()

    foreach ($policy in Get-MDEJsonPolicyCatalog) {
        if (-not (Test-Path -LiteralPath $policy.JsonPath)) {
            continue
        }

        try {
            $json = Get-MDEJsonBody -Path $policy.JsonPath

            foreach ($setting in $json.settings) {
                $instance = $setting.settingInstance

                if (-not $instance) {
                    continue
                }

                $inventory += [pscustomobject]@{
                    Policy    = $policy.Name
                    SettingId = $instance.settingDefinitionId
                    Type      = $instance.'@odata.type'
                    Value     = Get-MDESettingValue -Setting $setting
                }
            }
        }
        catch {
            $inventory += [pscustomobject]@{
                Policy    = $policy.Name
                SettingId = "Inventory Error"
                Type      = "Error"
                Value     = $_.Exception.Message
            }
        }
    }

    return $inventory
}

function Get-MDEZeroTrustChecks {
    return @(
        @{
            Policy = "Firewall"
            Label = "Firewall policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\firewall.json"
        },
        @{
            Policy = "Firewall"
            Label = "Firewall contains settings"
            Type = "HasSettings"
            JsonPath = "Config\SettingsCatalog\firewall.json"
        },
        @{
            Policy = "Firewall"
            Label = "Firewall has default inbound block settings"
            Type = "ContainsAnySetting"
            JsonPath = "Config\SettingsCatalog\firewall.json"
            Match = @("defaultinboundaction", "default_inbound", "inbound")
        },
        @{
            Policy = "Firewall"
            Label = "Firewall has logging visibility settings"
            Type = "ContainsAnySetting"
            JsonPath = "Config\SettingsCatalog\firewall.json"
            Match = @("log", "logging", "dropped")
        },
        @{
            Policy = "ASR"
            Label = "ASR policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\asr.json"
        },
        @{
            Policy = "ASR"
            Label = "ASR contains configured rules"
            Type = "HasSettings"
            JsonPath = "Config\SettingsCatalog\asr.json"
        },
        @{
            Policy = "ASR"
            Label = "ASR contains attack surface reduction configuration"
            Type = "ContainsAnySetting"
            JsonPath = "Config\SettingsCatalog\asr.json"
            Match = @("attacksurfacereduction", "asr", "defender")
        },
        @{
            Policy = "EDR"
            Label = "EDR policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\edr.json"
        },
        @{
            Policy = "EDR"
            Label = "EDR excludes connector onboarding secret"
            Type = "DoesNotContainSetting"
            JsonPath = "Config\SettingsCatalog\edr.json"
            Match = @("device_vendor_msft_windowsadvancedthreatprotection_onboarding_fromconnector")
        },
        @{
            Policy = "Windows Security Experience"
            Label = "Windows Security Experience policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\windows-security-experience.json"
        },
        @{
            Policy = "AVC Update Controls"
            Label = "AVC Update Controls policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\avc-update-controls.json"
        }
    )
}

function Test-MDEZeroTrustAlignment {
    $results = @()

    foreach ($check in Get-MDEZeroTrustChecks) {
        $fullPath = Join-Path $PSScriptRoot $check.JsonPath
        $passed = $false
        $found = ""
        $details = ""

        try {
            switch ($check.Type) {
                "FileExists" {
                    $passed = Test-Path -LiteralPath $fullPath
                    $found = if ($passed) { "File found" } else { "Missing file" }
                    $details = $fullPath
                }

                "HasSettings" {
                    if (Test-Path -LiteralPath $fullPath) {
                        $json = Get-MDEJsonBody -Path $fullPath
                        $passed = [bool]($json.settings -and $json.settings.Count -gt 0)
                        $found = "$($json.settings.Count) settings"
                    }
                    else {
                        $found = "Missing file"
                    }
                    $details = $fullPath
                }

                "ContainsAnySetting" {
                    if (Test-Path -LiteralPath $fullPath) {
                        $raw = (Get-Content -LiteralPath $fullPath -Raw).ToLower()
                        foreach ($term in $check.Match) {
                            if ($raw -like "*$($term.ToLower())*") {
                                $passed = $true
                                $found = "Matched: $term"
                                break
                            }
                        }

                        if (-not $passed) {
                            $found = "No matching setting found"
                        }
                    }
                    else {
                        $found = "Missing file"
                    }
                    $details = "Expected one of: $($check.Match -join ', ')"
                }

                "DoesNotContainSetting" {
                    if (Test-Path -LiteralPath $fullPath) {
                        $raw = (Get-Content -LiteralPath $fullPath -Raw).ToLower()
                        $passed = $true

                        foreach ($term in $check.Match) {
                            if ($raw -like "*$($term.ToLower())*") {
                                $passed = $false
                                $found = "Found blocked setting: $term"
                                break
                            }
                        }

                        if ($passed) {
                            $found = "Blocked setting not found"
                        }
                    }
                    else {
                        $found = "Missing file"
                    }
                    $details = "Must not contain: $($check.Match -join ', ')"
                }
            }
        }
        catch {
            $passed = $false
            $found = "Error"
            $details = $_.Exception.Message
        }

        $results += [pscustomobject]@{
            Policy  = $check.Policy
            Control = $check.Label
            Result  = if ($passed) { "Pass" } else { "Review" }
            Found   = $found
            Details = $details
        }
    }

    return $results
}

function ConvertTo-HtmlEncoded {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function New-MDEDeploymentReport {
    param([array]$Results)

    $reportFolder = Get-MDEReportFolder
    $reportPath = Join-Path $reportFolder "deployment-report.html"
    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $inventory = Get-MDESettingsInventory
    $ztChecks = Test-MDEZeroTrustAlignment

    $deploymentRows = foreach ($r in $Results) {
        $statusClass = switch ($r.Status) {
            "Success"  { "success" }
            "Assigned" { "success" }
            "Valid"    { "success" }
            "WhatIf"   { "whatif" }
            "Skipped"  { "skipped" }
            "Missing"  { "skipped" }
            "Failed"   { "failed" }
            "Invalid"  { "failed" }
            default    { "default" }
        }

        "<tr class='$statusClass'><td>$(ConvertTo-HtmlEncoded $r.Time)</td><td>$(ConvertTo-HtmlEncoded $r.Name)</td><td>$(ConvertTo-HtmlEncoded $r.Status)</td><td>$(ConvertTo-HtmlEncoded $r.Details)</td></tr>"
    }

    $inventoryRows = foreach ($i in $inventory) {
        "<tr><td>$(ConvertTo-HtmlEncoded $i.Policy)</td><td><code>$(ConvertTo-HtmlEncoded $i.SettingId)</code></td><td>$(ConvertTo-HtmlEncoded $i.Type)</td><td><code>$(ConvertTo-HtmlEncoded $i.Value)</code></td></tr>"
    }

    $ztRows = foreach ($z in $ztChecks) {
        $class = if ($z.Result -eq "Pass") { "success" } else { "review" }
        $checked = if ($z.Result -eq "Pass") { "checked" } else { "" }

        "<tr class='$class'><td><input type='checkbox' disabled $checked></td><td>$(ConvertTo-HtmlEncoded $z.Policy)</td><td>$(ConvertTo-HtmlEncoded $z.Control)</td><td>$(ConvertTo-HtmlEncoded $z.Result)</td><td>$(ConvertTo-HtmlEncoded $z.Found)</td><td>$(ConvertTo-HtmlEncoded $z.Details)</td></tr>"
    }
function Backup-MDEAllPolicies {
    Assert-Mg

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $backupRoot = Join-Path $PSScriptRoot "Backups"
        $backupFolder = Join-Path $backupRoot $timestamp

        if (-not (Test-Path $backupFolder)) {
            New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
        }

        foreach ($policy in Get-MDEJsonPolicyCatalog) {

            $displayName = Get-MDEPolicyName $policy.Name
            $safeName = $policy.Name.ToLower() -replace '\s+','-' 

            try {
                if (-not (Test-MDEConfigPolicyExists -Name $policy.Name)) {
                    Add-Result $displayName "Skipped" "Policy not found, skipping backup"
                    continue
                }

                $outputPath = Join-Path $backupFolder "$safeName.json"

                $result = Export-MDEConfigPolicyJson `
                    -PolicyName $displayName `
                    -OutputPath $outputPath

                Add-Result $displayName $result.Status "Backed up to $outputPath"
            }
            catch {
                Add-Result $displayName "Failed" $_.Exception.Message
            }
        }

        Add-Log "Backup complete: $backupFolder"
        Start-Process $backupFolder
    }
    catch {
        Add-Result "Backup All" "Failed" $_.Exception.Message
    }
}


    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>MDE Deployment Report</title>
<style>
body {
    font-family: Segoe UI, Arial, sans-serif;
    background: #111827;
    color: #e5e7eb;
    margin: 30px;
}
h1, h2 {
    color: #ffffff;
}
.badge {
    display: inline-block;
    padding: 6px 12px;
    background: #1f2937;
    border-radius: 8px;
    margin-bottom: 20px;
}
table {
    width: 100%;
    border-collapse: collapse;
    background: #1f2937;
    margin-bottom: 30px;
}
th {
    background: #374151;
    color: #ffffff;
    text-align: left;
    padding: 10px;
}
td {
    padding: 10px;
    border-bottom: 1px solid #374151;
    vertical-align: top;
}
code {
    color: #bfdbfe;
    word-break: break-all;
}
tr.success td {
    background: #14532d;
}
tr.whatif td {
    background: #1e3a8a;
}
tr.skipped td {
    background: #713f12;
}
tr.failed td {
    background: #7f1d1d;
}
tr.review td {
    background: #713f12;
}
tr.default td {
    background: #1f2937;
}
input[type="checkbox"] {
    transform: scale(1.2);
}
.note {
    background: #1f2937;
    padding: 14px;
    border-left: 4px solid #60a5fa;
    margin-bottom: 25px;
}
.footer {
    margin-top: 20px;
    font-size: 12px;
    color: #9ca3af;
}
</style>
</head>
<body>
<h1>Microsoft Defender for Endpoint Deployment Report</h1>
<div class="badge">Generated: $generated</div>

<div class="note">
This report includes deployment results, Settings Catalog inventory, and a basic Zero Trust alignment checklist.
The checklist is intended as a guide and does not replace tenant-specific security review.
</div>

<h2>Deployment Results</h2>
<table>
<thead>
<tr>
<th>Time</th>
<th>Name</th>
<th>Status</th>
<th>Details</th>
</tr>
</thead>
<tbody>
$($deploymentRows -join "`n")
</tbody>
</table>

<h2>Zero Trust Alignment Checklist</h2>
<table>
<thead>
<tr>
<th>Aligned</th>
<th>Policy</th>
<th>Control</th>
<th>Result</th>
<th>Found</th>
<th>Details</th>
</tr>
</thead>
<tbody>
$($ztRows -join "`n")
</tbody>
</table>

<h2>Settings Inventory</h2>
<table>
<thead>
<tr>
<th>Policy</th>
<th>Setting ID</th>
<th>Type</th>
<th>Value</th>
</tr>
</thead>
<tbody>
$($inventoryRows -join "`n")
</tbody>
</table>

<div class="footer">
Generated by MDE Deployment Tool
</div>
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
        "Success"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Assigned" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "Valid"    { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(22,101,52) }
        "WhatIf"   { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,64,175) }
        "Skipped"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Missing"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Failed"   { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        "Invalid"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
    }

    $gridResults.Rows[$row].DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    Add-Log "${Name}: $Status - $Details"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Microsoft Defender for Endpoint Deployment Tool"
$form.Size = New-Object System.Drawing.Size(1120,900)
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

$chkAssignAfterDeploy = New-Object System.Windows.Forms.CheckBox
$chkAssignAfterDeploy.Text = "Assign after deploy"
$chkAssignAfterDeploy.Location = New-Object System.Drawing.Point(700,48)
$chkAssignAfterDeploy.Size = New-Object System.Drawing.Size(180,24)
$chkAssignAfterDeploy.ForeColor = $Theme.Text
$chkAssignAfterDeploy.BackColor = $Theme.Back
$form.Controls.Add($chkAssignAfterDeploy)

$txtGroupName = New-Object System.Windows.Forms.TextBox
$txtGroupName.Location = New-Object System.Drawing.Point(880,48)
$txtGroupName.Size = New-Object System.Drawing.Size(210,24)
$txtGroupName.BackColor = $Theme.PanelAlt
$txtGroupName.ForeColor = $Theme.Text
$txtGroupName.Text = "MDE Pilot Devices"
$form.Controls.Add($txtGroupName)

$btnInit = New-DarkButton "Initialize Graph" 940 15 150 28
$form.Controls.Add($btnInit)

$gridPolicies = New-Object System.Windows.Forms.DataGridView
$gridPolicies.Location = New-Object System.Drawing.Point(20,90)
$gridPolicies.Size = New-Object System.Drawing.Size(650,200)
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
$txtLog.Location = New-Object System.Drawing.Point(20,575)
$txtLog.Size = New-Object System.Drawing.Size(1070,280)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(12,12,16)
$txtLog.ForeColor = $Theme.Text
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtLog)

$btnRefresh = New-DarkButton "Refresh JSON List" 0 0 150 36
$btnDeploy = New-DarkButton "Deploy Selected" 0 0 150 36
$btnExport = New-DarkButton "Export Existing Policy" 0 0 150 36
$btnOpenConfig = New-DarkButton "Open Config Folder" 0 0 150 36
$btnOpenLogs = New-DarkButton "Open Logs Folder" 0 0 150 36
$btnValidate = New-DarkButton "Validate JSON" 0 0 150 36
$btnReport = New-DarkButton "Generate Report" 0 0 150 36
$btnOpenReports = New-DarkButton "Open Reports Folder" 0 0 150 36
$btnBackupAll = New-DarkButton "Backup All Policies" 0 0 150 36

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Location = New-Object System.Drawing.Point(20,315)
$buttonPanel.Size = New-Object System.Drawing.Size(650,265)
$buttonPanel.BackColor = $Theme.Back
$buttonPanel.FlowDirection = "LeftToRight"
$buttonPanel.WrapContents = $true
$buttonPanel.AutoScroll = $false
$buttonPanel.Padding = New-Object System.Windows.Forms.Padding(4)
$form.Controls.Add($buttonPanel)

foreach ($button in @(
    $btnRefresh,
    $btnDeploy,
    $btnExport,
    $btnBackupAll,
    $btnOpenConfig,
    $btnOpenLogs,
    $btnValidate,
    $btnReport,
    $btnOpenReports
)) {
    $button.Size = New-Object System.Drawing.Size(150,36)
    $button.Margin = New-Object System.Windows.Forms.Padding(6)
    $buttonPanel.Controls.Add($button)
}

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
            "Directory.Read.All",
            "Group.Read.All"
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

    foreach ($row in $gridPolicies.SelectedRows) {
        $name = $row.Cells["Name"].Value
        $path = $row.Cells["JsonPath"].Value

        $result = New-MDEConfigPolicyFromJson `
            -Name $name `
            -JsonPath $path `
            -WhatIf:$chkWhatIf.Checked

        Add-Result $result.Name $result.Status $result.Details

        if ($chkAssignAfterDeploy.Checked -and -not $chkWhatIf.Checked) {
            if ($result.Status -in @("Success","Skipped")) {
                $groupName = $txtGroupName.Text

                if ([string]::IsNullOrWhiteSpace($groupName)) {
                    Add-Result $result.Name "Failed" "Assign after deploy selected, but group name is blank."
                }
                else {
                    $assignResult = Add-MDEConfigPolicyAssignment `
                        -PolicyDisplayName (Get-MDEPolicyName $name) `
                        -GroupName $groupName

                    Add-Result $assignResult.Name $assignResult.Status $assignResult.Details
                }
            }
        }
    }

    if ($script:LastResults.Count -gt 0) {
        $reportPath = New-MDEDeploymentReport -Results $script:LastResults
        Add-Log "Deployment report generated: $reportPath"
    }
})

$btnBackupAll.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()

    try {
        Backup-MDEAllPolicies
    }
    catch {
        Add-Result "Backup All" "Failed" $_.Exception.Message
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
    $path = Get-MDELogFolder
    Start-Process $path
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
    $path = Get-MDEReportFolder
    Start-Process $path
})

Load-PolicyGrid
[void]$form.ShowDialog()
