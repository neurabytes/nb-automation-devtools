#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="3.11.6"

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

# -------------------------
# Use pyenv Python for pip/pipenv/pre-commit
# -------------------------
# Ensure we are using the pyenv-managed python
PYENV_PYTHON="$(pyenv which python)"
export PIP_BREAK_SYSTEM_PACKAGES=1

"$PYENV_PYTHON" -m pip install --upgrade pip
"$PYENV_PYTHON" -m pip install pipenv pre-commit

echo "pip / pipenv / pre-commit installed using: $PYENV_PYTHON"

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
