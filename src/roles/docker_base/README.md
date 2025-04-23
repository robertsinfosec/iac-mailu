# Docker Base Role

This Ansible role installs and configures Docker and Docker Compose, which are required for running Mailu in containers. It handles Docker installation, configuration, network setup, and optional maintenance tasks.

## Responsibilities

- Installing Docker and Docker Compose
- Configuring Docker daemon settings
- Setting up Docker users and permissions
- Creating required Docker networks
- Configuring maintenance tasks (e.g., automatic cleanup)

## Requirements

- A supported Linux distribution (Debian/Ubuntu)
- Ansible 2.10 or higher
- Sudo/root access for installation

## Role Variables

### Default Variables

```yaml
# Docker installation method
docker_install_method: "package"  # Options: package, script

# Docker package names
docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-compose-plugin

# Docker service name
docker_service_name: "docker"

# Docker users (to be added to docker group)
docker_users:
  - "{{ ansible_user }}"

# Docker daemon options
docker_daemon_options:
  log-driver: "json-file"
  log-opts:
    max-size: "100m"
    max-file: "3"
  storage-driver: "overlay2"
  iptables: true
  live-restore: true

# Docker Compose version
docker_compose_version: "latest"

# Docker network configuration
docker_networks:
  - name: "traefik-public"
    driver: "bridge"
    attachable: true
    ipam_config:
      - subnet: "172.28.0.0/16"
        gateway: "172.28.0.1"

# Docker storage directory
docker_data_dir: "/var/lib/docker"

# Whether to enable Docker system prune cron job
docker_enable_autoclean: true

# Docker autoclean schedule (cron syntax)
docker_autoclean_schedule: "0 2 * * 0"  # 2 AM on Sundays

# Docker autoclean options
docker_autoclean_options: "--all --volumes --force"
```

## Example Playbook

```yaml
- hosts: mail_servers
  become: true
  roles:
    - role: docker_base
      docker_users:
        - "{{ ansible_user }}"
        - "admin"
      docker_networks:
        - name: "traefik-public"
          driver: "bridge"
          attachable: true
        - name: "mail-network"
          driver: "bridge"
      docker_enable_autoclean: true
```

## Dependencies

None

## Author Information

Created for Mailu Multi-Domain Ansible project.