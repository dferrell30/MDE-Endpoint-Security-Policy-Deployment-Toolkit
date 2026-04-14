Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

function New-MDEPolicyResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details,
        [string]$PolicyId = ''
    )

    [pscustomobject]@{
        Name     = $Name
        Status   = $Status
        Details  = $Details
        PolicyId = $PolicyId
        Time     = Get-Date
    }
}

function Write-MDELog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $logRoot = Join-Path $PSScriptRoot '..\Logs'
    if (-not (Test-Path -LiteralPath $logRoot)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }

    $logFile = Join-Path $logRoot 'deployment.log'
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $logFile -Value $line
}

function Test-MDEGraphConnection {
    try {
        $ctx = Get-MgContext
        return [bool]$ctx
    }
    catch {
        return $false
    }
}

function Assert-MDEGraphConnection {
    if (-not (Test-MDEGraphConnection)) {
        throw 'Microsoft Graph is not connected. Run Initialize first.'
    }
}

function New-MDEConfigurationPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [hashtable]$PolicyBody
    )

    Assert-MDEGraphConnection

    $fullName = "$($script:PolicyPrefix) - $PolicyName"
    $uri = 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'

    $PolicyBody.name = $fullName
    if (-not $PolicyBody.ContainsKey('description')) {
        $PolicyBody.description = 'Created via MDE Endpoint Security Deployment Tool'
    }
    if (-not $PolicyBody.ContainsKey('platforms')) {
        $PolicyBody.platforms = 'windows10'
    }
    if (-not $PolicyBody.ContainsKey('roleScopeTagIds')) {
        $PolicyBody.roleScopeTagIds = @('0')
    }

    $json = $PolicyBody | ConvertTo-Json -Depth 20

    Write-MDELog -Message "Creating policy: $fullName"
    $policy = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType 'application/json' -OutputType PSObject

    Write-MDELog -Message "Created policy: $fullName ($($policy.id))"
    return $policy
}

function Get-MDEConfigurationPolicyByName {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName
    )

    Assert-MDEGraphConnection

    $fullName = "$($script:PolicyPrefix) - $PolicyName"
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$fullName'"

    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    if ($result.value -and $result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function New-MDESettingsCatalogResultWrapper {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [scriptblock]$CreateAction
    )

    try {
        $existing = Get-MDEConfigurationPolicyByName -PolicyName $PolicyName
        if ($existing) {
            $msg = "Policy already exists: $($existing.name)"
            Write-MDELog -Message $msg -Level 'WARN'
            return New-MDEPolicyResult -Name $PolicyName -Status 'Skipped' -Details $msg -PolicyId $existing.id
        }

        $policy = & $CreateAction
        return New-MDEPolicyResult -Name $PolicyName -Status 'Success' -Details 'Policy created.' -PolicyId $policy.id
    }
    catch {
        Write-MDELog -Message "$PolicyName failed: $($_.Exception.Message)" -Level 'ERROR'
        return New-MDEPolicyResult -Name $PolicyName -Status 'Failed' -Details $_.Exception.Message
    }
}
