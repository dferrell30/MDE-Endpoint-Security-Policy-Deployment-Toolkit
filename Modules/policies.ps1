Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

function Get-LogsPath {
    $root = Split-Path -Path $PSScriptRoot -Parent
    $logPath = Join-Path $root 'Logs'
    if (-not (Test-Path -LiteralPath $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    return $logPath
}

function Write-MDELog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $logFile = Join-Path (Get-LogsPath) 'deployment.log'
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $logFile -Value $line
}

function Assert-MgConnected {
    $ctx = Get-MgContext
    if (-not $ctx) {
        throw "Microsoft Graph is not connected. Click Initialize first."
    }
}

function New-MDEPolicyResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
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

function Get-MDEPolicyDisplayName {
    param(
        [Parameter(Mandatory)]
        [string]$ShortName
    )

    return "$($script:PolicyPrefix) - $ShortName"
}

function Get-MDEExistingPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    Assert-MgConnected

    $safeName = $DisplayName.Replace("'", "''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$safeName'"

    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    if ($result.value -and $result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function Invoke-MDEConfigurationPolicyCreate {
    param(
        [Parameter(Mandatory)]
        [string]$ShortName,

        [Parameter(Mandatory)]
        [hashtable]$Body
    )

    Assert-MgConnected

    $displayName = Get-MDEPolicyDisplayName -ShortName $ShortName
    $existing = Get-MDEExistingPolicy -DisplayName $displayName
    if ($existing) {
        Write-MDELog -Message "Skipped existing policy: $displayName" -Level 'WARN'
        return New-MDEPolicyResult -Name $displayName -Status 'Skipped' -Details 'Policy already exists.' -PolicyId $existing.id
    }

    $Body['name'] = $displayName

    if (-not $Body.ContainsKey('description')) {
        $Body['description'] = 'Created via MDE Endpoint Security Deployment Tool'
    }

    if (-not $Body.ContainsKey('platforms')) {
        $Body['platforms'] = 'windows10'
    }

    if (-not $Body.ContainsKey('roleScopeTagIds')) {
        $Body['roleScopeTagIds'] = @('0')
    }

    try {
        $json = $Body | ConvertTo-Json -Depth 25
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'

        Write-MDELog -Message "Creating policy: $displayName"
        $policy = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType 'application/json' -OutputType PSObject
        Write-MDELog -Message "Created policy: $displayName ($($policy.id))"

        return New-MDEPolicyResult -Name $displayName -Status 'Success' -Details 'Policy created.' -PolicyId $policy.id
    }
    catch {
        Write-MDELog -Message "Failed creating policy $displayName. $($_.Exception.Message)" -Level 'ERROR'
        return New-MDEPolicyResult -Name $displayName -Status 'Failed' -Details $_.Exception.Message
    }
}

function New-MDEAntivirusPolicy {
    $body = @{
        description  = 'Microsoft Defender Antivirus baseline'
        platforms    = 'windows10'
        technologies = 'mdm,microsoftSense'
        settings     = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_allowarchivescanning'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'device_vendor_msft_policy_config_defender_allowarchivescanning_1'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_allowemailscanning'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'device_vendor_msft_policy_config_defender_allowemailscanning_1'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_allowrealtimemonitoring'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'device_vendor_msft_policy_config_defender_allowrealtimemonitoring_1'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_allowcloudprotection'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'device_vendor_msft_policy_config_defender_allowcloudprotection_1'
                        children = @()
                    }
                }
            }
        )
    }

    Invoke-MDEConfigurationPolicyCreate -ShortName 'Antivirus' -Body $body
}

function New-MDESecurityExperiencePolicy {
    $body = @{
        description       = 'Windows Security Experience baseline'
        platforms         = 'windows10'
        technologies      = 'mdm,microsoftSense'
        templateReference = @{
            templateId = 'd948ff9b-99cb-4ee0-8012-1fbc09685377_1'
        }
        settings = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_defender_configuration_tamperprotection_options'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_defender_configuration_tamperprotection_options_0'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_defender_configuration_familyui_options'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_defender_configuration_familyui_options_1'
                        children = @()
                    }
                }
            }
        )
    }

    Invoke-MDEConfigurationPolicyCreate -ShortName 'Windows Security Experience' -Body $body
}

function New-MDEFirewallPolicy {
    $body = @{
        description = 'Windows Defender Firewall baseline'
        platforms   = 'windows10'
        settings    = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_domainprofile_enablefirewall'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_domainprofile_enablefirewall_true'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_privateprofile_enablefirewall'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_privateprofile_enablefirewall_true'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_publicprofile_enablefirewall'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_publicprofile_enablefirewall_true'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_domainprofile_defaultinboundaction'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_domainprofile_defaultinboundaction_0'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_privateprofile_defaultinboundaction'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_privateprofile_defaultinboundaction_0'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_publicprofile_defaultinboundaction'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_publicprofile_defaultinboundaction_0'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_domainprofile_defaultoutboundaction'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_domainprofile_defaultoutboundaction_1'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_privateprofile_defaultoutboundaction'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_privateprofile_defaultoutboundaction_1'
                        children = @()
                    }
                }
            },
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_publicprofile_defaultoutboundaction'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_publicprofile_defaultoutboundaction_1'
                        children = @()
                    }
                }
            }
        )
    }

    Invoke-MDEConfigurationPolicyCreate -ShortName 'Firewall' -Body $body
}

