#!/usr/bin/env bash
#
# Script: mail-users.sh
# Description: Manage users within iac-mailu domain configurations (add, list, remove users).
# Usage: mail-admin.sh user [domain] <command> [username]
#
# Follows iac-mailu standards: robust input validation, colorized output, status reporting, strict error handling, and no logic outside functions/main.
#
# Commands:
#   list [domain]       List users for the specified domain (prompts if domain missing).
#   add [domain] [user] Add a new user to the domain configuration and vault (prompts if missing).
#   remove [domain] [user] Remove a user from the domain configuration (prompts if missing, warns about vault).
#   help                Show this help message.
#
# See project STYLE_GUIDE.md for coding and output standards.

set -euo pipefail

# --- Common Library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh" || { echo -e "\033[31m[-] Error: Unable to source common.sh from mail-users.sh\033[0m"; exit 1; }

# --- Prevent Direct Execution Unless Dispatched ---
if [[ "${MAILU_ADMIN_DISPATCH:-}" != "1" ]]; then
    echo -e "${RED}[-] This script is an internal module. Use 'mail-admin.sh' as the entry point.${RESET}"
    echo "Usage: mail-admin.sh user [domain] <command> [username]"
    exit 2
fi

# --- Helper Functions ---

# Print usage/help
user_help() {
    echo -e "${CYAN}[*] User Management Module Help${RESET}"
    echo "Usage: mail-admin.sh user [domain] <command> [username]"
    echo ""
    echo "Commands:"
    echo "  list [domain]       List users for the specified domain (prompts if domain missing)."
    echo "  add [domain] [user] Add a new user to the domain configuration and vault (prompts if missing)."
    echo "  remove [domain] [user] Remove a user from the domain configuration (prompts if missing)."
    echo "  help, -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  mail-admin.sh user list example.com"
    echo "  mail-admin.sh user add example.com support"
    echo "  mail-admin.sh user remove example.com olduser"
    echo ""
    echo "Notes:"
    echo "- Domain config files are in src/domains/"
    echo "- Secrets are managed in src/vault/secrets.yml"
    echo "- Run the main playbook ('site.yml' or 'manage_users.yml') to apply changes."
}

# Validate domain name (RFC 1035)
is_valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](\.[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])+$ ]]
}

# Validate username (alphanumeric, hyphen, underscore, no leading/trailing -/_)
is_valid_username() {
    local username="$1"
    [[ "$username" =~ ^[a-zA-Z0-9]([a-zA-Z0-9_-]*[a-zA-Z0-9])?$ ]]
}

# Generate a secure 32-char password
generate_password() {
    openssl rand -base64 32 | head -c 32
}

# Get domain file path and check existence
get_domain_file() {
    local domain_name="$1"
    if ! is_valid_domain "$domain_name"; then
        print_error "Invalid domain name format: '$domain_name'"
        exit 1
    fi
    domain_file="$DOMAINS_DIR/${domain_name}.yml"
    if [[ ! -f "$domain_file" ]]; then
        print_error "Domain configuration file not found: $domain_file"
        print_warn "Available domains:"
        local available_domains
        available_domains=$(find "$DOMAINS_DIR" -maxdepth 1 -name '*.yml' -printf '%f\n' | sed 's/\.yml$//')
        if [[ -n "$available_domains" ]]; then
            echo "$available_domains" | sed 's/^/ - /'
        else
            print_warn "No domain files found in $DOMAINS_DIR"
        fi
        exit 1
    fi
}

# --- Main Action Functions ---

# List users for a domain
user_list() {
    local domain_name="${1:-}"
    if [[ -z "$domain_name" ]]; then
        read -rp "Enter domain name to list users for: " domain_name
        if [[ -z "$domain_name" ]]; then
            print_error "Domain name cannot be empty."
            exit 1
        fi
    fi
    get_domain_file "$domain_name"
    check_prerequisites "yq"
    print_info "Listing users for domain '$domain_name' from $domain_file..."
    local users
    users=$(yq eval '.users[].name' "$domain_file")
    if [[ -z "$users" || "$users" == "null" ]]; then
        print_warn "No users found for domain '$domain_name'."
    else
        print_success "Users for domain '$domain_name':"
        echo "$users" | sed 's/^/ - /'
    fi
}

