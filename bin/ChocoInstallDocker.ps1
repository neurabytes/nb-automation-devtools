function CanInstallDocker {
    # Check Windows Edition
    $windowsEdition = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    $isProOrEnterprise = $windowsEdition -match 'Pro|Enterprise'

    # Check Hyper-V Availability
    $hyperVAvailable = $false
    $hyperVState = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -like 'Hyper-V*'
    if ($hyperVState.State -eq 'Enabled') {
        $hyperVAvailable = $true
    }

    # Check for Hardware-Assisted Virtualization
    $virtualizationEnabled = (Get-ComputerInfo).HyperVisorPresent

    # Generate Results
    $results = @()

    if ($isProOrEnterprise) {
        $results += "You have a Windows edition ($windowsEdition) that supports Hyper-V and Containers."
    } else {
        $results += "You have $windowsEdition, which doesn't natively support Hyper-V. Consider upgrading to Pro or Enterprise edition."
    }

    if (-not $hyperVAvailable) {
        $results += "Hyper-V is either unavailable or not enabled on your system."

        # Asking user for consent to enable Hyper-V
        $userConsent = $null
        while ($userConsent -notmatch '^[yn]$') {
            $userConsent = Read-Host "Would you like to enable Hyper-V? (Y/N)"
            $userConsent = $userConsent.ToLower()
        }

        if ($userConsent -eq 'y') {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
            $hyperVAvailable = $true
            $results += "Hyper-V is now being enabled. You might need to restart your computer to complete the process."
        }
    } else {
        $results += "Hyper-V is available and enabled on your system."
    }

    if ($virtualizationEnabled) {
        $results += "Hardware-assisted virtualization is enabled on your system."
    } else {
        $results += "Hardware-assisted virtualization is not enabled. Please restart your computer, enter BIOS/UEFI settings, and enable virtualization. Consult your computer's manual or manufacturer for guidance."
    }

    $canInstall = $isProOrEnterprise -and $hyperVAvailable -and $virtualizationEnabled
    $outputObj = [PSCustomObject]@{
        Reasoning = $results -join " "
        CanInstallDocker = $canInstall
    }

    return $outputObj
}

# To use the function:
$result = CanInstallDocker
Write-Output $result.Reasoning
Write-Output ("Can I install Docker? " + $result.CanInstallDocker)
