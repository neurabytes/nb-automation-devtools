#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="3.11.14"
CREDENTIALS_URL="https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/develop/devtools/setup_credentials.py"
BASE_PROJECT_DIR="$HOME/.nb/python"
NB_PYTHON="$BASE_PROJECT_DIR/.venv/bin/python"

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this as root/sudo."
  exit 1
fi

# -------------------------
# Functions
# -------------------------
ask_action() {
  read -r -p "Do you want to install uv+python? (install/uninstall) " ACTION
  case "$ACTION" in
    install|uninstall) ;;
    *) echo "Invalid input. Please enter 'install' or 'uninstall'." ; exit 1 ;;
  esac
}

ensure_homebrew_uv_or_exit() {

  local missing=0

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed."
    missing=1
  fi

  if ! command -v uv >/dev/null 2>&1; then
    echo "uv is not installed."
    missing=1
  fi

  if [ "${missing:-0}" -eq 1 ]; then
    echo ""
    echo "Please first run the following command:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/mac/bin/setup_dev_environment.sh)"'
    echo ""
    echo "After installation, re-run this script."
    exit 1
  fi
}


install_and_activate_python() {
  echo "Installing Python ${PYTHON_VERSION} with uv (if not already installed)..."
  uv python install "${PYTHON_VERSION}"

  echo "Python versions detected/managed by uv:"
  uv python list || true

  echo "Ensuring base uv project exists at: $BASE_PROJECT_DIR"
  mkdir -p "$BASE_PROJECT_DIR"

  # Ensure this project uses the intended Python version (project-local)
  echo "${PYTHON_VERSION}" > "$BASE_PROJECT_DIR/.python-version"

  # Initialize project if missing
  if [ ! -f "$BASE_PROJECT_DIR/pyproject.toml" ]; then
    (cd "$BASE_PROJECT_DIR" && uv init)
  fi

  # Install deps into the project's .venv
  (cd "$BASE_PROJECT_DIR" && uv add rich pre-commit)

  # Sanity checks
  if [ ! -x "$NB_PYTHON" ]; then
    echo "ERROR: Expected venv python not found at $NB_PYTHON" >&2
    exit 1
  fi

  if [ ! -x "$BASE_PROJECT_DIR/.venv/bin/pre-commit" ]; then
    echo "ERROR: Expected pre-commit not found at $BASE_PROJECT_DIR/.venv/bin/pre-commit" >&2
    exit 1
  fi

  echo "Version check:"
  "$NB_PYTHON" --version || true

  # Optional: enforce exact python version
  if ! "$NB_PYTHON" -c "import sys; assert sys.version.startswith('${PYTHON_VERSION}'), sys.version"; then
    echo "ERROR: nb venv python is not ${PYTHON_VERSION}" >&2
    exit 1
  fi

  "$NB_PYTHON" -c "import rich; print('rich OK')" >/dev/null

  echo "Base project ready. Use:"
  echo "  Python:     $NB_PYTHON"
  echo "  pre-commit: $BASE_PROJECT_DIR/.venv/bin/pre-commit"

  echo "Versions:"
  "$BASE_PROJECT_DIR/.venv/bin/pre-commit" --version || true
}



optional_setup_credentials() {
  read -r -p "Do you also want to set up the credentials now? (yes/no) " ANSWER
  case "$ANSWER" in
    yes|y|Y)
      echo "Downloading credentials setup script..."
      TMP_FILE="$(mktemp -t nb_setup_credentials.XXXXXX.py)"

      if curl -fsSL "$CREDENTIALS_URL" -o "$TMP_FILE"; then
        echo "Running credentials setup script with $NB_PYTHON ..."
        if ! "$NB_PYTHON" "$TMP_FILE"; then
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

uninstall_uv_setup() {
  echo "Starting full uninstall of uv-based setup..."

  # 1) Remove base uv project
  rm -rf "$BASE_PROJECT_DIR" || true

  # 2) Remove uv tools installed by this script
  if command -v uv >/dev/null 2>&1; then
    # Python: only uninstall if present
    if uv python list 2>/dev/null | grep -q "${PYTHON_VERSION}"; then
      uv python uninstall "${PYTHON_VERSION}" || true
    else
      echo "uv Python ${PYTHON_VERSION} not installed (skipping)."
    fi
  fi

  # 3) Remove default python shims created by --default
  rm -f \
    "$HOME/.local/bin/python" \
    "$HOME/.local/bin/python3" \
    "$HOME/.local/bin/python3.11" \
    "$HOME/.local/bin/python3.12" \
    "$HOME/.local/bin/python3.13" \
    2>/dev/null || true
  hash -r 2>/dev/null || true

  # 4) Remove global python pin if it matches
  if [ -f "$HOME/.python-version" ] && grep -qx "${PYTHON_VERSION}" "$HOME/.python-version"; then
    rm -f "$HOME/.python-version"
  fi

  # 5) Remove all uv-managed data
  if [ -d "$HOME/.local/share/uv" ]; then
    rm -rf "$HOME/.local/share/uv"
  fi

  # 6) Report PATH status (non-destructive)
  report_uv_shell_path_changes

  echo "Uninstall complete. uv-managed data removed."
}


is_local_bin_on_path() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return 0 ;;
    *) return 1 ;;
  esac
}

print_path_entries() {
  echo ""
  echo "Current PATH entries:"
  echo "$PATH" | tr ':' '\n' | nl -ba

  if is_local_bin_on_path; then
    echo ""
    echo "FLAG: PATH contains $HOME/.local/bin"
  fi
}

report_uv_shell_path_changes() {
  local targets=(
    "$HOME/.zshenv"
    "$HOME/.zprofile"
    "$HOME/.zshrc"
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.config/fish/config.fish"
  )

  echo ""
  echo "Checking for shell PATH lines that may have been added by 'uv tool update-shell'..."

  local found=0
  for f in "${targets[@]}"; do
    [ -f "$f" ] || continue

    # Show lines that add ~/.local/bin to PATH (common outcome)
    if grep -nF 'export PATH="$HOME/.local/bin:$PATH"' "$f" >/dev/null 2>&1; then
      echo ""
      echo "Found in: $f"
      grep -nF 'export PATH="$HOME/.local/bin:$PATH"' "$f" || true
      found=1
    fi

    # Fish common form (if applicable)
    if grep -nF 'set -gx PATH $HOME/.local/bin $PATH' "$f" >/dev/null 2>&1; then
      echo ""
      echo "Found in: $f"
      grep -nF 'set -gx PATH $HOME/.local/bin $PATH' "$f" || true
      found=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "No matching PATH lines found in common shell config files."
    echo "Note: uv may have updated a different file depending on your shell/environment."
  fi

  print_path_entries

  if is_local_bin_on_path; then
    echo ""
    echo "If you want to remove $HOME/.local/bin from PATH, delete the line(s) shown above from your shell config file."
  else
    echo ""
    echo "No manual PATH cleanup appears necessary."
  fi
}

# -------------------------
# Main
# -------------------------
ask_action

if [ "$ACTION" = "uninstall" ]; then
  uninstall_uv_setup
  echo ""
  echo "Uninstall complete."
  exit 0
fi

# install
ensure_homebrew_uv_or_exit
install_and_activate_python

echo ""
echo "Setup complete."
echo "Use:"
echo "  $NB_PYTHON"
echo "  $BASE_PROJECT_DIR/.venv/bin/pre-commit"
echo "If you want it immediately in this window, run: exec \"$SHELL\""

optional_setup_credentials