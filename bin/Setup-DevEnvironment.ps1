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

# List of developer tools with specific versions to install/upgrade
$tools = @{

    # General developer tools
    'git' = '2.42.0'

    # IDEs
    'intellijidea-community' = '2023.2.3'
    'R.Studio' = '2023.9.1'

    # For comapring files
    'meld' = '3.22.0'

    # For unziping files
    'winscp' = '6.1.2'

    # for testing APIs
    'postman' = '10.18.10'

    'terraform' = '1.6.2'

    # Java Lanuage
    'openjdk' = '17.0.2'
    'maven' = '3.9.5'

    # Scala Language
    'scala.install' = '2.11.4'

    # NodeJS Language
    'nodejs' = '21.1.0'

    # R Language
    'r' = '4.3.1'

    # required for git code signing
    'Gpg4win' = '4.2.0'


    # Database tools
    'SQLite' = '3.43.2' # or the latest version
    'dbeaver' = '23.2.1' # or the latest version you want



    'powerbi' = '2.122.746.0' # If you use PowerBI for visualization
    'tableau-public' = '2023.3.0'
}

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
                choco upgrade $tool.Name --version $tool.Value -y --force
            }
        } else {
            Write-Host "Installing $($tool.Name) version $($tool.Value)..."
            choco install $tool.Name --version $tool.Value -y
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
