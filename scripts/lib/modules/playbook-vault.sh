#!/usr/bin/env bash
#
# Script: playbook-vault.sh
# Description: Manage secrets in the iac-mailu Ansible vault (init, add, remove, destroy, etc.).
# Usage: mail-admin.sh vault <command> [options]
#
# Commands:
#   view          View the decrypted vault content
#   edit          Edit the encrypted vault file
#   encrypt <file> Encrypt a file using the vault password
#   decrypt <file> Decrypt a file using the vault password
#   rekey         Change the vault password
#   add <key> <value> Add/Update a key-value pair (plaintext value)
#   remove <key>  Remove a key from the vault
#   init          Initialize the vault file and password file if they don't exist
#   destroy       Delete the vault file and password file (requires confirmation)
#   help          Show this help message
#

# ---------------------------------------------------------------------------
# WARNING: This is an internal support script for iac-mailu.
# Do NOT run this script directly. Use 'mail-admin.sh' as the entry point.
# ---------------------------------------------------------------------------

# --- Common Library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh" || { echo "Error: Unable to source common.sh"; exit 1; }

# --- Prevent Direct Execution Unless Dispatched ---
if [[ "${MAILU_ADMIN_DISPATCH:-}" != "1" ]]; then
    echo -e "\033[31m[-] This script is an internal module. Use 'mail-admin.sh' as the entry point.\033[0m"
    echo "Usage: mail-admin.sh vault <command> [options]"
    exit 2
fi

# --- Vault Management Functions ---

vault_view() {
    check_prerequisites "ansible-vault"
    info "Viewing vault file: $VAULT_FILE"
    local vault_args
    vault_args=$(get_vault_pass_args)
    (cd "$SRC_DIR" && ansible-vault view "$VAULT_FILE" $vault_args) || error "Failed to view vault."
}

vault_edit() {
    check_prerequisites "ansible-vault"
    info "Editing vault file: $VAULT_FILE"
    local vault_args
    vault_args=$(get_vault_pass_args)
    (cd "$SRC_DIR" && ansible-vault edit "$VAULT_FILE" $vault_args)
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        success "Vault edit session finished."
    else
        error "Vault edit session failed or was cancelled."
    fi
    return $exit_code
}

vault_encrypt_file() {
    check_prerequisites "ansible-vault"
    local file_to_encrypt="$1"
    if [[ -z "$file_to_encrypt" ]]; then
        error "Usage: $0 encrypt <path/to/file>"
        exit 1
    fi
    if [[ ! -f "$file_to_encrypt" ]]; then
        error "File not found: $file_to_encrypt"
        exit 1
    fi
    # Check if already encrypted? ansible-vault encrypt will overwrite
    info "Encrypting file: $file_to_encrypt"
    local vault_args
    vault_args=$(get_vault_pass_args)
    # Run from repo root to ensure relative paths work if needed
    (cd "$REPO_ROOT" && ansible-vault encrypt "$file_to_encrypt" $vault_args)
    local exit_code=$?
     if [[ $exit_code -eq 0 ]]; then
        success "File encrypted successfully: $file_to_encrypt"
    else
        error "Failed to encrypt file."
    fi
    return $exit_code
}

vault_decrypt_file() {
    check_prerequisites "ansible-vault"
    local file_to_decrypt="$1"
    local output_file="${2:-}" # Optional output file

    if [[ -z "$file_to_decrypt" ]]; then
        error "Usage: $0 decrypt <path/to/encrypted_file> [output_file]"
        exit 1
    fi
     if [[ ! -f "$file_to_decrypt" ]]; then
        error "Encrypted file not found: $file_to_decrypt"
        exit 1
    fi

    info "Decrypting file: $file_to_decrypt"
    local vault_args
    vault_args=$(get_vault_pass_args)
    local decrypt_cmd="ansible-vault decrypt "$file_to_decrypt" $vault_args"

    if [[ -n "$output_file" ]]; then
        info "Outputting decrypted content to: $output_file"
        decrypt_cmd+=" --output "$output_file""
    else
        info "Outputting decrypted content to standard output."
    fi

    # Run from repo root
    eval "(cd "$REPO_ROOT" && $decrypt_cmd)"
    local exit_code=$?
     if [[ $exit_code -eq 0 ]]; then
        success "File decrypted successfully."
    else
        error "Failed to decrypt file."
    fi
    return $exit_code
}

