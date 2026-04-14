. "$PSScriptRoot\Policy.Common.ps1"

function New-MDEAntivirusPolicy {
    New-MDESettingsCatalogResultWrapper -PolicyName 'Antivirus' -CreateAction {
        $body = @{
            description = 'Microsoft Defender Antivirus baseline'
            name        = ''
            platforms   = 'windows10'
            roleScopeTagIds = @('0')
            technologies = 'mdm,microsoftSense'
            settings = @(
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
                        settingDefinitionId = 'device_vendor_msft_policy_config_defender_realtimescandirection'
                        choiceSettingValue = @{
                            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                            value = 'device_vendor_msft_policy_config_defender_realtimescandirection_0'
                            children = @()
                        }
                    }
                }
            )
        }

        New-MDEConfigurationPolicy -PolicyName 'Antivirus' -PolicyBody $body
    }
}
