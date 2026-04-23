Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

Import-Module "$PSScriptRoot\Modules\Bootstrapper.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.EDR.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.ApplicationControl.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.ASR.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.Antivirus.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.Firewall.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\Modules\Policy.SecurityExperience.psm1" -Force -DisableNameChecking

$colorFormBg   = [System.Drawing.Color]::FromArgb(24,28,34)
$colorCardBg   = [System.Drawing.Color]::FromArgb(31,36,43)
$colorButtonBg = [System.Drawing.Color]::FromArgb(34,39,46)
$colorBorder   = [System.Drawing.Color]::FromArgb(68,74,83)
$colorAccent   = [System.Drawing.Color]::FromArgb(98,114,164)
$colorText     = [System.Drawing.Color]::FromArgb(240,240,240)
$colorMuted    = [System.Drawing.Color]::FromArgb(188,188,188)
$colorLogBg    = [System.Drawing.Color]::FromArgb(19,22,27)

$fontTitle  = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontText   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

function New-SectionPanel {
    param(
        [string]$Title,
        [int]$PanelX,
        [int]$PanelY,
        [int]$PanelWidth,
        [int]$PanelHeight
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($PanelX,$PanelY)
    $panel.Size = New-Object System.Drawing.Size($PanelWidth,$PanelHeight)
    $panel.BackColor = $colorCardBg
    $panel.BorderStyle = 'FixedSingle'

    if ($Title) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Title
        $label.Font = $fontHeader
        $label.ForeColor = $colorMuted
        $label.AutoSize = $true
        $label.Location = New-Object System.Drawing.Point(14,10)
        $panel.Controls.Add($label)

        $line = New-Object System.Windows.Forms.Panel
        $line.BackColor = $colorBorder
        $line.Size = New-Object System.Drawing.Size(([Math]::Max(40, $PanelWidth - 30)), 1)
        $line.Location = New-Object System.Drawing.Point(14,34)
        $panel.Controls.Add($line)
    }

    return $panel
}

function New-StyledButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height = 40,
        [bool]$Accent = $false
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X,$Y)
    $btn.Size = New-Object System.Drawing.Size($Width,$Height)
    $btn.BackColor = $colorButtonBg
    $btn.ForeColor = $colorText
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $(if ($Accent) { $colorAccent } else { $colorBorder })
    $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(42,48,57)
    $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(48,54,63)
    $btn.Font = $fontText
    $btn.UseVisualStyleBackColor = $false
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

function New-StyledCheckBox {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y
    )

    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $Text
    $chk.Location = New-Object System.Drawing.Point($X,$Y)
    $chk.AutoSize = $true
    $chk.Font = $fontText
    $chk.ForeColor = $colorText
    $chk.BackColor = $colorCardBg
    return $chk
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "MDE Endpoint Security Deployment Tool"
$form.Size = New-Object System.Drawing.Size(1000, 800)
$form.MinimumSize = New-Object System.Drawing.Size(1000, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = $colorFormBg
$form.ForeColor = $colorText
$form.FormBorderStyle = 'Sizable'

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "MDE Endpoint Security Deployment Tool"
$titleLabel.Font = $fontTitle
$titleLabel.ForeColor = $colorText
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20,16)
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Endpoint Security policy deployment using Microsoft Graph"
$subtitleLabel.Font = $fontText
$subtitleLabel.ForeColor = $colorMuted
$subtitleLabel.AutoSize = $true
$subtitleLabel.Location = New-Object System.Drawing.Point(22,46)
$form.Controls.Add($subtitleLabel)

$btnInit = New-StyledButton -Text "Initialize Graph Connection" -X 20 -Y 84 -Width 300 -Height 42 -Accent $true
$btnCreateSelected = New-StyledButton -Text "Create Selected Policies" -X 340 -Y 84 -Width 300 -Height 42 -Accent $true
$btnCreateAll = New-StyledButton -Text "Create All Policies" -X 660 -Y 84 -Width 300 -Height 42
$form.Controls.AddRange(@($btnInit,$btnCreateSelected,$btnCreateAll))

$btnOpenLogs = New-StyledButton -Text "Open Logs Folder" -X 20 -Y 138 -Width 300 -Height 40
$btnClear = New-StyledButton -Text "Clear Results" -X 340 -Y 138 -Width 300 -Height 40
$btnExit = New-StyledButton -Text "Exit" -X 660 -Y 138 -Width 300 -Height 40
$form.Controls.AddRange(@($btnOpenLogs,$btnClear,$btnExit))

