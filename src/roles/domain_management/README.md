# Domain Management Role

This Ansible role manages email domains for the Mailu mail server. It handles domain configuration, registration with the Mailu admin API, and DKIM key generation.

## Responsibilities

- Finding and loading domain configuration files
- Registering domains with Mailu
- Creating domain aliases
- Generating DKIM keys for email authentication
- Exporting domain information for use by other roles

## Requirements

- Running Mailu instance
- Docker
- Domain configuration files in YAML format

## Role Variables

### Default Variables

```yaml
# Base directory for domain configurations
domain_config_dir: "{{ playbook_dir }}/../domains"

# Base directory for mail server
mailu_base_dir: "/opt/mailu"

# Whether to generate debug output
domain_debug: false

# Default maximum users per domain (-1 = unlimited)
domain_max_users: -1

# Default maximum aliases per domain (-1 = unlimited)
domain_max_aliases: -1

# Default maximum quota in bytes (-1 = unlimited)
domain_max_quota_bytes: -1

# DKIM configuration
dkim_enabled: true

# Default DMARC policy
default_dmarc_policy: "v=DMARC1; p=none; rua=mailto:postmaster@{{ domain }}"
```

### Required Variables

- `vault_mailu_admin_secret`: The admin secret for the Mailu API

## Dependencies

- docker_base role
- traefik role (if using Traefik for reverse proxy)

## Example Playbook

```yaml
- hosts: mail_servers
  roles:
    - role: docker_base
    - role: traefik
    - role: domain_management
      domain_config_dir: "{{ playbook_dir }}/../custom_domains"
      dkim_enabled: true
```

## Domain Configuration Format

Each domain should have its own YAML file in the `domain_config_dir` with the following structure:

```yaml
# domains/example.com.yml
domain: example.com
hostname: mail.example.com
webmail: webmail.example.com
admin: webmailadmin.example.com
max_users: -1
max_aliases: -1
max_quota_bytes: -1

domain_aliases:
  - alias1.example.com
  - alias2.example.com

users:
  - name: user1
    password_var: vault_user1_password
    catchall: false
  - name: support
    password_var: vault_support_password
    catchall: true
```

## Author Information

Created for the Mailu Multi-Domain Ansible project.