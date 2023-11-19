#!/bin/bash

# Check if Homebrew is installed, install if not
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Define a list of tools to install or upgrade
declare -A tools=(
    [git]="2.42.0"
    [intellij-idea-ce]="2023.2.3" # IntelliJ IDEA Community Edition
    [r]="4.3.1"
    [meld]="3.22.0"
    [wget]="6.1.2" # Using wget as an alternative to WinSCP
    [postman]="10.18.10"
    [terraform]="1.6.2"
    [awscli]="2.13.32"
    [azure-cli]="2.53.1"
    [openjdk]="17.0.2"
    [maven]="3.9.5"
    [scala]="2.11.4"
    [node]="21.1.0"
    [gnupg]="4.2.0" # Gpg4win alternative
    [sqlite]="3.43.2"
    [dbeaver-community]="23.2.1" # DBeaver Community Edition
    # No direct equivalents for 'powerbi' and 'tableau-public' on macOS via Homebrew
)

# Function to install or upgrade a tool
install_or_upgrade() {
    if brew ls --versions "$1" > /dev/null; then
        echo "Upgrading $1..."
        brew upgrade "$1"
    else
        echo "Installing $1..."
        brew install "$1"
    fi
}

# Function to uninstall a tool
uninstall() {
    if brew ls --versions "$1" > /dev/null; then
        echo "Uninstalling $1..."
        brew uninstall "$1"
    else
        echo "$1 is not installed."
    fi
}

# Prompt user for action
read -p "Enter desired action (install, upgrade, uninstall): " action

# Process the action
case $action in
    install)
        for tool in "${!tools[@]}"; do
            install_or_upgrade "$tool"
        done
        ;;
    uninstall)
        for tool in "${!tools[@]}"; do
            uninstall "$tool"
        done
        ;;
    *)
        echo "Invalid action specified. Please enter either 'install' or 'uninstall'."
        exit 1
        ;;
esac

# Report on installed tools
echo "Installed tools:"
brew list
