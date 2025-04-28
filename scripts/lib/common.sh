#!/usr/bin/env bash
#
# Library: common.sh
# Description: Shared functions, variables, and settings for iac-mailu admin scripts.
#

# --- Strict Mode & Error Handling ---
set -euo pipefail

# --- Configuration Variables ---
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
# Assuming lib is one level down from scripts/
SCRIPTS_ROOT_DIR="$(cd "$LIB_DIR/.." &>/dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_ROOT_DIR/.." &>/dev/null && pwd)"
SRC_DIR="$REPO_ROOT/src"
DOMAINS_DIR="$SRC_DIR/domains"
VAULT_FILE="$SRC_DIR/vault/secrets.yml"
INVENTORY_FILE="$SRC_DIR/inventory/hosts"
PLAYBOOKS_DIR="$SRC_DIR/playbooks"
VAULT_PASS_FILE="$REPO_ROOT/.vault_pass" # Standard location for vault pass file

# --- Colors ---
CYAN='[36m'
GREEN='[32m'
RED='[31m'
YELLOW='[33m'
GRAY='[90m'
RESET='[0m'

# --- Helper Functions ---
info()    { echo -e "${CYAN}[*] $1${RESET}"; }
success() { echo -e "${GREEN}[+] $1${RESET}"; }
error()   { echo -e "${RED}[-] $1${RESET}" >&2; }
warning() { echo -e "${YELLOW}[!] $1${RESET}"; }
debug()   { [[ "${DEBUG:-false}" == "true" ]] && echo -e "${GRAY}[%] $1${RESET}"; }

# --- Input Validation ---
require_yq() {
    if ! command -v yq &>/dev/null; then
        error "'yq' (mikefarah/yq v4+) is required for this operation."
        error "You can try installing it using: $SCRIPTS_ROOT_DIR/mail-admin.sh install-prereqs"
        exit 1
    fi
    # Optional: Add version check if needed
}

require_ansible() {
    if ! command -v ansible &>/dev/null; then
        error "'ansible' is required for this operation. Please install Ansible."
        exit 1
    fi
}

require_ansible_vault() {
    if ! command -v ansible-vault &>/dev/null; then
        error "'ansible-vault' is required for this operation. Please install Ansible."
        exit 1
    fi
}

require_git() {
    if ! command -v git &>/dev/null; then
        error "'git' is required for this operation. Please install Git."
        exit 1
    fi
}

# --- Prerequisite Check ---
# Usage: check_prerequisites "yq" "ansible" "git"
check_prerequisites() {
    local missing=()
    info "Checking prerequisites: $*"
    for tool in "$@"; do
        case "$tool" in
            yq) require_yq ;;
            ansible) require_ansible ;;
            ansible-vault) require_ansible_vault ;;
            git) require_git ;;
            *) warning "Unknown prerequisite check requested: $tool" ;;
        esac || missing+=("$tool")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing prerequisites: ${missing[*]}. Please install them."
        exit 1
    else
        success "All checked prerequisites are installed."
    fi
}


# --- Install Prerequisites (Go yq) ---
# Note: This function remains here but might be better suited in a dedicated setup script.
install_yq() {
    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    local yq_dest="/usr/local/bin/yq" # Or suggest a user-local bin path
    info "Attempting to install Go-based yq (mikefarah/yq) to $yq_dest..."

    if command -v yq &>/dev/null; then
        local yq_version
        yq_version=$(yq --version 2>/dev/null || true)
        if [[ "$yq_version" =~ mikefarah ]]; then
            success "Go-based yq is already installed: $yq_version"
            return 0
        else
            warning "A different yq seems to be installed ($yq_version). Attempting to replace with Go-based yq."
        fi
    fi

    if [[ $EUID -ne 0 ]]; then
        warning "Root privileges (sudo) are required to install yq to $yq_dest."
        if sudo curl -L "$yq_url" -o "$yq_dest" && sudo chmod +x "$yq_dest"; then
             : # Explicitly do nothing on success
        else
            error "Failed to install yq using sudo. Please check permissions or install manually."
            return 1
        fi
    else
        if curl -L "$yq_url" -o "$yq_dest" && chmod +x "$yq_dest"; then
             : # Explicitly do nothing on success
        else
             error "Failed to install yq as root. Please check permissions or install manually."
             return 1
        fi
    fi

    # Verify installation
    if command -v yq &>/dev/null && yq --version 2>&1 | grep -qi mikefarah; then
        success "Go-based yq installed successfully: $(yq --version)"
    else
        error "Failed to verify Go-based yq installation. Please check $yq_dest."
        exit 1
    fi
}

# --- Vault Password Handling ---
get_vault_pass_args() {
    if [[ -f "$VAULT_PASS_FILE" ]]; then
        echo "--vault-password-file $VAULT_PASS_FILE"
    else
        # Prompt interactively if file doesn't exist
        echo "--ask-vault-pass"
    fi
}

# --- Common Ansible Playbook Runner ---
# Usage: run_ansible_playbook <playbook_name.yml> [extra_ansible_args...]
run_ansible_playbook() {
    require_ansible
    local playbook_file="$PLAYBOOKS_DIR/$1"
    shift # Remove playbook name from args
    local vault_args
    vault_args=$(get_vault_pass_args)

    if [[ ! -f "$playbook_file" ]]; then
        error "Playbook file not found: $playbook_file"
        exit 1
    fi

    info "Running playbook: $playbook_file $* $vault_args"
    # Use exec to replace the script process with ansible-playbook
    # Or run directly if you need to capture output/status within the script
    (cd "$SRC_DIR" && ansible-playbook -i "$INVENTORY_FILE" "$playbook_file" $vault_args "$@")

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        success "Playbook execution finished successfully."
    else
        error "Playbook execution failed with exit code $exit_code."
    fi
    return $exit_code
}

