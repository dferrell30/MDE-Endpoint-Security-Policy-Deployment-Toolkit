function New-MDEFirewallPolicy {
    if ([string]::IsNullOrWhiteSpace($script:SourceFirewallPolicyName)) {
        $displayName = Get-DisplayName "Firewall"
        return New-MDEPolicyResult -Name $displayName -Status "Info" -Details "Set `$script:SourceFirewallPolicyName in Common.psm1 to the exact name of one working Firewall policy, then rerun."
    }

    Clone-MDEConfigPolicy `
        -SourcePolicyName $script:SourceFirewallPolicyName `
        -NewShortName "Firewall"
}

Export-ModuleMember -Function 'New-MDEFirewallPolicy'
