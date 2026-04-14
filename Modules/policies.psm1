Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

function New-MDEPolicyResult {
    param($Name,$Status,$Details)

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

# ============================================
# CORE: CREATE ENDPOINT SECURITY POLICY
# ============================================
function New-MDEEndpointSecurityPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [string]$TemplateId
    )

    Assert-Mg

    $displayName = "$script:PolicyPrefix - $PolicyName"

    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/templates/$TemplateId/createInstance"

        $body = @{
            displayName = $displayName
            description = "$PolicyName policy created via automation"
        } | ConvertTo-Json -Depth 5

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult $displayName "Success" "Endpoint Security policy created"
    }
    catch {
        return New-MDEPolicyResult $displayName "Failed" $_.Exception.Message
    }
}

# ============================================
# POLICY TYPES (TEMPLATE IDS)
# ============================================

function New-MDEASRPolicy {
    New-MDEEndpointSecurityPolicy -PolicyName "ASR" -TemplateId "attackSurfaceReduction"
}

function New-MDEAntivirusPolicy {
    New-MDEEndpointSecurityPolicy -PolicyName "Antivirus" -TemplateId "endpointSecurityAntivirus"
}

function New-MDEFirewallPolicy {
    New-MDEEndpointSecurityPolicy -PolicyName "Firewall" -TemplateId "endpointSecurityFirewall"
}

function New-MDEEDRPolicy {
    New-MDEEndpointSecurityPolicy -PolicyName "EDR" -TemplateId "endpointDetectionAndResponse"
}

function New-MDESecurityExperiencePolicy {
    New-MDEEndpointSecurityPolicy -PolicyName "Windows Security Experience" -TemplateId "endpointSecurityExperience"
}

function New-MDEApplicationControlPolicy {
    New-MDEEndpointSecurityPolicy -PolicyName "Application Control" -TemplateId "endpointSecurityApplicationControl"
}

Export-ModuleMember -Function @(
    'New-MDEASRPolicy',
    'New-MDEAntivirusPolicy',
    'New-MDEFirewallPolicy',
    'New-MDEEDRPolicy',
    'New-MDESecurityExperiencePolicy',
    'New-MDEApplicationControlPolicy'
)
