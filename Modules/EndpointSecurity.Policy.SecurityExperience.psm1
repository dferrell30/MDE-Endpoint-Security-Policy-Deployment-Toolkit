Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-MDESecurityExperiencePolicy {
    [CmdletBinding()]
    param()

    try {
        $settings = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_defender_configuration_tamperprotection_options'
                    settingInstanceTemplateReference = @{
                        settingInstanceTemplateId = '5655cab2-7e6b-4c49-9ce2-3865da05f7e6'
                    }
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_defender_configuration_tamperprotection_options_0'
                        children = @()
                        settingValueTemplateReference = @{
                            settingValueTemplateId = 'fc365da9-2c1b-4f79-aa4b-dedca69e728f'
                        }
                    }
                }
            }
        )

        $policy = New-MDEConfigurationPolicy `
            -PolicyName 'Windows Security Experience' `
            -Description 'Windows Security Experience policy created by deployment tool.' `
            -Settings $settings `
            -TemplateId 'd948ff9b-99cb-4ee0-8012-1fbc09685377_1'

        New-MDELogObject -Name 'Windows Security Experience' -Status 'Success' -Details 'Policy created.' -PolicyId $policy.id
    }
    catch {
        New-MDELogObject -Name 'Windows Security Experience' -Status 'Failed' -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function New-MDESecurityExperiencePolicy
