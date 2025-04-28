#!/usr/bin/env bash
#
# Script: mail-admin.sh
# Description: Unified CLI dispatcher for managing iac-mailu configuration, secrets, and deployment.
# Usage: ./mail-admin.sh <module> <command> [options]
#
# Modules:
#   domain        Manage domain configurations (calls mail-domains.sh)
#   user          Manage users within domains (calls mail-users.sh)
#   vault         Manage Ansible vault secrets (calls playbook-vault.sh)
#   playbook      Run Ansible playbooks (calls playbook-runner.sh)
#   install-prereqs Install prerequisites (like yq)
#   help|--help|-h Show this help message or module-specific help
#
# See project STYLE_GUIDE.md for coding and output standards.

# --- Strict Mode & Error Handling ---
set -euo pipefail

# --- Configuration & Common Library ---
# Always resolve SCRIPT_DIR to the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || { echo "Error: Unable to source common.sh from mail-admin.sh"; exit 1; }

# --- Main Dispatcher Logic ---
main() {
    local module="${1:-help}" # Default to help if no module provided
    shift || true

    case "$module" in
        domain|domains)
            MAILU_ADMIN_DISPATCH=1 exec "$SCRIPT_DIR/lib/modules/mail-domains.sh" "$@"
            ;;
        user|users)
            MAILU_ADMIN_DISPATCH=1 exec "$SCRIPT_DIR/lib/modules/mail-users.sh" "$@"
            ;;
        vault)
            MAILU_ADMIN_DISPATCH=1 exec "$SCRIPT_DIR/lib/modules/playbook-vault.sh" "$@"
            ;;
        playbook|run|deploy|healthcheck|backup|restore)
            MAILU_ADMIN_DISPATCH=1 exec "$SCRIPT_DIR/lib/modules/playbook-runner.sh" "$module" "$@"
            ;;
        install-prereqs)
            # Keep prerequisite installation here for convenience
            install_yq # Assuming install_yq is the primary one needed now
            # Add other installations if necessary
            ;;
        check-prereqs)
            # Allow checking all common prereqs
             check_prerequisites "ansible" "ansible-vault" "yq" "git"
            ;;
        help|-h|--help)
            echo "iac-mailu Admin Helper"
            echo "Usage: $0 <module> <command> [options]"
            echo ""
            echo "Modules:"
            echo "  domain        Manage domain configurations (use '$0 domain help')"
            echo "  user          Manage users within domains (use '$0 user <domain> help')"
            echo "  vault         Manage Ansible vault secrets (use '$0 vault help')"
            echo "  playbook      Run Ansible playbooks (use '$0 playbook help')"
            echo "                Shortcuts: deploy, healthcheck, backup, restore"
            echo ""
            echo "Other Commands:"
            echo "  install-prereqs Install prerequisites (e.g., yq)"
            echo "  check-prereqs   Verify required tools are installed"
            echo "  help          Show this help message"
            echo ""
            echo "Run '$0 <module> help' for module-specific commands."
            ;;
        *)
            # Check if it's a direct playbook run attempt (e.g., site.yml)
            if [[ "$module" == *.yml && -f "$PLAYBOOKS_DIR/$module" ]]; then
                 exec "$SCRIPT_DIR/lib/modules/playbook-runner.sh" "$module" "$@"
            else
                error "Unknown module or command: $module"
                error "Run '$0 help' for usage."
                exit 1
            fi
            ;;
    esac
}

# --- Run Main ---
main "$@"
