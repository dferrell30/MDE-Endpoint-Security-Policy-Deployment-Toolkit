Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

function New-MDEPolicyResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details
    )

    [pscustomobject]@{
        Name    = $Name
        Status  = $Status
        Details = $Details
        Time    = Get-Date
    }
}

function Assert-Mg {
    if (-not (Get-MgContext)) {
        throw "Not connected to Microsoft Graph. Click Initialize Graph first."
    }
}

function Get-MDEPolicyName {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    "$script:PolicyPrefix - $Name"
}

function Write-MDELog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    try {
        $root = Split-Path -Path $PSScriptRoot -Parent
        $logFolder = Join-Path $root 'Logs'

        if (-not (Test-Path -LiteralPath $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        }

        $logPath = Join-Path $logFolder 'deployment.log'
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

        Add-Content -LiteralPath $logPath -Value $line
    }
    catch { }
}

function Get-MDEErrorDetail {
    param(
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    try {
        if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
            return $ErrorRecord.ErrorDetails.Message
        }
    }
    catch { }

    try {
        return $ErrorRecord.Exception.Message
    }
    catch {
        return "Unknown error"
    }
}

function Get-MDEJsonBody {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Set-MDEPolicyName {
    param(
        [Parameter(Mandatory)]
        $Body,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Body.name = Get-MDEPolicyName -Name $Name
    return $Body
}

function Test-MDEConfigPolicyExists {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Assert-Mg

    $displayName = Get-MDEPolicyName -Name $Name
    $escapedName = $displayName.Replace("'", "''")

    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'"

    try {
        $result = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $uri `
            -OutputType PSObject

        return [bool]($result.value -and $result.value.Count -gt 0)
    }
    catch {
        return $false
    }
}

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
        $json = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json

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

function New-MDEConfigPolicyFromJson {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$JsonPath,

        [switch]$WhatIf
    )

    Assert-Mg

    $displayName = Get-MDEPolicyName -Name $Name

    try {
        if (Test-MDEConfigPolicyExists -Name $Name) {
            return New-MDEPolicyResult `
                -Name $displayName `
                -Status "Skipped" `
                -Details "Policy already exists"
        }

        $body = Get-MDEJsonBody -Path $JsonPath
        $body = Set-MDEPolicyName -Body $body -Name $Name

        $json = $body | ConvertTo-Json -Depth 100 -Compress

        Write-MDELog -Message "Prepared policy [$displayName] from [$JsonPath]"
        Write-MDELog -Message "Request JSON [$displayName]: $json"

        if ($WhatIf) {
            return New-MDEPolicyResult `
                -Name $displayName `
                -Status "WhatIf" `
                -Details "Validated JSON only: $JsonPath"
        }

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
            -Body $json `
            -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult `
            -Name $displayName `
            -Status "Success" `
            -Details "Created configuration policy"
    }
    catch {
        $detail = Get-MDEErrorDetail -ErrorRecord $_
        Write-MDELog -Level ERROR -Message "Failed creating policy [$displayName]: $detail"

        return New-MDEPolicyResult `
            -Name $displayName `
            -Status "Failed" `
            -Details $detail
    }
}

function Export-MDEConfigPolicyJson {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Assert-Mg

    try {
        $escapedName = $PolicyName.Replace("'", "''")

        $policyUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'"
        $policy = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $policyUri `
            -OutputType PSObject

        if (-not $policy.value -or $policy.value.Count -eq 0) {
            throw "Policy not found: $PolicyName"
        }

        $policyObject = $policy.value[0]
        $policyId = $policyObject.id

        $settingsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/settings"
        $settings = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $settingsUri `
            -OutputType PSObject

        $body = [ordered]@{
            name            = $policyObject.name
            description     = $policyObject.description
            platforms       = $policyObject.platforms
            technologies    = $policyObject.technologies
            roleScopeTagIds = @($policyObject.roleScopeTagIds)
            settings        = @($settings.value)
        }

        if ($policyObject.PSObject.Properties.Name -contains 'templateReference' -and $policyObject.templateReference) {
            $body.templateReference = $policyObject.templateReference
        }

        $folder = Split-Path -Path $OutputPath -Parent

        if ($folder -and -not (Test-Path -LiteralPath $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }

        $body | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

        Write-MDELog -Message "Exported policy [$PolicyName] to [$OutputPath]"

        return New-MDEPolicyResult `
            -Name $PolicyName `
            -Status "Success" `
            -Details "Exported to $OutputPath"
    }
    catch {
        $detail = Get-MDEErrorDetail -ErrorRecord $_
        Write-MDELog -Level ERROR -Message "Failed exporting policy [$PolicyName]: $detail"

        return New-MDEPolicyResult `
            -Name $PolicyName `
            -Status "Failed" `
            -Details $detail
    }
}

Export-ModuleMember -Function @(
    'New-MDEPolicyResult',
    'Assert-Mg',
    'Get-MDEPolicyName',
    'Write-MDELog',
    'Get-MDEErrorDetail',
    'Get-MDEJsonBody',
    'Set-MDEPolicyName',
    'Test-MDEConfigPolicyExists',
    'Test-MDEJsonPolicyFile',
    'New-MDEConfigPolicyFromJson',
    'Export-MDEConfigPolicyJson'
)
