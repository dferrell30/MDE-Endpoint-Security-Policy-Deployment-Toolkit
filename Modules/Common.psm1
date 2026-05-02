Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

function New-MDEPolicyResult {
    param([string]$Name,[string]$Status,[string]$Details)

    [pscustomobject]@{
        Name    = $Name
        Status  = $Status
        Details = $Details
        Time    = Get-Date
    }
}

function Assert-Mg {
    if (-not (Get-MgContext)) {
        throw "Not connected to Microsoft Graph."
    }
}

function Get-MDEPolicyName {
    param([string]$Name)
    "$script:PolicyPrefix - $Name"
}

function Write-MDELog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $root = Split-Path $PSScriptRoot -Parent
    $logFolder = Join-Path $root 'Logs'

    if (-not (Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    }

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path (Join-Path $logFolder 'deployment.log') -Value $line
}

function Get-MDEErrorDetail {
    param($ErrorRecord)

    try {
        if ($ErrorRecord.ErrorDetails.Message) {
            return $ErrorRecord.ErrorDetails.Message
        }
    }
    catch {}

    return $ErrorRecord.Exception.Message
}

function Get-MDEJsonBody {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Set-MDEPolicyName {
    param(
        [Parameter(Mandatory)]$Body,
        [Parameter(Mandatory)][string]$Name
    )

    $Body.name = Get-MDEPolicyName $Name
    return $Body
}

function Test-MDEConfigPolicyExists {
    param([string]$Name)

    Assert-Mg

    $displayName = Get-MDEPolicyName $Name
    $escaped = $displayName.Replace("'", "''")
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
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$JsonPath,
        [switch]$WhatIf
    )

    Assert-Mg

    $displayName = Get-MDEPolicyName $Name

    try {
        if (Test-MDEConfigPolicyExists -Name $Name) {
            return New-MDEPolicyResult -Name $displayName -Status 'Skipped' -Details 'Policy already exists'
        }

        $body = Get-MDEJsonBody -Path $JsonPath
        $body = Set-MDEPolicyName -Body $body -Name $Name
        $json = $body | ConvertTo-Json -Depth 100 -Compress

        Write-MDELog -Message "Prepared policy [$displayName] from [$JsonPath]"
        Write-MDELog -Message "Request JSON [$displayName]: $json"

        if ($WhatIf) {
            return New-MDEPolicyResult -Name $displayName -Status 'WhatIf' -Details "Validated JSON only: $JsonPath"
        }

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
            -Body $json `
            -ContentType 'application/json' | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status 'Success' -Details 'Created configuration policy'
    }
    catch {
        $detail = Get-MDEErrorDetail $_
        Write-MDELog -Level ERROR -Message "Failed [$displayName]: $detail"
        return New-MDEPolicyResult -Name $displayName -Status 'Failed' -Details $detail
    }
}

function Export-MDEConfigPolicyJson {
    param(
        [Parameter(Mandatory)][string]$PolicyName,
        [Parameter(Mandatory)][string]$OutputPath
    )

    Assert-Mg

    $escaped = $PolicyName.Replace("'", "''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"
    $policy = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $policy.value -or $policy.value.Count -eq 0) {
        throw "Policy not found: $PolicyName"
    }

    $p = $policy.value[0]
    $settingsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($p.id)/settings"
    $settings = Invoke-MgGraphRequest -Method GET -Uri $settingsUri -OutputType PSObject

    $body = [ordered]@{
        name            = $p.name
        description     = $p.description
        platforms       = $p.platforms
        technologies    = $p.technologies
        roleScopeTagIds = @($p.roleScopeTagIds)
        settings        = @($settings.value)
    }

    if ($p.templateReference) {
        $body.templateReference = $p.templateReference
    }

    $folder = Split-Path $OutputPath -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $body | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

    return New-MDEPolicyResult -Name $PolicyName -Status 'Success' -Details "Exported to $OutputPath"
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
    'New-MDEConfigPolicyFromJson',
    'Export-MDEConfigPolicyJson'
)
