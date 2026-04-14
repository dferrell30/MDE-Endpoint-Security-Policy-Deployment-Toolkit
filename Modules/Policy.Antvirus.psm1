Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-MDEAntivirusPolicy {
    [CmdletBinding()]
    param()

    try {
        $settings = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_allowarchivescanning'
                    settingInstanceTemplateReference = @{
                        settingInstanceTemplateId = '7c5c9cde-f74d-4d11-904f-de4c27f72d89'
                    }
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'device_vendor_msft_policy_config_defender_allowarchivescanning_1'
                        children = @()
                        settingValueTemplateReference = @{
                            settingValueTemplateId = '9ead75d4-6f30-4bc5-8cc5-ab0f999d79f0'
                        }
                    }
                }
            }
        )

        $policy = New-MDEConfigurationPolicy `
            -PolicyName 'Antivirus' `
            -Description 'Microsoft Defender Antivirus policy created by deployment tool.' `
            -Settings $settings

        New-MDELogObject -Name 'Antivirus' -Status 'Success' -Details 'Policy created.' -PolicyId $policy.id
    }
    catch {
        New-MDELogObject -Name 'Antivirus' -Status 'Failed' -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function New-MDEAntivirusPolicy
