# Hardening Role

This role applies OS-level security hardening, including sysctl tuning, SSH daemon lockdown (PermitRootLogin no, PasswordAuthentication no, AllowUsers), and SSH warning banner configuration. It must run after the common role and before firewall or application roles.

## Requirements
- Ubuntu 22.04/24.04 LTS or Debian 12
- Must be run with become: true

## Role Variables
See `defaults/main.yml` for all variables and their documentation.

## Dependencies
- `common` role (must run first)

## Example Usage
```yaml
- hosts: all
  roles:
    - role: hardening
```