vault_rekey() {
    check_prerequisites "ansible-vault"
    info "Rekeying vault file: $VAULT_FILE"
    warning "You will be prompted for the current vault password and the new vault password."
    # Cannot use vault pass file for rekey, must be interactive
    (cd "$SRC_DIR" && ansible-vault rekey "$VAULT_FILE")
    local exit_code=$?
     if [[ $exit_code -eq 0 ]]; then
        success "Vault rekeyed successfully."
        warning "If you were using a vault password file ($VAULT_PASS_FILE), update it with the new password."
    else
        error "Failed to rekey vault."
    fi
    return $exit_code
}

vault_add_key() {
    check_prerequisites "ansible-vault" "yq"
    local key="$1"
    local value="$2"

    if [[ -z "$key" || -z "$value" ]]; then
        error "Usage: $0 add <key_name> <secret_value>"
        exit 1
    fi

    info "Adding/Updating key '$key' in vault: $VAULT_FILE"
    local vault_args
    vault_args=$(get_vault_pass_args)
    local temp_vault_file
    temp_vault_file=$(mktemp)

    # Decrypt vault to temp file
    info "Decrypting vault to temporary file..."
    if ! (cd "$SRC_DIR" && ansible-vault decrypt "$VAULT_FILE" --output "$temp_vault_file" $vault_args); then
        error "Failed to decrypt vault file."
        rm -f "$temp_vault_file"
        exit 1
    fi

    # Use yq to add/update the key
    info "Updating key '$key' in temporary file..."
    if ! yq eval -i ".${key} = "${value}"" "$temp_vault_file"; then
        error "Failed to update key using yq. Check key format or temp file content."
        rm -f "$temp_vault_file"
        exit 1
    fi

    # Re-encrypt the temp file back to the original vault file
    info "Re-encrypting vault file..."
     if ! (cd "$SRC_DIR" && ansible-vault encrypt "$temp_vault_file" --output "$VAULT_FILE" $vault_args); then
        error "Failed to re-encrypt vault file."
        warning "Original vault file may be unchanged. Check $temp_vault_file for updated content."
        # Consider leaving temp file for recovery? Or just error out.
        # rm -f "$temp_vault_file" # Clean up temp file on failure too? Maybe not.
        exit 1
    fi

    # Clean up temp file on success
    rm -f "$temp_vault_file"
    success "Key '$key' added/updated in vault successfully."
}

vault_remove_key() {
     check_prerequisites "ansible-vault" "yq"
    local key="$1"

    if [[ -z "$key" ]]; then
        error "Usage: $0 remove <key_name>"
        exit 1
    fi

    info "Removing key '$key' from vault: $VAULT_FILE"
    local vault_args
    vault_args=$(get_vault_pass_args)
    local temp_vault_file
    temp_vault_file=$(mktemp)

    # Decrypt vault to temp file
    info "Decrypting vault to temporary file..."
    if ! (cd "$SRC_DIR" && ansible-vault decrypt "$VAULT_FILE" --output "$temp_vault_file" $vault_args); then
        error "Failed to decrypt vault file."
        rm -f "$temp_vault_file"
        exit 1
    fi

    # Check if key exists before trying to delete
    if ! yq eval ".${key}" "$temp_vault_file" &> /dev/null; then
         warning "Key '$key' not found in the vault. No changes made."
         rm -f "$temp_vault_file"
         exit 0
    fi

    # Use yq to remove the key
    info "Removing key '$key' in temporary file..."
    if ! yq eval -i "del(.${key})" "$temp_vault_file"; then
        error "Failed to remove key using yq. Check key format or temp file content."
        rm -f "$temp_vault_file"
        exit 1
    fi

    # Re-encrypt the temp file back to the original vault file
    info "Re-encrypting vault file..."
     if ! (cd "$SRC_DIR" && ansible-vault encrypt "$temp_vault_file" --output "$VAULT_FILE" $vault_args); then
        error "Failed to re-encrypt vault file."
        warning "Original vault file may be unchanged. Check $temp_vault_file for updated content."
        exit 1
    fi

    # Clean up temp file on success
    rm -f "$temp_vault_file"
    success "Key '$key' removed from vault successfully."
}

