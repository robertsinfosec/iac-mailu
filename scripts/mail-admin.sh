#!/usr/bin/env bash
#
# Script: mail-admin.sh
# Description: Unified CLI and interactive shell for managing iac-mailu configuration, secrets, and deployment.
# Usage: ./mail-admin.sh <command> [options]
#        ./mail-admin.sh shell   # Enter interactive shell
#
# Commands:
#   domain list|add|remove
#   domain user list|add|remove
#   vault list|add|remove
#   deploy [check]
#   healthcheck
#   help|--help|-h
#
# Dependencies:
#   - ansible
#   - ansible-vault
#   - yq (recommended for YAML editing)
#   - git
#
# See project STYLE_GUIDE.md for coding and output standards.

# --- Strict Mode & Error Handling ---
set -euo pipefail

# --- Configuration Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)"
SRC_DIR="$REPO_ROOT/src"
DOMAINS_DIR="$SRC_DIR/domains"
VAULT_FILE="$SRC_DIR/vault/secrets.yml"
INVENTORY_FILE="$SRC_DIR/inventory/hosts"
PLAYBOOKS_DIR="$SRC_DIR/playbooks"
VAULT_PASS_FILE="$REPO_ROOT/.vault_pass"

# --- Colors ---
CYAN='\033[36m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
GRAY='\033[90m'
RESET='\033[0m'

# --- Helper Functions ---
info()    { echo -e "${CYAN}[*] $1${RESET}"; }
success() { echo -e "${GREEN}[+] $1${RESET}"; }
error()   { echo -e "${RED}[-] $1${RESET}" >&2; }
warning() { echo -e "${YELLOW}[!] $1${RESET}"; }
debug()   { [[ "${DEBUG:-false}" == "true" ]] && echo -e "${GRAY}[%] $1${RESET}"; }

# --- Input Validation ---
require_yq() {
    if ! command -v yq &>/dev/null; then
        error "'yq' is required for this operation. Please install yq v4+."
        exit 1
    fi
}

# --- Prerequisite Check ---
prerequisite_check() {
    local missing=()
    info "Checking prerequisites..."
    for cmd in ansible ansible-vault yq git; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warning "The following required tools are missing: ${missing[*]}"
        if [[ " ${missing[*]} " =~ " yq " ]]; then
            warning "The yq package from apt is NOT compatible with this project."
            warning "You must install the Go-based yq (mikefarah/yq) binary."
            warning "To install the correct version, run:"
            warning "  $0 install-prereqs"
        fi
        error "Please install all required prerequisites before continuing."
        exit 1
    else
        success "All prerequisites are installed."
    fi
}

# --- Install Prerequisites (Go yq) ---
install_prereqs() {
    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    local yq_dest="/usr/local/bin/yq"
    info "Installing Go-based yq (mikefarah/yq) to $yq_dest..."
    if command -v yq &>/dev/null; then
        local yq_version
        yq_version=$(yq --version 2>/dev/null || true)
        if [[ "$yq_version" =~ mikefarah ]]; then
            success "Go-based yq is already installed: $yq_version"
            return 0
        else
            warning "A different yq is installed. Replacing with Go-based yq."
        fi
    fi
    if [[ $EUID -ne 0 ]]; then
        warning "Root privileges are required to install yq to $yq_dest. You may be prompted for your password."
        sudo bash -c "curl -L '$yq_url' -o '$yq_dest' && chmod +x '$yq_dest'"
    else
        curl -L "$yq_url" -o "$yq_dest" && chmod +x "$yq_dest"
    fi
    if command -v yq &>/dev/null && yq --version 2>&1 | grep -qi mikefarah; then
        success "Go-based yq installed successfully: $(yq --version)"
    else
        error "Failed to install Go-based yq. Please check your network connection and permissions."
        exit 1
    fi
}

