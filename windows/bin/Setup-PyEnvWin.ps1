# Enforce TLS 1.2+ for all downloads in this script
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Function to check if running as an administrator
function Test-IsAdmin {
    $admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    return $admin
}

# Check for admin rights
if (Test-IsAdmin) {
    Write-Host "Please run this script as a non Administrator!" -ForegroundColor Red
    return
}

function Get-UserProfiles {
    $userDirectories = Get-ChildItem 'C:\Users\' | Where-Object { $_.PSIsContainer } | ForEach-Object { $_.Name }
    return $userDirectories
}

function Select-UserProfile {
    $profiles = Get-UserProfiles
    $i = 1
    $profiles | ForEach-Object {
        Write-Host "[$i] $_"
        $i++
    }

    $selection = 0
    while ($selection -lt 1 -or $selection -gt $profiles.Length) {
        $input = Read-Host "Please select a user profile by number (1-$($profiles.Length))"
        if ($input -match '^\d+$') {
            $selection = [int]$input
        }
    }

    return "C:\Users\" + $profiles[$selection-1]
}

function ConfirmUserProfile {
    $userProfileConfirmed = $false
    while (-not $userProfileConfirmed) {
        $userProfile = Select-UserProfile
        $confirmProfile = Read-Host -Prompt "You've selected the profile path: $userProfile. Is this correct? (yes/no)"

        if ($confirmProfile -eq "yes") {
            $userProfileConfirmed = $true
        }
    }
    return $userProfile
}

function CloneOrUpdatePyEnv {
    if (Test-Path $pyenvPath) {
        $overwrite = Read-Host -Prompt "$pyenvPath already exists. Do you want to overwrite it? (yes/no)"

        if ($overwrite -eq 'yes') {
            Write-Host "Removing existing directory..."
            Remove-Item -Path $pyenvPath -Recurse -Force
            Write-Host "Cloning pyenv-win to $pyenvPath..."
            $cloneOutput = git clone https://github.com/pyenv-win/pyenv-win.git $pyenvPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: Failed to clone pyenv-win repository: $cloneOutput" -ForegroundColor Red
                return
            }
        } else {
            Write-Host "Skipped cloning pyenv-win since directory already exists and overwrite was not chosen."
        }
    } else {
        Write-Host "Cloning pyenv-win to $pyenvPath..."
        $cloneOutput = git clone https://github.com/pyenv-win/pyenv-win.git $pyenvPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to clone pyenv-win repository: $cloneOutput" -ForegroundColor Red
            return
        }
    }
}


function AddToUserPath {
    param (
        [string]$pathToAdd
    )

    # Get the current PATH
    $currentPath = [System.Environment]::GetEnvironmentVariable('path', "User")

    # Split into individual paths
    $paths = $currentPath -split ';'

    # Remove the path if it already exists
    $paths = $paths | Where-Object { $_ -ne $pathToAdd }

    # Add the path back in at the start
    $newPath = $pathToAdd + ';' + ($paths -join ';')

    # Set the new PATH
    [System.Environment]::SetEnvironmentVariable('path', $newPath, "User")
}

function RemoveFromUserPath {
    param (
        [string]$pathToRemove
    )

    # Get the current PATH
    $currentPath = [System.Environment]::GetEnvironmentVariable('path', "User")

    # Split into individual paths
    $paths = $currentPath -split ';'

    # Remove the path using exact match (case-insensitive)
    $newPath = ($paths | Where-Object { $_ -ne $pathToRemove }) -join ';'

    # Set the new PATH
    [System.Environment]::SetEnvironmentVariable('path', $newPath, "User")
}

function Invoke-SetupCredentials {
    param(
        [string]$PythonExe = "python"
    )

    $answer = Read-Host -Prompt "Do you also want to set up the credentials now? (yes/no)"
    if ($answer -ne "yes") {
        Write-Host "Skipping credentials setup."
        return
    }

    $url = "https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/devtools/setup_credentials.py"
    $tmpFile = Join-Path $env:TEMP ("nb_setup_credentials_{0}.py" -f ([Guid]::NewGuid().ToString("N")))

    try {
        Write-Host "Downloading credentials setup script from $url ..."
        Invoke-WebRequest -Uri $url -OutFile $tmpFile

        Write-Host "Running credentials setup script with $PythonExe ..."
        & $PythonExe $tmpFile
    }
    catch {
        Write-Error "Failed to download or run credentials setup script: $_"
    }
    finally {
        if (Test-Path $tmpFile) {
            Remove-Item $tmpFile -Force
        }
    }
}



$pyenvPath = $env:USERPROFILE + "\.pyenv\pyenv-win\"

$action = Read-Host -Prompt "Please choose an action (install/uninstall)"

if ($action -eq "install") {


    $userProfile = ConfirmUserProfile

    # Defining the .pyenv path based on the user's input
    $pyenvPath = "$userProfile\.pyenv"

    cloneOrUpdatePyEnv

    # Get the location of powershell.exe
    $powershellPath = (Get-Command powershell).Source


    # Set the PYENV variables
    [System.Environment]::SetEnvironmentVariable('PYENV', $pyenvPath, "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_ROOT', $pyenvPath, "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_HOME', $pyenvPath, "User")
    [System.Environment]::SetEnvironmentVariable('PIPENV_SHELL', $powershellPath, "User")

    # Add the necessary paths to PATH variable
    AddToUserPath ($env:USERPROFILE + "\.pyenv\pyenv-win\bin")
    AddToUserPath ($env:USERPROFILE + "\.pyenv\pyenv-win\shims")

    Import-Module $env:ChocolateyInstall\helpers\ChocolateyProfile.psm1
    refreshenv

    pyenv install 3.11.9
    pyenv global 3.11.9

    refreshenv
    python --version
    pip install pipenv
    pip install pre-commit
    pip install rich
    pyenv rehash

    $pythonCmd = (Get-Command python).Source
    Invoke-SetupCredentials -PythonExe $pythonCmd

    Write-Output "Installation is done. Hurray!"
}
elseif ($action -eq "uninstall") {
    # Remove the PYENV variables
    [System.Environment]::SetEnvironmentVariable('PYENV', $null, "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_ROOT', $null, "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_HOME', $null, "User")
    [System.Environment]::SetEnvironmentVariable('PIPENV_SHELL', $null, "User")

    # Remove the paths from PATH variable
    RemoveFromUserPath ("\.pyenv\pyenv-win\bin")
    RemoveFromUserPath ("\.pyenv\pyenv-win\shims")

    $userProfile = ConfirmUserProfile

    # Defining the .pyenv path based on the user's input
    $pyenvPath = "$userProfile\.pyenv"

    # Remove the pyenv directory if it exists
    if (Test-Path $pyenvPath) {
        Write-Host "Removing $pyenvPath directory..."
        Remove-Item -Path $pyenvPath -Recurse -Force
    }

    Write-Output "Uninstallation is done."
}
else {
    Write-Error "Invalid action selected. Please choose 'install' or 'uninstall'."
}
