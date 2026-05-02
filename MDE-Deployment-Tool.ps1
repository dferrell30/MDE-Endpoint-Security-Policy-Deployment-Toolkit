#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

Import-Module "$PSScriptRoot\Modules\Common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.Json.psm1" -Force -DisableNameChecking

$script:Theme = @{
    Back      = [System.Drawing.Color]::FromArgb(18,18,24)
    Panel     = [System.Drawing.Color]::FromArgb(30,30,38)
    PanelAlt  = [System.Drawing.Color]::FromArgb(38,38,48)
    Button    = [System.Drawing.Color]::FromArgb(55,65,81)
    Accent    = [System.Drawing.Color]::FromArgb(0,120,215)
    Text      = [System.Drawing.Color]::White
    Muted     = [System.Drawing.Color]::FromArgb(200,200,210)
    Border    = [System.Drawing.Color]::FromArgb(70,70,85)
    Success   = [System.Drawing.Color]::FromArgb(22,101,52)
    Warning   = [System.Drawing.Color]::FromArgb(113,63,18)
    Error     = [System.Drawing.Color]::FromArgb(127,29,29)
    Info      = [System.Drawing.Color]::FromArgb(30,64,175)
}

function Add-Log {
    param([string]$Message)
    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
}

function New-DarkButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H
    )

    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X,$Y)
    $b.Size = New-Object System.Drawing.Size($W,$H)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $script:Theme.Button
    $b.ForeColor = $script:Theme.Text
    $b.FlatAppearance.BorderColor = $script:Theme.Border
    $b.FlatAppearance.MouseOverBackColor = $script:Theme.Accent
    return $b
}

function Set-ResultRowColor {
    param(
        [System.Windows.Forms.DataGridViewRow]$Row,
        [string]$Status
    )

    switch ($Status) {
        "Success" { $Row.DefaultCellStyle.BackColor = $script:Theme.Success }
        "Valid"   { $Row.DefaultCellStyle.BackColor = $script:Theme.Success }
        "WhatIf"  { $Row.DefaultCellStyle.BackColor = $script:Theme.Info }
        "Skipped" { $Row.DefaultCellStyle.BackColor = $script:Theme.Warning }
        "Missing" { $Row.DefaultCellStyle.BackColor = $script:Theme.Warning }
        "Info"    { $Row.DefaultCellStyle.BackColor = $script:Theme.Info }
        "Failed"  { $Row.DefaultCellStyle.BackColor = $script:Theme.Error }
        "Invalid" { $Row.DefaultCellStyle.BackColor = $script:Theme.Error }
        default   { $Row.DefaultCellStyle.BackColor = $script:Theme.PanelAlt }
    }

    $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
}

function Add-ResultRow {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details
    )

    $rowIndex = $gridResults.Rows.Add($Name,$Status,$Details)
    Set-ResultRowColor -Row $gridResults.Rows[$rowIndex] -Status $Status
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Microsoft Defender for Endpoint Deployment Tool"
$form.Size = New-Object System.Drawing.Size(1120,740)
$form.StartPosition = "CenterScreen"
$form.BackColor = $script:Theme.Back
$form.ForeColor = $script:Theme.Text
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Defender for Endpoint Deployment Tool"
$title.Location = New-Object System.Drawing.Point(20,15)
$title.Size = New-Object System.Drawing.Size(650,32)
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold",16,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = $script:Theme.Text
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "JSON-driven policy deployment with editable baselines and protected templates"
$subtitle.Location = New-Object System.Drawing.Point(22,48)
$subtitle.Size = New-Object System.Drawing.Size(720,24)
$subtitle.ForeColor = $script:Theme.Muted
$form.Controls.Add($subtitle)

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = "WhatIf / Validate only"
$chkWhatIf.Location = New-Object System.Drawing.Point(760,25)
$chkWhatIf.Size = New-Object System.Drawing.Size(180,24)
$chkWhatIf.ForeColor = $script:Theme.Text
$chkWhatIf.BackColor = $script:Theme.Back
$form.Controls.Add($chkWhatIf)

$btnInit = New-DarkButton "Initialize Graph" 940 20 140 34
$form.Controls.Add($btnInit)

$gridPolicies = New-Object System.Windows.Forms.DataGridView
$gridPolicies.Location = New-Object System.Drawing.Point(20,90)
$gridPolicies.Size = New-Object System.Drawing.Size(660,430)
$gridPolicies.BackgroundColor = $script:Theme.Panel
$gridPolicies.GridColor = $script:Theme.Border
$gridPolicies.ForeColor = $script:Theme.Text
$gridPolicies.DefaultCellStyle.BackColor = $script:Theme.PanelAlt
$gridPolicies.DefaultCellStyle.ForeColor = $script:Theme.Text
$gridPolicies.DefaultCellStyle.SelectionBackColor = $script:Theme.Accent
$gridPolicies.DefaultCellStyle.SelectionForeColor = $script:Theme.Text
$gridPolicies.ColumnHeadersDefaultCellStyle.BackColor = $script:Theme.Button
$gridPolicies.ColumnHeadersDefaultCellStyle.ForeColor = $script:Theme.Text
$gridPolicies.EnableHeadersVisualStyles = $false
$gridPolicies.RowHeadersVisible = $false
$gridPolicies.AllowUserToAddRows = $false
$gridPolicies.SelectionMode = 'FullRowSelect'
$gridPolicies.MultiSelect = $true
$gridPolicies.AutoSizeColumnsMode = 'Fill'

[void]$gridPolicies.Columns.Add("Name","Policy")
[void]$gridPolicies.Columns.Add("Category","Category")
[void]$gridPolicies.Columns.Add("JsonPath","JSON Path")
[void]$gridPolicies.Columns.Add("Exists","JSON Exists")

$form.Controls.Add($gridPolicies)

$gridResults = New-Object System.Windows.Forms.DataGridView
$gridResults.Location = New-Object System.Drawing.Point(700,90)
$gridResults.Size = New-Object System.Drawing.Size(380,250)
$gridResults.BackgroundColor = $script:Theme.Panel
$gridResults.GridColor = $script:Theme.Border
$gridResults.ForeColor = $script:Theme.Text
$gridResults.Default
