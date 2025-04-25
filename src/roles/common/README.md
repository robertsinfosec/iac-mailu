# Common Role

This role installs essential system packages and configures basic system environment settings (e.g., timezone) required by multiple roles. It is the first role to run in the playbook and ensures a consistent, secure baseline for all subsequent roles.

## Requirements
- Ubuntu 22.04/24.04 LTS or Debian 12
- Must be run with become: true

## Role Variables
See `defaults/main.yml` for all variables and their documentation.

## Dependencies
None (should be run first).

## Example Usage
```yaml
- hosts: all
  roles:
    - role: common
```
