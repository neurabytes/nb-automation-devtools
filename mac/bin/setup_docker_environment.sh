#!/bin/bash

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Check for virtualization support (Intel-based Macs)
check_virtualization() {
    sysctl kern.hv_support | grep -q "1"
    return $?
}

# Function to check if Docker Desktop is installed
check_docker_installed() {
    if brew list --cask | grep -q "docker"; then
        true
    else
        false
    fi
}

# Function to install Docker Desktop
install_docker() {
    echo "Installing Docker Desktop..."
    brew install --cask docker
    echo "Docker Desktop installed."
}

# Function to uninstall Docker Desktop
uninstall_docker() {
    echo "Uninstalling Docker Desktop..."
    brew uninstall --cask docker
    echo "Docker Desktop uninstalled."
}

# Main function to handle user interaction
main() {
    if ! check_virtualization; then
        echo "Virtualization not supported on this machine. Cannot proceed with Docker installation."
        exit 1
    fi

    if check_docker_installed; then
        echo "Docker Desktop is already installed."
        read -p "Do you want to uninstall Docker Desktop? (y/n): " choice
        if [ "$choice" = "y" ]; then
            uninstall_docker
        fi
    else
        echo "Docker Desktop is not installed."
        read -p "Do you want to install Docker Desktop? (y/n): " choice
        if [ "$choice" = "y" ]; then
            install_docker
        fi
    fi
}

main
