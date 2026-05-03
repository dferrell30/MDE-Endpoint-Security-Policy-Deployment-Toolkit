Import-Module (Join-Path $PSScriptRoot 'Common.psm1') -Force -DisableNameChecking -Global
Import-Module (Join-Path $PSScriptRoot 'Baseline.Engine.psm1') -Force -DisableNameChecking -Global

$script:AntivirusMap = @{
    cloudProtection = @{
        Type = 'String'
        SettingDefinitionId = 'device_vendor_msft_policy_config_defender_allowcloudprotection'
    }

    realTimeMonitoring = @{
        Type = 'String'
        SettingDefinitionId = 'device_vendor_msft_policy_config_defender_allowrealtimemonitoring'
    }

    puaProtection = @{
        Type = 'String'
        SettingDefinitionId = 'device_vendor_msft_policy_config_defender_puaprotection'
    }

    avgCpuLoadFactor = @{
        Type = 'Integer'
        SettingDefinitionId = 'device_vendor_msft_policy_config_defender_avgcpuloadfactor'
    }
}

function New-MDEJsonPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$JsonPath,

        [switch]$WhatIf
    )

    New-MDEConfigPolicyFromJson `
        -Name $Name `
        -JsonPath $JsonPath `
        -WhatIf:$WhatIf
}

function New-MDEAntivirusBaselinePolicy {
    param([switch]$WhatIf)

    $root = Split-Path $PSScriptRoot -Parent

    New-MDEPolicyFromBaseline `
        -Name 'Antivirus Baseline' `
        -BaselinePath (Join-Path $root 'Config\Baselines\antivirus.baseline.json') `
        -TemplatePath (Join-Path $root 'Config\Templates\antivirus.template.json') `
        -Map $script:AntivirusMap `
        -WhatIf:$WhatIf
}

function New-MDEAntivirusSettingsCatalogPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\antivirus.json'
    New-MDEJsonPolicy -Name 'Antivirus' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEFirewallPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\firewall.json'
    New-MDEJsonPolicy -Name 'Firewall' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEASRPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\asr.json'
    New-MDEJsonPolicy -Name 'ASR' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEEDRPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\edr.json'
    New-MDEJsonPolicy -Name 'EDR' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEWindowsSecurityExperiencePolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\windows-security-experience.json'
    New-MDEJsonPolicy -Name 'Windows Security Experience' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEAVCUpdateControlsPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\avc-update-controls.json'
    New-MDEJsonPolicy -Name 'AVC Update Controls' -JsonPath $path -WhatIf:$WhatIf
}

function Get-MDEJsonPolicyCatalog {
    $root = Split-Path $PSScriptRoot -Parent

    @(
        [pscustomobject]@{
            Name     = 'Antivirus Baseline'
            Category = 'Editable Baseline'
            JsonPath = Join-Path $root 'Config\Baselines\antivirus.baseline.json'
            Function = 'New-MDEAntivirusBaselinePolicy'
        }

        [pscustomobject]@{
            Name     = 'Antivirus'
            Category = 'Settings Catalog Raw JSON'
            JsonPath = Join-Path $root 'Config\SettingsCatalog\antivirus.json'
            Function = 'New-MDEAntivirusSettingsCatalogPolicy'
        }

        [pscustomobject]@{
            Name     = 'Firewall'
            Category = 'Settings Catalog Raw JSON'
            JsonPath = Join-Path $root 'Config\SettingsCatalog\firewall.json'
            Function = 'New-MDEFirewallPolicy'
        }

        [pscustomobject]@{
            Name     = 'ASR'
            Category = 'Settings Catalog Raw JSON'
            JsonPath = Join-Path $root 'Config\SettingsCatalog\asr.json'
            Function = 'New-MDEASRPolicy'
        }

        [pscustomobject]@{
            Name     = 'EDR'
            Category = 'Settings Catalog Raw JSON'
            JsonPath = Join-Path $root 'Config\SettingsCatalog\edr.json'
            Function = 'New-MDEEDRPolicy'
        }

        [pscustomobject]@{
            Name     = 'Windows Security Experience'
            Category = 'Settings Catalog Raw JSON'
            JsonPath = Join-Path $root 'Config\SettingsCatalog\windows-security-experience.json'
            Function = 'New-MDEWindowsSecurityExperiencePolicy'
        }

        [pscustomobject]@{
            Name     = 'AVC Update Controls'
            Category = 'Settings Catalog Raw JSON'
            JsonPath = Join-Path $root 'Config\SettingsCatalog\avc-update-controls.json'
            Function = 'New-MDEAVCUpdateControlsPolicy'
        }
    )
}

Export-ModuleMember -Function @(
    'New-MDEJsonPolicy',
    'New-MDEAntivirusBaselinePolicy',
    'New-MDEAntivirusSettingsCatalogPolicy',
    'New-MDEFirewallPolicy',
    'New-MDEASRPolicy',
    'New-MDEEDRPolicy',
    'New-MDEWindowsSecurityExperiencePolicy',
    'New-MDEAVCUpdateControlsPolicy',
    'Get-MDEJsonPolicyCatalog'
)
