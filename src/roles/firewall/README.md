# Firewall Role

This role configures the host firewall (UFW or firewalld) to allow only required ingress/egress ports for Mailu, Traefik, SSH, and related services. It must run after hardening and before any application roles.

## Requirements
- Ubuntu 22.04/24.04 LTS or Debian 12
- Must be run with become: true

## Role Variables
See `defaults/main.yml` for all variables and their documentation.

## Dependencies
- `hardening` role (must run first)

## Example Usage
```yaml
- hosts: all
  roles:
    - role: firewall
```
