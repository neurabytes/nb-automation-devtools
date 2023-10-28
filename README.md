# Neurabytes Automation for DevTools

This repository contains a dynamic collection of scripts designed to streamline the development setup process across various platforms. The goal is to provide an automated, efficient, and continuously evolving set of tools that cater to the ever-changing needs of developers.

## Features:

1. Cross-platform Compatibility: Works seamlessly across different operating systems and environments.
2. Automation: Reduces manual setup and configuration, letting developers focus on what they do best: code.
3. Adaptive: Regular updates and additions to ensure the tools remain relevant and efficient.


## Getting Started

### Prerequisites

- Windows Operating System
- PowerShell with administrative rights


### Overview

1. `ChocoToolSetup.ps1`: Ensures that Chocolatey is installed and then facilitates the installation, upgrade, or uninstallation of a predefined list of developer tools.
2. `PyenvSetup.ps1`: Facilitates the installation or uninstallation of `pyenv-win` on Windows platforms.
3. `ChocoInstallDocker.ps1`: Installs Docker Desktop for Windows using Chocolatey.

---

### Chocolatey Tools Setup Script (ChocoToolSetup.ps1)

This script ensures that Chocolatey is installed. After this verification, it will either install, upgrade, or uninstall a specified list of developer tools based on the versions provided in the script.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/bin/ChocoToolSetup.ps1')
```

---

### Pyenv Setup Script (`PyenvSetup.ps1`)

This script aids in setting up `pyenv-win` to manage Python versions on a Windows machine. It can both install and uninstall `pyenv-win`.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/bin/PyenvSetup.ps1')
```

---

### Docker Desktop for Windows Setup Script (`ChocoInstallDocker.ps1`)
This script installs Docker Desktop for Windows using Chocolatey.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/bin/ChocoInstallDocker.ps1')
```
---


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



