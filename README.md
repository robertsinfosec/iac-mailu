# Mailu Multi-Domain Ansible Deployment

This Ansible playbook automates the deployment and management of a [Mailu](https://mailu.io/) email server with multi-domain support, integrated with Traefik for TLS handling, Cloudflare for DNS management, and CrowdSec for security hardening.

<img src="https://raw.githubusercontent.com/Mailu/Mailu/refs/heads/master/docs/assets/logomark.png" alt="Mailu Logo" width="200"/>

## Features

- **Multi-domain email hosting** - Configure and manage multiple email domains from a single server
- **Automated DNS management** via Cloudflare API
- **Per-domain TLS certificates** with Cloudflare DNS challenge
- **Security hardening** via CrowdSec integration
- **Health monitoring** with Ntfy notifications
- **CI/CD integration** via GitHub Actions workflow
- **Complete email server stack** including:
  - SMTP (Postfix)
  - IMAP/POP3 (Dovecot)
  - Webmail (Roundcube)
  - Admin interface
  - Antispam (Rspamd)
  - Antivirus (ClamAV)

## Prerequisites

- A server with a public IP address running a recent Linux distribution
- Docker and Docker Compose installed
- Ansible 2.10+ on your control node
- Domain(s) managed through Cloudflare DNS
- Cloudflare API token with DNS edit permissions
- (Optional) Access to Ntfy.sh or a self-hosted Ntfy instance for notifications

## Directory Structure

```
.
├── ansible.cfg                    # Ansible configuration
├── domains/                       # Domain configuration files
│   └── example.com.yml            # Example domain configuration
├── group_vars/                    # Group variables
│   └── all.yml                    # Common variables for all hosts
├── inventory/                     # Inventory files
│   └── hosts                      # Host definitions
├── playbooks/                     # Ansible playbooks
│   ├── health_check.yml           # Health checking playbook
│   └── site.yml                   # Main playbook
├── roles/                         # Ansible roles
│   └── mailu/                     # Mailu role
│       ├── files/                 # Static files
│       ├── handlers/              # Handlers for service restarts
│       │   └── main.yml
│       ├── tasks/                 # Task definitions
│       │   ├── health_check.yml   # Health monitoring tasks
│       │   ├── main.yml           # Main tasks file
│       │   ├── manage_crowdsec.yml # CrowdSec integration
│       │   ├── manage_dns.yml     # DNS record management
│       │   ├── manage_domains.yml # Domain management
│       │   └── manage_users.yml   # User management
│       └── templates/             # Role-specific templates
├── templates/                     # Global templates
│   ├── .env.j2                    # Mailu environment configuration
│   ├── crowdsec_acquis.yaml.j2    # CrowdSec log acquisition config
│   ├── crowdsec_collections.yaml.j2 # CrowdSec security collections
│   ├── docker-compose.yml.j2      # Docker Compose template
│   ├── traefik_dynamic.yml.j2     # Traefik dynamic configuration
│   └── traefik.yml.j2             # Traefik static configuration
├── vault/                         # Ansible vault for secrets
│   └── secrets.yml                # Encrypted secrets
├── .github/                       # GitHub specific files
│   └── workflows/                 # GitHub Actions workflows
│       └── deploy.yml             # Deployment workflow
├── PERSONALIZATION.md            # Guide for customizing the repository
└── README.md                     # This file
```

## Configuration

### Setting Up Domains

1. Create a domain configuration file in the `domains/` directory, e.g., `yourdomain.com.yml`:

```yaml
---
# domains/yourdomain.com.yml
domain: yourdomain.com
hostname: mail.yourdomain.com
webmail: webmail.yourdomain.com
admin: webmailadmin.yourdomain.com

users:
  - name: user1
    password_var: vault_user1_yourdomain_com
    catchall: true
  - name: postmaster
    password_var: vault_postmaster_yourdomain_com

# Optional: Override default DMARC
# dmarc_policy: "v=DMARC1; p=reject; rua=mailto:dmarc@yourdomain.com"
```

2. Add the corresponding passwords to your Ansible vault:

```bash
ansible-vault edit vault/secrets.yml
```

Add entries for each password variable referenced in your domain config:

```yaml
vault_user1_yourdomain_com: "YourSecurePassword1"
vault_postmaster_yourdomain_com: "YourSecurePassword2"
vault_cloudflare_api_token: "YourCloudflareAPIToken"
vault_mailu_admin_secret: "YourMailuAdminAPISecret"
```

### Inventory Setup

Edit the inventory file to specify your target server(s):

```ini
# inventory/hosts
[mail_server]
mail.example.com ansible_host=203.0.113.10 ansible_user=admin
```

### Common Variables

Review and adjust the common variables in `group_vars/all.yml`:

```yaml
# Common variables for all hosts
mailu_base_dir: /opt/mailu
traefik_network_name: traefik_proxy
traefik_config_dir: "{{ mailu_base_dir }}/traefik"
default_dmarc_policy: "v=DMARC1; p=none; rua=mailto:postmaster@{{ domain }}"
crowdsec_enabled: true

# Health monitoring settings
health_check_enabled: true
health_check_interval: 5m  # Format for cron job

# Ntfy notification settings
ntfy_enabled: false  # Set to true to enable notifications
ntfy_url: https://ntfy.sh  # Change to self-hosted URL if needed
ntfy_topic: "mailu-alerts"  # Topic name for notifications
```

### User and Ownership Variables: ansible_user vs. target_user

**ansible_user** is the SSH user Ansible uses to connect to the target host. **target_user** is the system user that will own Mailu files, directories, and run Mailu-related services on the target host. By default, both are set to 'mailu' for security and production-readiness, but you can override them per host or group as needed.

- **Default (in group_vars/all.yml):**
  ```yaml
  target_user: mailu
  ansible_user: mailu
  ```
- **Override per host in inventory/hosts:**
  ```ini
  mail.example.com ansible_user=operations target_user=operations
  mail2.example.com ansible_user=conan_the_deployer target_user=mailu
  ```
- **Override per group in group_vars/mygroup.yml:**
  ```yaml
  target_user: ansible
  ansible_user: ansible
  ```

**Best Practice:**
- Always use `target_user` for file ownership and service management in roles and playbooks.
- Always use `ansible_user` for SSH connection.
- Document any overrides in your inventory or group_vars for clarity.

## Usage

### Deploying the Stack

```bash
# Deploy using the site playbook
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

### Adding a New Domain

1. Create a new domain configuration file in the `domains/` directory
2. Add password variables to your vault
3. Run the playbook

### Managing Users

To add, update, or remove users:

1. Modify the `users` section in your domain configuration file
2. Run the playbook

For password updates, add the `update_password: true` flag to the user entry:

```yaml
users:
  - name: user1
    password_var: vault_user1_yourdomain_com
    update_password: true
```

### Health Monitoring

Health checks are automatically configured to run periodically. To run a check manually:

```bash
ansible-playbook -i inventory/hosts playbooks/health_check.yml --ask-vault-pass
```

To enable notifications via Ntfy when health checks fail, set the following in `group_vars/all.yml`:

```yaml
ntfy_enabled: true
ntfy_url: https://ntfy.sh  # Or your self-hosted instance
ntfy_topic: "your-private-topic"  # Choose a unique, private topic
```

## GitHub Actions Deployment

This project includes a GitHub Actions workflow for automated deployment. To use it:

1. Set up a self-hosted GitHub Actions runner on your server or network
2. Configure the following secrets in your GitHub repository:
   - `ANSIBLE_VAULT_PASSWORD`: Your Ansible vault password
   - `SSH_PRIVATE_KEY`: Private key for SSH access to the server
   - `KNOWN_HOSTS`: Known hosts file content for the server

The workflow will:
- Run `ansible-lint` to check playbook syntax
- Deploy in check mode first for pull requests
- Deploy to the selected environment for pushes to main/production
- Run health checks to verify the deployment

Deployment can be manually triggered via the GitHub Actions interface with:
- Environment selection (staging or production)
- Option to run in check mode (dry run)

## Security Notes

- CrowdSec integration provides behavioral detection and prevention of attacks
- The LAPI key for CrowdSec will be output during the first run and should be added to your vault
- All sensitive information is stored in the Ansible vault
- Mail services are NOT proxied through Cloudflare to maintain email security
- Admin and webmail interfaces ARE proxied through Cloudflare for enhanced protection

## Maintenance

### Updating the Stack

To update to the latest Mailu and supporting services:

```bash
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

The playbook will pull the latest images and recreate containers as needed.

### Backing Up

The playbook does not include backup functionality. Consider implementing a backup solution for:

- `/opt/mailu/data` - User data, emails, etc.
- `/opt/mailu/certs` - TLS certificates
- Database dumps if using an external database

## Customization

If you want to personalize this repository for your specific needs, see [PERSONALIZATION.md](PERSONALIZATION.md) for detailed instructions on:

- Forking and customizing the codebase
- Setting up your own configuration
- Maintaining your personalized version
- Advanced customizations

## Troubleshooting

Common issues:

1. **DNS propagation delays** - DNS changes may take time to propagate
2. **TLS certificate errors** - Verify Cloudflare API permissions 
3. **Initial user creation fails** - The admin API may not be available immediately; retry the playbook
4. **Health check failures** - Check container logs with `docker logs mailu_front` (or other container names)
5. **Ntfy notification issues** - Ensure the topic is correct and network connectivity to Ntfy service

## License

This playbook is provided under the MIT License.

## References

- [Mailu Documentation](https://mailu.io/master/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [CrowdSec Documentation](https://docs.crowdsec.net/)
- [Cloudflare API Documentation](https://api.cloudflare.com/)
- [Ntfy Documentation](https://docs.ntfy.sh/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)