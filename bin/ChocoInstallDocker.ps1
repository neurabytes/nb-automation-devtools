# Function to check if running as an administrator
function Test-IsAdmin {
    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    return $admin
}

# Check for admin rights
if (-not (Test-IsAdmin)) {
    Write-Host "Please run this script as an Administrator!" -ForegroundColor Red
    return
}


function CheckWindowsEdition {
    # Initialize variable for Windows edition
    $windowsEdition = $null

    # First try using Get-CimInstance
    try {
        $windowsEdition = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    } catch {
        Write-Host "Failed using Get-CimInstance. Trying Get-WmiObject..."
    }

    # If the previous method failed, try using Get-WmiObject
    if (-not $windowsEdition) {
        try {
            $windowsEdition = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        } catch {
            Write-Host "Failed using both Get-CimInstance and Get-WmiObject."
            return $false, "We could not identify the Windows version, so no."
        }
    }

    # Check if the edition is Pro or Enterprise
    $isProOrEnterprise = $windowsEdition -match 'Pro|Enterprise'

    # Provide feedback to the user
    if ($isProOrEnterprise) {
        return $true, "You have a Windows edition ($windowsEdition) that supports Hyper-V and Containers."
    } else {
        return $false, "You have $windowsEdition, which doesn't natively support Hyper-V. Consider upgrading to Pro or Enterprise edition."
    }
}


function CheckHyperVAvailability {
    $hyperVStates = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq 'Microsoft-Hyper-V' -or $_.FeatureName -eq 'Microsoft-Hyper-V-All' }

    if (-not $hyperVStates) {
        return $false, "We couldn't determine the Hyper-V status on your system."
    }

    $isHyperVEnabled = ($hyperVStates | Where-Object { $_.State -eq 'Enabled' }).Count -gt 0

    if ($isHyperVEnabled) {
        return $true, "Hyper-V is available and enabled on your system."
    } else {
        return $false, "Hyper-V is either unavailable or not enabled on your system."
    }
}


function CheckVirtualizationEnabled {
    $virtualizationEnabled = (Get-ComputerInfo).HyperVisorPresent

    if ($virtualizationEnabled) {
        return $true, "Hardware-assisted virtualization is enabled on your system."
    } else {
        return $false, "Hardware-assisted virtualization is not enabled. Please restart your computer, enter BIOS/UEFI settings, and enable virtualization. Consult your computer's manual or manufacturer for guidance."
    }
}


function CheckWSL2Supported {
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Build -lt 18362) {
        $message = "Your current Windows version does not support WSL 2. Please update Windows."
        return $false, $message
    }

    $message = "Your current Windows version supports WSL 2."
    return $true, $message
}


function CheckWSLInstalled {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    if ($wslFeature.State -eq 'Enabled') {
        return $true, "WSL is installed."
    }

    return $false, "WSL is not installed."
}


function EnableHyperVWithConsent {
    # Get user's consent
    $userConsent = $null
    while ($userConsent -notmatch '^[yn]$') {
        $userConsent = Read-Host "Would you like to enable Hyper-V? (Y/N)"
        $userConsent = $userConsent.ToLower()
    }

    # If user gives consent, enable Hyper-V
    if ($userConsent -eq 'y') {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
        Write-Host "Hyper-V is now being enabled. You might need to restart your computer to complete the process."
    } else {
        Write-Host "Hyper-V enablement aborted by the user."
    }
}


function InstallWSLWithConsent {
    $IsWSLInstalled, $isWSLInstallReason = CheckWSLInstalled

    if (-not $IsWSLInstalled) {
        Write-Host "WSL is not installed because: $isWSLInstallReason"
        $consent = Read-Host "Would you like to install WSL? (yes/no)"

        if ($consent -eq "yes") {
            Write-Host "Installing WSL..."

            # Install the WSL feature
            Start-Process -Verb runas powershell -ArgumentList "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"

            # After this step, you may want to prompt the user to restart their PC
            # as enabling WSL often requires a restart.
            # Once restarted, you can then proceed to install a Linux distribution.
            Write-Host "WSL installation initiated. Please follow the prompts. Restart your computer if necessary."

        } else {
            Write-Host "WSL installation aborted by the user."
        }
    } else {
        Write-Host "WSL is already installed."
    }
}


function SetDefaultWSL2WithConsent {
    # Assuming the CheckWSLInstalled and CheckWSL2Supported functions are defined elsewhere
    $IsWSLInstalled, $isWSLInstallReason = CheckWSLInstalled
    $IsWSL2Supported, $WSL2SupportedReason = CheckWSL2Supported

    # Check if WSL is installed
    if (-not $IsWSLInstalled) {
        Write-Host "WSL is not installed. Reason: $isWSLInstallReason" -ForegroundColor Red
        return
    }

    # Check if WSL 2 is supported
    if (-not $IsWSL2Supported) {
        Write-Host "WSL 2 is not supported. Reason: $WSL2SupportedReason" -ForegroundColor Red
        return
    }

    # Ask user for consent
    $userConsent = Read-Host "Do you want to set WSL default version to 2? (yes/no)"

    if ($userConsent -ne "yes") {
        Write-Host "Operation cancelled by the user." -ForegroundColor Yellow
        return
    }

    # Try to set WSL default version to 2
    try {
        wsl --set-default-version 2
        Write-Host "WSL default version has been set to 2." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to set WSL default version to 2." -ForegroundColor Red
    }
}


