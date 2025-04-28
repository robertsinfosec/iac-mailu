# iac-mailu Scripts

This directory contains helper scripts for managing the `iac-mailu` deployment.

## `mail-admin.sh`

A unified command-line interface (CLI) and interactive shell for managing `iac-mailu` configuration, secrets, inventory, and deployment tasks.

### Prerequisites

- `ansible`
- `ansible-vault`
- `yq` (Go-based version, v4+) - Required for YAML manipulation.
- `git`

You can install the correct `yq` version using the script itself:
```bash
./scripts/mail-admin.sh install-prereqs
```

### Usage

```bash
./scripts/mail-admin.sh <command> [subcommand] [options]
./scripts/mail-admin.sh shell  # Enter interactive mode
```

### Commands

#### Domain Management (`domain`)

-   `domain list`: List all configured mail domains found in `src/domains/`.
-   `domain add [--domain <domain_name>]`: Interactively prompts to add a new domain configuration file (`src/domains/<domain_name>.yml`).
-   `domain remove [--domain <domain_name>]`: Removes the specified domain configuration file.

#### User Management (`user`)

-   `user list [--domain <domain_name>]`: List users within a specific domain. Prompts interactively if `--domain` is omitted.
-   `user add [--domain <domain_name>] [--username <username>]`: Adds a new user to a domain. Generates a secure password, adds it to the vault (`vault_<username>_<domain_underscores>`), and updates the domain file. Prompts interactively if arguments are omitted.
-   `user remove [--domain <domain_name>] [--username <username>]`: Removes a user from a domain's configuration file. Prompts interactively if arguments are omitted.
-   `user password [--domain <domain_name>] [--username <username>]`: *(Not yet implemented)* Intended for updating user passwords. Currently requires manual vault update.

#### Vault Management (`vault`)

Requires `src/vault/secrets.yml` and `.vault_pass` to exist.

-   `vault list`: Lists all top-level keys stored in the Ansible vault (`src/vault/secrets.yml`).
-   `vault add <key> <value>`: Adds or updates a key-value pair in the vault.
-   `vault remove <key>`: Removes a key from the vault.
-   `vault update <key> <value>`: Updates an existing key in the vault. Fails if the key doesn't exist.
-   `vault init`: Initializes the vault by creating `.vault_pass` (if missing) and creating/encrypting `src/vault/secrets.yml` (if missing or unencrypted).
-   `vault destroy [--force]`: Deletes the `.vault_pass` file and the `src/vault/secrets.yml` file. Prompts for confirmation unless `--force` is used.

#### Inventory Management (`inventory`)

Manages server entries in `src/inventory/hosts`.

-   `inventory list`: Displays the servers configured in the inventory file.
-   `inventory add <hostname>`: Interactively prompts for details (IP, user, connection method, sudo) and adds a new server entry to the inventory. Handles adding SSH/sudo passwords to the vault if needed.
-   `inventory remove <hostname>`: Removes a server entry from the inventory. Optionally prompts to remove related vault secrets.
-   `inventory update <hostname>`: Interactively prompts to update the configuration for an existing server entry. Handles adding/removing vault secrets as needed.
-   `inventory test <hostname>`: Tests the Ansible connection to the specified host using the `ping` module.

#### Deployment & Checks

-   `deploy [check]`: Runs the main deployment playbook (`src/playbooks/site.yml`). If `check` is provided, runs in check mode (`--check`). Validates global variables first.
-   `healthcheck`: Runs the health check playbook (`src/playbooks/health_check.yml`).

#### Utility

-   `install-prereqs`: Installs the Go-based `yq` binary to `/usr/local/bin/yq` (may require sudo).
-   `shell`: Enters an interactive shell mode where commands can be run without `./scripts/mail-admin.sh` prefix.
-   `help`, `--help`, `-h`: Displays the help message summarizing commands.

### Interactive Shell

Running `./scripts/mail-admin.sh shell` provides a convenient way to run multiple commands without retyping the script path:

```
[*] Entering mail-admin shell. Type 'help' for commands, 'exit' to quit.
mail-admin > domain list
[*] Listing configured domains...
example.com
[+] Domain list complete.
mail-admin > vault list
[*] Listing vault keys...
vault_cloudflare_api_token
vault_mailu_admin_secret
vault_postmaster_example_com
vault_user1_example_com
[+] Vault key list complete.
mail-admin > exit
```

### Output Formatting

The script uses colored output to indicate status:

-   `[*]` (Cyan): Informational message (e.g., starting an action).
-   `[+]` (Green): Success message.
-   `[-]` (Red): Error message.
-   `[!]` (Yellow): Warning message.
-   `[%]` (Gray): Debug message (if `DEBUG=true` is set).
