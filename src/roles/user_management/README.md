# User Management Role

This Ansible role manages email users and aliases for the Mailu mail server. It handles user creation, password management, quota settings, and email aliases including catchall addresses.

## Responsibilities

- Creating and managing email users for domains
- Setting user quotas and access permissions
- Configuring spam filtering settings for users
- Creating email aliases and catchall addresses
- Managing user settings via the Mailu API

## Requirements

- Running Mailu instance with Admin API accessible
- Domain configurations with user definitions
- Password variables in Ansible vault

## Role Variables

### Default Variables

```yaml
# Base directory for domain configurations
domain_config_dir: "{{ playbook_dir }}/../domains"

# Base directory for mail server
mailu_base_dir: "/opt/mailu"

# Admin API URL
mailu_admin_api_url: "http://localhost:8080/admin/api/v1"

# Default user settings
default_user_quota_bytes: 1073741824  # 1 GB
default_user_enable_imap: true
default_user_enable_pop: true
default_user_enable_webmail: true
default_user_spam_enabled: true
default_user_spam_threshold: 80

# Whether to create catchall aliases for domains
enable_catchall: true

# Enable user debug output
user_debug: false
```

### Required Variables

- `vault_mailu_admin_secret`: The admin secret for the Mailu API

## Dependencies

- domain_management role (domains must be configured before users)

## Example Playbook

```yaml
- hosts: mail_servers
  roles:
    - role: docker_base
    - role: traefik
    - role: domain_management
    - role: user_management
      default_user_quota_bytes: 2147483648  # 2 GB
      enable_catchall: true
```

## Domain and User Configuration Format

Each domain should have its own YAML file in the `domain_config_dir` with users defined:

```yaml
# domains/example.com.yml
domain: example.com
hostname: mail.example.com
webmail: webmail.example.com
admin: admin.example.com

users:
  - name: user1
    password_var: vault_user1_password
    quota_bytes: 1073741824  # 1 GB
    enable_imap: true
    enable_pop: true
    enable_webmail: true
    spam_enabled: true
    spam_threshold: 80
    catchall: false
    comment: "Regular user account"
    aliases:
      - localpart: info
      - localpart: hello
      - localpart: contact
      
  - name: support
    password_var: vault_support_password
    catchall: true  # This user will receive all unmatched emails for the domain
    aliases:
      - localpart: help
```

## Vault Configuration

Passwords should be stored in an Ansible vault file:

```yaml
# vault/secrets.yml
vault_user1_password: "SecurePassword123"
vault_support_password: "AnotherSecurePassword456"
```

## Author Information

Created for the Mailu Multi-Domain Ansible project.