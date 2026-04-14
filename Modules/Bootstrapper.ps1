Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-MDEDeployment {
    $requiredModules = @(
        'Microsoft.Graph.Authentication'
    )

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Install-Module -Name $module -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
        }
    }

    Import-Module Microsoft.Graph.Authentication -Force

    $ctx = $null
    try {
        $ctx = Get-MgContext
    }
    catch {
        $ctx = $null
    }

    if (-not $ctx) {
        Connect-MgGraph -Scopes @(
            'DeviceManagementConfiguration.ReadWrite.All',
            'DeviceManagementManagedDevices.Read.All',
            'DeviceManagementServiceConfig.ReadWrite.All',
            'Directory.Read.All',
            'Policy.Read.All'
        ) -NoWelcome
    }

    Select-MgProfile -Name 'beta'

    $ctx = Get-MgContext
    if (-not $ctx) {
        throw "Failed to connect to Microsoft Graph."
    }

    return $ctx
}

Export-ModuleMember -Function Initialize-MDEDeployment

