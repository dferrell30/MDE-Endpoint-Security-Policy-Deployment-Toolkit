function New-MDEApplicationControlPolicy {
    Invoke-CreateTemplatePolicy `
        -Name "Application Control" `
        -TemplateId "63be6324-e3c9-4c97-948a-e7f4b96f0f20"
}

Export-ModuleMember -Function 'New-MDEApplicationControlPolicy'
