#!/usr/bin/env bash

set -u  # (keep -e/-o pipefail off while you're still iterating)

TOOLS_JSON="tools.json"
STATE_DIR="/Library/Application Support/nb-automation"
STATE_FILE="$STATE_DIR/installed_tools_state.json"

DRY_RUN=false   # <- set to false later when you want real installs
DEBUG=true     # <- set to false to quiet debug logs

debug() {
    if [ "${DEBUG}" = "true" ]; then
        printf '[DEBUG] %s\n' "$*" >&2
    fi
}

# -------------------------
# Helpers
# -------------------------

ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Installing jq..."
        if [ "$DRY_RUN" = "true" ]; then
            echo "(DRY RUN) brew install jq"
        else
            brew install jq
        fi
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
        if [ "$DRY_RUN" = "true" ]; then
            debug "Would create state dir: $STATE_DIR (DRY RUN)"
        else
            sudo mkdir -p "$STATE_DIR"
            sudo chmod 777 "$STATE_DIR"
        fi
    fi
}

get_previous_state() {
    # Suppress debug from ensure_state_dir so it doesn't pollute JSON
    ensure_state_dir >/dev/null 2>&1
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo ""
    fi
}

save_current_state() {
    local role="$1"
    local installed_tools_json="$2"

    ensure_state_dir >/dev/null 2>&1

    if [ "$DRY_RUN" = "true" ]; then
        debug "Would save state for role=$role JSON=$installed_tools_json (DRY RUN)"
        return
    fi

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
# Homebrew
# -------------------------

ensure_brew_installed() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew missing — installing..."
        if [ "$DRY_RUN" = "true" ]; then
            echo "(DRY RUN) /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    else
        echo "Homebrew is already installed."
    fi
}

# -------------------------
# Load role + tools
# -------------------------

