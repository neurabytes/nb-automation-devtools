# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Neurabytes Automation DevTools repository, containing cross-platform scripts for automating developer environment setup. The repository is organized with platform-specific directories containing setup scripts.

## Architecture

- `windows/bin/` - PowerShell scripts for Windows environment setup
- `mac/bin/` - Shell scripts for macOS environment setup  
- `tools.json` - Central configuration file defining tool versions for installation
- Root-level scripts are referenced via GitHub raw URLs for direct execution

## Key Components

### Tools Configuration
- `tools.json` contains role-based tool definitions with versioned tools for each role
- Supports roles: data_engineer, software_engineer, data_analyst, data_scientist
- Scripts download this file dynamically from the GitHub repository  
- The `ignore_checksum_tools` array lists tools that skip checksum validation
- State management tracks installed tools in `C:\ProgramData\nb-automation\installed_tools_state.json`

### Setup Scripts (Windows)
- `Setup-DevEnvironment.ps1` - Main script with role-based tool installation via Chocolatey
  - Presents role selection menu (1-4) for users to choose their development focus
  - Automatically detects and uninstalls tools removed from role configuration
  - Maintains state file to track nb-automation managed tools
  - Supports install/uninstall operations with version-specific handling
- `Setup-PyEnvWin.ps1` - Python version management setup for Windows
- `Setup-DockerEnvironment.ps1` - Docker Desktop installation  
- `Setup-GitGPG.ps1` - Git GPG signature configuration

### Setup Scripts (macOS)
- `setup_dev_environment.sh` - Developer tools installation for macOS
- `setup_pyenv.sh` - Python version management setup
- `setup_docker_environment.sh` - Docker installation
- `setup_git_gpg.sh` - Git GPG configuration

## Development Commands

No build, test, or lint commands are present in this repository as it contains configuration scripts rather than a traditional software project.

## Script Execution Pattern

Scripts are designed to be executed directly from GitHub via:
```powershell
# Windows
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/ScriptName.ps1')
```

```bash  
# macOS
curl -s https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/mac/bin/script_name.sh | bash
```

## Important Notes

- Windows scripts require administrator privileges except for PyEnv setup
- All scripts implement safety checks and can handle both installation and uninstallation
- The main development branch is `develop`, not `main`
- Scripts dynamically download `tools.json` to ensure latest tool versions