function InstallDockerDesktopWithConsent {
    # Get user's consent
    $userConsent = $null
    while ($userConsent -notmatch '^[yn]$') {
        $userConsent = Read-Host "Would you like to install Docker Desktop? (Y/N)"
        $userConsent = $userConsent.ToLower()
    }

    # If user gives consent, proceed with Docker Desktop installation
    if ($userConsent -eq 'y') {
        Write-Host "Installing Docker Desktop..."

        try {
            Invoke-Command -ScriptBlock { choco install docker-desktop -y }
            Write-Host "Docker Desktop installed successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Error encountered while installing Docker Desktop: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Docker Desktop installation aborted by the user."
    }
}

function AddUserToDockerGroupWithConsent {

    # List all users
    $users = Get-LocalUser | Where-Object { $_.Enabled -eq $true } | Select-Object Name, Description

    $index = 1
    $users | ForEach-Object {
        Write-Host "$index. $($_.Name) - $($_.Description)"
        $index++
    }

    # Take input from the user for multiple selections
    $selection = Read-Host "Enter the numbers (separated by commas) of the users you want to add to the docker-users group"

    $selectedUsers = $selection -split ',' | ForEach-Object {
        $users[$_.Trim() - 1].Name
    }

    # Get the usernames from the current members of docker-users group
    $currentMembers = Get-LocalGroupMember -Group "docker-users" | ForEach-Object { $_.Name.Split('\')[-1] }

    # Identify users who will be removed
    $usersToRemove = $currentMembers | Where-Object { $selectedUsers -notcontains $_ }

    # Confirm the selection
    $confirmationMessage = "You selected $($selectedUsers -join ', ') to be added to the group."
    if ($usersToRemove.Count -gt 0) {
        $confirmationMessage += " The following users will be removed from the docker-users group: $($usersToRemove -join ', ')."
    }
    $confirmation = Read-Host "$confirmationMessage Do you want to proceed? (yes/no)"

    if ($confirmation -eq "yes") {
        # Remove users who were not selected
        $usersToRemove | ForEach-Object {
            Remove-LocalGroupMember -Group "docker-users" -Member $_
            Write-Host "Removed $_ from docker-users group." -ForegroundColor Red
        }

        # Add selected users
        $selectedUsers | ForEach-Object {
            if ($currentMembers -contains $_) {
                Write-Host "$_ is already a member of the docker-users group."
            } else {
                try {
                    Add-LocalGroupMember -Group "docker-users" -Member $_
                    Write-Host "Added $_ to docker-users group." -ForegroundColor Green
                } catch {
                    Write-Error "An error occurred: $_"
                }
            }
        }

        Write-Host "Please restart your computer to complete the process."

    } else {
        Write-Host "Operation cancelled."
    }
}



function CanInstallDocker {
    $isProOrEnterprise, $isProOrEnterpriseReason = CheckWindowsEdition
    $hyperVAvailable, $hyperVAvailableReason = CheckHyperVAvailability
    $virtualizationEnabled, $virtualizationEnabledReason = CheckVirtualizationEnabled
    $IsWSLInstalled, $isWSLInstallReason = CheckWSLInstalled
    $IsWSL2Supported, $WSL2SupportedReason = CheckWSL2Supported

    $results = @(
    $isProOrEnterpriseReason,
    $hyperVAvailableReason,
    $virtualizationEnabledReason,
    $isWSLInstallReason,
    $WSL2SupportedReason
    )

    $canInstall = ($isProOrEnterprise -and ($hyperVAvailable -or $virtualizationEnabled)) -or ($virtualizationEnabled)

    $complete_result = $results -join " "

    # Determine message and color
    if ($canInstall) {
        $message = "You can install Docker because $complete_result"
        $color = "Green"
    } else {
        $message = "You cannot install Docker because $complete_result"
        $color = "Red"
    }

    # Write colored output
    Write-Host $message -ForegroundColor $color

    return $canInstall
}



function InstallOrUninstallDockerAndDependencies {

    $canInstall = CanInstallDocker

    # If Docker can't be installed, exit early
    if (-not $canInstall) {
        Write-Host "You cannot install Docker based on your system's requirements. Exiting." -ForegroundColor Red
        return
    }

    # Get user input for the desired action
    $userChoice = $null
    while ($null -eq $userChoice) {
        $userChoice = Read-Host "Do you want to install or uninstall Docker? (install/uninstall)"
        if ($userChoice -ne "install" -and $userChoice -ne "uninstall") {
            Write-Host "Invalid choice. Please select 'install' or 'uninstall'."
            $userChoice = $null
        }
    }

    # Perform action based on user choice
    switch ($userChoice) {
        "install" {
            # Check the Windows edition to decide whether to prompt for Hyper-V and WSL
            $isProOrEnterprise, $isProOrEnterpriseReason = CheckWindowsEdition

            if ($isProOrEnterprise) {
                EnableHyperVWithConsent
                InstallWSLWithConsent
                SetDefaultWSL2WithConsent
            }
            else {
                # For Home editions, just ensure WSL 2 is set up
                InstallWSLWithConsent
                SetDefaultWSL2WithConsent
            }

            InstallDockerDesktopWithConsent
            AddUserToDockerGroupWithConsent
        }
        "uninstall" {
            UninstallDockerDesktop
        }
    }
}


InstallOrUninstallDockerAndDependencies