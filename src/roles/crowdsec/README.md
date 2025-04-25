# CrowdSec Role

This role deploys and configures the CrowdSec agent and Docker bouncer for proactive intrusion detection and blocking. It must run after Docker is installed and before application roles are exposed to the internet.

## Requirements
- Docker Engine and Compose installed (via `docker_base` role)
- Must be run with become: true

## Role Variables
See `defaults/main.yml` for all variables and their documentation.

## Dependencies
- `docker_base` role (must run first)

## Example Usage
```yaml
- hosts: all
  roles:
    - role: crowdsec
```
