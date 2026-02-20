# Security Policy

## Overview

This repository contains scripts that automate developer environment setup by installing packages via **Homebrew** (macOS) and **Chocolatey** (Windows). Because these scripts run with elevated privileges and install software, security is critical.

## Threat Model

### What these scripts do

- Download a `tools.json` configuration file from this GitHub repository over HTTPS
- Parse the configuration to determine which packages to install for a chosen role
- Install, upgrade, or uninstall packages using the platform's package manager
- Optionally configure Git credentials (GitHub CLI token, AWS config)

### Trust boundaries

| Boundary | Trust level |
|----------|------------|
| This GitHub repository | **Trusted** — scripts and configuration originate here |
| GitHub HTTPS (TLS) | **Trusted** — all downloads enforce TLS 1.2+ |
| Homebrew package registry | **Trusted** — official Homebrew taps with package checksums |
| Chocolatey package registry | **Trusted** — official Chocolatey repository with package verification |
| User's network | **Untrusted** — HTTPS protects against interception |
| User's local machine | **Trusted** — scripts assume a clean, non-compromised OS |

### What we verify

- **TLS 1.2+** is enforced for all downloads (Windows scripts explicitly set `SecurityProtocol`)
- **SHA-256 checksums** are verified for `tools.json` after download — the expected hash is published alongside each `tools.json` file as `tools.json.sha256`
- **Chocolatey checksums** are verified for all packages during installation (except where explicitly listed in `ignore_checksum_tools` with documented justification)
- **Download failures abort execution** — scripts do not continue silently if a download fails

### What we do NOT verify (known limitations)

- Scripts downloaded via the one-liner execution pattern (`curl | bash`, `iex DownloadString`) are not individually signed. Users should review scripts before running them.
- We rely on GitHub's HTTPS and access controls to protect repository integrity. If the GitHub account is compromised, scripts could be tampered with.
- The Chocolatey and Homebrew registries are trusted third parties — we do not independently verify their package contents beyond what each package manager provides.

## For Users: Running Scripts Safely

1. **Review before running.** Before executing any script, download it first and read it:
   ```bash
   # macOS — download and review before executing
   curl -fsSL -o setup.sh https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/mac/bin/setup_dev_environment.sh
   less setup.sh        # review the script
   bash setup.sh        # run only after review
   ```
   ```powershell
   # Windows — download and review before executing
   $url = 'https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/windows/bin/Setup-DevEnvironment.ps1'
   Invoke-WebRequest -Uri $url -OutFile Setup-DevEnvironment.ps1
   Get-Content Setup-DevEnvironment.ps1 | more   # review the script
   .\Setup-DevEnvironment.ps1                     # run only after review
   ```

2. **Verify checksums.** The `tools.json.sha256` files in each platform directory contain the expected SHA-256 hash. After downloading `tools.json`, you can verify manually:
   ```bash
   # macOS
   shasum -a 256 tools.json
   # Compare output against the contents of tools.json.sha256
   ```

3. **Use a dedicated machine or VM** for initial testing if you are evaluating these scripts for the first time.

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, please report it responsibly:

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. Email **security@neurabytes.com** with:
   - A description of the vulnerability
   - Steps to reproduce
   - Potential impact
3. You will receive an acknowledgment within 48 hours
4. We will work with you to understand and address the issue before any public disclosure

## Supported Versions

Security updates are applied to the `develop` branch. We recommend always pulling the latest version of scripts before running them.
