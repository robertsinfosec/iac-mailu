#!/usr/bin/env bash
#
# Script: mail-vault.sh
# Description: Manage secrets in the iac-mailu Ansible vault.
# Usage: ./mail-vault.sh <command> [options]
#
# Commands:
#   view          View the decrypted vault content
#   edit          Edit the encrypted vault file
#   encrypt <file> Encrypt a file using the vault password
#   decrypt <file> Decrypt a file using the vault password
#   rekey         Change the vault password
#   add <key> <value> Add/Update a key-value pair (plaintext value)
#   remove <key>  Remove a key from the vault (TODO: Complex, requires decrypt/edit/encrypt)
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
    echo "  help, -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  mail-admin.sh vault view"
    echo "  mail-admin.sh vault add vault_user_example_com 'SuperSecret'"
    echo "  mail-admin.sh vault remove vault_user_example_com"
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
