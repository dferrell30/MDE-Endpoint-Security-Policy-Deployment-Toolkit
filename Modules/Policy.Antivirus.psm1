function New-MDEAntivirusPolicy {
    Clone-MDEConfigPolicy `
        -SourcePolicyName $script:SourceAntivirusPolicyName `
        -NewShortName "Antivirus"
}

Export-ModuleMember -Function 'New-MDEAntivirusPolicy'
