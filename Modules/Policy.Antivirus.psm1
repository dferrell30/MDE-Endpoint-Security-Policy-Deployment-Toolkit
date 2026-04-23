function New-MDEAntivirusPolicy {
    $jsonPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Config\antivirus.json'

    if (-not (Test-Path -LiteralPath $jsonPath)) {
        $displayName = Get-DisplayName "Antivirus"
        return New-MDEPolicyResult -Name $displayName -Status "Info" -Details "Missing JSON file: $jsonPath"
    }

    try {
        $raw = Get-Content -LiteralPath $jsonPath -Raw
        $bodyObject = $raw | ConvertFrom-Json
        $body = ConvertTo-MDEHashtable -InputObject $bodyObject

        Invoke-CreateConfigPolicy -Name "Antivirus" -Body $body
    }
    catch {
        $displayName = Get-DisplayName "Antivirus"
        return New-MDEPolicyResult -Name $displayName -Status "Failed" -Details $_.Exception.Message
    }
}

Export-ModuleMember -Function 'New-MDEAntivirusPolicy'
