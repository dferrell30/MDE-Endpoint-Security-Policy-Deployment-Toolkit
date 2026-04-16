function New-MDEASRPolicy {
    $body = @{
        description       = "ASR policy created via tool"
        platforms         = "windows10"
        technologies      = "mdm,microsoftSense"
        roleScopeTagIds   = @("0")
        templateReference = @{
            templateId = "e8c053d6-9f95-42b1-a7f1-ebfd71c67a4b_1"
        }
        settings = @(
            @{
                "@odata.type" = "#microsoft.graph.deviceManagementConfigurationSetting"
                settingInstance = @{
                    "@odata.type" = "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance"
                    settingDefinitionId = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules"
                    settingInstanceTemplateReference = @{
                        settingInstanceTemplateId = "19600663-e264-4c02-8f55-f2983216d6d7"
                    }
                    groupSettingCollectionValue = @(
                        @{
                            children = @(
                                @{
                                    "@odata.type" = "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
                                    settingDefinitionId = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses"
                                    choiceSettingValue = @{
                                        "@odata.type" = "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue"
                                        value = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses_block"
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

    Invoke-CreateConfigPolicy -Name "ASR" -Body $body
}

Export-ModuleMember -Function 'New-MDEASRPolicy'
