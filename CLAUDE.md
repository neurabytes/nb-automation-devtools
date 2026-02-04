# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Neurabytes Automation DevTools repository, containing cross-platform scripts for automating developer environment setup. The repository is organized with platform-specific directories containing setup scripts.

## Architecture

- `windows/bin/` - PowerShell scripts for Windows environment setup (uses Chocolatey)
- `mac/bin/` - Shell scripts for macOS environment setup (uses Homebrew)
- `windows/bin/tools.json` - Tool versions for Windows (Chocolatey package names)
- `mac/bin/tools.json` - Tool versions for macOS (Homebrew formula/cask names)
- `.github/workflows/` - Automated tool version update workflow

## Key Components

### Tools Configuration
- Separate `tools.json` files for each platform with platform-specific package names
- Supports roles: `data_engineer`, `student`, `data_analyst`, `data_scientist`
- Scripts download tools.json dynamically from GitHub at runtime
- The `ignore_checksum_tools` array lists tools that skip checksum validation
- State management tracks installed tools:
  - Windows: `C:\ProgramData\nb-automation\installed_tools_state.json`
  - macOS: `/Library/Application Support/nb-automation/installed_state.json`

### Setup Scripts (Windows)
- `Setup-DevEnvironment.ps1` - Main script with role-based tool installation via Chocolatey
  - Presents role selection menu (1-4) for users to choose their development focus
  - Automatically detects and uninstalls tools removed from role configuration
  - Maintains state file to track nb-automation managed tools
- `Setup-PyEnvWin.ps1` - Python version management via pyenv-win (requires non-admin)
- `Setup-UV-Python.ps1` - Alternative Python management via UV
- `Setup-DockerEnvironment.ps1` - Docker Desktop installation (validates Hyper-V)
- `Setup-GitGPG.ps1` - Git GPG signature configuration

### Setup Scripts (macOS)
- `setup_dev_environment.sh` - Developer tools installation via Homebrew
  - Supports `DRY_RUN` and `DEBUG` flags for testing
  - Auto-taps `hashicorp/tap` for Terraform
- `setup_pyenv.sh` - Python version management via pyenv
- `setup_uv_python.sh` - Alternative Python management via UV
- `setup_docker_environment.sh` - Docker Desktop installation via Homebrew Cask
- `setup_git_gpg.sh` - Git GPG configuration

### Automated Version Updates
- `.github/workflows/update-tools.yml` - Weekly workflow (Sundays 8AM UTC) that:
  - Runs `update_tools.py` to query Chocolatey API for Windows tool versions
  - Runs `update_tools_macos.py` to query Homebrew for macOS tool versions
  - Creates PR to `develop` branch with updated versions

## Development Commands

No build, test, or lint commands are present in this repository as it contains configuration scripts rather than a traditional software project.

## Script Execution Pattern

Scripts are designed to be executed directly from GitHub via:
```powershell
# Windows
Set-ExecutionPolicy Bypass -Scope Process
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/ScriptName.ps1')
```

```bash
# macOS
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/script_name.sh)"
```

## Important Notes

- Windows scripts require administrator privileges except for PyEnv/UV setup
- macOS pyenv/UV scripts require non-root execution
- The main development branch is `develop`, not `main`
- Scripts dynamically download `tools.json` to ensure latest tool versions
- Homebrew tap-qualified packages (e.g., `hashicorp/tap/terraform`) are auto-tapped