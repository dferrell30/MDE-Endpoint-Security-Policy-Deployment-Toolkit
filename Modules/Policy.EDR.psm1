Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-MDEEDRPolicy {
    [CmdletBinding()]
    param()

    try {
        # Graph template subtype spelling follows the API, not the UI wording.
        $policy = New-MDEPolicyFromTemplate `
            -PolicyName 'EDR' `
            -Description 'Endpoint Detection and Response policy created by deployment tool.' `
            -TemplateSubtype 'endpointDetectionReponse'

        New-MDELogObject -Name 'EDR' -Status 'Success' -Details 'Policy shell created. Configure connector/package options in tenant if required.' -PolicyId $policy.id
    }
    catch {
        New-MDELogObject -Name 'EDR' -Status 'Failed' -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function New-MDEEDRPolicy
