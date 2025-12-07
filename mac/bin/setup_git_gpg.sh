#!/bin/bash
set -euo pipefail

# -------------------------
# Dependency checks
# -------------------------

if ! command -v gpg >/dev/null 2>&1; then
    echo "Error: GPG is not installed. Please install it first."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed. Please install it first."
    exit 1
fi

# -------------------------
# Helpers
# -------------------------

new_gpg_command_file() {
    local email="$1"
    local name="$2"
    local temp_file
    temp_file=$(mktemp)

    cat <<EOF >"$temp_file"
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

invoke_gpg_key_generation() {
    local email="$1"
    local name="$2"
    local temp_file

    temp_file=$(new_gpg_command_file "$email" "$name")

    echo "Generating GPG key in batch mode..."
    # Modern GPG supports this; if you truly need legacy handling,
    # add a proper version compare and branch here.
    gpg --batch --generate-key "$temp_file"

    rm -f "$temp_file"
}

get_key_id_by_email() {
    local email="$1"

    # Take the first matching secret key ID (LONG format)
    gpg --list-secret-keys --keyid-format LONG "$email" 2>/dev/null \
        | awk '/^sec/{print $2}' \
        | head -n1 \
        | cut -d'/' -f2
}

export_gpg_public_key() {
    local key_id="$1"
    local public_key_file="$HOME/public_key.asc"

    gpg --export -a "$key_id" >"$public_key_file"
    echo "Public key exported to: $public_key_file"
    echo "Upload this key (or its contents) where needed, then remove the file if desired."
}

set_git_gpg_configuration() {
    local key_id="$1"
    local gpg_location

    gpg_location=$(command -v gpg)

    git config --global gpg.program "$gpg_location"
    git config --global user.signingkey "$key_id"
    git config --global commit.gpgsign true
}

# -------------------------
# Main
# -------------------------

echo "Checking GPG and git installation... OK"

# Prompt for user details
read -rp "Enter your name (e.g., John Doe): " name
read -rp "Enter your verified email address for your GitHub account: " email

if [[ -z "$name" || -z "$email" ]]; then
    echo "Error: Name and email cannot be empty."
    exit 1
fi

existing_key_id=$(get_key_id_by_email "$email" || true)

key_id=""

if [[ -n "$existing_key_id" ]]; then
    echo "Found existing GPG key for email '$email': $existing_key_id"
    read -rp "Use this existing key for Git signing? (yes/no): " choice
    choice_lc=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice_lc" in
        y|yes)
            key_id="$existing_key_id"
            ;;
        *)
            echo "Generating a new GPG key..."
            invoke_gpg_key_generation "$email" "$name"
            key_id=$(get_key_id_by_email "$email" || true)
            ;;
    esac
else
    echo "No existing GPG key found for '$email'. Generating a new one..."
    invoke_gpg_key_generation "$email" "$name"
    key_id=$(get_key_id_by_email "$email" || true)
fi

if [[ -z "$key_id" ]]; then
    echo "Error: Failed to locate a GPG key for '$email' after generation."
    exit 1
fi

echo "Using GPG key ID: $key_id"
export_gpg_public_key "$key_id"
set_git_gpg_configuration "$key_id"

echo
echo "GPG key has been generated (or selected) and configured for Git signing."
echo "Git will now sign commits by default using key: $key_id"
