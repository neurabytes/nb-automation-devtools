#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="3.11.9"
CREDENTIALS_URL="https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/devtools/setup_credentials.py"

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this as root/sudo."
  exit 1
fi

# -------------------------
# Detect shell + rc file
# -------------------------
SHELL_NAME="${SHELL##*/}"

case "$SHELL_NAME" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    ;;
  bash)
    # prefer .bashrc, fall back to .bash_profile
    if [ -f "$HOME/.bashrc" ]; then
      RC_FILE="$HOME/.bashrc"
    else
      RC_FILE="$HOME/.bash_profile"
    fi
    ;;
  *)
    # default to zsh-style config
    RC_FILE="$HOME/.zshrc"
    ;;
esac

echo "Using shell rc file: $RC_FILE"

# -------------------------
# Ensure Homebrew + pyenv
# -------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v pyenv >/dev/null 2>&1; then
  echo "pyenv not found. Installing pyenv via Homebrew..."
  brew install pyenv
fi

# -------------------------
# Configure pyenv for THIS script
# -------------------------
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
if ! echo "$PATH" | grep -q "$PYENV_ROOT/bin"; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi

eval "$(pyenv init -)"

# -------------------------
# Install + activate Python
# -------------------------
echo "Installing Python ${PYTHON_VERSION} with pyenv (if not already installed)..."
pyenv install -s "${PYTHON_VERSION}"
pyenv global "${PYTHON_VERSION}"
pyenv rehash

echo "Python versions after pyenv setup:"
command -v python || true
command -v python3 || true
python --version || true
python3 --version || true

echo "Installing pip, pipenv, and pre-commit."
# -------------------------
# Use pyenv Python for pip/pipenv/pre-commit
# -------------------------
PYENV_PYTHON="$(pyenv which python)"
export PIP_BREAK_SYSTEM_PACKAGES=1

"$PYENV_PYTHON" -m pip install --upgrade pip
"$PYENV_PYTHON" -m pip install pipenv pre-commit

echo "pip / pipenv / pre-commit installed using: $PYENV_PYTHON"

echo "Rehashing pyenv shims."
pyenv rehash
command -v pipenv || true
pipenv --version || true

# -------------------------
# OPTIONAL: setup credentials (same URL as Windows script)
# -------------------------
read -r -p "Do you also want to set up the credentials now? (yes/no) " ANSWER
case "$ANSWER" in
  yes|y|Y)
    echo "Downloading credentials setup script..."
    TMP_FILE="$(mktemp -t nb_setup_credentials.XXXXXX.py)"

    if curl -fsSL "$CREDENTIALS_URL" -o "$TMP_FILE"; then
      echo "Running credentials setup script with $PYENV_PYTHON ..."
      if ! "$PYENV_PYTHON" "$TMP_FILE"; then
        echo "Error: credentials setup script failed." >&2
      fi
    else
      echo "Error: failed to download credentials setup script from $CREDENTIALS_URL" >&2
    fi

    rm -f "$TMP_FILE"
    ;;
  *)
    echo "Skipping credentials setup."
    ;;
esac

# -------------------------
# Persist pyenv init into rc file (idempotent)
# -------------------------
PYENV_SNIPPET='
# --- pyenv setup (added by setup_pyenv.sh) ---
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null 2>&1 || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# --- end pyenv setup ---
'

mkdir -p "$(dirname "$RC_FILE")"

if [ -f "$RC_FILE" ] && grep -q 'pyenv init' "$RC_FILE"; then
  echo "pyenv initialization already present in $RC_FILE (not adding again)."
else
  echo "Adding pyenv initialization block to $RC_FILE..."
  {
    echo ""
    echo "$PYENV_SNIPPET"
  } >> "$RC_FILE"
fi

echo ""
echo "Setup complete."
echo "From the next terminal session, 'python' and 'python3' will come from pyenv (${PYTHON_VERSION})."
echo "If you want it immediately in this window, run: exec \"$SHELL\""
