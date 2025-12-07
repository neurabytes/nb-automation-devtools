#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------------
# Do NOT run as root (Homebrew refuses to run as root)
# --------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "Do NOT run this script with sudo or as root."
    echo "Run it as your normal user (the same one that installed Homebrew)."
    exit 1
fi

# --------------------------------------------------------------------
# Ensure Homebrew exists
# --------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Install Homebrew first, then re-run this script."
    exit 1
fi

# --------------------------------------------------------------------
# Check for virtualization support (Intel & Apple Silicon Macs)
# --------------------------------------------------------------------
check_virtualization() {
    if sysctl kern.hv_support 2>/dev/null | grep -q '1'; then
        return 0
    else
        return 1
    fi
}

# --------------------------------------------------------------------
# Check if Docker Desktop is installed
# --------------------------------------------------------------------
check_docker_installed() {
    # This returns 0 if the cask is installed, 1 otherwise
    brew list --cask docker >/dev/null 2>&1
}

# --------------------------------------------------------------------
# Install Docker Desktop
# --------------------------------------------------------------------
install_docker() {
    echo "Installing Docker Desktop via Homebrew Cask..."
    brew install --cask docker
    echo "Docker Desktop installation completed (via Homebrew)."
    echo "You may need to open Docker.app from /Applications the first time."
}

# --------------------------------------------------------------------
# Uninstall Docker Desktop
# --------------------------------------------------------------------
uninstall_docker() {
    echo "Uninstalling Docker Desktop via Homebrew Cask..."
    brew uninstall --cask docker
    echo "Docker Desktop uninstalled."
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------
main() {
    if ! check_virtualization; then
        echo "Virtualization not supported on this machine. Cannot proceed with Docker installation."
        exit 1
    fi

    if check_docker_installed; then
        echo "Docker Desktop is already installed."
        read -r -p "Do you want to uninstall Docker Desktop? (y/n): " choice
        if [ "$choice" = "y" ]; then
            uninstall_docker
        else
            echo "Leaving Docker Desktop installed."
        fi
    else
        echo "Docker Desktop is not installed."
        read -r -p "Do you want to install Docker Desktop? (y/n): " choice
        if [ "$choice" = "y" ]; then
            install_docker
        else
            echo "Skipping Docker Desktop installation."
        fi
    fi
}

main
