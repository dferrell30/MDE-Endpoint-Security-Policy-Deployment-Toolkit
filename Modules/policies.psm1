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

function Invoke-CreatePolicy {
    param($Name,$Body)

    Assert-Mg

    $displayName = "$script:PolicyPrefix - $Name"

    try {
        $Body.name = $displayName

        $json = $Body | ConvertTo-Json -Depth 20

        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

        $res = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType "application/json"

        return New-MDEPolicyResult $displayName "Success" "Created"
    }
    catch {
        return New-MDEPolicyResult $displayName "Failed" $_.Exception.Message
    }
}

# =========================
# ANTIVIRUS (WORKING)
# =========================
function New-MDEAntivirusPolicy {

    $body = @{
        platforms = "windows10"
        technologies = "mdm,microsoftSense"
        settings = @()
    }

    Invoke-CreatePolicy "Antivirus" $body
}

# =========================
# ASR (FIXED - VALID TEMPLATE)
# =========================
function New-MDEASRPolicy {

    $body = @{
        description = "ASR baseline"
        platforms   = "windows10"
        technologies = "mdm,microsoftSense"

        templateReference = @{
            templateId = "e8c053d6-9f95-42b1-a7f1-ebfd71c67a4b_1"
        }

        settings = @()
    }

    Invoke-CreatePolicy "ASR" $body
}

# =========================
# FIREWALL (FIXED)
# =========================
function New-MDEFirewallPolicy {

    $body = @{
        description = "Firewall baseline"
        platforms   = "windows10"

        templateReference = @{
            templateId = "b0f1b5a3-1879-4c7a-8cfd-2f3cb0c9c0c8_1"
        }

        settings = @()
    }

    Invoke-CreatePolicy "Firewall" $body
}

# =========================
# WINDOWS SECURITY EXPERIENCE (FIXED)
# =========================
function New-MDESecurityExperiencePolicy {

    $body = @{
        description = "Security Experience baseline"
        platforms   = "windows10"
        technologies = "mdm,microsoftSense"

        templateReference = @{
            templateId = "d948ff9b-99cb-4ee0-8012-1fbc09685377_1"
        }

        settings = @()
    }

    Invoke-CreatePolicy "Windows Security Experience" $body
}

# =========================
# APPLICATION CONTROL (SAFE FIX)
# =========================
function New-MDEApplicationControlPolicy {

    $body = @{
        description = "Application Control baseline"
        platforms   = "windows10"
        settings    = @()
    }

    Invoke-CreatePolicy "Application Control" $body
}

# =========================
# EDR (KEEP AS SHELL)
# =========================
function New-MDEEDRPolicy {

    Assert-Mg

    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents"

        $body = @{
            displayName = "MDE - EDR"
            description = "EDR placeholder policy"
        }

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json)

        return New-MDEPolicyResult "MDE - EDR" "Success" "EDR shell created"
    }
    catch {
        return New-MDEPolicyResult "MDE - EDR" "Failed" $_.Exception.Message
    }
}

Export-ModuleMember -Function * 
