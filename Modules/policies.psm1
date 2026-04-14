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
        throw "Not connected. Click Initialize first."
    }
}

function Invoke-CreatePolicy {
    param(
        [string]$Name,
        [hashtable]$Body
    )

    Assert-Mg

    $displayName = "$script:PolicyPrefix - $Name"

    try {
        $Body.name = $displayName

        $json = $Body | ConvertTo-Json -Depth 25
        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "Created"
    }
    catch {
        $detail = $_.Exception.Message

        try {
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $detail = $_.ErrorDetails.Message
            }
        }
        catch { }

        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

function New-MDEAntivirusPolicy {
    $body = @{
        description = "Antivirus policy create attempt"
        platforms   = "windows10"
        technologies = "mdm,microsoftSense"
        settings    = @()
    }

    Invoke-CreatePolicy -Name "Antivirus" -Body $body
}

function New-MDESecurityExperiencePolicy {
    $body = @{
        description = "Windows Security Experience policy create attempt"
        platforms   = "windows10"
        technologies = "mdm,microsoftSense"
        settings    = @()
    }

    Invoke-CreatePolicy -Name "Windows Security Experience" -Body $body
}

function New-MDEASRPolicy {
    $body = @{
        description = "ASR policy create attempt"
        platforms   = "windows10"
        technologies = "mdm,microsoftSense"
        settings    = @()
    }

    Invoke-CreatePolicy -Name "ASR" -Body $body
}

function New-MDEFirewallPolicy {
    $body = @{
        description = "Firewall policy create attempt"
        platforms   = "windows10"
        settings    = @()
    }

    Invoke-CreatePolicy -Name "Firewall" -Body $body
}

function New-MDEApplicationControlPolicy {
    $body = @{
        description = "Application Control policy create attempt"
        platforms   = "windows10"
        settings    = @()
    }

    Invoke-CreatePolicy -Name "Application Control" -Body $body
}

function New-MDEEDRPolicy {
    Assert-Mg

    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents"

        $body = @{
            displayName = "MDE - EDR"
            description = "EDR placeholder policy"
        }

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json) -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name "MDE - EDR" -Status "Success" -Details "EDR shell created"
    }
    catch {
        $detail = $_.Exception.Message

        try {
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $detail = $_.ErrorDetails.Message
            }
        }
        catch { }

        return New-MDEPolicyResult -Name "MDE - EDR" -Status "Failed" -Details $detail
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