function New-MDEASRPolicy {
    $body = @{
        description       = 'Attack Surface Reduction baseline'
        platforms         = 'windows10'
        technologies      = 'mdm,microsoftSense'
        templateReference = @{
            templateId = 'e8c053d6-9f95-42b1-a7f1-ebfd71c67a4b_1'
        }
        settings = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules'
                    groupSettingCollectionValue = @(
                        @{
                            children = @(
                                @{
                                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses'
                                    choiceSettingValue = @{
                                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                                        value = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses_block'
                                        children = @()
                                    }
                                },
                                @{
                                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockallofficeapplicationsfromcreatingchildprocesses'
                                    choiceSettingValue = @{
                                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                                        value = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockallofficeapplicationsfromcreatingchildprocesses_block'
                                        children = @()
                                    }
                                },
                                @{
                                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockofficeapplicationsfromcreatingexecutablecontent'
                                    choiceSettingValue = @{
                                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                                        value = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockofficeapplicationsfromcreatingexecutablecontent_block'
                                        children = @()
                                    }
                                },
                                @{
                                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_usesaferulesforofficeapplications'
                                    choiceSettingValue = @{
                                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                                        value = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_usesaferulesforofficeapplications_block'
                                        children = @()
                                    }
                                }
                            )
                        }
                    )
                }
            }
        )
    }

    Invoke-MDEConfigurationPolicyCreate -ShortName 'ASR' -Body $body
}

function Enable-MDEManagedInstaller {
    Assert-MgConnected

    $checkUri = 'https://graph.microsoft.com/beta/deviceAppManagement/windowsManagementApp/'
    $setUri   = 'https://graph.microsoft.com/beta/deviceAppManagement/windowsManagementApp/setAsManagedInstaller'

    try {
        $current = Invoke-MgGraphRequest -Method GET -Uri $checkUri -OutputType PSObject
        if ($current.managedInstaller -eq $true) {
            Write-MDELog -Message "Managed Installer already enabled."
            return
        }
    }
    catch {
        Write-MDELog -Message "Managed Installer status check failed: $($_.Exception.Message)" -Level 'WARN'
    }

    Write-MDELog -Message "Enabling Managed Installer..."
    Invoke-MgGraphRequest -Method POST -Uri $setUri -Body '{}' -ContentType 'application/json' -OutputType PSObject | Out-Null
    Write-MDELog -Message "Managed Installer enabled."
}

function New-MDEApplicationControlPolicy {
    try {
        Enable-MDEManagedInstaller
    }
    catch {
        return New-MDEPolicyResult -Name (Get-MDEPolicyDisplayName -ShortName 'Application Control') -Status 'Failed' -Details "Managed Installer failed: $($_.Exception.Message)"
    }

    $body = @{
        description = 'Application Control baseline'
        platforms   = 'windows10'
        settings    = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_applicationcontrol_builtins_trustwindowscomponentsandstoreapps'
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_applicationcontrol_builtins_trustwindowscomponentsandstoreapps_enforce'
                        children = @()
                    }
                }
            }
        )
    }

    Invoke-MDEConfigurationPolicyCreate -ShortName 'Application Control' -Body $body
}

function New-MDEEDRPolicy {
    Assert-MgConnected

    $displayName = Get-MDEPolicyDisplayName -ShortName 'EDR'
    $existing = Get-MDEExistingPolicy -DisplayName $displayName
    if ($existing) {
        Write-MDELog -Message "Skipped existing policy: $displayName" -Level 'WARN'
        return New-MDEPolicyResult -Name $displayName -Status 'Skipped' -Details 'Policy already exists.' -PolicyId $existing.id
    }

    try {
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/intents'

        $body = @{
            displayName = $displayName
            description = 'EDR policy shell created via MDE Endpoint Security Deployment Tool'
        }

        $json = $body | ConvertTo-Json -Depth 10

        Write-MDELog -Message "Creating EDR shell policy: $displayName"
        $policy = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $json -ContentType 'application/json' -OutputType PSObject
        Write-MDELog -Message "Created EDR shell policy: $displayName ($($policy.id))"

        return New-MDEPolicyResult -Name $displayName -Status 'Success' -Details 'EDR shell policy created.' -PolicyId $policy.id
    }
    catch {
        Write-MDELog -Message "Failed creating EDR policy $displayName. $($_.Exception.Message)" -Level 'ERROR'
        return New-MDEPolicyResult -Name $displayName -Status 'Failed' -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function @(
    'Write-MDELog',
    'New-MDEAntivirusPolicy',
    'New-MDESecurityExperiencePolicy',
    'New-MDEFirewallPolicy',
    'New-MDEASRPolicy',
    'New-MDEEDRPolicy',
    'New-MDEApplicationControlPolicy'
)
