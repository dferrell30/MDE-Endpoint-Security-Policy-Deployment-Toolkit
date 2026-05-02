Import-Module "$PSScriptRoot\Common.psm1" -Force -DisableNameChecking

function New-MDEJsonPolicy {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$JsonPath,
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

Export-ModuleMember -Function @(
    'New-MDEJsonPolicy',
    'New-MDEAntivirusSettingsCatalogPolicy',
    'New-MDEAntivirusEndpointSecurityPolicy',
    'New-MDEFirewallPolicy',
    'New-MDEASRPolicy',
    'New-MDEEDRPolicy',
    'New-MDEWebProtectionPolicy'
)