load_tools_and_role() {
    debug "load_tools_and_role: start"

    if [[ ! -f "$TOOLS_JSON" ]]; then
        echo "Downloading tools.json..."
        curl -s -o "$TOOLS_JSON" \
            https://raw.githubusercontent.com/neurabytes/nb-automation-devtools/refs/heads/feature/mac-installation/mac/bin/tools.json
    fi

    ROLE_KEYS=()
    while IFS= read -r role; do
        ROLE_KEYS+=( "$role" )
    done < <(jq -r '.roles | keys[]' "$TOOLS_JSON")

    ROLE_COUNT=${#ROLE_KEYS[@]}
    debug "Found $ROLE_COUNT roles"

    if [[ "$ROLE_COUNT" -eq 0 ]]; then
        echo "No roles found in $TOOLS_JSON. Check the JSON structure."
        exit 1
    fi

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
    TOOLS_JSON_DATA=$(jq -c ".roles[\"$SELECTED_ROLE\"].tools" "$TOOLS_JSON")

    debug "Selected role key: $SELECTED_ROLE"
    debug "Tools JSON for role: $TOOLS_JSON_DATA"
    echo "Selected role: $SELECTED_ROLE"
}

# -------------------------
# Remove old tools
# -------------------------

remove_obsolete_tools() {
    local prev_json="$1"
    local current_tool_json="$2"

    debug "remove_obsolete_tools: prev_json=$prev_json"
    debug "remove_obsolete_tools: current_tool_json=$current_tool_json"

    # Always initialize arrays so set -u is happy
    local PREV_LIST=()
    local CURR_LIST=()

    # previous installed tools keys (may be empty)
    while IFS= read -r key; do
        [ -n "$key" ] && PREV_LIST+=( "$key" )
    done < <(echo "$prev_json" | jq -r '.installed_tools // {} | keys[]?')

    # current role tools keys
    while IFS= read -r key; do
        [ -n "$key" ] && CURR_LIST+=( "$key" )
    done < <(echo "$current_tool_json" | jq -r 'keys[]?')

    if [ "${#PREV_LIST[@]}" -eq 0 ]; then
        debug "No previously recorded tools to check for removal."
        return
    fi

    for prev in "${PREV_LIST[@]}"; do
        local found=0
        for curr in "${CURR_LIST[@]}"; do
            if [[ "$prev" == "$curr" ]]; then
                found=1
                break
            fi
        done

        if [ "$found" -eq 0 ]; then
            if [ "$DRY_RUN" = "true" ]; then
                echo "Would uninstall obsolete tool: $prev   (DRY RUN)"
            else
                echo "Uninstalling obsolete tool: $prev"
                brew uninstall "$prev" || true
            fi
        fi
    done
}


# -------------------------
# Install / upgrade tools
# -------------------------

install_or_upgrade_tools() {
    local tools_json="$1"

    debug "install_or_upgrade_tools: tools_json=$tools_json"

    NAMES=()
    while IFS= read -r key; do
        NAMES+=( "$key" )
    done < <(echo "$tools_json" | jq -r 'keys[]')

    for tool in "${NAMES[@]}"; do
        VERSION=$(echo "$tools_json" | jq -r ".[\"$tool\"]")

        if brew list --versions "$tool" >/dev/null 2>&1; then
            if [ "$DRY_RUN" = "true" ]; then
                echo "Would upgrade $tool to $VERSION   (DRY RUN)"
            else
                echo "Upgrading $tool to $VERSION..."
                brew upgrade "$tool" || true
            fi
        else
            if [ "$DRY_RUN" = "true" ]; then
                echo "Would install $tool ($VERSION)   (DRY RUN)"
            else
                echo "Installing $tool ($VERSION)..."
                brew install "$tool"
            fi
        fi
    done
}

uninstall_tools() {
    local tools_json="$1"

    debug "uninstall_tools: tools_json=$tools_json"

    # Collect tool names from JSON
    NAMES=()
    while IFS= read -r key; do
        NAMES+=( "$key" )
    done < <(echo "$tools_json" | jq -r 'keys[]')

    # Filter to only those actually installed
    INSTALLED_TO_REMOVE=()
    for tool in "${NAMES[@]}"; do
        if brew list --versions "$tool" >/dev/null 2>&1; then
            INSTALLED_TO_REMOVE+=( "$tool" )
        fi
    done

    if [ "${#INSTALLED_TO_REMOVE[@]}" -eq 0 ]; then
        echo "No tools from role '$SELECTED_ROLE' are currently installed via Homebrew."
        return
    fi

    echo "The following Homebrew packages from role '$SELECTED_ROLE' will be uninstalled:"
    for t in "${INSTALLED_TO_REMOVE[@]}"; do
        echo "  - $t"
    done

    read -rp "Proceed with uninstall? (y/N): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Uninstall cancelled."
        return
    fi

    for tool in "${INSTALLED_TO_REMOVE[@]}"; do
        if [ "$DRY_RUN" = "true" ]; then
            echo "Would uninstall $tool   (DRY RUN)"
        else
            echo "Uninstalling $tool"
            if ! brew uninstall "$tool"; then
                echo "Warning: failed to uninstall $tool" >&2
            fi
        fi
    done
}


# -------------------------
# Final Report
# -------------------------

final_report() {
    echo "Installed tools (real system state):"
    brew list --versions
}

# -------------------------
# Main Flow
# -------------------------

debug "Script start; DRY_RUN=$DRY_RUN DEBUG=$DEBUG"

ensure_brew_installed
ensure_jq

load_tools_and_role   # sets SELECTED_ROLE and TOOLS_JSON_DATA

PREVIOUS_STATE=$(get_previous_state)
debug "PREVIOUS_STATE raw: $PREVIOUS_STATE"

if [[ -n "$PREVIOUS_STATE" ]]; then
    debug "Previous state not empty -> calling remove_obsolete_tools"
    remove_obsolete_tools "$PREVIOUS_STATE" "$TOOLS_JSON_DATA"
else
    debug "No previous state found; skipping obsolete removal"
fi

read -rp "Enter action (install/uninstall): " ACTION

if [[ "$ACTION" == "install" ]]; then
    debug "Action = install"
    install_or_upgrade_tools "$TOOLS_JSON_DATA"
    save_current_state "$SELECTED_ROLE" "$TOOLS_JSON_DATA"

elif [[ "$ACTION" == "uninstall" ]]; then
    debug "Action = uninstall"
    uninstall_tools "$TOOLS_JSON_DATA"
    save_current_state "" "{}"

else
    echo "Invalid action."
    exit 1
fi

final_report
check_and_delete_tools_json
