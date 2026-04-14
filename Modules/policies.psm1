Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

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

        $logFile = Join-Path $logFolder 'deployment.log'
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -LiteralPath $logFile -Value $line
    }
    catch {
    }
}

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

function Get-MDEPolicyDisplayName {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    "$script:PolicyPrefix - $Name"
}

function Get-MDEPolicyCreateErrorDetail {
    param(
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    $detail = $ErrorRecord.Exception.Message

    try {
        if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
            $detail = $ErrorRecord.ErrorDetails.Message
        }
    }
    catch {
    }

    return $detail
}

function Get-MDEConfigPath {
    $root = Split-Path -Path $PSScriptRoot -Parent
    Join-Path $root 'Config'
}

function Get-MDEPolicyTemplate {
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $configPath = Get-MDEConfigPath
    $filePath = Join-Path $configPath $FileName

    if (-not (Test-Path -LiteralPath $filePath)) {
        throw "Policy template file not found: $filePath"
    }

    return Get-Content -LiteralPath $filePath -Raw
}

function Test-MDEConfigurationPolicyExists {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    Assert-Mg

    try {
        $escapedName = $DisplayName.Replace("'", "''")
        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'"
        $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

        if ($result.value -and $result.value.Count -gt 0) {
            return $true
        }

        return $false
    }
    catch {
        Write-MDELog -Level 'WARN' -Message "Policy existence check failed for [$DisplayName]: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-CreatePolicyFromJson {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [string]$JsonFile
    )

    Assert-Mg

    $displayName = Get-MDEPolicyDisplayName -Name $PolicyName

    if (Test-MDEConfigurationPolicyExists -DisplayName $displayName) {
        return New-MDEPolicyResult -Name $displayName -Status "Skipped" -Details "Policy already exists"
    }

    try {
        $jsonText = Get-MDEPolicyTemplate -FileName $JsonFile

        # Replace placeholder token in JSON
        $jsonText = $jsonText.Replace('__POLICY_NAME__', $displayName)

        Write-MDELog -Message "Creating policy [$displayName] from [$JsonFile]"
        Write-MDELog -Message "Request JSON [$displayName]: $jsonText"

        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $jsonText -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "Created"
    }
    catch {
        $detail = Get-MDEPolicyCreateErrorDetail -ErrorRecord $_
        Write-MDELog -Level 'ERROR' -Message "Create failed [$displayName]: $detail"
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

function New-MDEAntivirusPolicy {
    Invoke-CreatePolicyFromJson -PolicyName "Antivirus" -JsonFile "Antivirus.json"
}

function New-MDESecurityExperiencePolicy {
    Invoke-CreatePolicyFromJson -PolicyName "Windows Security Experience" -JsonFile "WindowsSecurityExperience.json"
}

function New-MDEASRPolicy {
    Invoke-CreatePolicyFromJson -PolicyName "ASR" -JsonFile "ASR.json"
}

function New-MDEFirewallPolicy {
    Invoke-CreatePolicyFromJson -PolicyName "Firewall" -JsonFile "Firewall.json"
}

function New-MDEApplicationControlPolicy {
    Invoke-CreatePolicyFromJson -PolicyName "Application Control" -JsonFile "ApplicationControl.json"
}

function New-MDEEDRPolicy {
    Assert-Mg

    $displayName = Get-MDEPolicyDisplayName -Name "EDR"

    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents"

        $body = @{
            displayName = $displayName
            description = "EDR placeholder policy"
        } | ConvertTo-Json -Depth 10

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "EDR shell created"
    }
    catch {
        $detail = Get-MDEPolicyCreateErrorDetail -ErrorRecord $_
        Write-MDELog -Level 'ERROR' -Message "EDR create failed [$displayName]: $detail"
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

Export-ModuleMember -Function @(
    'New-MDEAntivirusPolicy',
    'New-MDESecurityExperiencePolicy',
    'New-MDEASRPolicy',
    'New-MDEEDRPolicy',
    'New-MDEFirewallPolicy',
    'New-MDEApplicationControlPolicy'
)