vault_init() {
    check_prerequisites "ansible-vault" "yq"
    
    info "Initializing vault system..."
    
    # 1. Check if vault password file exists, create if it doesn't
    if [[ ! -f "$VAULT_PASS_FILE" ]]; then
        info "Vault password file doesn't exist. Creating ${VAULT_PASS_FILE}..."
        
        # Generate a secure random password or prompt for one
        local create_random_pass
        read -p "Do you want to generate a random password? [Y/n]: " create_random_pass
        create_random_pass="${create_random_pass:-Y}"
        
        if [[ "${create_random_pass^^}" == "Y" ]]; then
            # Generate a secure random password (32 characters)
            if command -v openssl &> /dev/null; then
                password=$(openssl rand -base64 24)
            else
                # Fallback method if openssl is not available
                password=$(head -c 24 /dev/urandom | base64)
            fi
            echo "$password" > "$VAULT_PASS_FILE"
            success "Generated random vault password and saved to ${VAULT_PASS_FILE}"
            warning "IMPORTANT: Keep this password file secure. Anyone with access to it can decrypt your secrets."
        else
            # Prompt for password
            local password
            local password_confirm
            while true; do
                read -s -p "Enter vault password: " password
                echo
                read -s -p "Confirm vault password: " password_confirm
                echo
                
                if [[ "$password" == "$password_confirm" ]]; then
                    echo "$password" > "$VAULT_PASS_FILE"
                    break
                else
                    error "Passwords don't match. Please try again."
                fi
            done
            success "Vault password saved to ${VAULT_PASS_FILE}"
            warning "IMPORTANT: Keep this password file secure. Anyone with access to it can decrypt your secrets."
        fi
        
        # Set appropriate permissions
        chmod 600 "$VAULT_PASS_FILE"
    else
        info "Vault password file ${VAULT_PASS_FILE} already exists."
    fi

    # 2. Check if vault file exists, create if it doesn't
    if [[ ! -f "$VAULT_FILE" ]]; then
        info "Vault file doesn't exist. Creating ${VAULT_FILE}..."
        
        # Create vault directory if it doesn't exist
        mkdir -p "$(dirname "$VAULT_FILE")"
        
        # Create a basic vault YAML file with a timestamp
        local timestamp
        timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
        
        # Create an initial YAML structure
        cat > "$VAULT_FILE" << EOF
# Ansible Vault file for iac-mailu
# Created: $timestamp
# 
# This file contains sensitive information and should always be encrypted.
# Use 'mail-admin.sh vault edit' to modify this file.

# Example structure:
# vault_user_example_com: "user_password"
# vault_cloudflare_api_token: "your-cloudflare-token"
# vault_mailu_admin_secret: "your-admin-secret"
EOF

        # Encrypt the new vault file
        local vault_args
        vault_args=$(get_vault_pass_args)
        
        if ! (cd "$SRC_DIR" && ansible-vault encrypt "$VAULT_FILE" $vault_args); then
            error "Failed to encrypt new vault file."
            return 1
        fi
        
        success "Vault file created and encrypted: ${VAULT_FILE}"
    elif ! grep -q "ANSIBLE_VAULT" "$VAULT_FILE"; then
        # File exists but is not encrypted
        warning "Vault file ${VAULT_FILE} exists but is not encrypted. Encrypting..."
        
        # Encrypt the existing vault file
        local vault_args
        vault_args=$(get_vault_pass_args)
        
        if ! (cd "$SRC_DIR" && ansible-vault encrypt "$VAULT_FILE" $vault_args); then
            error "Failed to encrypt existing vault file."
            return 1
        fi
        
        success "Existing vault file encrypted: ${VAULT_FILE}"
    else
        info "Vault file ${VAULT_FILE} already exists and is encrypted."
    fi
    
    success "Vault system initialized successfully."
    info "You can now use 'mail-admin.sh vault add <key> <value>' to add secrets."
}

