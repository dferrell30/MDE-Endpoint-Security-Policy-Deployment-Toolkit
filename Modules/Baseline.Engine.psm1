Import-Module "$PSScriptRoot\Common.psm1" -Force -DisableNameChecking

function Get-MDEBaselineJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Baseline JSON not found: $Path"
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-MDETemplateJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Template JSON not found: $Path"
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Set-MDETemplateSettingValue {
    param(
        [Parameter(Mandatory)]
        $Template,

        [Parameter(Mandatory)]
        [string]$SettingDefinitionId,

        [Parameter(Mandatory)]
        $Value
    )

    foreach ($setting in $Template.settings) {
        if (-not $setting.settingInstance) {
            continue
        }

        $instance = $setting.settingInstance

        if ($instance.settingDefinitionId -ne $SettingDefinitionId) {
            continue
        }

        if ($instance.PSObject.Properties.Name -contains 'choiceSettingValue') {
            $instance.choiceSettingValue.value = $Value

            if ($null -eq $instance.choiceSettingValue.children) {
                $instance.choiceSettingValue.children = @()
            }

            return $true
        }

        if ($instance.PSObject.Properties.Name -contains 'simpleSettingValue') {
            $instance.simpleSettingValue.value = $Value
            return $true
        }
    }

    return $false
}

function Convert-MDEBooleanToChoiceValue {
    param(
        [Parameter(Mandatory)]
        [bool]$Value,

        [Parameter(Mandatory)]
        [string]$SettingDefinitionId
    )

    if ($Value) {
        return "$($SettingDefinitionId)_1"
    }

    return "$($SettingDefinitionId)_0"
}

function New-MDEPolicyFromBaseline {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$BaselinePath,

        [Parameter(Mandatory)]
        [string]$TemplatePath,

        [Parameter(Mandatory)]
        [hashtable]$Map,

        [switch]$WhatIf
    )

    try {
        $baseline = Get-MDEBaselineJson -Path $BaselinePath
        $template = Get-MDETemplateJson -Path $TemplatePath

        if ($baseline.PSObject.Properties.Name -contains 'name' -and -not [string]::IsNullOrWhiteSpace($baseline.name)) {
            $template.name = Get-MDEPolicyName $baseline.name
        }
        else {
            $template.name = Get-MDEPolicyName $Name
        }

        if ($baseline.PSObject.Properties.Name -contains 'description' -and -not [string]::IsNullOrWhiteSpace($baseline.description)) {
            $template.description = $baseline.description
        }

        if (-not ($baseline.PSObject.Properties.Name -contains 'settings')) {
            throw "Baseline JSON is missing the settings object."
        }

        foreach ($friendlyName in $baseline.settings.PSObject.Properties.Name) {
            if (-not $Map.ContainsKey($friendlyName)) {
                Write-MDELog -Level WARN -Message "No mapping found for [$friendlyName]. Skipping."
                continue
            }

            $mapping = $Map[$friendlyName]
            $settingDefinitionId = $mapping.SettingDefinitionId
            $rawValue = $baseline.settings.$friendlyName

            switch ($mapping.Type) {
                'BooleanChoice' {
                    $graphValue = Convert-MDEBooleanToChoiceValue `
                        -Value ([bool]$rawValue) `
                        -SettingDefinitionId $settingDefinitionId
                }

                'Choice' {
                    if (-not $mapping.Values.ContainsKey($rawValue)) {
                        throw "Invalid value [$rawValue] for [$friendlyName]."
                    }

                    $graphValue = $mapping.Values[$rawValue]
                }

                'Integer' {
                    $graphValue = [int]$rawValue
                }

                'String' {
                    $graphValue = [string]$rawValue
                }

                default {
                    throw "Unsupported mapping type: $($mapping.Type)"
                }
            }

            $updated = Set-MDETemplateSettingValue `
                -Template $template `
                -SettingDefinitionId $settingDefinitionId `
                -Value $graphValue

            if (-not $updated) {
                Write-MDELog -Level WARN -Message "Setting not found in template: $settingDefinitionId"
            }
        }

        $tempFolder = Join-Path $env:TEMP 'MDE-Deployment-Tool'
        if (-not (Test-Path -LiteralPath $tempFolder)) {
            New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
        }

        $tempPath = Join-Path $tempFolder "$($Name)-payload.json"
        $template | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $tempPath -Encoding UTF8

        return New-MDEConfigPolicyFromJson `
            -Name $Name `
            -JsonPath $tempPath `
            -WhatIf:$WhatIf
    }
    catch {
        return New-MDEPolicyResult `
            -Name $Name `
            -Status "Failed" `
            -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function @(
    'Get-MDEBaselineJson',
    'Get-MDETemplateJson',
    'Set-MDETemplateSettingValue',
    'Convert-MDEBooleanToChoiceValue',
    'New-MDEPolicyFromBaseline'
)