$policyPanel = New-SectionPanel -Title "POLICY SELECTION" -PanelX 20 -PanelY 200 -PanelWidth 940 -PanelHeight 130
$form.Controls.Add($policyPanel)

$chkAV = New-StyledCheckBox -Text "Antivirus" -X 20 -Y 50
$chkSec = New-StyledCheckBox -Text "Windows Security Experience" -X 170 -Y 50
$chkASR = New-StyledCheckBox -Text "Attack Surface Reduction" -X 420 -Y 50
$chkEDR = New-StyledCheckBox -Text "Endpoint Detection and Response" -X 650 -Y 50

$chkFW = New-StyledCheckBox -Text "Firewall" -X 20 -Y 82
$chkApp = New-StyledCheckBox -Text "Application Control" -X 170 -Y 82

$policyPanel.Controls.AddRange(@($chkAV,$chkSec,$chkASR,$chkEDR,$chkFW,$chkApp))

$statusPanel = New-SectionPanel -Title "CURRENT STATUS" -PanelX 20 -PanelY 346 -PanelWidth 940 -PanelHeight 110
$form.Controls.Add($statusPanel)

$lblConnection = New-Object System.Windows.Forms.Label
$lblConnection.Text = "Status: Not Connected"
$lblConnection.Font = $fontHeader
$lblConnection.ForeColor = $colorText
$lblConnection.AutoSize = $true
$lblConnection.Location = New-Object System.Drawing.Point(16,46)
$statusPanel.Controls.Add($lblConnection)

$lblMode = New-Object System.Windows.Forms.Label
$lblMode.Text = "Mode: Create policies only. No assignments are applied."
$lblMode.Font = $fontText
$lblMode.ForeColor = $colorMuted
$lblMode.AutoSize = $true
$lblMode.Location = New-Object System.Drawing.Point(16,72)
$statusPanel.Controls.Add($lblMode)

$resultPanel = New-SectionPanel -Title "POLICY RESULTS" -PanelX 20 -PanelY 472 -PanelWidth 940 -PanelHeight 180
$form.Controls.Add($resultPanel)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(16,42)
$listView.Size = New-Object System.Drawing.Size(908,124)
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.BackColor = $colorLogBg
$listView.ForeColor = $colorText
$listView.BorderStyle = 'FixedSingle'
$listView.Font = $fontText

[void]$listView.Columns.Add("Policy Name", 230)
[void]$listView.Columns.Add("Status", 95)
[void]$listView.Columns.Add("Details", 430)
[void]$listView.Columns.Add("Time", 140)

$resultPanel.Controls.Add($listView)

$logPanel = New-SectionPanel -Title "ACTIVITY LOG" -PanelX 20 -PanelY 668 -PanelWidth 940 -PanelHeight 80
$form.Controls.Add($logPanel)

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$statusBox.Size = New-Object System.Drawing.Size(908,36)
$statusBox.Location = New-Object System.Drawing.Point(16,38)
$statusBox.BackColor = $colorLogBg
$statusBox.ForeColor = $colorText
$statusBox.BorderStyle = 'FixedSingle'
$statusBox.Font = $fontText
$logPanel.Controls.Add($statusBox)

function Log {
    param([string]$Message)
    $statusBox.AppendText("$Message`r`n")
}

function Update-ConnectionLabel {
    try {
        $ctx = Get-MgContext

        if ($ctx -and $ctx.Account) {
            $tenantId = $ctx.TenantId
            $account = $ctx.Account

            $tenantText = $tenantId
            try {
                $org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization" -OutputType PSObject
                if ($org.value -and $org.value.Count -gt 0) {
                    if ($org.value[0].displayName) {
                        $tenantText = "$($org.value[0].displayName) ($tenantId)"
                    }
                }
            }
            catch {
                $tenantText = $tenantId
            }

            $lblConnection.Text = "Status: Connected to $tenantText as $account"
            $lblConnection.ForeColor = [System.Drawing.Color]::LightGreen
        }
        else {
            $lblConnection.Text = "Status: Not Connected"
            $lblConnection.ForeColor = $colorText
        }
    }
    catch {
        $lblConnection.Text = "Status: Not Connected"
        $lblConnection.ForeColor = $colorText
    }
}

