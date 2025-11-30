#!/usr/bin/env bash

TOOLS_JSON="tools.json"
STATE_DIR="/Library/Application Support/nb-automation"
STATE_FILE="$STATE_DIR/installed_tools_state.json"


# -------------------------
# Helpers
# -------------------------

ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Installing jq..."
        brew install jq
    else
        echo "JQ is already installed."
    fi
}

check_and_delete_tools_json() {
    if [[ -f "$TOOLS_JSON" ]]; then
        echo "tools.json exists. Deleting."
        rm -f "$TOOLS_JSON"
    else
        echo "tools.json does not exist."
    fi
}

ensure_state_dir() {
    if [[ ! -d "$STATE_DIR" ]]; then
        sudo mkdir -p "$STATE_DIR"
        sudo chmod 777 "$STATE_DIR"
    fi
}

get_previous_state() {
    ensure_state_dir
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo ""
    fi
}

save_current_state() {
    local role="$1"
    local installed_tools_json="$2"

    ensure_state_dir

    cat <<EOF | sudo tee "$STATE_FILE" >/dev/null
{
  "last_role": "$role",
  "last_install_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "installed_tools": $installed_tools_json
}
EOF

    echo "State saved to $STATE_FILE"
}



# -------------------------
# Load role + tools
# -------------------------

ensure_brew_installed() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew missing — installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew is already installed."
    fi
}

load_tools_and_role() {
    if [[ ! -f "$TOOLS_JSON" ]]; then
        echo "Downloading tools.json..."
        curl -s -o "$TOOLS_JSON" \
            https://raw.githubusercontent.com/neurabytes/nb-local-setup/develop/windows/bin/tools.json
    fi

    # Get role keys as an array
    mapfile -t ROLE_KEYS < <(jq -r '.roles | keys[]' "$TOOLS_JSON")
    ROLE_COUNT=${#ROLE_KEYS[@]}

    echo "Select your role:"
    for ((i=0; i<ROLE_COUNT; i++)); do
        role="${ROLE_KEYS[i]}"
        desc=$(jq -r ".roles[\"$role\"].description" "$TOOLS_JSON")
        printf "%d. %s\n" "$((i+1))" "$desc"
    done

    while true; do
        read -rp "Enter choice (1-$ROLE_COUNT): " SEL
        if [[ "$SEL" =~ ^[0-9]+$ ]] && (( SEL >= 1 && SEL <= ROLE_COUNT )); then
            break
        fi
    done

    INDEX=$((SEL-1))
    SELECTED_ROLE="${ROLE_KEYS[INDEX]}"

    # Tools JSON for this role (compact so it’s a single line)
    TOOLS_JSON_DATA=$(jq -c ".roles[\"$SELECTED_ROLE\"].tools" "$TOOLS_JSON")

    echo "Selected role: $SELECTED_ROLE"
}


# -------------------------
# Remove old tools
# -------------------------

remove_obsolete_tools() {
    local prev_json="$1"
    local current_tool_json="$2"

    mapfile -t prev_list < <(echo "$prev_json" | jq -r '.installed_tools | keys[]')
    mapfile -t curr_list < <(echo "$current_tool_json" | jq -r 'keys[]')

    for prev in "${prev_list[@]}"; do
        if ! printf '%s\n' "${curr_list[@]}" | grep -qx "$prev"; then
            echo "Removing obsolete tool: $prev"
            brew uninstall "$prev"
        fi
    done
}

# -------------------------
# Install / upgrade tools
# -------------------------

install_or_upgrade_tools() {
    local tools_json="$1"

    mapfile -t names < <(echo "$tools_json" | jq -r 'keys[]')

    for tool in "${names[@]}"; do
        VERSION=$(echo "$tools_json" | jq -r ".[\"$tool\"]")

        if brew list --versions "$tool" >/dev/null 2>&1; then
            echo "$tool already installed — checking version..."
            brew upgrade "$tool" || true
        else
            echo "Installing $tool..."
            brew install "$tool"
        fi
    done
}

uninstall_tools() {
    local tools_json="$1"

    mapfile -t names < <(echo "$tools_json" | jq -r 'keys[]')

    for tool in "${names[@]}"; do
        if brew list --versions "$tool" >/dev/null 2>&1; then
            echo "Uninstalling $tool"
            brew uninstall "$tool"
        fi
    done
}


# -------------------------
# Final Report
# -------------------------

final_report() {
    local tools_json="$1"

    echo "Installed tools:"
    brew list --versions
}


# -------------------------
# Main Flow
# -------------------------

ensure_brew_installed
ensure_jq

load_tools_and_role   # sets SELECTED_ROLE and TOOLS_JSON_DATA

PREVIOUS_STATE=$(get_previous_state)

if [[ -n "$PREVIOUS_STATE" ]]; then
    remove_obsolete_tools "$PREVIOUS_STATE" "$TOOLS_JSON_DATA"
fi

read -rp "Enter action (install/uninstall): " ACTION

if [[ "$ACTION" == "install" ]]; then
    install_or_upgrade_tools "$TOOLS_JSON_DATA"
    save_current_state "$SELECTED_ROLE" "$TOOLS_JSON_DATA"

elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall_tools "$TOOLS_JSON_DATA"
    save_current_state "" "{}"
else
    echo "Invalid action."
    exit 1
fi

final_report "$TOOLS_JSON_DATA"
check_and_delete_tools_json


#SELECTED_ROLE="${RESULT[0]}"
#TOOLS_JSON_DATA="${RESULT[1]}"
#
#PREVIOUS_STATE=$(get_previous_state)
#
#if [[ -n "$PREVIOUS_STATE" ]]; then
#    remove_obsolete_tools "$(echo "$PREVIOUS_STATE")" "$TOOLS_JSON_DATA"
#fi
#
#read -rp "Enter action (install/uninstall): " ACTION
#
#if [[ "$ACTION" == "install" ]]; then
#    install_or_upgrade_tools "$TOOLS_JSON_DATA"
#    INSTALLED="$(echo "$TOOLS_JSON_DATA")"
#    save_current_state "$SELECTED_ROLE" "$INSTALLED"
#
#elif [[ "$ACTION" == "uninstall" ]]; then
#    uninstall_tools "$TOOLS_JSON_DATA"
#    save_current_state "" "{}"
#else
#    echo "Invalid action."
#    exit 1
#fi
#
#final_report "$TOOLS_JSON_DATA"
#
#check_and_delete_tools_json