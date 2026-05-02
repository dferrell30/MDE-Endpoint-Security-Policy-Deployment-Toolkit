function New-MDEEDRPolicy {
    Invoke-CreateTemplatePolicy `
        -Name "EDR" `
        -TemplateId "e44c2ca3-2f9a-400a-a113-6cc88efd773d"
}

Export-ModuleMember -Function 'New-MDEEDRPolicy'
