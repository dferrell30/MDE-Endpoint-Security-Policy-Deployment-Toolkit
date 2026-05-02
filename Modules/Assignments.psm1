Import-Module "$PSScriptRoot\Common.psm1" -Force -DisableNameChecking

function Get-MDEAssignmentConfig {
    $root = Split-Path $PSScriptRoot -Parent
    $path = Join-Path $root 'Assignments\assignments.json'

    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Get-MDEGroupIdByName {
    param(
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    Assert-Mg

    $escapedName = $GroupName.Replace("'", "''")
    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escapedName'"

    $result = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $uri `
        -OutputType PSObject

    if (-not $result.value -or $result.value.Count -eq 0) {
        throw "Group not found: $GroupName"
    }

    if ($result.value.Count -gt 1) {
        throw "Multiple groups found with name: $GroupName"
    }

    return $result.value[0].id
}

function Get-MDEConfigPolicyIdByName {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName
    )

    Assert-Mg

    $escapedName = $PolicyName.Replace("'", "''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'"

    $result = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $uri `
        -OutputType PSObject

    if (-not $result.value -or $result.value.Count -eq 0) {
        throw "Policy not found: $PolicyName"
    }

    return $result.value[0].id
}

function Add-MDEConfigPolicyAssignment {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [string]$GroupName
    )

    Assert-Mg

    try {
        $policyId = Get-MDEConfigPolicyIdByName -PolicyName $PolicyName
        $groupId = Get-MDEGroupIdByName -GroupName $GroupName

        $body = @{
            assignments = @(
                @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId       = $groupId
                    }
                }
            )
        } | ConvertTo-Json -Depth 20 -Compress

        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assign"

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri $uri `
            -Body $body `
            -ContentType "application/json" | Out-Null

        Write-MDELog -Message "Assigned policy [$PolicyName] to group [$GroupName]"

        return New-MDEPolicyResult `
            -Name $PolicyName `
            -Status "Assigned" `
            -Details "Assigned to group: $GroupName"
    }
    catch {
        $detail = Get-MDEErrorDetail -ErrorRecord $_

        Write-MDELog -Level ERROR -Message "Failed assigning policy [$PolicyName] to [$GroupName]: $detail"

        return New-MDEPolicyResult `
            -Name $PolicyName `
            -Status "Failed" `
            -Details $detail
    }
}

function Add-MDEAssignmentFromConfig {
    param(
        [Parameter(Mandatory)]
        [string]$PolicyFriendlyName
    )

    $config = Get-MDEAssignmentConfig

    if (-not $config) {
        return New-MDEPolicyResult `
            -Name $PolicyFriendlyName `
            -Status "Skipped" `
            -Details "No Assignments\assignments.json file found"
    }

    $policyDisplayName = Get-MDEPolicyName -Name $PolicyFriendlyName
    $groupName = $null

    if ($config.policies -and ($config.policies.PSObject.Properties.Name -contains $PolicyFriendlyName)) {
        $groupName = $config.policies.$PolicyFriendlyName
    }
    elseif ($config.defaultGroupName) {
        $groupName = $config.defaultGroupName
    }

    if ([string]::IsNullOrWhiteSpace($groupName)) {
        return New-MDEPolicyResult `
            -Name $policyDisplayName `
            -Status "Skipped" `
            -Details "No assignment group configured"
    }

    Add-MDEConfigPolicyAssignment `
        -PolicyName $policyDisplayName `
        -GroupName $groupName
}

Export-ModuleMember -Function @(
    'Get-MDEAssignmentConfig',
    'Get-MDEGroupIdByName',
    'Get-MDEConfigPolicyIdByName',
    'Add-MDEConfigPolicyAssignment',
    'Add-MDEAssignmentFromConfig'
)
