# This function checks if the tools.json file exists and deletes it if it does
function CheckAndDeleteToolsJson {
    $toolsJsonPath = "tools.json"

    if (Test-Path -Path $toolsJsonPath) {
        Write-Host "tools.json exists. Deleting the file."
        Remove-Item -Path $toolsJsonPath -Force
    } else {
        Write-Host "tools.json does not exist."
    }
}

# Function to check if running as an administrator
function Test-IsAdmin {
    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    return $admin
}

# Function to manage the state file
function Get-StateFilePath {
    $stateDir = "C:\ProgramData\nb-automation"
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    return Join-Path $stateDir "installed_tools_state.json"
}

function Get-PreviousState {
    $stateFilePath = Get-StateFilePath
    if (Test-Path $stateFilePath) {
        try {
            return Get-Content $stateFilePath -Raw | ConvertFrom-Json
        } catch {
            Write-Host "Warning: Could not read state file. Creating new state." -ForegroundColor DarkYellow
            return $null
        }
    }
    return $null
}

function Save-CurrentState {
    param(
        [string]$selectedRole,
        [hashtable]$installedTools
    )
    
    $stateFilePath = Get-StateFilePath
    $newState = @{
        last_role = $selectedRole
        last_install_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        installed_tools = $installedTools
    }
    
    try {
        $newState | ConvertTo-Json -Depth 3 | Set-Content $stateFilePath -Encoding UTF8
        Write-Host "State saved to: $stateFilePath" -ForegroundColor DarkGreen
    } catch {
        Write-Host "Warning: Could not save state file: $_" -ForegroundColor DarkYellow
    }
}

function Set-YellowBackgroundBlackText {
    $script:originalBackgroundColor = $Host.UI.RawUI.BackgroundColor
    $script:originalForegroundColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.BackgroundColor = "White"
    $Host.UI.RawUI.ForegroundColor = "Black"
    Clear-Host
}

function Ensure-ChocolateyInstalled {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

function Get-ToolsAndRoleSelection {
    # Download tools.json if it does not exist
    if (-not (Test-Path -Path "tools.json")) {
        Write-Host "Downloading tools.json..."
        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/tools.json' -OutFile 'tools.json'
    }

    # Read tools and ignore_checksum_tools from JSON file
    $jsonData = Get-Content -Raw -Path "tools.json" | ConvertFrom-Json

    # Display role selection menu
    Write-Host "Please select your role:" -ForegroundColor Black
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
    Write-Host "Selected role: $($jsonData.roles.$selectedRole.description)" -ForegroundColor DarkGreen

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

    return @{
        selectedRole = $selectedRole
        tools = $tools
        ignore_checksum_tools = $ignore_checksum_tools
        installedPackagesDetails = $installedPackagesDetails
    }
}

function Remove-ObsoleteTools {
    param(
        [Parameter(Mandatory = $true)]
        $previousState,
        [Parameter(Mandatory = $true)]
        $tools
    )

    Write-Host "Checking for tools that were removed from configuration..." -ForegroundColor Black

    # Find tools that were previously installed but not in current role
    $toolsToUninstall = @()
    foreach ($previousTool in $previousState.installed_tools.PSObject.Properties.Name) {
        if ($previousTool -notin $tools.Keys) {
            $toolsToUninstall += $previousTool
        }
    }

    if ($toolsToUninstall.Count -gt 0) {
        Write-Host "The following tools were removed from your role configuration and will be uninstalled:" -ForegroundColor DarkYellow
        $toolsToUninstall | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkYellow }

        $confirm = Read-Host "Proceed with uninstalling removed tools? (y/n)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            foreach ($tool in $toolsToUninstall) {
                Write-Host "Uninstalling removed tool: $tool" -ForegroundColor DarkRed
                choco uninstall $tool -y
            }
        }
    } else {
        Write-Host "No tools need to be removed." -ForegroundColor DarkGreen
    }
}


function Install-Or-Upgrade-Tools {
    param(
        [Parameter(Mandatory = $true)]
        $tools,
        [Parameter(Mandatory = $true)]
        $installedPackagesDetails,
        [Parameter(Mandatory = $true)]
        $ignore_checksum_tools
    )

    foreach ($tool in $tools.GetEnumerator()) {
        $installedDetail = $installedPackagesDetails | Where-Object { $_.Name -eq $tool.Name }

        if ($installedDetail) { # If package is installed
            if ($installedDetail.Version -eq $tool.Value) {
                Write-Host "$($tool.Name) is already at version $($tool.Value). Marking as managed by nb-automation." -ForegroundColor DarkGreen
            } else {
                Write-Host "Upgrading $($tool.Name) from version $($installedDetail.Version) to version $($tool.Value)..." -ForegroundColor Black
                if ($ignore_checksum_tools -contains $tool.Name) {
                    choco upgrade $tool.Name --version $tool.Value -y --force --ignore-checksums
                } else {
                    choco upgrade $tool.Name --version $tool.Value -y --force
                }
            }
        } else {
            Write-Host "Installing $($tool.Name) version $($tool.Value)..." -ForegroundColor Black

            if ($ignore_checksum_tools -contains $tool.Name) {
                choco install $tool.Name --version $tool.Value -y --ignore-checksums
            } else {
                choco install $tool.Name --version $tool.Value -y
            }
        }
    }
}

