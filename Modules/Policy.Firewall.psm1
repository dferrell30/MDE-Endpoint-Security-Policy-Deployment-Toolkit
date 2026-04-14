Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-MDEFirewallPolicy {
    [CmdletBinding()]
    param()

    try {
        $settings = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'
                settingInstance = @{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
                    settingDefinitionId = 'vendor_msft_firewall_mdmstore_global_disablestatefulftp'
                    settingInstanceTemplateReference = @{
                        settingInstanceTemplateId = '38329af6-2670-4a71-972d-482010ca97fc'
                    }
                    choiceSettingValue = @{
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                        value = 'vendor_msft_firewall_mdmstore_global_disablestatefulftp_true'
                        children = @()
                        settingValueTemplateReference = @{
                            settingValueTemplateId = '559f6e01-53a9-4c10-9f10-d09d8fe7f903'
                        }
                    }
                }
            }
        )

        $policy = New-MDEConfigurationPolicy `
            -PolicyName 'Firewall' `
            -Description 'Microsoft Defender Firewall policy created by deployment tool.' `
            -Settings $settings

        New-MDELogObject -Name 'Firewall' -Status 'Success' -Details 'Policy created.' -PolicyId $policy.id
    }
    catch {
        New-MDELogObject -Name 'Firewall' -Status 'Failed' -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function New-MDEFirewallPolicy
