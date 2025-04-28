#!/usr/bin/env bash
#
# Script: playbook-runner.sh
# Description: Run common iac-mailu Ansible playbooks.
# Usage: ./playbook-runner.sh <playbook_action> [ansible_options]
#
# Actions:
#   deploy        Run the main site.yml playbook
#   healthcheck   Run the health_check.yml playbook
#   backup        Run the backup.yml playbook
#   restore       Run the restore.yml playbook
#   <playbook.yml> Run a specific playbook from the playbooks directory
#
# Options:
#   check         Pass --check to ansible-playbook (dry-run)
#   Any other options are passed directly to ansible-playbook
#

# ---------------------------------------------------------------------------
# WARNING: This is an internal support script for iac-mailu.
# Do NOT run this script directly. Use 'mail-admin.sh' as the entry point.
# ---------------------------------------------------------------------------

# --- Common Library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh" || { echo "Error: Unable to source common.sh"; exit 1; }

# --- Prevent Direct Execution Unless Dispatched ---
if [[ "${MAILU_ADMIN_DISPATCH:-}" != "1" ]]; then
    echo -e "\033[31m[-] This script is an internal module. Use 'mail-admin.sh' as the entry point.\033[0m"
    echo "Usage: mail-admin.sh playbook <action|playbook.yml> [options]"
    exit 2
fi

playbook_help() {
    echo -e "\033[36m[*] Playbook Runner Module Help\033[0m"
    echo "Usage: mail-admin.sh playbook <action|playbook.yml> [options]"
    echo ""
    echo "Actions:"
    echo "  deploy              Run site.yml (main deployment)"
    echo "  healthcheck         Run health_check.yml"
    echo "  backup              Run backup.yml"
    echo "  restore             Run restore.yml (with confirmation)"
    echo "  <playbook.yml>      Run a specific playbook from playbooks/"
    echo ""
    echo "Options:"
    echo "  check               Run playbook in check mode (dry-run)"
    echo "  ...                 Other options are passed directly to ansible-playbook"
    echo ""
    echo "Examples:"
    echo "  mail-admin.sh playbook deploy check"
    echo "  mail-admin.sh playbook site.yml --tags mailu"
    echo ""
    echo "Notes:"
    echo "- All playbooks are run from src/playbooks/."
    echo "- Use tags for granular execution."
}

# --- Main Script Logic ---
main() {
    local action="${1:-}"
    shift || true # Shift off action
    local playbook_name=""
    local ansible_args=()

    # If the user runs 'mail-admin.sh playbook help' or similar, show help
    if [[ -z "$action" || "$action" == "help" || "$action" == "-h" || "$action" == "--help" || "$action" == "playbook" ]]; then
        playbook_help
        exit 0
    fi

    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            check|--check)
                ansible_args+=("--check")
                shift # past argument
                ;;
            # Add other specific options if needed, e.g., --limit
            # --limit=*)
            #    ansible_args+=("$1")
            #    shift # past argument=value
            #    ;;
            *)
                # Assume remaining args are for ansible-playbook
                ansible_args+=("$1")
                shift # past argument
                ;;
        esac
    done

    case "$action" in
        deploy)
            playbook_name="site.yml"
            info "Running main deployment playbook..."
            ;;
        healthcheck|health)
            playbook_name="health_check.yml"
            info "Running health check playbook..."
            ;;
        backup)
            playbook_name="backup.yml"
            info "Running backup playbook..."
            ;;
        restore)
            playbook_name="restore.yml"
            info "Running restore playbook..."
            warning "Ensure backups exist and target system is prepared before restoring!"
            read -rp "Proceed with restore? [y/N]: " confirm
            if [[ "${confirm,,}" != "y" ]]; then
                info "Restore operation cancelled."
                exit 0
            fi
            ;;
        *.yml)
            # Allow running any playbook directly
            if [[ -f "$PLAYBOOKS_DIR/$action" ]]; then
                playbook_name="$action"
                info "Running specified playbook: $playbook_name"
            else
                error "Specified playbook not found: $PLAYBOOKS_DIR/$action"
                exit 1
            fi
            ;;
        help|-h|--help|"")
            playbook_help
            exit 0
            ;;
        *)
            error "Unknown action or invalid playbook: $action"
            error "Run 'mail-admin.sh playbook help' for usage."
            exit 1
            ;;
    esac

    # Use the common runner function from lib/common.sh
    run_ansible_playbook "$playbook_name" "${ansible_args[@]}"
}

# --- Run Main ---
main "$@"
