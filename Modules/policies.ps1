$Prefix = "MDE"

function New-Policy {
    param($Name,$Template)

    try {
        $body = @{
            displayName = "$Prefix - $Name"
            description = "Created via deployment tool"
        } | ConvertTo-Json

        $uri = "https://graph.microsoft.com/beta/deviceManagement/templates/$Template/createInstance"
        $res = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body

        return @{
            Name = $Name
            Status = "Success"
            Details = "Created ($($res.id))"
        }
    } catch {
        return @{
            Name = $Name
            Status = "Failed"
            Details = $_.Exception.Message
        }
    }
}

function New-MDEAntivirusPolicy {
    New-Policy "Antivirus" "antivirus-template-id"
}

function New-MDESecurityExperiencePolicy {
    New-Policy "Windows Security Experience" "securityExperience-template-id"
}

function New-MDEASRPolicy {
    New-Policy "ASR" "asr-template-id"
}

function New-MDEEDRPolicy {
    New-Policy "EDR" "edr-template-id"
}

function New-MDEFirewallPolicy {
    New-Policy "Firewall" "firewall-template-id"
}

function New-MDEAppControlPolicy {
    New-Policy "Application Control" "appcontrol-template-id"
}
