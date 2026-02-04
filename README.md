# Neurabytes Automation - Dev Tools

**Zero-prerequisite, cross-platform developer environment setup with safe uninstall for personal laptops.**

## The Problem

You manage a team with short-term contributors (interns, contractors, students) who bring their **personal laptops**. You need to:

1. Set up a consistent development environment quickly
2. Not require them to install prerequisites first
3. **Safely uninstall** when they leave - removing only what you installed, not breaking their existing setup

## The Solution

One command. No prerequisites. Safe uninstall.

**macOS:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/setup_dev_environment.sh)"
```

**Windows** (Run PowerShell as Administrator):
```powershell
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/Setup-DevEnvironment.ps1')
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Zero Prerequisites** | Just `curl` (macOS) or PowerShell (Windows). No Python, no package managers to install first. |
| **Role-Based Installation** | Select a role (Data Engineer, Student, Data Analyst, Data Scientist) and get the right tools. |
| **State Tracking** | Tracks what THIS script installed vs. what was already on the machine. |
| **Safe Uninstall** | Removes only the tools we installed. Your existing setup stays intact. |
| **Cross-Platform** | Single repository manages both Windows (Chocolatey) and macOS (Homebrew). |
| **Automated Updates** | GitHub Actions automatically updates tool versions weekly. |


## Why Not Just Use...?

| Alternative | Why It Doesn't Fit This Use Case |
|-------------|----------------------------------|
| **Ansible** | Requires Python + Ansible installed first. Not "zero prerequisites." |
| **Brewfile** | `brew bundle cleanup` removes ALL packages not in file - dangerous on personal laptops. |
| **Nix** | Steep learning curve. Overkill for short-term contributors. |
| **Dev Containers** | Requires Docker. Changes workflow. Not everyone wants to develop inside a container. |
| **Manual docs** | Gets outdated. Inconsistently followed. No safe uninstall path. |


## How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│  1. User runs one-liner command                                  │
│  2. Script auto-installs package manager if missing              │
│  3. User selects role (Data Engineer / Student / Analyst / etc.) │
│  4. Tools for that role get installed                            │
│  5. State saved: "These tools were installed by nb-automation"   │
└──────────────────────────────────────────────────────────────────┘

On uninstall → Script reads state → Removes ONLY those tools → User's existing setup untouched
```

**State file locations:**
- Windows: `C:\ProgramData\nb-automation\installed_tools_state.json`
- macOS: `/Library/Application Support/nb-automation/`

## Available Roles

| Role | Description | Example Tools |
|------|-------------|---------------|
| **Data Engineer** | Data pipelines, cloud platforms, infrastructure | AWS CLI, Terraform, Scala, Go |
| **Student** | Essential tools for learning and productivity | Git, IntelliJ IDEA, Node.js, Maven |
| **Data Analyst** | Data analysis and visualization | R, RStudio, Tableau, Power BI |
| **Data Scientist** | Machine learning and research | R, RStudio, Cursor, Python tools |

Tool configurations: [`windows/bin/tools.json`](windows/bin/tools.json) | [`mac/bin/tools.json`](mac/bin/tools.json)

## Additional Scripts

### Python Setup

**Using uv (recommended):**
```bash
# macOS
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/setup_uv_python.sh)"
```
```powershell
# Windows
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/Setup-UV-Python.ps1')
```

**Using pyenv:**
```bash
# macOS
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/setup_pyenv.sh)"
```
```powershell
# Windows (Run as non-admin)
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/Setup-PyEnvWin.ps1')
```

### Docker Desktop

```bash
# macOS
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/setup_docker_environment.sh)"
```
```powershell
# Windows
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/Setup-DockerEnvironment.ps1')
```

### Git GPG Signing

```bash
# macOS
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/setup_git_gpg.sh)"
```
```powershell
# Windows
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/Setup-GitGPG.ps1')
```

## Security Note

These scripts execute directly from GitHub. Before running:
1. Review the script source code
2. Understand what will be installed
3. Close elevated terminals after setup completes

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Submit a pull request to the `develop` branch

**Adding a new tool:** Add to `windows/bin/tools.json` and/or `mac/bin/tools.json` with the correct package name for each platform.

## License

[Apache 2.0](LICENSE)
