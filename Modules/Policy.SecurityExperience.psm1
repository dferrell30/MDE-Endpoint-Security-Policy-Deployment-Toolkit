function New-MDESecurityExperiencePolicy {
    $displayName = Get-DisplayName "Windows Security Experience"
    return New-MDEPolicyResult -Name $displayName -Status "Info" -Details "Not creating this yet. Leave this for the final pass."
}

Export-ModuleMember -Function 'New-MDESecurityExperiencePolicy'