function Add-ListRow {
    param($Result)

    $rowTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ($null -ne $Result -and $Result.PSObject.Properties['Time'] -and $Result.Time) {
        try { $rowTime = Get-Date -Date $Result.Time -Format 'yyyy-MM-dd HH:mm:ss' } catch {}
    }

    $item = New-Object System.Windows.Forms.ListViewItem([string]$Result.Name)
    [void]$item.SubItems.Add([string]$Result.Status)
    [void]$item.SubItems.Add([string]$Result.Details)
    [void]$item.SubItems.Add($rowTime)

    switch ([string]$Result.Status) {
        'Success' { $item.ForeColor = [System.Drawing.Color]::LightGreen }
        'Failed'  { $item.ForeColor = [System.Drawing.Color]::Tomato }
        'Skipped' { $item.ForeColor = [System.Drawing.Color]::Khaki }
        'Info'    { $item.ForeColor = [System.Drawing.Color]::LightBlue }
        default   { $item.ForeColor = $colorText }
    }

    [void]$listView.Items.Add($item)
}

function Invoke-SelectedPolicyCreation {
    $results = @()

    if ($chkAV.Checked)  {
        Log "[INFO] Creating Antivirus policy..."
        $results += New-MDEAntivirusPolicy
    }

    if ($chkSec.Checked) {
        Log "[INFO] Creating Windows Security Experience policy..."
        $results += New-MDESecurityExperiencePolicy
    }

    if ($chkASR.Checked) {
        Log "[INFO] Creating ASR policy..."
        $results += New-MDEASRPolicy
    }

    if ($chkEDR.Checked) {
        Log "[INFO] Creating EDR policy..."
        $results += New-MDEEDRPolicy
    }

    if ($chkFW.Checked)  {
        Log "[INFO] Creating Firewall policy..."
        $results += New-MDEFirewallPolicy
    }

    if ($chkApp.Checked) {
        Log "[INFO] Creating Application Control policy..."
        $results += New-MDEApplicationControlPolicy
    }

    return $results
}

function Run-PolicyCreation {
    try {
        $btnCreateSelected.Enabled = $false
        $btnCreateAll.Enabled = $false

        $listView.Items.Clear()
        Log "[INFO] Starting policy creation..."

        $results = Invoke-SelectedPolicyCreation

        foreach ($r in $results) {
            Add-ListRow -Result $r
            Log ("[{0}] {1} - {2}" -f $r.Status, $r.Name, $r.Details)
        }

        if (-not $results -or $results.Count -eq 0) {
            Log "[WARN] No policies selected."
        }
        else {
            $summary = $results | Group-Object Status | Sort-Object Name | ForEach-Object {
                "{0}: {1}" -f $_.Name, $_.Count
            }
            Log "[INFO] Summary: $($summary -join '; ')"
        }

        Log "[OK] Policy creation complete."
    }
    catch {
        Log "[ERR] Policy creation failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.ToString(),
            "Execution Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $btnCreateSelected.Enabled = $true
        $btnCreateAll.Enabled = $true
    }
}

$btnInit.Add_Click({
    try {
        $btnInit.Enabled = $false
        Log "[INFO] Initializing Microsoft Graph connection..."
        Initialize-MDEDeployment | Out-Null
        Update-ConnectionLabel
        Log "[OK] Microsoft Graph initialized."
    }
    catch {
        Log "[ERR] Initialization failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.ToString(),
            "Initialization Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $btnInit.Enabled = $true
    }
})

$btnCreateSelected.Add_Click({
    Run-PolicyCreation
})

$btnCreateAll.Add_Click({
    $chkAV.Checked = $true
    $chkSec.Checked = $true
    $chkASR.Checked = $true
    $chkEDR.Checked = $true
    $chkFW.Checked = $true
    $chkApp.Checked = $true
    Run-PolicyCreation
})

$btnOpenLogs.Add_Click({
    $logPath = Join-Path $PSScriptRoot 'Logs'
    if (-not (Test-Path -LiteralPath $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    Start-Process explorer.exe $logPath
})

$btnClear.Add_Click({
    $listView.Items.Clear()
    $statusBox.Clear()
    Log "[INFO] Results cleared."
})

$btnExit.Add_Click({
    $form.Close()
})

$form.Add_Shown({
    $form.Activate()
    Update-ConnectionLabel
    Log "[INFO] Tool ready."
})

[void]$form.ShowDialog()
