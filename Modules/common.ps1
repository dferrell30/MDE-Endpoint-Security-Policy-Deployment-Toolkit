Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PolicyPrefix = 'MDE'

function New-MDELogObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Success','Failed','Skipped')][string]$Status,
        [Parameter(Mandatory)][string]$Details,
        [string]$PolicyId = ''
    )

    [pscustomobject]@{
        Name     = $Name
        Status   = $Status
        Details  = $Details
        PolicyId = $PolicyId
        Time     = Get-Date
    }
}

function Invoke-MDEGraphPost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][object]$Body
    )

    $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 20 }
    Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $json -ContentType 'application/json' -OutputType PSObject
}

function Invoke-MDEGraphGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri
    )

    Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
}

function New-MDEConfigurationPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PolicyName,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][array]$Settings,
        [string]$TemplateId,
        [string]$Technologies = 'mdm,microsoftSense'
    )

    $body = @{
        name            = "$script:PolicyPrefix - $PolicyName"
        description     = $Description
        platforms       = 'windows10'
        roleScopeTagIds = @('0')
        settings        = $Settings
        technologies    = $Technologies
    }

    if ($TemplateId) {
        $body.templateReference = @{
            templateId = $TemplateId
        }
    }

    Invoke-MDEGraphPost -Uri 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies' -Body $body
}

function Get-MDETemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Subtype
    )

    $uri = 'https://graph.microsoft.com/beta/deviceManagement/templates'
    $templates = (Invoke-MDEGraphGet -Uri $uri).value

    $match = $templates |
        Where-Object {
            $_.templateType -eq 'securityTemplate' -and
            $_.templateSubtype -eq $Subtype
        } |
        Sort-Object publishedDateTime -Descending |
        Select-Object -First 1

    return $match
}

function New-MDEPolicyFromTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PolicyName,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$TemplateSubtype
    )

    $template = Get-MDETemplate -Subtype $TemplateSubtype
    if (-not $template) {
        throw "No endpoint security template found for subtype '$TemplateSubtype'."
    }

    $uri = "https://graph.microsoft.com/beta/deviceManagement/templates/$($template.id)/createInstance"
    $body = @{
        displayName = "$script:PolicyPrefix - $PolicyName"
        description = $Description
    }

    Invoke-MDEGraphPost -Uri $uri -Body $body
}

Export-ModuleMember -Function @(
    'New-MDELogObject',
    'Invoke-MDEGraphPost',
    'Invoke-MDEGraphGet',
    'New-MDEConfigurationPolicy',
    'Get-MDETemplate',
    'New-MDEPolicyFromTemplate'
)
