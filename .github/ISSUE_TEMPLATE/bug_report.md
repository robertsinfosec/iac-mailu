---
name: Bug Report
about: Report a problem with the iac-mailu Ansible deployment
title: "[BUG] Brief description of the issue"
labels: bug
assignees: ''

---

**Describe the Bug**
A clear and concise description of what the bug is. Please explain the impact (e.g., deployment fails, service unavailable, incorrect configuration applied).

**To Reproduce**
Steps to reproduce the behavior:
1.  Which playbook or command was run? (e.g., `ansible-playbook playbooks/site.yml`, `ansible-playbook playbooks/health_check.yml`)
2.  What changes were made to configuration files (`domains/`, `group_vars/all.yml`, `inventory/hosts`) before running the command?
3.  Any specific actions taken on the server or via Mailu interfaces?
4.  What was the result? (e.g., error message, incorrect state)

**Expected Behavior**
A clear and concise description of what you expected to happen.

**Actual Behavior**
Describe what actually happened. Include full error messages or tracebacks if applicable.

**Screenshots or Logs**
- If applicable, add screenshots to help explain your problem (e.g., Mailu UI issues).
- Please provide relevant **sanitized** logs:
    - Ansible output (run with `-vvv` for more detail if possible).
    - Relevant Docker container logs (e.g., `docker logs mailu_front`, `docker logs mailu_admin`, `docker logs mailu_rspamd`, `docker logs traefik`, `docker logs crowdsec`). Use `docker ps` to find container names.

**Environment Details**
Please complete the following information:
 - **Control Node OS:** [e.g., Ubuntu 22.04, macOS Sonoma]
 - **Ansible Version:** (Run `ansible --version`)
 - **Target Server OS:** [e.g., Debian 12, Ubuntu 24.04]
 - **Docker Version:** (Run `docker --version` on the target server)
 - **Docker Compose Version:** (Run `docker compose version` or `docker-compose --version` on the target server)
 - **Mailu Version:** (Specify if not using default from `docker-compose.yml.j2`)
 - **Browser (if applicable):** [e.g., Chrome 110, Firefox 109] - *Only if the bug relates to Webmail or Admin UI*

**Relevant Configuration**
Please provide **sanitized** snippets from your configuration files. **DO NOT INCLUDE SECRETS (passwords, API keys).**
- `inventory/hosts`:
  ```ini
  # Paste relevant lines
  ```
- `group_vars/all.yml`:
  ```yaml
  # Paste relevant lines
  ```
- Relevant `domains/<yourdomain>.yml`:
  ```yaml
  # Paste relevant lines, replacing user passwords with placeholders like ***
  ```
- `vault/secrets.yml` (Show relevant keys, **NOT** values):
  ```yaml
  # Example: vault_cloudflare_api_token: <present>
  ```

**Additional Context**
Add any other context about the problem here. Does it relate specifically to Mailu, Traefik, Cloudflare DNS updates, CrowdSec, Ntfy, a specific role task, etc.? Is this a fresh deployment or an update?