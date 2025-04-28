#!/usr/bin/env bash

# Script: mail-domains.sh
# Description: Manage iac-mailu domain configurations (add, list, remove domains).
# Usage: mail-admin.sh domain <command> [options]
#
# NOTE: Per project standards, there must be NO variable assignments or logic outside functions and the main dispatcher. Only function definitions and 'main "$@"' are allowed at the top level. This is required for robust, production-grade Bash scripting with 'set -u'.
#
# Commands:
#   list                List configured domains
#   add <domain>        Add a new domain configuration interactively
#   remove <domain>     Remove a domain configuration
#   help, -h, --help    Show this help message
#
# Dependencies:
#   - yq (for YAML parsing)
#
# Follows iac-mailu coding standards: robust input validation, user status reporting, colorized output, and strict error handling.

set -euo pipefail

# --- Colors ---
CYAN='\033[36m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
RESET='\033[0m'

# --- Common Library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh" || { echo -e "${RED}[-] Error: Unable to source common.sh${RESET}"; exit 1; }

# --- Prevent Direct Execution Unless Dispatched ---
if [[ "${MAILU_ADMIN_DISPATCH:-}" != "1" ]]; then
    echo -e "${RED}[-] This script is an internal module. Use 'mail-admin.sh' as the entry point.${RESET}"
    echo "Usage: mail-admin.sh domain <command> [options]"
    exit 2
fi

# --- Helper Functions ---
print_info()    { echo -e "${CYAN}[*] $*${RESET}"; }
print_success() { echo -e "${GREEN}[+] $*${RESET}"; }
print_error()   { echo -e "${RED}[-] $*${RESET}"; }
print_warn()    { echo -e "${YELLOW}[!] $*${RESET}"; }

# --- Usage/Help Function ---
domain_help() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        # Show general domain module help
        echo -e "${CYAN}[*] Domain Management Module Help${RESET}"
        echo "Usage: mail-admin.sh domain <command> [options]"
        echo ""
        echo "Commands:"
        echo "  list                List all configured domains (from src/domains/)"
        echo "  add <domain>        Add a new domain configuration interactively (validates input)"
        echo "  remove <domain>     Remove a domain configuration file (does not touch secrets)"
        echo "  view <domain>       View the formatted YAML configuration of a specific domain file"
        echo "  help [command]      Show this help or help for a specific command"
        echo ""
        echo "Examples:"
        echo "  mail-admin.sh domain list"
        echo "  mail-admin.sh domain add example.com"
        echo "  mail-admin.sh domain remove example.com"
        echo "  mail-admin.sh domain help add      # Get help specifically for the 'add' command"
        echo ""
        echo "Notes:"
        echo "- Domain config files are stored in src/domains/<domain>.yml."
        echo "- User entries and secrets must be managed separately."
        echo "- See docs/PRD.md for schema and operational details."
    else
        # Show command-specific help
        case "$command" in
            list)
                echo -e "${CYAN}[*] Help for 'domain list' command${RESET}"
                echo "Usage: mail-admin.sh domain list"
                echo ""
                echo "Lists all configured domains found in the domains directory."
                echo "Domains are identified by their filenames (example.com from src/domains/example.com.yml)."
                echo ""
                echo "This command does not take any arguments."
                ;;
            add)
                echo -e "${CYAN}[*] Help for 'domain add' command${RESET}"
                echo "Usage: mail-admin.sh domain add <domain_name>"
                echo ""
                echo "Adds a new domain configuration file (src/domains/<domain_name>.yml) interactively,"
                echo "prompting for necessary details such as hostname, webmail, and admin hostnames."
                echo ""
                echo "Arguments:"
                echo "  <domain_name>  The fully qualified domain name to add (e.g., example.com)"
                echo ""
                echo "The domain name must follow RFC1035 format requirements."
                echo "After creating a domain, use 'mail-admin.sh user add <username> <domain>' to add users."
                ;;
            remove)
                echo -e "${CYAN}[*] Help for 'domain remove' command${RESET}"
                echo "Usage: mail-admin.sh domain remove <domain_name> [--force]"
                echo ""
                echo "Removes a domain configuration file (src/domains/<domain_name>.yml)."
                echo "This action requires confirmation and only removes the configuration file."
                echo ""
                echo "Arguments:"
                echo "  <domain_name>  The fully qualified domain name to remove"
                echo "  [--force]      Optional flag to force removal without confirmation"
                echo ""
                echo "WARNING: This does not automatically remove associated secrets in the vault"
                echo "         that might need manual cleanup."
                ;;
            view)
                echo -e "${CYAN}[*] Help for 'domain view' command${RESET}"
                echo "Usage: mail-admin.sh domain view <domain_name>"
                echo ""
                echo "Views the formatted YAML configuration of a specific domain file"
                echo "(src/domains/<domain_name>.yml)."
                echo ""
                echo "Arguments:"
                echo "  <domain_name>  The fully qualified domain name whose configuration"
                echo "                 file should be viewed (e.g., example.com)"
                ;;
            help)
                echo -e "${CYAN}[*] Help for 'domain help' command${RESET}"
                echo "Usage: mail-admin.sh domain help [command]"
                echo ""
                echo "Shows help information for the domain module or a specific command."
                echo ""
                echo "Arguments:"
                echo "  [command]  Optional command name to get specific help"
                echo "             (e.g., list, add, remove, view)"
                echo ""
                echo "Examples:"
                echo "  mail-admin.sh domain help"
                echo "  mail-admin.sh domain help add"
                ;;
            *)
                print_error "Unknown command: $command"
                print_warn "Available commands: list, add, remove, view, help"
                return 1
                ;;
        esac
    fi
}