function Uninstall-SelectedTools {
    param(
        [Parameter(Mandatory = $true)]
        $tools,
        [Parameter(Mandatory = $true)]
        $installedPackagesDetails
    )

    foreach ($tool in $tools.GetEnumerator()) {
        $installedDetail = $installedPackagesDetails | Where-Object { $_.Name -eq $tool.Name }

        if ($installedDetail) { # If package is installed
            Write-Host "Uninstalling $($tool.Name) version $($installedDetail.Version)..." -ForegroundColor DarkRed
            choco uninstall $tool.Name -y
        } else {
            Write-Host "$($tool.Name) is not installed. No action taken." -ForegroundColor Black
        }
    }
}


function Update-ToolStateAndReport {
    param(
        [Parameter(Mandatory = $true)]
        $action,
        [Parameter(Mandatory = $true)]
        $tools,
        [Parameter(Mandatory = $true)]
        $selectedRole,
        [Parameter(Mandatory = $true)]
        $toolsAndRole
    )

    # Get a list of currently installed Chocolatey packages
    $updatedInstalledPackagesDetails = choco list --local-only -r | ForEach-Object {
        $parts = $_.Split('|')
        @{ Name = $parts[0]; Version = $parts[1] }
    }

    $tools = $toolsAndRole.tools

    $installedTools = @()
    $notInstalledTools = @()
    $userInstalledTools = @()

    # Build a set of tool names requested by this script
    $requestedToolNames = $tools.Keys

    # Build a set of installed package names for quick lookup
    $installedPackageNames = @($updatedInstalledPackagesDetails | ForEach-Object { $_.Name })

    foreach ($tool in $tools.GetEnumerator()) {
        if ($installedPackageNames -contains $tool.Name) {
            $installedTools += $tool.Name
        } else {
            $notInstalledTools += $tool.Name
        }
    }

    foreach ($pkgName in $installedPackageNames) {
        if ($tools.Keys -notcontains $pkgName) {
            $userInstalledTools += $pkgName
        }
    }

    # Save current state after install operation
    if ($action -eq "install") {
        $successfullyInstalledTools = @{}
        foreach ($tool in $installedTools) {
            $successfullyInstalledTools[$tool] = $tools[$tool]
        }
        Save-CurrentState -selectedRole $selectedRole -installedTools $successfullyInstalledTools
        Write-Host "Installation state saved for role: $selectedRole" -ForegroundColor Black
    } elseif ($action -eq "uninstall") {
        Save-CurrentState -selectedRole "" -installedTools @{}
        Write-Host "State cleared after uninstalling all tools." -ForegroundColor Black
    }

    return @{
        installedTools = $installedTools
        notInstalledTools = $notInstalledTools
        userInstalledTools = $userInstalledTools
    }
}


function Report-ToolStatus {
    param(
        [Parameter(Mandatory = $true)]
        $finalState
    )

    if ($finalState.installedTools.Count -gt 0) {
        Write-Host "Installed tools:" -ForegroundColor DarkGreen
        $finalState.installedTools | ForEach-Object { Write-Host $_ -ForegroundColor DarkGreen }
    }

    if ($finalState.notInstalledTools.Count -gt 0) {
        Write-Host "Tools not installed:" -ForegroundColor DarkRed
        $finalState.notInstalledTools | ForEach-Object { Write-Host $_ -ForegroundColor DarkRed }
    }

    if ($finalState.userInstalledTools.Count -gt 0) {
        Write-Host "The following tools are installed on your system but were not managed by this script:" -ForegroundColor DarkYellow
        $finalState.userInstalledTools | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkYellow }
        Write-Host "If you want these tools managed by this script, add them to your role configuration." -ForegroundColor DarkYellow
    }
}


# Main script
# This is to ensure that the tools.json file is not left behind after the script has completed
try {

    # Check for admin rights
    if (-not (Test-IsAdmin)) {
        Write-Host "Please run this script as an Administrator!" -ForegroundColor DarkRed
        return
    }

    Set-YellowBackgroundBlackText

    Ensure-ChocolateyInstalled

    # Download tools.json if it does not exist
    $toolsAndRole = Get-ToolsAndRoleSelection
    $selectedRole = $toolsAndRole.selectedRole
    $tools = $toolsAndRole.tools
    $ignore_checksum_tools = $toolsAndRole.ignore_checksum_tools
    $installedPackagesDetails = $toolsAndRole.installedPackagesDetails

    # Check previous state and handle removed tools
    $previousState = Get-PreviousState
    if ($previousState -and $previousState.installed_tools) {
        Remove-ObsoleteTools -previousState $previousState -tools $tools
    }

    $action = Read-Host "Enter desired action (install or uninstall)"

    if ($action -eq "install") {
        Install-Or-Upgrade-Tools -tools $tools -installedPackagesDetails $installedPackagesDetails -ignore_checksum_tools $ignore_checksum_tools
    } elseif ($action -eq "uninstall") {
        Uninstall-SelectedTools -tools $tools -installedPackagesDetails $installedPackagesDetails
    } else {
        Write-Host "Invalid action specified. Please enter either 'install' or 'uninstall'." -ForegroundColor DarkRed
    }

    # After the action blocks (install or uninstall), fetch the list of installed packages again
    $finalState = Update-ToolStateAndReport -action $action -tools $tools -selectedRole $selectedRole -toolsAndRole $toolsAndRole

    Report-ToolStatus -finalState $finalState

} catch {
    Write-Host "An error occurred: $_" -ForegroundColor DarkRed
} finally {
    CheckAndDeleteToolsJson
}
