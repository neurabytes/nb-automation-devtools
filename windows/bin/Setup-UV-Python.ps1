<#  nb_uv_setup_windows.ps1  (PowerShell)

- Mirrors your mac script behavior, but with your “select a user profile” pattern.
- Installs base uv project at: <SelectedUserProfile>\.nb\python
- Pins Python via .python-version
- Ensures venv + installs: rich, pre-commit
- Optional: downloads & runs credentials script

Prereq: uv is already installed and on PATH.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------------
# Config
# -------------------------
$PYTHON_VERSION  = "3.11.14"
$CREDENTIALS_URL = "https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/devtools/setup_credentials.py"

# -------------------------
# Admin guard
# -------------------------
function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

if (Test-IsAdmin) {
    Write-Host "Please run this script as a non-Administrator!" -ForegroundColor Red
    exit 1
}

# -------------------------
# Profile selection (inspired by your pyenv script)
# -------------------------
function Get-UserProfiles {
    Get-ChildItem "C:\Users\" -Directory | Select-Object -ExpandProperty Name
}

function Select-UserProfile {
    $profiles = @(Get-UserProfiles)

    Write-Host ""
    Write-Host "Choose where to install the base uv project (.nb\python):"
    Write-Host "[0] Use current user: $env:USERPROFILE"
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        Write-Host ("[{0}] C:\Users\{1}" -f ($i + 1), $profiles[$i])
    }

    while ($true) {
        $sel = Read-Host ("Select a profile by number (0-{0})" -f $profiles.Count)
        if ($sel -match '^\d+$') {
            $n = [int]$sel
            if ($n -eq 0) { return $env:USERPROFILE }
            if ($n -ge 1 -and $n -le $profiles.Count) { return ("C:\Users\{0}" -f $profiles[$n - 1]) }
        }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}

function Confirm-UserProfile {
    while ($true) {
        $p = Select-UserProfile
        $confirm = Read-Host "You've selected: $p . Is this correct? (yes/no)"
        if ($confirm -in @("yes","y","Y")) { return $p }
    }
}

# -------------------------
# Actions
# -------------------------
function Ask-Action {
    $action = Read-Host "Do you want to install uv+python? (install/uninstall)"
    if ($action -ne "install" -and $action -ne "uninstall") {
        throw "Invalid input. Please enter 'install' or 'uninstall'."
    }
    return $action
}

function Ensure-Uv-OrExit {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host "uv is not installed or not on PATH." -ForegroundColor Red
        Write-Host "Install uv, then re-run this script."
        exit 1
    }
}

function Optional-Setup-Credentials {
    param([string]$PythonExe)

    $answer = Read-Host "Do you also want to set up the credentials now? (yes/no)"
    if ($answer -notin @("yes","y","Y")) {
        Write-Host "Skipping credentials setup."
        return
    }

    $tmp = Join-Path $env:TEMP ("nb_setup_credentials_{0}.py" -f ([Guid]::NewGuid().ToString("N")))
    try {
        Write-Host "Downloading credentials setup script..."
        Invoke-RestMethod -Uri $CREDENTIALS_URL -OutFile $tmp

        Write-Host "Running credentials setup script with $PythonExe ..."
        & $PythonExe $tmp
    }
    catch {
        Write-Warning "Credentials setup failed: $($_.Exception.Message)"
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmp | Out-Null
    }
}

function Install-AndActivate-Python {
    param([string]$BaseProjectDir)

    $nbPython     = Join-Path $BaseProjectDir ".venv\Scripts\python.exe"
    $preCommitExe = Join-Path $BaseProjectDir ".venv\Scripts\pre-commit.exe"

    Write-Host ""
    Write-Host "Installing Python $PYTHON_VERSION with uv (if not already installed)..."
    & uv python install $PYTHON_VERSION

    Write-Host "Ensuring base uv project exists at: $BaseProjectDir"
    New-Item -ItemType Directory -Force -Path $BaseProjectDir | Out-Null

    # project-local pin
    Set-Content -Path (Join-Path $BaseProjectDir ".python-version") -Value $PYTHON_VERSION -NoNewline

    # init if missing
    $pyproject = Join-Path $BaseProjectDir "pyproject.toml"
    if (-not (Test-Path $pyproject)) {
        Push-Location $BaseProjectDir
        try { & uv init } finally { Pop-Location }
    }

    # deps into .venv
    Push-Location $BaseProjectDir
    try { & uv add rich pre-commit } finally { Pop-Location }

    if (-not (Test-Path $nbPython))     { throw "ERROR: Expected venv python not found at $nbPython" }
    if (-not (Test-Path $preCommitExe)) { throw "ERROR: Expected pre-commit not found at $preCommitExe" }

    Write-Host "Version check:"
    & $nbPython --version

    # enforce exact version, same as your mac script
    & $nbPython -c "import sys; assert sys.version.startswith('$PYTHON_VERSION'), sys.version"

    & $nbPython -c "import rich; print('rich OK')" | Out-Null

    Write-Host ""
    Write-Host "Base project ready. Use:"
    Write-Host "  Python:     $nbPython"
    Write-Host "  pre-commit: $preCommitExe"
    Write-Host ""
    & $preCommitExe --version

    return @{
        NB_PYTHON  = $nbPython
        PRECOMMIT  = $preCommitExe
        BASE_DIR   = $BaseProjectDir
    }
}

function Uninstall-Uv-Setup {
    param([string]$BaseProjectDir)

    Write-Host "Starting full uninstall of uv-based setup..."

    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $BaseProjectDir | Out-Null

    # Uninstall python version if uv reports it (best-effort)
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        $list = ""
        try { $list = (& uv python list | Out-String) } catch { $list = "" }
        if ($list -match [Regex]::Escape($PYTHON_VERSION)) {
            try { & uv python uninstall $PYTHON_VERSION } catch { Write-Host "(uv python uninstall failed; continuing)" }
        } else {
            Write-Host "uv Python $PYTHON_VERSION not detected (skipping uninstall)."
        }
    }

    # Optional cleanup of uv cache dirs (best-effort; non-destructive if not present)
    $uvCache    = Join-Path $env:LOCALAPPDATA "uv\cache"
    $uvRoaming  = Join-Path $env:APPDATA "uv"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $uvCache   | Out-Null
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $uvRoaming | Out-Null

    Write-Host "Uninstall complete."
}

# -------------------------
# Main
# -------------------------
$action = Ask-Action

# choose user profile path (install/uninstall both need it)
$userProfile = Confirm-UserProfile

$baseProjectDir = Join-Path $userProfile ".nb\python"

if ($action -eq "uninstall") {
    Uninstall-Uv-Setup -BaseProjectDir $baseProjectDir
    exit 0
}

Ensure-Uv-OrExit

$result = Install-AndActivate-Python -BaseProjectDir $baseProjectDir

Write-Host ""
Write-Host "Setup complete."
Write-Host "Use:"
Write-Host "  $($result['NB_PYTHON'])"
Write-Host "  $($result['PRECOMMIT'])"
Write-Host "Restart PowerShell if PATH changes are needed for uv."

Optional-Setup-Credentials -PythonExe $result.NB_PYTHON
