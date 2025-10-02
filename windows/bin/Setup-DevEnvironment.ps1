# This function checks if the tools.json file exists and deletes it if it does
function CheckAndDeleteToolsJson {
    $toolsJsonPath = "tools.json"

    if (Test-Path -Path $toolsJsonPath) {
        Write-Host "tools.json exists. Deleting the file."
#        Remove-Item -Path $toolsJsonPath -Force
    } else {
        Write-Host "tools.json does not exist."
    }
}

# Function to check if running as an administrator
function Test-IsAdmin {
    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    return $admin
}

# Main script
# This is to ensure that the tools.json file is not left behind after the script has completed
try {

    # Check for admin rights
    if (-not (Test-IsAdmin)) {
        Write-Host "Please run this script as an Administrator!" -ForegroundColor Red
        return
    }

    # Change background color to yellow and text color to black
    $originalBackgroundColor = $Host.UI.RawUI.BackgroundColor
    $originalForegroundColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.BackgroundColor = "Yellow"
    $Host.UI.RawUI.ForegroundColor = "Black"
    Clear-Host


    # Ensure Chocolatey is installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    # Download tools.json if it does not exist
#    if (-not (Test-Path -Path "tools.json")) {
#        Write-Host "Downloading tools.json..."
#        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/tools.json' -OutFile 'tools.json'
#    }

    # Read tools and ignore_checksum_tools from JSON file
    $jsonData = Get-Content -Raw -Path "tools.json" | ConvertFrom-Json

    # Display role selection menu
    Write-Host "Please select your role:" -ForegroundColor Cyan
    $roleNames = @($jsonData.roles.PSObject.Properties.Name)
    for ($i = 0; $i -lt $roleNames.Length; $i++) {
        $roleName = $roleNames[$i]
        $roleDescription = $jsonData.roles.$roleName.description
        Write-Host "$($i + 1). $roleDescription" -ForegroundColor Black
    }
    
    # Get user selection
    do {
        $selection = Read-Host "Enter your choice (1-$($roleNames.Length))"
        $selectedIndex = [int]$selection - 1
    } while ($selectedIndex -lt 0 -or $selectedIndex -ge $roleNames.Length)
    
    $selectedRole = $roleNames[$selectedIndex]
    Write-Host "Selected role: $($jsonData.roles.$selectedRole.description)" -ForegroundColor Green

    # Get tools for selected role
    $tools = @{}
    foreach ($key in $jsonData.roles.$selectedRole.tools.PSObject.Properties.Name) {
        $tools[$key] = $jsonData.roles.$selectedRole.tools.$key
    }

    $ignore_checksum_tools = $jsonData.ignore_checksum_tools

    # Get a list of currently installed Chocolatey packages
    $installedPackagesDetails = choco list --local-only -r | ForEach-Object {
        $parts = $_.Split('|')
        @{ Name = $parts[0]; Version = $parts[1] }
    }


    $action = Read-Host "Enter desired action (install or uninstall)"

    if ($action -eq "install") {
        foreach ($tool in $tools.GetEnumerator()) {
            $installedDetail = $installedPackagesDetails | Where-Object { $_.Name -eq $tool.Name }

            if ($installedDetail) { # If package is installed
                if ($installedDetail.Version -eq $tool.Value) {
                    Write-Host "$($tool.Name) is already at version $($tool.Value). No action taken."
                } else {
                    Write-Host "Upgrading $($tool.Name) from version $($installedDetail.Version) to version $($tool.Value)..."
                    if ($ignore_checksum_tools -contains $tool.Name) {
                        choco upgrade $tool.Name --version $tool.Value -y --force --ignore-checksums
                    } else {
                        choco upgrade $tool.Name --version $tool.Value -y --force
                    }
                }
            } else {
                Write-Host "Installing $($tool.Name) version $($tool.Value)..."

                if ($ignore_checksum_tools -contains $tool.Name) {
                    choco install $tool.Name --version $tool.Value -y --ignore-checksums
                } else {
                    choco install $tool.Name --version $tool.Value -y
                }
            }
        }
    } elseif ($action -eq "uninstall") {
        foreach ($tool in $tools.GetEnumerator()) {
            $installedDetail = $installedPackagesDetails | Where-Object { $_.Name -eq $tool.Name }

            if ($installedDetail) { # If package is installed
                Write-Host "Uninstalling $($tool.Name) version $($installedDetail.Version)..."
                choco uninstall $tool.Name -y
            } else {
                Write-Host "$($tool.Name) is not installed. No action taken."
            }
        }
    } else {
        Write-Host "Invalid action specified. Please enter either 'install' or 'uninstall'."
    }

    # After the action blocks (install or uninstall), fetch the list of installed packages again
    $updatedInstalledPackagesDetails = choco list --local-only -r | ForEach-Object {
        $parts = $_.Split('|')
        @{ Name = $parts[0]; Version = $parts[1] }
    }

    $installedTools = @()
    $notInstalledTools = @()

    foreach ($tool in $tools.GetEnumerator()) {
        $updatedInstalledDetail = $updatedInstalledPackagesDetails | Where-Object { $_.Name -eq $tool.Name }

        if ($updatedInstalledDetail) {
            $installedTools += $tool.Name
        } else {
            $notInstalledTools += $tool.Name
        }
    }

    # Reporting
    if ($installedTools.Count -gt 0) {
        Write-Host "Installed tools:" -ForegroundColor Green
        $installedTools | ForEach-Object { Write-Host $_ -ForegroundColor Green }
    }

    if ($notInstalledTools.Count -gt 0) {
        Write-Host "Tools not installed:" -ForegroundColor Red
        $notInstalledTools | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
} catch {
    Write-Host "An error occurred: $_"
} finally {
    CheckAndDeleteToolsJson
}