# Add a user to a domain
user_add() {
    local domain_name="${1:-}"
    local username="${2:-}"
    if [[ -z "$domain_name" ]]; then
        read -rp "Enter domain name to add user to: " domain_name
        if [[ -z "$domain_name" ]]; then
            print_error "Domain name cannot be empty."
            exit 1
        fi
    fi
    get_domain_file "$domain_name"
    if [[ -z "$username" ]]; then
        read -rp "Enter username to add (e.g., 'support'): " username
        if [[ -z "$username" ]]; then
            print_error "Username cannot be empty."
            exit 1
        fi
    fi
    if ! is_valid_username "$username"; then
        print_error "Invalid username format: '$username'. Use alphanumeric characters, hyphens, or underscores."
        exit 1
    fi
    check_prerequisites "yq" "ansible-vault"
    print_info "Attempting to add user '$username' to domain '$domain_name'"
    # Check if user already exists
    if yq eval ".users[] | select(.name == \"$username\")" "$domain_file" | grep -q 'name:'; then
        print_error "User '$username' already exists in $domain_file."
        exit 1
    fi
    # Generate password and vault variable name
    local password
    password=$(generate_password)
    local vault_var_name="vault_${username}_${domain_name//./_}"
    print_info "Generated password for '$username@$domain_name':"
    print_success "$password"
    print_warn "This password will be added to the vault and displayed only once. Store it securely."
    # Add password to vault (update or append)
    print_info "Adding password to vault ($VAULT_FILE) for variable '$vault_var_name'"
    local temp_vault
    temp_vault=$(mktemp)
    # Decrypt vault to temp file
    ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" > "$temp_vault" || { print_error "Failed to decrypt vault."; rm -f "$temp_vault"; exit 1; }
    # Remove any existing line for this variable
    sed -i "/^${vault_var_name}:/d" "$temp_vault"
    # Append new secret
    echo "${vault_var_name}: '$password'" >> "$temp_vault"
    # Validate YAML
    if ! yq eval "$temp_vault" > /dev/null; then
        print_error "Vault file would become invalid YAML. Aborting."
        rm -f "$temp_vault"
        exit 1
    fi
    # Re-encrypt
    ansible-vault encrypt "$temp_vault" --vault-password-file "$VAULT_PASS_FILE" --output "$VAULT_FILE" || { print_error "Failed to re-encrypt vault."; rm -f "$temp_vault"; exit 1; }
    rm -f "$temp_vault"
    print_success "Password added to vault for '$vault_var_name'."
    # Add user to domain YAML file
    print_info "Adding user '$username' to $domain_file"
    local new_user_yaml
    new_user_yaml=$(printf '{"name": "%s", "password_var": "%s"}' "$username" "$vault_var_name")
    if yq eval ".users += [${new_user_yaml}]" -i "$domain_file"; then
        print_success "User '$username' added to $domain_file."
        print_warn "Run the main playbook ('site.yml' or 'manage_users.yml') to apply the changes to the Mailu instance."
    else
        print_error "Failed to add user '$username' to $domain_file using yq."
        print_warn "Vault update was likely successful, but the domain file needs manual correction."
        exit 1
    fi
}

# Remove a user from a domain
user_remove() {
    local domain_name="${1:-}"
    local username="${2:-}"
    if [[ -z "$domain_name" ]]; then
        read -rp "Enter domain name to remove user from: " domain_name
        if [[ -z "$domain_name" ]]; then
            print_error "Domain name cannot be empty."
            exit 1
        fi
    fi
    get_domain_file "$domain_name"
    if [[ -z "$username" ]]; then
        read -rp "Enter username to remove (e.g., 'support'): " username
        if [[ -z "$username" ]]; then
            print_error "Username cannot be empty."
            exit 1
        fi
    fi
    check_prerequisites "yq"
    print_info "Attempting to remove user '$username' from domain '$domain_name'"
    # Check if user exists
    if ! yq eval ".users[] | select(.name == \"$username\")" "$domain_file" | grep -q 'name:'; then
        print_error "User '$username' not found in $domain_file."
        exit 1
    fi
    local vault_var_name="vault_${username}_${domain_name//./_}"
    print_warn "This will remove the user '$username' entry from $domain_file."
    print_warn "The corresponding secret '$vault_var_name' in the vault ($VAULT_FILE) will NOT be automatically removed."
    print_warn "You may want to remove it manually later using 'ansible-vault edit $VAULT_FILE'."
    read -rp "Are you sure you want to remove user '$username' from the domain configuration? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
    # Remove user from domain YAML file
    print_info "Removing user '$username' from $domain_file"
    if yq eval "del(.users[] | select(.name == \"$username\"))" -i "$domain_file"; then
        print_success "User '$username' removed from $domain_file."
        print_warn "Remember to manually remove '$vault_var_name' from the vault if desired."
        print_warn "Run the main playbook ('site.yml' or 'manage_users.yml') to apply the changes to the Mailu instance."
    else
        print_error "Failed to remove user '$username' from $domain_file using yq."
        exit 1
    fi
}

# --- Main Script Logic ---
main() {
    local domain=""
    local command=""
    local username=""
    local args=("$@")
    # Argument parsing: support flexible order
    if [[ $# -gt 0 ]]; then
        case "${args[0]}" in
            list|add|remove|help|-h|--help)
                command="${args[0]}"
                shift || true
                if [[ "$command" == "add" || "$command" == "remove" ]]; then
                    if [[ $# -gt 0 ]]; then
                        domain="${1}"; shift || true
                        if [[ $# -gt 0 ]]; then
                            username="${1}"; shift || true
                        fi
                    fi
                elif [[ "$command" == "list" ]]; then
                    if [[ $# -gt 0 ]]; then
                        domain="${1}"; shift || true
                    fi
                fi
                ;;
            *)
                domain="${args[0]}"; shift || true
                if [[ $# -gt 0 ]]; then
                    command="${1}"; shift || true
                    if [[ "$command" == "add" || "$command" == "remove" ]]; then
                        if [[ $# -gt 0 ]]; then
                            username="${1}"; shift || true
                        fi
                    fi
                else
                    command="help"
                fi
                ;;
        esac
    else
        command="help"
    fi
    case "$command" in
        list)
            user_list "$domain"
            ;;
        add)
            user_add "$domain" "$username"
            ;;
        remove)
            user_remove "$domain" "$username"
            ;;
        help|-h|--help|"")
            user_help
            ;;
        *)
            print_error "Unknown command or invalid argument combination: '$command $*'"
            print_warn "Run 'mail-admin.sh user help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