# --- Main Action Functions ---
domain_list() {
    print_info "Listing configured domains in $DOMAINS_DIR..."
    local domain_files=()
    local file
    shopt -s nullglob
    for file in "$DOMAINS_DIR"/*.yml; do
        [[ "$file" == *.disabled ]] && continue
        domain_files+=("$file")
    done
    shopt -u nullglob

    if [[ ${#domain_files[@]} -eq 0 ]]; then
        print_warn "No domain configuration files (*.yml) found."
        return 0
    fi

    for file in "${domain_files[@]}"; do
        echo " - $(basename "${file%.yml}")"
    done
    print_success "Found ${#domain_files[@]} domain(s)."
}

domain_add() {
    # Defensive: Check for required argument
    if [[ $# -lt 1 || -z "${1:-}" ]]; then
        print_error "Missing required argument: <domain_name>"
        print_warn "Usage: mail-admin.sh domain add <domain_name>"
        exit 1
    fi
    check_prerequisites "yq"
    local domain_name="$1"
    local domain_file
    domain_file="$DOMAINS_DIR/${domain_name}.yml"

    # Validate domain format (RFC 1035)
    if ! [[ "$domain_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](\.[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])+$ ]]; then
        print_error "Invalid domain name format: $domain_name"
        exit 1
    fi
    if [[ -f "$domain_file" ]]; then
        print_error "Domain configuration already exists: $domain_file"
        exit 1
    fi

    print_info "Adding domain configuration for: $domain_name"
    read -rp "Mail hostname [mail.${domain_name}]: " hostname; hostname=${hostname:-mail.${domain_name}}
    read -rp "Webmail hostname [webmail.${domain_name}]: " webmail; webmail=${webmail:-webmail.${domain_name}}
    read -rp "Admin hostname [webmailadmin.${domain_name}]: " admin; admin=${admin:-webmailadmin.${domain_name}}

    print_info "Creating domain file: $domain_file"
    {
        echo "---"
        echo "# Domain configuration for ${domain_name}"
        echo "domain: ${domain_name}"
        echo "hostname: ${hostname}"
        echo "webmail: ${webmail}"
        echo "admin: ${admin}"
        echo ""
        echo "# List of users for this domain"
        echo "# - name: <username>"
        echo "#   password_var: vault_<username>_${domain_name//./_}"
        echo "#   catchall: true # Optional, only one per domain"
        echo "#   update_password: true # Optional, set to force password update on next run"
        echo "users: []"
        echo ""
        echo "# Optional overrides for DNS/Security (defaults are usually sufficient)"
        echo "# dkim_selector: mail"
        echo "# dmarc_policy: \"v=DMARC1; p=none; rua=mailto:postmaster@${domain_name}\""
        echo "# spf_policy: \"v=spf1 mx a ~all\""
    } > "$domain_file"

    if yq eval "$domain_file" > /dev/null; then
        print_success "Domain configuration file created: $domain_file"
        print_warn "NEXT: Add users with 'mail-admin.sh user add <username> <domain>'"
    else
        print_error "Failed to create a valid YAML file: $domain_file"
        rm -f "$domain_file"
        exit 1
    fi
}

domain_remove() {
    # Parse arguments
    local domain_name=""
    local force=false

    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                force=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                print_warn "Usage: mail-admin.sh domain remove <domain_name> [--force]"
                exit 1
                ;;
            *)
                if [[ -z "$domain_name" ]]; then
                    domain_name="$1"
                    shift
                else
                    print_error "Too many arguments"
                    print_warn "Usage: mail-admin.sh domain remove <domain_name> [--force]"
                    exit 1
                fi
                ;;
        esac
    done

    # Defensive: Check for required argument
    if [[ -z "${domain_name}" ]]; then
        print_error "Missing required argument: <domain_name>"
        print_warn "Usage: mail-admin.sh domain remove <domain_name> [--force]"
        exit 1
    fi
    
    local domain_file
    domain_file="$DOMAINS_DIR/${domain_name}.yml"

    if [[ ! -f "$domain_file" ]]; then
        print_error "Domain configuration not found: $domain_file"
        exit 1
    fi

    # Prompt for confirmation unless --force is specified
    if [[ "$force" != "true" ]]; then
        print_warn "This will remove the domain configuration file: $domain_file"
        print_warn "It does NOT automatically remove users or secrets from the vault."
        read -rp "Are you sure you want to remove this domain configuration? [y/N]: " confirm
        if [[ "${confirm,,}" != "y" ]]; then
            print_info "Operation cancelled."
            exit 0
        fi
    else
        print_warn "Force flag detected. Removing domain configuration without confirmation: $domain_file"
        print_warn "NOTE: This does NOT automatically remove users or secrets from the vault."
    fi

    print_info "Removing domain file: $domain_file"
    if rm -f "$domain_file"; then
        print_success "Domain configuration file removed: $domain_file"
    else
        print_error "Failed to remove domain configuration file: $domain_file"
        exit 1
    fi
}

domain_view() {
    # Defensive: Check for required argument or offer selection
    local domain_name="${1:-}"
    local domain_file

    if [[ -z "$domain_name" ]]; then
        # No domain provided, offer interactive selection
        print_info "No domain specified. Please select from the available domains:"
        
        # Get list of available domains
        local domain_files=()
        local file
        shopt -s nullglob
        for file in "$DOMAINS_DIR"/*.yml; do
            [[ "$file" == *.disabled ]] && continue
            domain_files+=("$file")
        done
        shopt -u nullglob

        # Check if any domains exist
        if [[ ${#domain_files[@]} -eq 0 ]]; then
            print_warn "No domain configuration files (*.yml) found."
            print_error "No domains available to view."
            exit 1
        fi

        # Display domain options
        local i=1
        for file in "${domain_files[@]}"; do
            echo "  $i) $(basename "${file%.yml}")"
            ((i++))
        done

        # Prompt for selection
        local selection
        read -rp "Enter domain number to view (1-${#domain_files[@]}): " selection
        
        # Validate selection
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#domain_files[@]} ]]; then
            print_error "Invalid selection: $selection"
            exit 1
        fi

        # Set domain file based on selection
        domain_file="${domain_files[$((selection-1))]}"
        domain_name="$(basename "${domain_file%.yml}")"
    else
        # Domain was provided, check if it exists
        domain_file="$DOMAINS_DIR/${domain_name}.yml"
        if [[ ! -f "$domain_file" ]]; then
            print_error "Domain configuration not found: $domain_file"
            exit 1
        fi
    fi

    # Check prerequisite: yq
    check_prerequisites "yq"
    
    print_info "Viewing domain configuration for: $domain_name"
    print_info "File path: $domain_file"
    echo ""
    
    # Use yq to format the YAML for better readability
    if ! yq eval --colors "$domain_file"; then
        print_error "Failed to parse YAML file: $domain_file"
        exit 1
    fi

    print_success "Successfully displayed domain configuration for: $domain_name"
}

# --- Main Script Logic ---
main() {
    # Defensive: Always check for at least one argument, default to help
    local command="${1:-}"; shift || true
    case "$command" in
        list)
            domain_list
            ;;
        add)
            domain_add "$@"
            ;;
        remove)
            domain_remove "$@"
            ;;
        view)
            domain_view "$@"
            ;;
        help|-h|--help|"")
            domain_help "$@"
            ;;
        *)
            print_error "Unknown command: $command"
            print_warn "Run 'mail-admin.sh domain help' for usage."
            exit 1
            ;;
    esac
}

# Only function definitions and main dispatcher below. No variable assignments or logic outside functions. This is required for robust, production-grade Bash scripting with 'set -u'.

main "$@"
