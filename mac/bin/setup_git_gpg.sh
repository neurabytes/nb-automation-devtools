#!/bin/bash

# Check GPG Installation
if ! command -v gpg > /dev/null; then
    echo "GPG is not found on this system. Please install it first."
    exit 1
fi

# Get GPG Version
get_gpg_version() {
    gpg --version | head -n 1 | awk '{print $3}'
}

# Create GPG Command File
new_gpg_command_file() {
    local email=$1
    local name=$2
    local temp_file=$(mktemp)
    cat <<- EOF > "$temp_file"
        Key-Type: RSA
        Key-Length: 4096
        Subkey-Type: RSA
        Subkey-Length: 4096
        Name-Real: $name
        Name-Email: $email
        Expire-Date: 0
        %commit
EOF
    echo "$temp_file"
}

# Generate GPG Key
invoke_gpg_key_generation() {
    local email=$1
    local name=$2
    local gpg_version=$(get_gpg_version)
    local temp_file=$(new_gpg_command_file "$email" "$name")

    echo "Generating GPG key. Please follow any prompts..."
    if [[ "$gpg_version" > "2.1.17" ]]; then
        gpg --batch --generate-key "$temp_file"
    else
        gpg --gen-key --batch "$temp_file"
    fi

    rm -f "$temp_file"
}

# Get Key ID by Email
get_key_id_by_email() {
    local email=$1
    gpg --list-secret-keys --keyid-format LONG "$email" | grep 'sec' | awk '{print $2}' | cut -d'/' -f2
}

# Export GPG Public Key
export_gpg_public_key() {
    local key_id=$1
    local public_key_file="$HOME/public_key.asc"
    gpg --export -a "$key_id" > "$public_key_file"
    echo "Public key saved to: $public_key_file"
    echo "Please save the key from this location and then delete the file."
}

# Set Git GPG Configuration
set_git_gpg_configuration() {
    local key_id=$1
    local gpg_location=$(which gpg)
    git config --replace-all --global gpg.program "$gpg_location"
    git config --replace-all --global user.signingkey "$key_id"
    git config --global commit.gpgsign true
}

# Main Script Logic
echo "Checking GPG installation..."
name=$(read -p "Enter your name (e.g., John Doe): " name && echo $name)
email=$(read -p "Enter your verified email address for your GitHub account: " email && echo $email)

existing_key_id=$(get_key_id_by_email "$email")

if [[ -n $existing_key_id ]]; then
    echo "A GPG key associated with email: $email exists. Key ID: $existing_key_id"
    read -p "Do you want to generate a new one? (Yes/No): " choice
    if [[ $choice != "Yes" ]]; then
        echo "GPG key already exists. Exiting..."
        exit
    fi
fi

echo "Generating a new GPG key..."
invoke_gpg_key_generation "$email" "$name"
key_id=$(get_key_id_by_email "$email")

if [[ -n $key_id ]]; then
    export_gpg_public_key "$key_id"
    set_git_gpg_configuration "$key_id"
    echo "GPG key has been generated and configured for Git."
else
    echo "Failed to generate GPG key."
fi
