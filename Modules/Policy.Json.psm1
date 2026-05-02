Import-Module "$PSScriptRoot\Common.psm1" -Force -DisableNameChecking

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

function New-MDEAntivirusSettingsCatalogPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\SettingsCatalog\antivirus.json'
    New-MDEJsonPolicy -Name 'Antivirus' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEAntivirusEndpointSecurityPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\antivirus.json'
    New-MDEJsonPolicy -Name 'Antivirus Endpoint Security' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEFirewallPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\firewall.json'
    New-MDEJsonPolicy -Name 'Firewall' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEASRPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\asr.json'
    New-MDEJsonPolicy -Name 'ASR' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEEDRPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\edr.json'
    New-MDEJsonPolicy -Name 'EDR' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEWebProtectionPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\webprotection.json'
    New-MDEJsonPolicy -Name 'Web Protection' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEWindowsSecurityExperiencePolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\windows-security-experience.json'
    New-MDEJsonPolicy -Name 'Windows Security Experience' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEAVCUpdateControlsPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\avc-update-controls.json'
    New-MDEJsonPolicy -Name 'AVC Update Controls' -JsonPath $path -WhatIf:$WhatIf
}

function New-MDEApplicationControlPolicy {
    param([switch]$WhatIf)

    $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\EndpointSecurity\application-control.json'
    New-MDEJsonPolicy -Name 'Application Control' -JsonPath $path -WhatIf:$WhatIf
}

function Get-MDEJsonPolicyCatalog {
    $root = Split-Path $PSScriptRoot -Parent

    @(
        [pscustomobject]@{
            Name        = 'Antivirus'
            Category    = 'Settings Catalog'
            JsonPath    = Join-Path $root 'Config\SettingsCatalog\antivirus.json'
            Function    = 'New-MDEAntivirusSettingsCatalogPolicy'
        }

        [pscustomobject]@{
            Name        = 'Antivirus Endpoint Security'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\antivirus.json'
            Function    = 'New-MDEAntivirusEndpointSecurityPolicy'
        }

        [pscustomobject]@{
            Name        = 'Firewall'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\firewall.json'
            Function    = 'New-MDEFirewallPolicy'
        }

        [pscustomobject]@{
            Name        = 'ASR'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\asr.json'
            Function    = 'New-MDEASRPolicy'
        }

        [pscustomobject]@{
            Name        = 'EDR'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\edr.json'
            Function    = 'New-MDEEDRPolicy'
        }

        [pscustomobject]@{
            Name        = 'Web Protection'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\webprotection.json'
            Function    = 'New-MDEWebProtectionPolicy'
        }

        [pscustomobject]@{
            Name        = 'Windows Security Experience'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\windows-security-experience.json'
            Function    = 'New-MDEWindowsSecurityExperiencePolicy'
        }

        [pscustomobject]@{
            Name        = 'AVC Update Controls'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\avc-update-controls.json'
            Function    = 'New-MDEAVCUpdateControlsPolicy'
        }

        [pscustomobject]@{
            Name        = 'Application Control'
            Category    = 'Endpoint Security'
            JsonPath    = Join-Path $root 'Config\EndpointSecurity\application-control.json'
            Function    = 'New-MDEApplicationControlPolicy'
        }
    )
}

Export-ModuleMember -Function @(
    'New-MDEJsonPolicy',
    'New-MDEAntivirusSettingsCatalogPolicy',
    'New-MDEAntivirusEndpointSecurityPolicy',
    'New-MDEFirewallPolicy',
    'New-MDEASRPolicy',
    'New-MDEEDRPolicy',
    'New-MDEWebProtectionPolicy',
    'New-MDEWindowsSecurityExperiencePolicy',
    'New-MDEAVCUpdateControlsPolicy',
    'New-MDEApplicationControlPolicy',
    'Get-MDEJsonPolicyCatalog'
)
