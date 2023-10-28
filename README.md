# Neurabytes Scripts for Development Setup

This repository contains two essential PowerShell scripts intended for developers:

1. `ChocoToolSetup.ps1`: Ensures that Chocolatey is installed and then facilitates the installation, upgrade, or uninstallation of a predefined list of developer tools.
2. `PyenvSetup.ps1`: Facilitates the installation or uninstallation of `pyenv-win` on Windows platforms.

## Prerequisites

- Windows Operating System
- PowerShell with administrative rights

## Usage

### Chocolatey Tools Setup Script (ChocoToolSetup.ps1)

This script ensures that Chocolatey is installed. After this verification, it will either install, upgrade, or uninstall a specified list of developer tools based on the versions provided in the script.

**To Run the Script Directly from GitHub:**

```powershell
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO_NAME/main/ChocoToolSetup.ps1')
```

### Pyenv Setup Script (`PyenvSetup.ps1`)

This script aids in setting up `pyenv-win` to manage Python versions on a Windows machine. It can both install and uninstall `pyenv-win`.

**To Run the Script Directly from GitHub:**

```powershell
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO_NAME/main/PyenvSetup.ps1')
```

##  Security Note
The PowerShell commands provided above pull scripts directly from the web and execute them. This can be risky if you're not entirely certain of the script's source or its content. Always ensure you trust the source and have inspected the script content before executing.

##  Additional Note
Given the default security policies on Windows, you might encounter an error like "Running scripts is disabled on this system". If this happens, you can temporarily allow the script to run with the following command, but exercise this with caution:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
```

This command allows scripts to run in your current session. Remember, only use this if you trust the source of the script.

## Contribution
If you have suggestions for improvements or bug fixes, feel free to submit a pull request or open an issue.