# --- Domain Management ---
domain_list() {
    info "Listing configured domains..."
    if compgen -G "$DOMAINS_DIR/*.yml" > /dev/null; then
        for f in "$DOMAINS_DIR"/*.yml; do basename "$f" .yml; done
        success "Domain list complete."
    else
        warning "No domain configuration files found."
    fi
}

domain_add() {
    require_yq
    local domain_name="$1"
    local domain_file="$DOMAINS_DIR/${domain_name}.yml"
    if [[ -z "$domain_name" ]]; then error "Domain name required."; exit 1; fi
    if [[ -f "$domain_file" ]]; then error "Domain already exists: $domain_name"; exit 1; fi
    info "Adding domain: $domain_name"

    # Prompt for key hostnames, with secure defaults
    read -p "Mail hostname [mail.${domain_name}]: " hostname; hostname=${hostname:-mail.${domain_name}}
    read -p "Webmail hostname [webmail.${domain_name}]: " webmail; webmail=${webmail:-webmail.${domain_name}}
    read -p "Admin hostname [webmailadmin.${domain_name}]: " admin; admin=${admin:-webmailadmin.${domain_name}}

    # Prompt for postmaster address
    read -p "Postmaster address [postmaster@${domain_name}]: " postmaster_address; postmaster_address=${postmaster_address:-postmaster@${domain_name}}

    # Prompt for DKIM selector (default: mail)
    read -p "DKIM selector [mail]: " dkim_selector; dkim_selector=${dkim_selector:-mail}

    # Prompt for SPF record (default: v=spf1 mx a -all)
    read -p "SPF record [v=spf1 mx a -all]: " spf_record; spf_record=${spf_record:-v=spf1 mx a -all}

    # Prompt for max quota (default: 1GB)
    read -p "Max quota bytes [1073741824]: " max_quota_bytes; max_quota_bytes=${max_quota_bytes:-1073741824}

    # Prompt for aliases (comma separated, optional)
    read -p "Aliases (comma separated, optional): " aliases_input
    aliases_array=()
    if [[ -n "$aliases_input" ]]; then
        IFS=',' read -ra aliases_array <<< "$aliases_input"
    fi

    # Build aliases YAML array string safely
    if [[ ${#aliases_array[@]} -eq 0 ]]; then
        aliases_yaml="[]"
    else
        aliases_yaml="["
        for i in "${!aliases_array[@]}"; do
            alias_trimmed="$(echo "${aliases_array[$i]}" | xargs)"
            aliases_yaml+="\"${alias_trimmed//\"/}\""
            if [[ $i -lt $((${#aliases_array[@]} - 1)) ]]; then
                aliases_yaml+=", "
            fi
        done
        aliases_yaml+="]"
    fi

    # Use Go yq v4+ to create the YAML file with all required keys atomically
    yq eval -n \
      ".domain = \"${domain_name}\" | \
       .hostname = \"${hostname}\" | \
       .webmail = \"${webmail}\" | \
       .admin = \"${admin}\" | \
       .aliases = ${aliases_yaml} | \
       .relay_enabled = false | \
       .relay_host = null | \
       .relay_port = null | \
       .relay_username = null | \
       .relay_password = null | \
       .dkim_enabled = true | \
       .dkim_selector = \"${dkim_selector}\" | \
       .spf_record = \"${spf_record}\" | \
       .max_users = -1 | \
       .max_aliases = -1 | \
       .max_quota_bytes = ${max_quota_bytes} | \
       .catchall_enabled = false | \
       .catchall_destination = null | \
       .postmaster_address = \"${postmaster_address}\" | \
       .dns.mx.priority = 10 | \
       .dns.mx.hostname = \"${hostname}\" | \
       .dns.additional_mx_hosts = [] | \
       .dns.spf_include = [] | \
       .users = []" \
      > "$domain_file"
    local yq_status=$?
    if [[ $yq_status -ne 0 || ! -s "$domain_file" ]]; then
        rm -f "$domain_file"
        error "Failed to create domain YAML file. Please check yq installation and input values."
        exit 1
    fi
    # Optionally, validate YAML file is well-formed
    if ! yq eval '.' "$domain_file" &>/dev/null; then
        rm -f "$domain_file"
        error "Generated YAML is invalid. File has been removed."
        exit 1
    fi
    success "Domain created: $domain_file"
    echo -e "${CYAN}[*] Domain configuration file created: ${domain_file}${RESET}"
}

domain_remove() {
    local domain_name="$1"
    local domain_file="$DOMAINS_DIR/${domain_name}.yml"
    if [[ ! -f "$domain_file" ]]; then error "Domain not found: $domain_name"; exit 1; fi
    info "Removing domain: $domain_name"
    rm -f "$domain_file" && success "Domain removed: $domain_name"
}

domain_user_list() {
    require_yq
    local domain_name="$1"
    local domain_file="$DOMAINS_DIR/${domain_name}.yml"
    if [[ ! -f "$domain_file" ]]; then error "Domain not found: $domain_name"; exit 1; fi
    info "Listing users for domain: $domain_name"
    yq eval '.users[].name' "$domain_file" || warning "No users found."
}

domain_user_add() {
    require_yq
    local domain_name="$1"; shift
    local username="$1"
    local domain_file="$DOMAINS_DIR/${domain_name}.yml"
    if [[ ! -f "$domain_file" ]]; then error "Domain not found: $domain_name"; exit 1; fi
    if [[ -z "$username" ]]; then error "Username required."; exit 1; fi
    local vault_var="vault_${username}_${domain_name//./_}"
    read -p "Is this user a catch-all? (y/N): " catchall; catchall_flag=false; [[ "$catchall" =~ ^[Yy]$ ]] && catchall_flag=true
    
    # Generate a secure random password (32 characters, alphanumeric only)
    info "Generating a secure random password for the user"
    local generated_password=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c 32)
    
    # Add the password to the vault
    info "Adding password to vault as ${vault_var}"
    vault_add "$vault_var" "$generated_password"

    # Build the user object as a JSON string for yq (avoids YAML parsing issues)
    local user_json
    user_json="{\"name\": \"$username\", \"password_var\": \"$vault_var\", \"catchall\": $catchall_flag}"
    # Append the new user to the users array using yq (robust for yq v4+)
    if yq eval ".users += [${user_json}]" -i "$domain_file"; then
        success "User '$username' added to $domain_name."
        success "Generated password for $username@$domain_name: $generated_password"
        warning "Please save this password securely. It has been added to the vault."
    else
        error "Failed to add user to $domain_name. Please check the domain file syntax."
        exit 1
    fi
}

domain_user_remove() {
    require_yq
    local domain_name="$1"; local username="$2"
    local domain_file="$DOMAINS_DIR/${domain_name}.yml"
    if [[ ! -f "$domain_file" ]]; then error "Domain not found: $domain_name"; exit 1; fi
    yq eval ".users |= map(select(.name != \"$username\"))" -i "$domain_file"
    success "User '$username' removed from $domain_name."
}

# --- Vault Management ---
vault_list() {
    info "Listing vault keys..."
    # Check for required files before proceeding
    if [[ ! -f "$VAULT_PASS_FILE" || ! -f "$VAULT_FILE" ]]; then
        if [[ ! -f "$VAULT_PASS_FILE" ]]; then
            error "Vault password file not found at $VAULT_PASS_FILE."
        fi
        if [[ ! -f "$VAULT_FILE" ]]; then
            error "Vault secrets file not found at $VAULT_FILE."
        fi
        echo -e "${YELLOW}[!] The vault is not initialized. Run: ./mail-admin.sh vault init${RESET}"
        exit 1
    fi
    
    # Decrypt and get keys
    local tmpfile; tmpfile=$(mktemp)
    ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" > "$tmpfile"
    
    # Check if vault is empty (no keys)
    if [[ ! -s "$tmpfile" || "$(yq eval 'keys | length' "$tmpfile")" == "0" ]]; then
        rm -f "$tmpfile"
        warning "Vault is empty. Use 'vault add <key> <value>' to add secrets."
        success "Vault key list complete."
        return 0
    fi
    
    # Display keys
    yq eval 'keys | .[]' "$tmpfile"
    rm -f "$tmpfile"
    success "Vault key list complete."
}

vault_add() {
    local key="$1"; local value="$2"
    if [[ -z "$key" || -z "$value" ]]; then error "Usage: vault add <key> <value>"; exit 1; fi
    info "Adding/updating vault key: $key"
    local tmpfile; tmpfile=$(mktemp)
    ansible-vault decrypt "$VAULT_FILE" --output "$tmpfile" --vault-password-file "$VAULT_PASS_FILE"
    yq eval ".$key = \"$value\"" "$tmpfile" > "$tmpfile.2"
    ansible-vault encrypt "$tmpfile.2" --output "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"
    rm -f "$tmpfile" "$tmpfile.2"
    success "Vault key '$key' added/updated."
}

vault_remove() {
    local key="$1"
    if [[ -z "$key" ]]; then error "Usage: vault remove <key>"; exit 1; fi
    info "Removing vault key: $key"
    local tmpfile; tmpfile=$(mktemp)
    ansible-vault decrypt "$VAULT_FILE" --output "$tmpfile" --vault-password-file "$VAULT_PASS_FILE"
    yq eval "del(.$key)" "$tmpfile" > "$tmpfile.2"
    ansible-vault encrypt "$tmpfile.2" --output "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"
    rm -f "$tmpfile" "$tmpfile.2"
    success "Vault key '$key' removed."
}

vault_update() {
    local key="$1"; local value="$2"
    if [[ -z "$key" || -z "$value" ]]; then error "Usage: vault update <key> <value>"; exit 1; fi
    
    info "Checking if vault key exists: $key"
    local tmpfile; tmpfile=$(mktemp)
    # Decrypt vault file to check key existence
    ansible-vault decrypt "$VAULT_FILE" --output "$tmpfile" --vault-password-file "$VAULT_PASS_FILE"
    
    # Check if key exists in the vault
    if ! yq eval "has(\"$key\")" "$tmpfile" | grep -q "true"; then
        rm -f "$tmpfile"
        error "Vault key '$key' does not exist. Use 'vault add' to create a new key."
        exit 1
    fi
    
    info "Updating vault key: $key"
    yq eval ".$key = \"$value\"" "$tmpfile" > "$tmpfile.2"
    ansible-vault encrypt "$tmpfile.2" --output "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"
    rm -f "$tmpfile" "$tmpfile.2"
    success "Vault key '$key' updated."
}

# --- Inventory Management Functions ---

inventory_list() {
    echo -e "${CYAN}[*] Listing servers in inventory${RESET}"
    
    # Check if inventory file exists
    if [[ ! -f "${SCRIPT_DIR}/../src/inventory/hosts" ]]; then
        echo -e "${YELLOW}[!] Inventory file not found. No servers configured yet.${RESET}"
        return 0
    fi
    
    # Extract and print server entries (skip empty lines and comments)
    echo -e "\n${GREEN}Configured Servers:${RESET}"
    echo -e "${GRAY}----------------------------------------${RESET}"
    grep -v '^\s*$\|^\s*\[.*\]\s*$\|^\s*#' "${SCRIPT_DIR}/../src/inventory/hosts" | while read -r line; do
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+(.*) ]]; then
            local hostname="${BASH_REMATCH[1]}"
            local config="${BASH_REMATCH[2]}"
            echo -e "${GREEN}$hostname${RESET} → ${GRAY}$config${RESET}"
        else
            echo "$line"
        fi
    done
    echo -e "${GRAY}----------------------------------------${RESET}"
}

inventory_add() {
    local hostname="$1"
    
    # Validate hostname
    if [[ -z "$hostname" ]]; then
        echo -e "${RED}[-] Error: Hostname is required${RESET}"
        echo -e "${YELLOW}[!] Usage: $0 inventory add HOSTNAME${RESET}"
        return 1
    fi
    
    echo -e "${CYAN}[*] Adding new server to inventory: $hostname${RESET}"
    
    # Create inventory directory if it doesn't exist
    if [[ ! -d "${SCRIPT_DIR}/../src/inventory" ]]; then
        echo -e "${YELLOW}[!] Inventory directory not found, creating it${RESET}"
        mkdir -p "${SCRIPT_DIR}/../src/inventory"
    fi
    
    # Create inventory file if it doesn't exist
    if [[ ! -f "${SCRIPT_DIR}/../src/inventory/hosts" ]]; then
        echo -e "${YELLOW}[!] Inventory file not found, creating it${RESET}"
        cat > "${SCRIPT_DIR}/../src/inventory/hosts" << EOF
# Ansible Inventory for Mailu Mail Servers
# Managed by mail-admin.sh script

[mail_servers]
# Server entries will be added below
EOF
    fi
    
    # Check if server already exists in inventory
    if grep -q "^${hostname}[[:space:]]" "${SCRIPT_DIR}/../src/inventory/hosts"; then
        echo -e "${RED}[-] Error: Server $hostname already exists in inventory${RESET}"
        echo -e "${YELLOW}[!] Use 'inventory update $hostname' to modify it${RESET}"
        return 1
    fi
    
    # Get connection details
    read -p "IP address or hostname [leave empty to use $hostname]: " ip_address
    ip_address=${ip_address:-$hostname}
    
    read -p "SSH user [default: ansible]: " ansible_user
    ansible_user=${ansible_user:-ansible}
    
    echo -e "${YELLOW}Connection method:${RESET}"
    echo "1) SSH key authentication (recommended)"
    echo "2) Password authentication"
    read -p "Select method [1]: " auth_method
    auth_method=${auth_method:-1}
    
    ansible_connection=""
    
    if [[ "$auth_method" == "1" ]]; then
        # SSH key authentication
        read -p "Path to private SSH key [default: ~/.ssh/id_rsa]: " ssh_key_path
        ssh_key_path=${ssh_key_path:-~/.ssh/id_rsa}
        
        # Expand tilde to home directory
        ssh_key_path="${ssh_key_path/#\~/$HOME}"
        
        # Check if SSH key exists
        if [[ ! -f "$ssh_key_path" ]]; then
            echo -e "${YELLOW}[!] Warning: SSH key not found at $ssh_key_path${RESET}"
            read -p "Continue anyway? [y/N]: " continue_anyway
            if [[ "${continue_anyway,,}" != "y" ]]; then
                echo -e "${RED}[-] Operation cancelled${RESET}"
                return 1
            fi
        fi
        
        ansible_connection="ansible_ssh_private_key_file=$ssh_key_path"
    else
        # Password authentication
        echo -e "${YELLOW}[!] Note: SSH password will be stored in the Ansible vault${RESET}"
        read -s -p "SSH password: " ssh_password
        echo
        
        # Generate variable name for vault
        vault_var="vault_ssh_password_${hostname//[.-]/_}"
        
        # Add password to vault
        echo -e "${CYAN}[*] Adding SSH password to vault${RESET}"
        vault_add "$vault_var" "$ssh_password"
        
        ansible_connection="ansible_ssh_pass={{ $vault_var }}"
    fi
    
    # Privilege escalation
    echo -e "${YELLOW}Privilege escalation (sudo):${RESET}"
    echo "1) Use sudo with no password"
    echo "2) Use sudo with password"
    echo "3) Don't use sudo"
    read -p "Select option [1]: " sudo_option
    sudo_option=${sudo_option:-1}
    
    ansible_become=""
    
    case "$sudo_option" in
        1)
            ansible_become="ansible_become=true"
            ;;
        2)
            read -s -p "Sudo password: " sudo_password
            echo
            
            # Generate variable name for vault
            vault_var="vault_sudo_password_${hostname//[.-]/_}"
            
            # Add password to vault
            echo -e "${CYAN}[*] Adding sudo password to vault${RESET}"
            vault_add "$vault_var" "$sudo_password"
            
            ansible_become="ansible_become=true ansible_become_pass={{ $vault_var }}"
            ;;
        3)
            ansible_become="ansible_become=false"
            ;;
        *)
            echo -e "${RED}[-] Invalid option${RESET}"
            return 1
            ;;
    esac
    
    # Add server to inventory
    echo -e "${CYAN}[*] Adding server to inventory${RESET}"
    echo "$hostname ansible_host=$ip_address ansible_user=$ansible_user $ansible_connection $ansible_become" >> "${SCRIPT_DIR}/../src/inventory/hosts"
    
    echo -e "${GREEN}[+] Successfully added server $hostname to inventory${RESET}"
    echo -e "${GREEN}[+] Configuration: ansible_host=$ip_address ansible_user=$ansible_user${RESET}"
}

inventory_remove() {
    local hostname="$1"
    
    # Validate hostname
    if [[ -z "$hostname" ]]; then
        echo -e "${RED}[-] Error: Hostname is required${RESET}"
        echo -e "${YELLOW}[!] Usage: $0 inventory remove HOSTNAME${RESET}"
        return 1
    fi
    
    # Check if inventory file exists
    if [[ ! -f "${SCRIPT_DIR}/../src/inventory/hosts" ]]; then
        echo -e "${RED}[-] Error: Inventory file not found${RESET}"
        return 1
    fi
    
    echo -e "${CYAN}[*] Removing server $hostname from inventory${RESET}"
    
    # Check if server exists in inventory
    if ! grep -q "^${hostname}[[:space:]]" "${SCRIPT_DIR}/../src/inventory/hosts"; then
        echo -e "${RED}[-] Error: Server $hostname not found in inventory${RESET}"
        return 1
    fi
    
    # Create a temporary file
    local temp_file
    temp_file="$(mktemp)"
    
    # Remove server from inventory
    grep -v "^${hostname}[[:space:]]" "${SCRIPT_DIR}/../src/inventory/hosts" > "$temp_file"
    mv "$temp_file" "${SCRIPT_DIR}/../src/inventory/hosts"
    
    echo -e "${GREEN}[+] Successfully removed server $hostname from inventory${RESET}"
    
    # Check if there are vault variables for this server
    local server_var="${hostname//[.-]/_}"
    local vars_to_remove=()
    
    # Look for vault variables related to this server
    if [[ -f "${SCRIPT_DIR}/../src/vault/secrets.yml" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^vault_(ssh|sudo)_password_${server_var}: ]]; then
                local var_name
                var_name=$(echo "$line" | cut -d: -f1)
                vars_to_remove+=("$var_name")
            fi
        done < <(ansible-vault view "${SCRIPT_DIR}/../src/vault/secrets.yml" 2>/dev/null || echo "")
    fi
    
    # Ask if vault variables should be removed too
    if [[ ${#vars_to_remove[@]} -gt 0 ]]; then
        echo -e "${YELLOW}[!] Found these vault variables related to $hostname:${RESET}"
        printf "   %s\n" "${vars_to_remove[@]}"
        read -p "Do you want to remove them too? [y/N]: " remove_vars
        
        if [[ "${remove_vars,,}" == "y" ]]; then
            echo -e "${CYAN}[*] Removing vault variables${RESET}"
            for var in "${vars_to_remove[@]}"; do
                remove_from_vault "$var"
            done
        fi
    fi
}

inventory_update() {
    local hostname="$1"
    
    # Validate hostname
    if [[ -z "$hostname" ]]; then
        echo -e "${RED}[-] Error: Hostname is required${RESET}"
        echo -e "${YELLOW}[!] Usage: $0 inventory update HOSTNAME${RESET}"
        return 1
    fi
    
    # Check if inventory file exists
    if [[ ! -f "${SCRIPT_DIR}/../src/inventory/hosts" ]]; then
        echo -e "${RED}[-] Error: Inventory file not found${RESET}"
        return 1
    fi
    
    # Check if server exists in inventory
    if ! grep -q "^${hostname}[[:space:]]" "${SCRIPT_DIR}/../src/inventory/hosts"; then
        echo -e "${RED}[-] Error: Server $hostname not found in inventory${RESET}"
        echo -e "${YELLOW}[!] Use 'inventory add $hostname' to add it${RESET}"
        return 1
    fi
    
    echo -e "${CYAN}[*] Updating server $hostname in inventory${RESET}"
    
    # Get current configuration
    local current_config
    current_config=$(grep "^${hostname}[[:space:]]" "${SCRIPT_DIR}/../src/inventory/hosts}")
    
    # Extract current values
    local current_host=$(echo "$current_config" | grep -o "ansible_host=[^ ]*" | cut -d= -f2)
    local current_user=$(echo "$current_config" | grep -o "ansible_user=[^ ]*" | cut -d= -f2)
    
    echo -e "${GREEN}Current configuration:${RESET}"
    echo -e "  Host: $current_host"
    echo -e "  User: $current_user"
    
    # Get updated values
    read -p "IP address or hostname [${current_host}]: " ip_address
    ip_address=${ip_address:-$current_host}
    
    read -p "SSH user [${current_user}]: " ansible_user
    ansible_user=${ansible_user:-$current_user}
    
    echo -e "${YELLOW}Connection method:${RESET}"
    echo "1) SSH key authentication (recommended)"
    echo "2) Password authentication"
    read -p "Select method [1]: " auth_method
    auth_method=${auth_method:-1}
    
    ansible_connection=""
    
    if [[ "$auth_method" == "1" ]]; then
        # SSH key authentication
        read -p "Path to private SSH key [default: ~/.ssh/id_rsa]: " ssh_key_path
        ssh_key_path=${ssh_key_path:-~/.ssh/id_rsa}
        
        # Expand tilde to home directory
        ssh_key_path="${ssh_key_path/#\~/$HOME}"
        
        # Check if SSH key exists
        if [[ ! -f "$ssh_key_path" ]]; then
            echo -e "${YELLOW}[!] Warning: SSH key not found at $ssh_key_path${RESET}"
            read -p "Continue anyway? [y/N]: " continue_anyway
            if [[ "${continue_anyway,,}" != "y" ]]; then
                echo -e "${RED}[-] Operation cancelled${RESET}"
                return 1
            fi
        fi
        
        ansible_connection="ansible_ssh_private_key_file=$ssh_key_path"
        
        # Clean up any existing password from vault
        local vault_var="vault_ssh_password_${hostname//[.-]/_}"
        if grep -q "^$vault_var:" "${SCRIPT_DIR}/../src/vault/secrets.yml" 2>/dev/null; then
            echo -e "${YELLOW}[!] Removing SSH password from vault${RESET}"
            remove_from_vault "$vault_var"
        fi
    else
        # Password authentication
        echo -e "${YELLOW}[!] Note: SSH password will be stored in the Ansible vault${RESET}"
        read -s -p "SSH password: " ssh_password
        echo
        
        # Generate variable name for vault
        vault_var="vault_ssh_password_${hostname//[.-]/_}"
        
        # Add password to vault
        echo -e "${CYAN}[*] Adding SSH password to vault${RESET}"
        vault_add "$vault_var" "$ssh_password"
        
        ansible_connection="ansible_ssh_pass={{ $vault_var }}"
    fi
    
    # Privilege escalation
    echo -e "${YELLOW}Privilege escalation (sudo):${RESET}"
    echo "1) Use sudo with no password"
    echo "2) Use sudo with password"
    echo "3) Don't use sudo"
    read -p "Select option [1]: " sudo_option
    sudo_option=${sudo_option:-1}
    
    ansible_become=""
    
    case "$sudo_option" in
        1)
            ansible_become="ansible_become=true"
            
            # Clean up any existing sudo password from vault
            local vault_var="vault_sudo_password_${hostname//[.-]/_}"
            if grep -q "^$vault_var:" "${SCRIPT_DIR}/../src/vault/secrets.yml" 2>/dev/null; then
                echo -e "${YELLOW}[!] Removing sudo password from vault${RESET}"
                remove_from_vault "$vault_var"
            fi
            ;;
        2)
            read -s -p "Sudo password: " sudo_password
            echo
            
            # Generate variable name for vault
            vault_var="vault_sudo_password_${hostname//[.-]/_}"
            
            # Add password to vault
            echo -e "${CYAN}[*] Adding sudo password to vault${RESET}"
            vault_add "$vault_var" "$sudo_password"
            
            ansible_become="ansible_become=true ansible_become_pass={{ $vault_var }}"
            ;;
        3)
            ansible_become="ansible_become=false"
            
            # Clean up any existing sudo password from vault
            local vault_var="vault_sudo_password_${hostname//[.-]/_}"
            if grep -q "^$vault_var:" "${SCRIPT_DIR}/../src/vault/secrets.yml" 2>/dev/null; then
                echo -e "${YELLOW}[!] Removing sudo password from vault${RESET}"
                remove_from_vault "$vault_var"
            fi
            ;;
        *)
            echo -e "${RED}[-] Invalid option${RESET}"
            return 1
            ;;
    esac
    
    # Update server in inventory
    echo -e "${CYAN}[*] Updating server in inventory${RESET}"
    
    # Create a temporary file
    local temp_file
    temp_file="$(mktemp)"
    
    # Update server entry
    while IFS= read -r line; do
        if [[ "$line" =~ ^"$hostname"[[:space:]] ]]; then
            echo "$hostname ansible_host=$ip_address ansible_user=$ansible_user $ansible_connection $ansible_become" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "${SCRIPT_DIR}/../src/inventory/hosts"
    
    mv "$temp_file" "${SCRIPT_DIR}/../src/inventory/hosts"
    
    echo -e "${GREEN}[+] Successfully updated server $hostname in inventory${RESET}"
    echo -e "${GREEN}[+] New configuration: ansible_host=$ip_address ansible_user=$ansible_user${RESET}"
}

inventory_test() {
    local hostname="$1"
    
    # Validate hostname
    if [[ -z "$hostname" ]]; then
        echo -e "${RED}[-] Error: Hostname is required${RESET}"
        echo -e "${YELLOW}[!] Usage: $0 inventory test HOSTNAME${RESET}"
        return 1
    fi
    
    echo -e "${CYAN}[*] Testing connection to server: $hostname${RESET}"
    
    # Check if inventory file exists
    if [[ ! -f "${SCRIPT_DIR}/../src/inventory/hosts" ]]; then
        echo -e "${RED}[-] Error: Inventory file not found${RESET}"
        return 1
    fi
    
    # Check if server exists in inventory
    if ! grep -q "^${hostname}" "${SCRIPT_DIR}/../src/inventory/hosts"; then
        echo -e "${RED}[-] Error: Server $hostname not found in inventory${RESET}"
        echo -e "${YELLOW}[!] Use 'inventory add $hostname' to add the server${RESET}"
        return 1
    fi
    
    # Test connection using Ansible ping module
    ansible "$hostname" -i "${SCRIPT_DIR}/../src/inventory/hosts" -m ping --vault-password-file "$VAULT_PASS_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Successfully connected to $hostname${RESET}"
    else
        echo -e "${RED}[-] Failed to connect to $hostname${RESET}"
        echo -e "${YELLOW}[!] Make sure all connection details are correct${RESET}"
    fi
}

vault_init() {
    info "Initializing Ansible Vault password file and secrets vault..."

    # Check for .vault_pass
    if [[ -f "$VAULT_PASS_FILE" ]]; then
        success ".vault_pass already exists at $VAULT_PASS_FILE."
    else
        read -s -p "Enter a new vault password (will not echo): " vault_pass1; echo
        read -s -p "Confirm vault password: " vault_pass2; echo
        if [[ "$vault_pass1" != "$vault_pass2" ]]; then
            error "Passwords do not match. Aborting vault initialization."
            exit 1
        fi
        echo -n "$vault_pass1" > "$VAULT_PASS_FILE"
        chmod 0600 "$VAULT_PASS_FILE"
        success ".vault_pass created at $VAULT_PASS_FILE with permissions 0600."
    fi

    # Check for secrets.yml
    if [[ -f "$VAULT_FILE" ]]; then
        # Check if file is already encrypted
        if grep -q '^\$ANSIBLE_VAULT;' "$VAULT_FILE"; then
            success "Vault file already exists and is encrypted at $VAULT_FILE."
        else
            warning "Vault file exists at $VAULT_FILE but is NOT encrypted."
            local backup_file="${VAULT_FILE}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$VAULT_FILE" "$backup_file"
            success "Unencrypted vault file backed up to $backup_file."
            info "Encrypting existing secrets file in place..."
            if ansible-vault encrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"; then
                chmod 0600 "$VAULT_FILE"
                success "Vault file encrypted in place at $VAULT_FILE."
            else
                error "Failed to encrypt $VAULT_FILE. Restore from backup if needed."
                exit 1
            fi
        fi
    else
        info "Creating and encrypting new secrets vault at $VAULT_FILE..."
        mkdir -p "$(dirname "$VAULT_FILE")"
        echo "{}" > "$VAULT_FILE.tmp"
        if ansible-vault encrypt "$VAULT_FILE.tmp" --output "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"; then
            rm -f "$VAULT_FILE.tmp"
            chmod 0600 "$VAULT_FILE"
            success "Vault secrets file created and encrypted at $VAULT_FILE."
        else
            rm -f "$VAULT_FILE.tmp"
            error "Failed to create and encrypt $VAULT_FILE."
            exit 1
        fi
    fi
}

vault_destroy() {
    local force=false
    if [[ "${1:-}" == "--force" ]]; then
        force=true
    fi
    info "Destroying vault password and secrets files..."
    if [[ "$force" == false ]]; then
        read -p "Are you sure you want to permanently delete .vault_pass and vault/secrets.yml? This cannot be undone. (type 'DESTROY' to confirm): " confirm
        if [[ "$confirm" != "DESTROY" ]]; then
            warning "Vault destroy aborted by user."
            return 1
        fi
    fi
    local failed=0
    if [[ -f "$VAULT_PASS_FILE" ]]; then
        rm -f "$VAULT_PASS_FILE" && success ".vault_pass deleted." || { error "Failed to delete .vault_pass."; failed=1; }
    else
        warning ".vault_pass not found, nothing to delete."
    fi
    if [[ -f "$VAULT_FILE" ]]; then
        rm -f "$VAULT_FILE" && success "Vault secrets file deleted." || { error "Failed to delete vault secrets file."; failed=1; }
    else
        warning "Vault secrets file not found, nothing to delete."
    fi
    if [[ $failed -eq 0 ]]; then
        success "Vault destroy operation complete."
    else
        error "Vault destroy encountered errors."
        exit 1
    fi
}

# --- Deployment & Healthcheck ---
validate_global_vars() {
    local all_yml="$SRC_DIR/group_vars/all.yml"
    local inventory_file="$SRC_DIR/inventory/hosts"
    local required_vars=("target_user" "ansible_user" "mailu_base_dir")
    local missing_vars=()
    local empty_vars=()
    local inventory_ansible_users=()
    local group_ansible_user=""
    local group_target_user=""
    info "Validating required global variables in group_vars/all.yml and inventory..."
    if [[ ! -f "$all_yml" ]]; then
        warning "group_vars/all.yml not found. Creating it."
        mkdir -p "$(dirname "$all_yml")"
        echo "---" > "$all_yml"
    fi
    # Check group_vars/all.yml for required vars and empty/whitespace
    for var in "${required_vars[@]}"; do
        local value
        value=$(yq eval ".${var}" "$all_yml" 2>/dev/null || echo "null")
        value="${value//\"/}" # Remove quotes
        value="$(echo "$value" | xargs)" # Trim whitespace
        if [[ "$value" == "null" || -z "$value" ]]; then
            missing_vars+=("$var")
        elif [[ -z "${value// }" ]]; then
            empty_vars+=("$var")
        fi
        if [[ "$var" == "ansible_user" ]]; then group_ansible_user="$value"; fi
        if [[ "$var" == "target_user" ]]; then group_target_user="$value"; fi
    done
    # Parse inventory for ansible_user and target_user
    if [[ -f "$inventory_file" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || "$line" =~ ^\[.*\]$ || -z "$line" ]] && continue
            local host=$(echo "$line" | awk '{print $1}')
            local inv_ansible_user=$(echo "$line" | grep -oE 'ansible_user=[^ ]+' | cut -d= -f2)
            local inv_target_user=$(echo "$line" | grep -oE 'target_user=[^ ]+' | cut -d= -f2)
            if [[ -n "$inv_ansible_user" ]]; then
                inventory_ansible_users+=("$host:$inv_ansible_user")
            fi
            if [[ -n "$inv_target_user" ]]; then
                # Optionally, check per-host target_user
                :
            fi
        done < "$inventory_file"
    fi
    # Warn if ansible_user is set in both places and differs
    if [[ -n "$group_ansible_user" && ${#inventory_ansible_users[@]} -gt 0 ]]; then
        for entry in "${inventory_ansible_users[@]}"; do
            local host=${entry%%:*}
            local inv_user=${entry##*:}
            if [[ "$inv_user" != "$group_ansible_user" ]]; then
                warning "ansible_user for host $host in inventory ($inv_user) overrides group_vars/all.yml ($group_ansible_user)"
            fi
        done
    fi
    # Prompt for missing/empty vars
    if [[ ${#missing_vars[@]} -gt 0 || ${#empty_vars[@]} -gt 0 ]]; then
        local all_missing=("${missing_vars[@]}" "${empty_vars[@]}")
        warning "The following required variables are missing or empty in group_vars/all.yml: ${all_missing[*]}"
        for var in "${all_missing[@]}"; do
            read -p "Enter value for ${var}: " value
            value="$(echo "$value" | xargs)"
            if [[ -z "$value" ]]; then
                error "Value for $var cannot be empty. Aborting validation."
                exit 1
            fi
            yq eval ".${var} = \"${value}\"" -i "$all_yml"
            success "Set ${var} in group_vars/all.yml"
        done
    fi
    # Print summary of ansible_user/target_user for each host
    if [[ -f "$inventory_file" ]]; then
        info "Summary of ansible_user and target_user for each host (inventory takes precedence):"
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || "$line" =~ ^\[.*\]$ || -z "$line" ]] && continue
            local host=$(echo "$line" | awk '{print $1}')
            local inv_ansible_user=$(echo "$line" | grep -oE 'ansible_user=[^ ]+' | cut -d= -f2)
            local inv_target_user=$(echo "$line" | grep -oE 'target_user=[^ ]+' | cut -d= -f2)
            local eff_ansible_user="$group_ansible_user"
            local eff_target_user="$group_target_user"
            [[ -n "$inv_ansible_user" ]] && eff_ansible_user="$inv_ansible_user"
            [[ -n "$inv_target_user" ]] && eff_target_user="$inv_target_user"
            echo -e "${CYAN}[*] Host: $host  ansible_user: $eff_ansible_user  target_user: $eff_target_user${RESET}"
        done < "$inventory_file"
    else
        info "No inventory file found. Only group_vars/all.yml values will be used."
    fi
    success "All required global variables are present and validated."
}

deploy() {
    validate_global_vars
    local check_flag=""
    [[ "${1:-}" == "check" ]] && check_flag="--check"
    info "Running deployment playbook (site.yml) $check_flag"
    (
        cd "$SRC_DIR"
        ansible-playbook -i "$INVENTORY_FILE" "playbooks/site.yml" --vault-password-file "$VAULT_PASS_FILE" $check_flag
    ) && success "Deployment complete." || error "Deployment failed."
}

healthcheck() {
    info "Running health check playbook."
    (
        cd "$SRC_DIR"
        ansible-playbook -i "$INVENTORY_FILE" "playbooks/health_check.yml" --vault-password-file "$VAULT_PASS_FILE"
    ) && success "Health check complete." || error "Health check failed."
}

# --- Argument Parsing & Interactive Selection ---
parse_user_args() {
    # Usage: parse_user_args "$@"; sets DOMAIN_ARG and USERNAME_ARG
    DOMAIN_ARG=""; USERNAME_ARG=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)
                DOMAIN_ARG="$2"; shift 2;;
            --username)
                USERNAME_ARG="$2"; shift 2;;
            --help|-h)
                show_help; exit 0;;
            *)
                # Positional fallback: user add DOMAIN USERNAME
                if [[ -z "$DOMAIN_ARG" ]]; then DOMAIN_ARG="$1"; shift; elif [[ -z "$USERNAME_ARG" ]]; then USERNAME_ARG="$1"; shift; else shift; fi
                ;;
        esac
    done
}

select_domain_interactive() {
    local domains=( $(ls "$DOMAINS_DIR"/*.yml 2>/dev/null | xargs -n1 basename | sed 's/\.yml$//') )
    if [[ ${#domains[@]} -eq 0 ]]; then
        error "No domains found. Please add a domain first."; exit 1
    fi
    echo -e "${CYAN}[*] Select a domain:${RESET}"
    select d in "${domains[@]}"; do
        if [[ -n "$d" ]]; then DOMAIN_ARG="$d"; break; fi
    done
}

select_user_interactive() {
    local domain="$1"
    local users=( $(yq eval '.users[].name' "$DOMAINS_DIR/${domain}.yml" 2>/dev/null) )
    if [[ ${#users[@]} -eq 0 ]]; then
        error "No users found in domain $domain."; exit 1
    fi
    echo -e "${CYAN}[*] Select a user:${RESET}"
    select u in "${users[@]}"; do
        if [[ -n "$u" ]]; then USERNAME_ARG="$u"; break; fi
    done
}

# --- Help ---
show_help() {
    cat << EOF
Usage: $0 [COMMAND] [ARGS...]

A utility script for managing the iac-mailu deployment.

Commands:
  domain list           List all configured mail domains
  domain add [--domain DOMAIN]
                       Add a new mail domain
  domain remove [--domain DOMAIN]
                       Remove a mail domain

  user list [--domain DOMAIN]
                       List all users in a domain (interactive if not provided)
  user add [--domain DOMAIN] [--username USERNAME]
                       Add a new user to a domain (interactive if not provided)
  user remove [--domain DOMAIN] [--username USERNAME]
                       Remove a user from a domain (interactive if not provided)
  user password [--domain DOMAIN] [--username USERNAME]
                       Update password for a user (not yet implemented)

  inventory list        List all servers in inventory
  inventory add HOSTNAME
                       Add a new server to the inventory
  inventory remove HOSTNAME
                       Remove a server from inventory
  inventory update HOSTNAME
                       Update an existing server in inventory

  vault encrypt         Encrypt vault files
  vault decrypt         Decrypt vault files
  vault edit            Edit vault files

  deploy [--check]      Run the main deployment playbook (optional check mode)
  backup                Run the backup playbook
  restore               Run the restore playbook
  healthcheck           Run the health check playbook

  help                  Show this help message
EOF
}

# --- Interactive Shell ---
mail_admin_shell() {
    info "Entering mail-admin shell. Type 'help' for commands, 'exit' to quit."
    while true; do
        read -rp "mail-admin > " line || break
        [[ -z "$line" ]] && continue
        [[ "$line" == "exit" ]] && break
        eval "$0 $line"
    done
}

# --- Main Script Logic ---
main() {
    if [[ "${1:-}" == "install-prereqs" ]]; then
        install_prereqs
        exit 0
    fi
    # Allow --help or no arguments to show help, but check prerequisites after
    if [[ $# -eq 0 || "${1:-}" =~ ^(-h|--help|help)$ ]]; then
        show_help
        # Check for missing prereqs, but do not exit immediately
        local missing=()
        for cmd in ansible ansible-vault yq git; do
            if ! command -v "$cmd" &>/dev/null; then
                missing+=("$cmd")
            fi
        done
        if [[ " ${missing[*]} " =~ " yq " ]]; then
            echo -e "${RED}[-] Prerequisites are missing. Please first run: $0 install-prereqs${RESET}"
        elif [[ ${#missing[@]} -gt 0 ]]; then
            echo -e "${RED}[-] Prerequisites are missing: ${missing[*]}. Please install them before continuing.${RESET}"
        fi
        exit 0
    fi
    prerequisite_check
    local cmd="${1:-help}"
    shift || true
    case "$cmd" in
        domain)
            # ...existing domain logic, update add/remove to support --domain ...
            if [[ $# -eq 0 ]]; then
                error "Missing subcommand for 'domain'. Usage: $0 domain <list|add|remove> ..."; show_help; exit 1
            fi
            case "$1" in
                list)
                    domain_list ;;
                add)
                    shift; local domain_name=""
                    while [[ $# -gt 0 ]]; do
                        case "$1" in
                            --domain) domain_name="$2"; shift 2;;
                            *) domain_name="$1"; shift;;
                        esac
                    done
                    if [[ -z "$domain_name" ]]; then
                        read -p "Enter domain name to add: " domain_name
                    fi
                    domain_add "$domain_name" ;;
                remove)
                    shift; local domain_name=""
                    while [[ $# -gt 0 ]]; do
                        case "$1" in
                            --domain) domain_name="$2"; shift 2;;
                            *) domain_name="$1"; shift;;
                        esac
                    done
                    if [[ -z "$domain_name" ]]; then
                        read -p "Enter domain name to remove: " domain_name
                    fi
                    domain_remove "$domain_name" ;;
                *)
                    error "Unknown or missing subcommand for 'domain'. Usage: $0 domain <list|add|remove> ..."; show_help; exit 1;;
            esac
            ;;
        user)
            if [[ $# -eq 0 ]]; then error "Missing subcommand for 'user'. Usage: $0 user <list|add|remove|password> ..."; show_help; exit 1; fi
            subcmd="$1"; shift
            case "$subcmd" in
                list)
                    parse_user_args "$@"
                    if [[ -z "$DOMAIN_ARG" ]]; then select_domain_interactive; fi
                    domain_user_list "$DOMAIN_ARG" ;;
                add)
                    parse_user_args "$@"
                    if [[ -z "$DOMAIN_ARG" ]]; then select_domain_interactive; fi
                    if [[ ! -f "$DOMAINS_DIR/${DOMAIN_ARG}.yml" ]]; then error "Domain not found: $DOMAIN_ARG"; exit 1; fi
                    if [[ -z "$USERNAME_ARG" ]]; then
                        read -p "Enter username to add (without @${DOMAIN_ARG}): " USERNAME_ARG
                    fi
                    domain_user_add "$DOMAIN_ARG" "$USERNAME_ARG" ;;
                remove)
                    parse_user_args "$@"
                    if [[ -z "$DOMAIN_ARG" ]]; then select_domain_interactive; fi
                    if [[ ! -f "$DOMAINS_DIR/${DOMAIN_ARG}.yml" ]]; then error "Domain not found: $DOMAIN_ARG"; exit 1; fi
                    if [[ -z "$USERNAME_ARG" ]]; then select_user_interactive "$DOMAIN_ARG"; fi
                    domain_user_remove "$DOMAIN_ARG" "$USERNAME_ARG" ;;
                password)
                    parse_user_args "$@"
                    if [[ -z "$DOMAIN_ARG" ]]; then select_domain_interactive; fi
                    if [[ ! -f "$DOMAINS_DIR/${DOMAIN_ARG}.yml" ]]; then error "Domain not found: $DOMAIN_ARG"; exit 1; fi
                    if [[ -z "$USERNAME_ARG" ]]; then select_user_interactive "$DOMAIN_ARG"; fi
                    error "Password update not yet implemented. Use vault update <key> <value> to change user passwords."; exit 1 ;;
                *)
                    error "Unknown or missing subcommand for 'user'. Usage: $0 user <list|add|remove|password> ..."; show_help; exit 1;;
            esac
            ;;
        inventory)
            if [[ $# -eq 0 ]]; then
                error "Missing subcommand for 'inventory'. Usage: $0 inventory <list|add|remove|update> ..."
                show_help
                exit 1
            fi
            case "$1" in
                list)
                    inventory_list ;;
                add)
                    if [[ -z "${2:-}" ]]; then
                        error "Missing hostname for 'inventory add'. Usage: $0 inventory add <hostname>"
                        show_help
                        exit 1
                    fi
                    inventory_add "$2" ;;
                remove)
                    if [[ -z "${2:-}" ]]; then
                        error "Missing hostname for 'inventory remove'. Usage: $0 inventory remove <hostname>"
                        show_help
                        exit 1
                    fi
                    inventory_remove "$2" ;;
                update)
                    if [[ -z "${2:-}" ]]; then
                        error "Missing hostname for 'inventory update'. Usage: $0 inventory update <hostname>"
                        show_help
                        exit 1
                    fi
                    inventory_update "$2" ;;
                *)
                    error "Unknown or missing subcommand for 'inventory'. Usage: $0 inventory <list|add|remove|update> ..."
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        vault)
            if [[ $# -eq 0 ]]; then
                error "Missing subcommand for 'vault'. Usage: $0 vault <list|add|remove|init|destroy> ..."
                show_help
                exit 1
            fi
            case "$1" in
                list)
                    vault_list ;;
                add)
                    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                        error "Missing arguments for 'vault add'. Usage: $0 vault add <key> <value>"
                        show_help
                        exit 1
                    fi
                    vault_add "$2" "$3" ;;
                remove)
                    if [[ -z "${2:-}" ]]; then
                        error "Missing key for 'vault remove'. Usage: $0 vault remove <key>"
                        show_help
                        exit 1
                    fi
                    vault_remove "$2" ;;
                update)
                    if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                        error "Missing arguments for 'vault update'. Usage: $0 vault update <key> <value>"
                        show_help
                        exit 1
                    fi
                    vault_update "$2" "$3" ;;
                init)
                    vault_init ;;
                destroy)
                    vault_destroy "${2:-}" ;;
                *)
                    error "Unknown or missing subcommand for 'vault'. Usage: $0 vault <list|add|remove|init|destroy> ..."
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        deploy)
            deploy "${1:-}" ;;
        healthcheck)
            healthcheck ;;
        shell)
            mail_admin_shell ;;
        help|--help|-h)
            show_help ;;
        *)
            error "Unknown or missing command."
            show_help
            exit 1
            ;;
    esac
}

main "$@"
