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

function Get-MDEPolicyDisplayName {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return "$script:PolicyPrefix - $Name"
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
    catch { }

    return $detail
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
        return $false
    }
}

function Invoke-CreatePolicy {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Body
    )

    Assert-Mg

    $displayName = Get-MDEPolicyDisplayName -Name $Name

    if (Test-MDEConfigurationPolicyExists -DisplayName $displayName) {
        return New-MDEPolicyResult -Name $displayName -Status "Skipped" -Details "Policy already exists"
    }

    try {
        $Body.name = $displayName

        $json = $Body | ConvertTo-Json -Depth 25
        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "Created"
    }
    catch {
        $detail = Get-MDEPolicyCreateErrorDetail -ErrorRecord $_
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
}

function New-MDEAntivirusPolicy {
    $body = @{
        description  = "Antivirus policy create attempt"
        platforms    = "windows10"
        technologies = "mdm,microsoftSense"
        settings     = @()
    }

    Invoke-CreatePolicy -Name "Antivirus" -Body $body
}

function New-MDESecurityExperiencePolicy {
    $body = @{
        description  = "Windows Security Experience policy create attempt"
        platforms    = "windows10"
        technologies = "mdm,microsoftSense"
        settings     = @()
    }

    Invoke-CreatePolicy -Name "Windows Security Experience" -Body $body
}

function New-MDEASRPolicy {
    Assert-Mg

    $displayName = Get-MDEPolicyDisplayName -Name "ASR"

    if (Test-MDEConfigurationPolicyExists -DisplayName $displayName) {
        return New-MDEPolicyResult -Name $displayName -Status "Skipped" -Details "Policy already exists"
    }

    try {
        $body = @{
            name         = $displayName
            description  = "ASR Policy - Hardened Block Mode"
            platforms    = "windows10"
            technologies = "mdm,microsoftSense"
            settings     = @(
                @{
                    "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSetting"
                    settingInstance = @{
                        "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance"
                        settingDefinitionId = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules"
                        simpleSettingValue = @{
                            "@odata.type" = "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                            value = @(
                                "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC", # Block execution of potentially obfuscated scripts
                                "C1DB55AB-C21A-4637-BB3F-A12568109D35", # Block Win32 API calls from Office macros
                                "01443614-CD74-433A-B99E-2ECDC07BFC25", # Block executable files from running unless prevalence/age/trusted
                                "26190899-1602-49E8-8B27-EB1D0A1CE869", # Block Office communication apps creating child processes
                                "D4F940AB-401B-4EFC-AADC-AD5F3C50688A", # Block all Office applications from creating child processes
                                "7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C", # Block Adobe Reader from creating child processes
                                "9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2", # Block credential stealing from LSASS
                                "D3E037E1-3EB8-44C8-A917-57927947596D", # Block JavaScript or VBScript launching downloaded executable content
                                "B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4", # Block untrusted and unsigned processes that run from USB
                                "E6DB77E5-3DF2-4CF1-B95A-636979351E5B", # Block persistence through WMI event subscription
                                "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B", # Block use of copied or impersonated system tools
                                "56A863A9-875E-4185-98A7-B882C64B5CE5", # Block abuse of exploited vulnerable signed drivers
                                "D1E49AAC-8F56-4280-B9BA-993A6D77406C", # Block process creations originating from PSExec and WMI commands
                                "3B576869-A4EC-4529-8536-B80A7769E899", # Block Office applications from creating executable content
                                "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84", # Block Office applications from injecting code into other processes
                                "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550"  # Use advanced protection against ransomware
                            ) -join ","
                        }
                    }
                },
                @{
                    "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSetting"
                    settingInstance = @{
                        "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance"
                        settingDefinitionId = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockwebshellcreationforservers"
                        simpleSettingValue = @{
                            "@odata.type" = "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                            value = "0"
                        }
                    }
                },
                @{
                    "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSetting"
                    settingInstance = @{
                        "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance"
                        settingDefinitionId = "device_vendor_msft_policy_config_defender_enablecontrolledfolderaccess"
                        simpleSettingValue = @{
                            "@odata.type" = "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                            value = "0"
                        }
                    }
                }
            )
        }

        $json = $body | ConvertTo-Json -Depth 25
        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "ASR policy created"
    }
    catch {
        $detail = Get-MDEPolicyCreateErrorDetail -ErrorRecord $_
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $detail
    }
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

    $displayName = Get-MDEPolicyDisplayName -Name "EDR"

    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents"

        $body = @{
            displayName = $displayName
            description = "EDR placeholder policy"
        }

        Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult -Name $displayName -Status "Success" -Details "EDR shell created"
    }
    catch {
        $detail = Get-MDEPolicyCreateErrorDetail -ErrorRecord $_
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
