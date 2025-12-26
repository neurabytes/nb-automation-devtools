#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="3.11.9"
CREDENTIALS_URL="https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/devtools/setup_credentials.py"

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this as root/sudo."
  exit 1
fi

# -------------------------
# Functions
# -------------------------
ask_action() {
  read -r -p "Do you want to install pyenv? (install/uninstall) " ACTION
  case "$ACTION" in
    install|uninstall) ;;
    *) echo "Invalid input. Please enter 'install' or 'uninstall'." ; exit 1 ;;
  esac
}

detect_shell_rc_file() {
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
}

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed."
    echo ""
    echo "Please first run the following command:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/mac/bin/setup_dev_environment.sh)"'
    echo ""
    echo "After Homebrew is installed, re-run this script."
    exit 1
  fi
}

ensure_pyenv() {
  if ! command -v pyenv >/dev/null 2>&1; then
    echo "pyenv not found. Installing pyenv via Homebrew..."
    brew install pyenv
  fi
}

configure_pyenv_for_script() {
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  if ! echo "$PATH" | grep -q "$PYENV_ROOT/bin"; then
    export PATH="$PYENV_ROOT/bin:$PATH"
  fi
  eval "$(pyenv init -)"
}

install_and_activate_python() {
  echo "Installing Python ${PYTHON_VERSION} with pyenv (if not already installed)..."
  pyenv install -s "${PYTHON_VERSION}"
  pyenv global "${PYTHON_VERSION}"
  pyenv rehash

  echo "Python versions after pyenv setup:"
  command -v python || true
  command -v python3 || true
  python --version || true
  python3 --version || true
}

install_pip_tools() {
  echo "Installing pip, pipenv, and pre-commit."
  export PIP_BREAK_SYSTEM_PACKAGES=1

  "$PYENV_PYTHON" -m pip install --upgrade pip
  "$PYENV_PYTHON" -m pip install pipenv pre-commit rich

  echo "pip / pipenv / pre-commit installed using: $PYENV_PYTHON"

  echo "Rehashing pyenv shims."
  pyenv rehash
  command -v pipenv || true
  pipenv --version || true
}

optional_setup_credentials() {
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
}

persist_pyenv_init_into_rc() {
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
}

remove_pyenv_init_from_rc() {
  if [ -f "$RC_FILE" ]; then
    # Remove only the block added by this script
    sed -i.bak '/# --- pyenv setup (added by setup_pyenv.sh) ---/,/# --- end pyenv setup ---/d' "$RC_FILE" || true
  fi
}


uninstall_pyenv_setup() {
  # Keep behavior tight: remove only what this script adds/uses.

  # Remove the pyenv init block added by this script.
  if [ -f "$RC_FILE" ]; then
    sed -i.bak '/# --- pyenv setup (added by setup_pyenv.sh) ---/,/# --- end pyenv setup ---/d' "$RC_FILE" || true
  fi

  # If pyenv is present, switch global back to system and uninstall the managed version (if present).
  if command -v pyenv >/dev/null 2>&1; then
    pyenv global system || true

    if pyenv versions --bare | grep -qx "${PYTHON_VERSION}"; then
      pyenv uninstall -f "${PYTHON_VERSION}" || true
    fi
  fi

  # Uninstall pyenv (if installed via brew).
  if command -v brew >/dev/null 2>&1; then
    if brew list pyenv >/dev/null 2>&1; then
      brew uninstall pyenv || true
    fi
  fi

  # Remove default pyenv root directory.
  if [ -d "$HOME/.pyenv" ]; then
    rm -rf "$HOME/.pyenv" || true
  fi
}

# -------------------------
# Main
# -------------------------
ask_action
detect_shell_rc_file

if [ "$ACTION" = "uninstall" ]; then
  uninstall_pyenv_setup
  remove_pyenv_init_from_rc
fi

if [ "$ACTION" = "install" ]; then
  ensure_homebrew
  ensure_pyenv
  configure_pyenv_for_script
  install_and_activate_python

  # Use pyenv Python for pip/pipenv/pre-commit (same as original)
  PYENV_PYTHON="$(pyenv which python)"
  install_pip_tools
  persist_pyenv_init_into_rc
fi

echo ""
echo "Setup complete."
echo "From the next terminal session, 'python' and 'python3' will come from pyenv (${PYTHON_VERSION})."
echo "If you want it immediately in this window, run: exec \"$SHELL\""

optional_setup_credentials
