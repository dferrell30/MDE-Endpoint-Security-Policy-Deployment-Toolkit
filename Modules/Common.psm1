Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

# Set these if you want clone-based creation for unfinished workloads
$script:SourceAntivirusPolicyName = 'Windows Endpoint Defender Anti-Virus Policy 122025'
$script:SourceFirewallPolicyName = ''

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
        throw "Not connected. Click Initialize first."
    }
}

function Get-DisplayName {
    param(
        [string]$Name
    )

    "$script:PolicyPrefix - $Name"
}

function Get-MDEErrorDetail {
    param(
        $ErrorRecord
    )

    $detail = $ErrorRecord.Exception.Message

    try {
        if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
            $detail = $ErrorRecord.ErrorDetails.Message
        }
    }
    catch { }

    return $detail
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
    catch {
        # Never throw from logging
    }
}

function Test-MDEIntentExists {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    Assert-Mg

    try {
        $escapedName = $DisplayName.Replace("'", "''")
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents?`$filter=displayName eq '$escapedName'"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

        if ($response.PSObject.Properties.Name -contains 'value' -and $response.value) {
            return [bool]($response.value.Count -gt 0)
        }

        return $false
    }
    catch {
        return $false
    }
}

function Test-MDEConfigPolicyExists {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    Assert-Mg

    try {
        $escapedName = $DisplayName.Replace("'", "''")
        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'"
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

        if ($response.PSObject.Properties.Name -contains 'value' -and $response.value) {
            return [bool]($response.value.Count -gt 0)
        }

        return $false
    }
    catch {
        return $false
    }
}

function Get-MDEConfigPolicyByName {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName
    )

    Assert-Mg

    $escapedName = $PolicyName.Replace("'", "''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'"
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $response.value -or $response.value.Count -eq 0) {
        return $null
    }

    return $response.value[0]
}

function Get-MDEConfigPolicySettings {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyId
    )

    Assert-Mg

    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId/settings"
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if ($response.PSObject.Properties.Name -contains 'value' -and $response.value) {
        return @($response.value)
    }

    return @()
}

function Clone-MDEConfigPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePolicyName,

        [Parameter(Mandatory)]
        [string]$NewShortName
    )

    Assert-Mg

    $displayName = Get-DisplayName $NewShortName

    if (Test-MDEConfigPolicyExists -DisplayName $displayName) {
        return New-MDEPolicyResult -Name $displayName -Status "Skipped" -Details "Policy already exists"
    }

    try {
        $source = Get-MDEConfigPolicyByName -PolicyName $SourcePolicyName
        if (-not $source) {
            return New-MDEPolicyResult -Name $displayName -Status "Info" -Details "Source policy not found: $SourcePolicyName"
        }

        $settings = Get-MDEConfigPolicySettings -PolicyId $source.id
        if (-not $settings -or $settings.Count -eq 0) {
            return New-MDEPolicyResult -Name $displayName -Status "Info" -Details "Source policy has no retrievable settings: $SourcePolicyName"
        }

        $body = @{
            name            = $displayName
            description     = "Cloned from $SourcePolicyName"
            platforms       = $source.platforms
            technologies    = $source.technologies
            roleScopeTagIds = @('0')
            settings        = $settings
        }

        if ($source.PSObject.Properties.Name -contains 'templateReference' -and $null -ne $source.templateReference) {
            $body.templateReference = $source.templateReference
        }

        $json = $body | ConvertTo-Json -Depth 100 -Compress

        Write-MDELog -Message "Cloning config policy [$displayName] from [$SourcePolicyName]"
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
            -Body $json `
            -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "Cloned from $SourcePolicyName"
    }
    catch {
        $detail = Get-MDEErrorDetail $_
        Write-MDELog -Level 'ERROR' -Message "Failed cloning config policy [$displayName]: $detail"
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

function Invoke-CreateConfigPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Body
    )

    Assert-Mg

    $displayName = Get-DisplayName $Name

    if (Test-MDEConfigPolicyExists -DisplayName $displayName) {
        return New-MDEPolicyResult -Name $displayName -Status "Skipped" -Details "Policy already exists"
    }

    try {
        $Body.name = $displayName
        $json = $Body | ConvertTo-Json -Depth 100 -Compress

        Write-MDELog -Message "Creating config policy [$displayName]"
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
            -Body $json `
            -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "Created configuration policy"
    }
    catch {
        $detail = Get-MDEErrorDetail $_
        Write-MDELog -Level 'ERROR' -Message "Failed creating config policy [$displayName]: $detail"
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

function Invoke-CreateTemplatePolicy {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$TemplateId
    )

    Assert-Mg

    $displayName = Get-DisplayName $Name

    if (Test-MDEIntentExists -DisplayName $displayName) {
        return New-MDEPolicyResult -Name $displayName -Status "Skipped" -Details "Policy already exists"
    }

    try {
        $body = @{
            displayName = $displayName
            description = "$Name policy created via tool"
        } | ConvertTo-Json -Depth 5 -Compress

        Write-MDELog -Message "Creating template policy [$displayName] using template [$TemplateId]"

        $response = Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$TemplateId/createInstance" `
            -Body $body `
            -ContentType "application/json" `
            -OutputType PSObject

        if ($response -and $response.id) {
            return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "Created intent id $($response.id)"
        }

        return New-MDEPolicyResult -Name $displayName -Status "Warning" -Details "Create call returned without an intent id"
    }
    catch {
        $detail = Get-MDEErrorDetail $_
        Write-MDELog -Level 'ERROR' -Message "Failed creating template policy [$displayName]: $detail"
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

Export-ModuleMember -Function @(
    'New-MDEPolicyResult',
    'Assert-Mg',
    'Get-DisplayName',
    'Get-MDEErrorDetail',
    'Write-MDELog',
    'Test-MDEIntentExists',
    'Test-MDEConfigPolicyExists',
    'Get-MDEConfigPolicyByName',
    'Get-MDEConfigPolicySettings',
    'Clone-MDEConfigPolicy',
    'Invoke-CreateConfigPolicy',
    'Invoke-CreateTemplatePolicy'
)