vault_destroy() {
    local force="${1:-}"
    local confirm="no"
    
    if [[ "$force" != "--force" ]]; then
        warning "WARNING! This will permanently delete your vault file and password file."
        warning "All secrets stored in the vault will be LOST FOREVER."
        read -p "Are you absolutely sure you want to continue? Type 'yes' to confirm: " confirm
        
        if [[ "$confirm" != "yes" ]]; then
            info "Operation cancelled."
            return 0
        fi
    fi
    
    # Check if files exist before trying to delete them
    if [[ -f "$VAULT_PASS_FILE" ]]; then
        info "Deleting vault password file: ${VAULT_PASS_FILE}..."
        rm -f "$VAULT_PASS_FILE"
        success "Vault password file deleted."
    else
        info "Vault password file does not exist: ${VAULT_PASS_FILE}"
    fi
    
    if [[ -f "$VAULT_FILE" ]]; then
        info "Deleting vault file: ${VAULT_FILE}..."
        rm -f "$VAULT_FILE"
        success "Vault file deleted."
    else
        info "Vault file does not exist: ${VAULT_FILE}"
    fi
    
    success "Vault system destroyed."
    warning "If you need to use the vault again, run 'mail-admin.sh vault init' to initialize a new vault."
}

vault_help() {
    echo -e "\033[36m[*] Vault Management Module Help\033[0m"
    echo "Usage: mail-admin.sh vault <command> [options]"
    echo ""
    echo "Commands:"
    echo "  view                View the decrypted vault content"
    echo "  edit                Edit the encrypted vault file"
    echo "  encrypt <file>      Encrypt a file using the vault password"
    echo "  decrypt <file> [out] Decrypt a file (optionally to [out])"
    echo "  rekey               Change the vault password"
    echo "  add <key> <value>   Add/Update a key-value pair (plaintext value)"
    echo "  remove <key>        Remove a key from the vault"
    echo "  init                Initialize vault system (create password and vault file)"
    echo "  destroy [--force]   Delete vault files (requires confirmation unless --force)"
    echo "  help, -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  mail-admin.sh vault view"
    echo "  mail-admin.sh vault add vault_user_example_com 'SuperSecret'"
    echo "  mail-admin.sh vault remove vault_user_example_com"
    echo "  mail-admin.sh vault init"
    echo "  mail-admin.sh vault destroy"
    echo ""
    echo "Notes:"
    echo "- All secrets must be managed via Ansible Vault."
    echo "- Use 'edit' for manual editing, or 'add'/'remove' for automation."
}

# --- Main Script Logic ---
main() {
    local command="${1:-}"
    shift || true # Shift even if no arguments

    case "$command" in
        view)
            vault_view
            ;;
        edit)
            vault_edit
            ;;
        encrypt)
            vault_encrypt_file "$@"
            ;;
        decrypt)
            vault_decrypt_file "$@"
            ;;
        rekey)
            vault_rekey
            ;;
        add)
            vault_add_key "$@"
            ;;
        remove)
            vault_remove_key "$@"
            ;;
        init)
            vault_init
            ;;
        destroy)
            vault_destroy "$@"
            ;;
        help|-h|--help|"")
            vault_help
            ;;
        *)
            error "Unknown command: $command"
            error "Run 'mail-admin.sh vault help' for usage."
            exit 1
            ;;
    esac
}

# --- Run Main ---
main "$@"
