#!/bin/bash

# Function to get user profiles
get_user_profiles() {
    ls /Users/
}

# Function to select a user profile
select_user_profile() {
    profiles=($(get_user_profiles))
    for i in "${!profiles[@]}"; do
        echo "[$((i + 1))] ${profiles[i]}"
    done

    read -p "Please select a user profile by number (1-${#profiles[@]}): " selection
    echo "/Users/${profiles[$((selection - 1))]}"
}

# Function to confirm user profile
confirm_user_profile() {
    user_profile_confirmed="no"
    while [ "$user_profile_confirmed" != "yes" ]; do
        user_profile=$(select_user_profile)
        read -p "You've selected the profile path: $user_profile. Is this correct? (yes/no) " confirm_profile
        user_profile_confirmed=$confirm_profile
    done
    echo $user_profile
}

# Function to clone or update pyenv
clone_or_update_pyenv() {
    if [ -d "$pyenv_path" ]; then
        read -p "$pyenv_path already exists. Do you want to overwrite it? (yes/no) " overwrite
        if [ "$overwrite" == "yes" ]; then
            echo "Removing existing directory..."
            rm -rf "$pyenv_path"
            echo "Cloning pyenv to $pyenv_path..."
            git clone https://github.com/pyenv/pyenv.git "$pyenv_path"
        else
            echo "Skipped cloning pyenv since directory already exists and overwrite was not chosen."
        fi
    else
        echo "Cloning pyenv to $pyenv_path..."
        git clone https://github.com/pyenv/pyenv.git "$pyenv_path"
    fi
}

# Function to add to user PATH
add_to_user_path() {
    local path_to_add=$1
    echo "export PATH=\"$path_to_add:\$PATH\"" >> ~/.bash_profile
}

# Main script logic
read -p "Please choose an action (install/uninstall): " action

if [ "$action" == "install" ]; then

    user_profile=$(confirm_user_profile)

    # Defining the pyenv path based on the user's input
    pyenv_path="$user_profile/.pyenv"

    clone_or_update_pyenv

    # Add the necessary paths to PATH variable
    add_to_user_path "$user_profile/.pyenv/bin"
    add_to_user_path "$user_profile/.pyenv/shims"

    # Reload the profile
    source ~/.bash_profile

    # Install and set the Python version
    pyenv install 3.11.6
    pyenv global 3.11.6

    # Check Python version
    python --version
    pip install pipenv
    pyenv rehash

    echo "Installation is done. Hurray!"

elif [ "$action" == "uninstall" ]; then

    # TODO: Add the code for uninstallation logic, similar to the installation logic.

else
    echo "Invalid action selected. Please choose 'install' or 'uninstall'."
fi
