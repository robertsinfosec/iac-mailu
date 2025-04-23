# Traefik Role

This Ansible role installs and configures Traefik as a reverse proxy for the Mailu mail server. It handles TLS certificate management, routing, and security configurations.

## Responsibilities

- Installing and configuring Traefik as a Docker container
- Setting up TLS certificate management with Let's Encrypt
- Configuring HTTP to HTTPS redirects
- Setting up security headers and middlewares
- Configuring the Traefik dashboard (optional)
- Setting up routing for mail services

## Requirements

- Docker and Docker Compose (can be installed using the docker_base role)
- Public IP address for Let's Encrypt validation
- Domain names configured in DNS

## Role Variables

### Default Variables

```yaml
# Traefik version
traefik_version: "v2.10.3"

# Traefik container name
traefik_container_name: "traefik"

# Base directory for Traefik
traefik_base_dir: "/opt/traefik"

# Traefik configuration directories
traefik_config_dir: "{{ traefik_base_dir }}/config"
traefik_dynamic_config_dir: "{{ traefik_config_dir }}/dynamic"
traefik_acme_dir: "{{ traefik_base_dir }}/acme"

# Traefik network name (should match docker_base network)
traefik_network_name: "traefik-public"

# Traefik ports
traefik_http_port: 80
traefik_https_port: 443

# Traefik dashboard configuration
traefik_dashboard_enabled: true
traefik_dashboard_host: "traefik.{{ primary_domain | default('example.com') }}"
traefik_dashboard_auth_enabled: true
traefik_dashboard_users:
  - name: "admin"
    password_var: "vault_traefik_dashboard_password"

# Let's Encrypt configuration
traefik_acme_enabled: true
traefik_acme_email: "admin@{{ primary_domain | default('example.com') }}"
traefik_acme_challenge_type: "tlsChallenge"
traefik_acme_staging: false

# Traefik log configuration
traefik_log_level: "INFO"  # Options: DEBUG, INFO, WARN, ERROR
traefik_access_logs_enabled: true
traefik_access_logs_file: "/var/log/traefik/access.log"

# Security options
traefik_ssl_options: "intermediate"  # Options: modern, intermediate, old
traefik_hsts_enabled: true
traefik_hsts_max_age: 31536000  # 1 year

# Default certificate resolver
traefik_default_cert_resolver: "letsencrypt"

# Middleware configurations
traefik_default_middlewares:
  - "security-headers@file"
  - "gzip@file"
```

### Required Variables

- `primary_domain`: The primary domain for your mail server
- `vault_traefik_dashboard_password`: Password for the Traefik dashboard (if authentication is enabled)

## Dependencies

- docker_base role

## Example Playbook

```yaml
- hosts: mail_servers
  roles:
    - role: docker_base
    - role: traefik
      traefik_dashboard_enabled: true
      traefik_acme_email: "admin@example.com"
```

## Security Considerations

This role implements several security best practices for Traefik:

1. Automatic redirection from HTTP to HTTPS
2. Modern or intermediate SSL/TLS configurations
3. Security headers (HSTS, XSS Protection, Content Type Nosniff, etc.)
4. Password protection for the Traefik dashboard
5. Non-root container execution

## Author Information

Created for the Mailu Multi-Domain Ansible project.