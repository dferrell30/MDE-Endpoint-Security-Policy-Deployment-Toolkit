function Invoke-MDEBootstrap {

    if (-not (Get-Module -ListAvailable Microsoft.Graph)) {
        Install-Module Microsoft.Graph -Scope CurrentUser -Force
    }

    Import-Module Microsoft.Graph

    Connect-MgGraph -Scopes @(
        "DeviceManagementConfiguration.ReadWrite.All",
        "Directory.Read.All"
    )

    Select-MgProfile beta
}
