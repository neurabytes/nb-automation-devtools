# Neurabytes Automation for DevTools
This repository contains automation to setup the development environment for the students. The goal is to provide an automated way to reduce the time it takes to setup the development environment.

### Features
1. Cross-platform Compatibility: Works seamlessly across different operating systems and environments.
2. Automation: Reduces manual setup and configuration, letting developers focus on what they do best: code.
3. Adaptive: Regular updates and additions to ensure the tools remain relevant and efficient.


## 1. Getting Started [Windows]

### 1.1 Overview
1. `Setup-DevEnvironment.ps1`: Ensures that Chocolatey is installed and then facilitates the installation, upgrade, or uninstallation of a predefined list of developer tools.
2. `Setup-PyEnvWin.ps1`: Facilitates the installation or uninstallation of `pyenv-win` on Windows platforms.
3. `Setup-DockerEnvironment.ps1`: Installs Docker Desktop for Windows using Chocolatey.
4. `Setup-GitGPG.ps1`: Configures Git to sign commits and tags with GPG on Windows.

---

### 1.3 Prerequisites
- Windows Operating System
- PowerShell with administrative rights

---


### 1.4 Install Development tools

This script will install Chocolatey first and it will either install, upgrade, or uninstall a specified list of developer tools based on the versions provided in the script.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/Setup-DevEnvironment.ps1')
```

---

### 1.5 Install Python and other packages using pyenv-win
This script installs python environment manager `pyenv-win` on Windows. This will also install pipenv and pre-commit.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/Setup-PyEnvWin.ps1')
```

---

### 1.6 Install Docker Desktop
This script installs Docker Desktop for Windows using Chocolatey.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/Setup-DockerEnvironment.ps1')
```

---

### 1.7 Install Git sign commit
This script configures Git to sign commits and tags with GPG on Windows. It automates the process of installing GPG and setting it up with Git for commit signature verification.

**To Run the Script Directly from GitHub:**

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/Setup-GitGPG.ps1')
```
---

## 2. Getting Started [Mac]

This section is pending and will be updated soon.


##  3. Security Note
This script will request for Execution Policy Change for the session. Please make sure that you close the admin panel once the script is completed. Never execute scripts from untrusted sources on same session.


## 4. Contribution
If you have suggestions for improvements or bug fixes, feel free to submit a pull request or open an issue.



