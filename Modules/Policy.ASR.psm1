Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-MDEASRPolicy {
    [CmdletBinding()]
    param(
        [ValidateSet('block','audit','warn','off')]
        [string]$AdobeReaderChildProcessRule = 'block'
    )

    try {
        $ruleValue = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses_$AdobeReaderChildProcessRule"

        $settings = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules'
                    settingInstanceTemplateReference = @{
                        settingInstanceTemplateId = '19600663-e264-4c02-8f55-f2983216d6d7'
                    }
                    groupSettingCollectionValue = @(
                        @{
                            children = @(
                                @{
                                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                                    settingDefinitionId = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses'
                                    choiceSettingValue = @{
                                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                                        value = $ruleValue
                                        children = @()
                                    }
                                }
                            )
                        }
                    )
                }
            }
        )

        $policy = New-MDEConfigurationPolicy `
            -PolicyName 'ASR' `
            -Description 'Attack Surface Reduction policy created by deployment tool.' `
            -Settings $settings `
            -TemplateId 'e8c053d6-9f95-42b1-a7f1-ebfd71c67a4b_1'

        New-MDELogObject -Name 'ASR' -Status 'Success' -Details 'Policy created.' -PolicyId $policy.id
    }
    catch {
        New-MDELogObject -Name 'ASR' -Status 'Failed' -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function New-MDEASRPolicy
