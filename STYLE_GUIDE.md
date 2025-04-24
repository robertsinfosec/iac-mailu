# iac-mailu Style Guide

This document outlines the coding standards and style guidelines for contributing to the `iac-mailu` project. Adhering to these guidelines ensures consistency, readability, and maintainability across the codebase.

## General Principles

- Write clean, readable, and maintainable Infrastructure as Code (IaC).
- Optimize for clarity, security, and long-term maintainability over cleverness or brevity.
- Be consistent with existing code patterns and architectural choices within this repository.
- Follow Ansible, Docker, and general IaC best practices rigorously.
- Prioritize security in all aspects of development and configuration.
- Ensure all contributions align with the project goals outlined in the [PRD](docs/PRD.md).
- **Absolutely no technical debt** - If a solution isn't meeting our quality standards, rework it rather than implementing a quick fix with plans to improve it later.

## Rule Prioritization

When guidelines appear to conflict, prioritize them in this order:

1. **Security Requirements** - Security standards should never be compromised for any other consideration. This includes proper permission handling, secret management, input validation, and secure defaults.
   
2. **Idempotency & Error Handling** - Ensuring operations can be safely repeated without side effects and properly handle failures is critical for operational reliability.
   
3. **Readability & Maintainability** - Code must be clear, well-documented, and follow established patterns even if it means being more verbose.
   
4. **Performance & Efficiency** - Optimize resource usage where reasonable without compromising the higher priorities.

If you encounter a scenario where following one rule means breaking another, use this hierarchy to decide. For example, if adding proper error handling makes a task longer and potentially less readable, prioritize the error handling and compensate with clear comments explaining the logic.

## Linting and Static Analysis

All code must pass automated linting and static analysis checks before being committed:

### Ansible

- **Linter**: `ansible-lint` must be used with the project's configuration in `.ansible-lint`
- **Command**: Run `ansible-lint .` to check all playbooks and roles
- **Integration**: Configure your IDE to show ansible-lint warnings and errors in real-time
- **Enforcement**: All PRs are checked with ansible-lint via CI; failing PRs cannot be merged

**Do:**
```yaml
# Uses correct YAML formatting and follows Ansible best practices
- name: Ensure Docker is installed
  ansible.builtin.package:
    name: docker-ce
    state: present
  tags: [docker, install]
```

**Don't:**
```yaml
# Missing name, using deprecated syntax, no tags
- package: name=docker-ce state=present
```

### YAML

- **Linter**: `yamllint` should be used with project configuration
- **Command**: Run `yamllint .` to validate YAML formatting
- **Errors**: Fix all formatting issues before committing

## Ansible Guidelines

### YAML Style

- **Readability:** Use clear indentation (2 spaces) and formatting.
- **Consistency:** Follow common Ansible YAML conventions. Refer to the official [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html).
- **Linting:** Code **must** pass `ansible-lint .` checks using the configuration in `.ansible-lint`. Fix all reported errors and warnings.
- **Line Length:** Keep lines reasonably short for readability. While `ansible-lint` may enforce a limit, prioritize clarity. Break long lines logically.
- **Quotes:** Use quotes consistently, especially for strings that might be misinterpreted as numbers or booleans (e.g., `'yes'`, `'no'`, version numbers like `'1.0'`). Prefer single quotes unless double quotes are needed for interpolation or escaping.
- **Boolean Values:** Use `true`/`false` (lowercase) for boolean values in YAML.

**Do:**
```yaml
- name: Create directory with specific permissions
  ansible.builtin.file:
    path: '/opt/mailu/data'
    state: directory
    mode: '0750'
    owner: '{{ mailu_user }}'
    group: '{{ mailu_group }}'
```

**Don't:**
```yaml
- file: path=/opt/mailu/data state=directory mode=750 owner={{ mailu_user }}
```

### Structure and Naming

- **Roles:** Structure logic into **single-responsibility roles** following the standard Ansible role directory structure (`tasks/`, `handlers/`, `templates/`, `files/`, `vars/`, `defaults/`, `meta/`). **Avoid monolithic roles.**
- **Task Names:** Use clear, descriptive task names using `name:`. The name should clearly state *what* the task is doing and *why*.
- **Variable Names:** Use descriptive `snake_case` names (e.g., `mailu_webmail_variant`, `traefik_enable_dashboard`). Provide clear explanations for variables, especially in `defaults/main.yml`.
- **File Names:** Use `snake_case` for playbook files, role directories, and template/file names.

**Do:**
```yaml
# roles/mail_security/tasks/main.yml
---
- name: Import DKIM key generation tasks
  ansible.builtin.import_tasks: setup_dkim.yml
  tags: [security, dkim]

- name: Import DNS record configuration tasks
  ansible.builtin.import_tasks: dns_records.yml
  tags: [security, dns]
```

**Don't:**
```yaml
# Monolithic file with poor organization
---
- name: do dkim
  shell: "openssl genrsa..."
  
- name: dns setup
  command: "..."
```

### Task Implementation

- **Idempotency:** Ensure **all** tasks are idempotent. Use Ansible modules designed for idempotency. Use `changed_when` and `failed_when` appropriately to accurately report state changes and failures.
- **Modules vs. `command`/`shell`:** **Strongly prefer** using built-in Ansible modules over `command` or `shell`. If `command`/`shell` is unavoidable, ensure the command itself is idempotent or use `creates`/`removes` arguments or `changed_when`/`failed_when` to make the task idempotent.
- **Error Handling:** Use `block`/`rescue`/`always` for robust error handling where appropriate. Use `failed_when` to define custom failure conditions. Use `ignore_errors: true` **very sparingly** and only when the failure is truly expected and handled.
- **Handlers:** Use handlers for actions that should only occur when a change is made and typically only once per play (e.g., restarting services).
- **Tags:** Use tags (`tags:`) effectively on plays, roles, and tasks to allow for granular execution (e.g., `tags: [mailu, configuration]`, `tags: [docker, install]`). Include `always` for critical setup/cleanup tasks if needed.
- **Privilege Escalation:** Use `become: true` only when necessary for specific tasks or blocks, rather than globally for an entire play if possible.

**Do (idempotent shell command):**
```yaml
- name: Generate DKIM key if it doesn't exist
  ansible.builtin.shell: openssl genrsa -out {{ key_path }} {{ mailu_dkim_key_size }}
  args:
    creates: "{{ key_path }}" # Makes the task idempotent
  changed_when: true # Explicitly mark that this creates something new
  vars:
    key_path: "{{ mailu_data_path }}/dkim/{{ domain }}.key"
```

**Don't (non-idempotent shell command):**
```yaml
- name: Generate DKIM key
  ansible.builtin.shell: openssl genrsa -out {{ mailu_data_path }}/dkim/{{ domain }}.key {{ mailu_dkim_key_size }}
  # Will run every time, potentially overwriting existing keys
```

**Do (error handling):**
```yaml
- name: Apply firewall rules
  block:
    - name: Configure UFW rules for mail ports
      community.general.ufw:
        rule: allow
        port: "{{ item }}"
      loop: "{{ mailu_required_ports }}"
      
    - name: Enable UFW
      community.general.ufw:
        state: enabled
        
  rescue:
    - name: Ensure SSH access is never lost
      community.general.ufw:
        rule: allow
        port: "{{ ssh_port | default('22') }}"
        
    - name: Log firewall configuration failure
      ansible.builtin.debug:
        msg: "Failed to configure firewall. Ensuring SSH access is maintained."
        
    - name: Re-throw the error for attention
      ansible.builtin.fail:
        msg: "Firewall configuration failed. SSH access has been preserved, but manual intervention is required."
```

**Don't (poor error handling):**
```yaml
- name: Configure UFW rules
  community.general.ufw:
    rule: allow
    port: "{{ item }}"
  loop: "{{ mailu_required_ports }}"
  ignore_errors: true # Dangerous - could lead to lockout or security issues
```

### Secrets Management

- **Ansible Vault:** **All** secrets (API keys, passwords, sensitive tokens) **must** be stored in `vault/secrets.yml` and encrypted using `ansible-vault`.
- **No Hardcoding:** Never hardcode secrets in playbooks, roles, templates, or variable files visible in Git.
- **`no_log: true`:** Use `no_log: true` on tasks that handle sensitive data to prevent secrets from appearing in logs.
- **Reference Variables:** Use clear variable references (e.g., `{{ vault_user_password }}`) in playbooks and templates.
- **Permission Control:** When generating files containing secrets, set appropriate restrictive permissions (e.g., `mode: '0600'` or `mode: '0640'`).

**Do:**
```yaml
# In vault/secrets.yml (encrypted with ansible-vault)
vault_cloudflare_api_token: "0123456789abcdef0123456789abcdef01234567"

# In group_vars/all.yml
cloudflare_api_email: "admin@example.com" # Not sensitive
# Reference to the vaulted variable
cloudflare_api_token: "{{ vault_cloudflare_api_token }}"

# In tasks
- name: Configure API credentials file
  ansible.builtin.template:
    src: api_credentials.j2
    dest: "{{ config_path }}/credentials"
    mode: '0600'
    owner: "{{ mailu_user }}"
    group: "{{ mailu_group }}"
  no_log: true # Prevents logging of task output with secrets
```

**Don't:**
```yaml
# In group_vars/all.yml (unencrypted)
cloudflare_api_token: "0123456789abcdef0123456789abcdef01234567" # NEVER do this!

# In tasks
- name: Configure with API credentials
  ansible.builtin.template:
    src: api_credentials.j2
    dest: /etc/credentials
    # Missing proper permissions
  # Missing no_log for sensitive task
```

## Error Handling Patterns

Implement robust error handling throughout your code to gracefully handle failures and ensure system stability.

### Standard Error Handling Pattern

Use the block/rescue/always pattern for complex operations:

```yaml
- name: Perform critical operation
  block:
    - name: First subtask
      ansible.builtin.command: /bin/critical-operation
      register: operation_result
      
    - name: Validate result
      ansible.builtin.assert:
        that: operation_result.rc == 0
        fail_msg: "Operation failed with error code {{ operation_result.rc }}"
        
  rescue:
    - name: Log failure
      ansible.builtin.debug:
        msg: "Critical operation failed: {{ ansible_failed_result }}"
        
    - name: Attempt recovery
      ansible.builtin.command: /bin/recovery-operation
      
    - name: Notify about failure
      ansible.builtin.debug:
        msg: "Recovery attempted, manual intervention may be required"
        
  always:
    - name: Clean up temporary files
      ansible.builtin.file:
        path: /tmp/operation-files
        state: absent
```

### Retrying Transient Failures

For operations that might fail due to transient issues:

```yaml
- name: Perform API request that might experience transient failures
  ansible.builtin.uri:
    url: "https://api.example.com/endpoint"
    method: POST
    body_format: json
    body:
      key: value
  register: api_result
  retries: 3
  delay: 5
  until: api_result is succeeded
```

### Validation and Pre-checks

Always validate inputs and system state before making changes:

```yaml
- name: Validate required variables
  ansible.builtin.assert:
    that:
      - mailu_base_dir is defined
      - mailu_base_dir | trim != ""
      - mailu_version is defined
    fail_msg: "Required variables are not set. Please define mailu_base_dir and mailu_version."
    
- name: Check if required directories exist
  ansible.builtin.stat:
    path: "{{ mailu_base_dir }}"
  register: dir_check
  
- name: Fail if directory doesn't exist and we're not allowed to create it
  ansible.builtin.fail:
    msg: "Required directory {{ mailu_base_dir }} doesn't exist and create_dirs is false"
  when: not dir_check.stat.exists and not create_dirs|default(true)
```

## Jinja2 Guidelines (Templates)

- **Clarity:** Write clear, readable, and well-formatted Jinja2 templates.
- **Indentation:** Maintain consistent indentation that reflects the structure of the generated file.
- **Comments:** Use Jinja2 comments (`{# This is a comment #}`) to explain complex logic, loops, or non-obvious sections within templates.
- **Variables:** Access variables clearly (e.g., `{{ mailu_admin_port }}`).
- **Logic:** Keep complex logic minimal within templates. Prefer preparing data structures in Ansible tasks using `set_fact` if it improves template readability. Use filters (`|`) for common transformations (e.g., `{{ some_list | join(',') }}`, `{{ some_var | default('default_value') }}`).
- **Whitespace Control:** Use whitespace control modifiers (`-`, `+`) carefully if needed to manage newlines and spacing in the generated output, but prioritize template readability.

**Do:**
```jinja
# Example docker-compose.yml.j2
version: '3.8'

{# Define services based on configured components #}
services:
{% if mailu_components.front | default(true) %}
  front:
    image: {{ mailu_registry }}/nginx:{{ mailu_version }}
    restart: always
    env_file: {{ mailu_env_file }}
    volumes:
      - {{ mailu_data_path }}/certs:/certs
{% endif %}

{% if mailu_components.admin | default(true) %}
  admin:
    image: {{ mailu_registry }}/admin:{{ mailu_version }}
    restart: always
    env_file: {{ mailu_env_file }}
    volumes:
      - {{ mailu_data_path }}/data:/data
      - {{ mailu_data_path }}/dkim:/dkim
{% endif %}

{# Add custom networks section if defined #}
{% if mailu_networks is defined and mailu_networks|length > 0 %}
networks:
  {% for network in mailu_networks %}
  {{ network.name }}:
    {# Apply network driver if specified #}
    {% if network.driver is defined %}
    driver: {{ network.driver }}
    {% endif %}
  {% endfor %}
{% endif %}
```

**Don't:**
```jinja
# Poor template practice
version: '3.8'
services:
  {% if mailu_components.front | default(true) %}front:
    image: {{ mailu_registry }}/nginx:{{ mailu_version }}
    restart: always
    env_file: {{ mailu_env_file }}
    volumes:
      - {{ mailu_data_path }}/certs:/certs{% endif %}
  {% if mailu_components.admin | default(true) %}admin:
    image: {{ mailu_registry }}/admin:{{ mailu_version }}
    restart: always
    env_file: {{ mailu_env_file }}
    volumes:
      - {{ mailu_data_path }}/data:/data
      - {{ mailu_data_path }}/dkim:/dkim{% endif %}
```

## Docker & Docker Compose Guidelines (Managed by Ansible)

These guidelines apply to how Ansible generates Docker configurations, primarily the `docker-compose.yml.j2` template and related files.

- **Templates:** The `docker-compose.yml.j2` template must be clear, maintainable, and heavily commented, especially regarding variable usage and configuration choices.
- **Configuration via Variables:** All configurable aspects of the Docker Compose services (image versions, ports, volumes, environment variables, labels) should be driven by Ansible variables defined in `group_vars` or `defaults`.
- **Secrets:** Secrets needed by containers (e.g., passwords, API keys in environment variables) must be sourced from Ansible Vault variables within the Jinja2 template. Avoid passing secrets directly via `command`.
- **Volumes:** Use named volumes for persistent data, configured via Ansible variables. Bind mounts should be used carefully and primarily for injecting configuration files generated by Ansible.
- **Networks:** Define explicit Docker networks using Ansible variables.
- **Health Checks:** Define meaningful `healthcheck` directives within the template for critical services, using Ansible variables for timing/retries if necessary.
- **Resource Limits:** Consider allowing resource limits (CPU, memory) to be configured via Ansible variables (optional, based on PRD).
- **Security:**
    - Configure services to run as non-root users where the image supports it, potentially configurable via Ansible variables.
    - Ensure generated configurations follow security best practices (e.g., minimal necessary privileges, secure network exposure).

**Do:**
```yaml
# roles/mailu/defaults/main.yml
mailu_version: "1.9.2"
mailu_services:
  smtp:
    memory_limit: "512M"
    cpu_limit: 0.5
    ports:
      - "25:25"
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "25"]
      interval: 10s
      timeout: 5s
      retries: 3

# templates/docker-compose.yml.j2
services:
  smtp:
    image: mailu/postfix:{{ mailu_version }}
    restart: unless-stopped
    env_file: mailu.env
    volumes:
      - {{ mailu_data_path }}/mail:/mail:rw
    {% if mailu_services.smtp.memory_limit is defined %}
    mem_limit: {{ mailu_services.smtp.memory_limit }}
    {% endif %}
    {% if mailu_services.smtp.cpu_limit is defined %}
    cpus: {{ mailu_services.smtp.cpu_limit }}
    {% endif %}
    ports:
      {% for port in mailu_services.smtp.ports %}
      - "{{ port }}"
      {% endfor %}
    healthcheck:
      test: {{ mailu_services.smtp.healthcheck.test | to_json }}
      interval: {{ mailu_services.smtp.healthcheck.interval }}
      timeout: {{ mailu_services.smtp.healthcheck.timeout }}
      retries: {{ mailu_services.smtp.healthcheck.retries }}
```

**Don't:**
```yaml
# Hard-coded values in template
services:
  smtp:
    image: mailu/postfix:1.9.2
    restart: unless-stopped
    env_file: mailu.env
    volumes:
      - /opt/mailu/mail:/mail:rw
    mem_limit: 512M
    ports:
      - "25:25"
    # Missing healthcheck
```

## Security Standards

Security is paramount in the `iac-mailu` project. All code must follow these security principles:

### File Permissions

Follow the least privilege principle for all file permissions:

| File Type | Permission | Owner:Group | Example |
|-----------|------------|-------------|---------|
| Configuration (no secrets) | 0644 | `target_user:target_user` | `ansible.builtin.template: dest: /etc/config mode: '0644'` |
| Configuration with secrets | 0640 | `target_user:target_user` | `ansible.builtin.template: dest: /etc/credentials mode: '0640'` |
| SSL/TLS keys | 0600 | `target_user:target_user` | `ansible.builtin.copy: dest: /etc/ssl/private.key mode: '0600'` |
| Executable scripts | 0750 | `target_user:target_user` | `ansible.builtin.template: dest: /usr/local/bin/script.sh mode: '0750'` |
| Data directories | 0750 | `target_user:target_user` | `ansible.builtin.file: path: /data state: directory mode: '0750'` |

### Input Validation

Always validate user-provided variables before using them in critical operations:

```yaml
- name: Validate domain format
  ansible.builtin.assert:
    that:
      - domain is match('^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](?:\.[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])+$')
    fail_msg: "Invalid domain format: {{ domain }}"
  when: domain is defined
```

### Network Security

- Always use TLS for remote connections where available
- Restrict firewall rules to the minimum required ports
- Use secure defaults for all protocols

### Container Security

- Enforce resource limits on all containers
- Use non-root users inside containers when supported
- Isolate container networks appropriately
- Keep container images updated to patched versions

### Secret Handling

- Use Ansible Vault for all secrets
- Never log sensitive information
- Set appropriate file permissions for secrets
- Implement rotation mechanisms for long-lived credentials

## Comprehensive Testing

Testing is critical for maintaining the quality and reliability of the codebase.

### Static Analysis

All code must pass static analysis checks before committing:

- `ansible-lint` for Ansible code
- `yamllint` for YAML formatting
- `shellcheck` for shell scripts

### Local Testing

Perform the following tests during development:

- Run playbooks with `--check` mode to verify syntax and logic
- Run playbooks with `--diff` to preview changes
- Run playbooks multiple times to verify idempotence
- Verify rendered templates for correctness

### Idempotence Testing

All playbooks and roles must be idempotent:

```bash
# First run to make changes
ansible-playbook playbooks/site.yml

# Second run should report no changes
ansible-playbook playbooks/site.yml | grep -q 'changed=0.*failed=0' && echo "Idempotence test passed"
```

### Molecule Testing (Roadmap)

As noted in the PRD roadmap, Molecule tests should be implemented for core roles:

```yaml
# Example molecule/default/molecule.yml structure
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2204}-ansible
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible
```

## Documentation Standards

### READMEs

Every role **must** have a README.md file with the following sections:

- **Role Name & Purpose:** Brief description of what the role does
- **Requirements:** Prerequisites for using the role
- **Dependencies:** Other roles or collections this role depends on
- **Role Variables:** Documentation for all configurable variables with types, defaults, and descriptions
- **Example Usage:** Code snippets showing how to use the role
- **License & Author Information**

Example structure:
```markdown
# Mailu Role

This role deploys and configures a Mailu mail server using Docker Compose.

## Requirements

- Docker and Docker Compose installed (use the `docker_base` role)
- Python 3.6+ with docker and docker-compose modules

## Role Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `mailu_version` | String | `1.9.2` | Version of Mailu to deploy |
| `mailu_base_dir` | String | `/opt/mailu` | Base directory for Mailu data |

## Dependencies

- `docker_base` role
- `firewall` role (recommended)

## Example Usage

```yaml
- hosts: mail_servers
  roles:
    - role: docker_base
    - role: mailu
      vars:
        mailu_version: "1.9.2"
        mailu_base_dir: "/opt/mailu"
```

### Variable Documentation

Document all variables thoroughly in the `defaults/main.yml` file:

```yaml
# roles/mailu/defaults/main.yml

# The version of Mailu to install
# Type: string
# Example: "1.9"
mailu_version: "1.9.2"

# Base directory where Mailu data will be stored
# Type: string
mailu_base_dir: "/opt/mailu"

# Whether to enable the web admin interface
# Type: boolean
mailu_enable_admin: true

# Memory limit for the SMTP container (in Docker format)
# Type: string
# Default is 512MB
mailu_smtp_memory: "512M"
```

### Inline Comments

Use comments to explain why certain decisions were made:

```yaml
- name: Configure postscreen
  ansible.builtin.template: 
    src: postscreen.cf.j2
    dest: "{{ mailu_base_dir }}/postfix/postscreen.cf"
    mode: '0644'
  # Postfix requires a service restart to pick up config changes
  notify: restart postfix container
```

## Git and Commit Style

- Use descriptive commit messages written in the **imperative mood** (e.g., "Add feature" not "Added feature" or "Adds feature").
- Begin commit message subject lines with a type prefix (following [Conventional Commits](https://www.conventionalcommits.org/) is strongly recommended):
    - `feat:` (new feature)
    - `fix:` (bug fix)
    - `docs:` (documentation changes)
    - `style:` (code style changes, formatting, linting fixes)
    - `refactor:` (code changes that neither fix a bug nor add a feature)
    - `perf:` (performance improvements)
    - `test:` (adding or correcting tests, molecule setup)
    - `build:` (changes affecting dependencies, `requirements.yml`)
    - `ci:` (changes to CI configuration)
    - `chore:` (routine tasks, maintenance, repo tooling)
- Keep commits focused on a single logical change. Avoid mixing unrelated changes in one commit.
- Reference relevant issue numbers in the commit message body or footer (e.g., `Fixes #123`, `Refs #456`).

**Do:**
```
feat(mailu): add option to configure Postscreen settings

Implement configurable Postscreen settings through new variables:
- mailu_postscreen_enabled
- mailu_postscreen_dnsbl_sites
- mailu_postscreen_dnsbl_threshold

This provides better spam protection at the SMTP connection stage.

Fixes #42
```

**Don't:**
```
Added postscreen stuff and fixed some bugs
```

## CI/CD Integration

### GitHub Actions

CI workflows should validate code quality using:

```yaml
# .github/workflows/ansible-lint.yml
---
name: Ansible Lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install ansible-lint yamllint

      - name: Run ansible-lint
        run: ansible-lint
```

### Pre-commit Hooks

Use pre-commit hooks to catch issues early:

```yaml
# .pre-commit-config.yaml
---
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.14.3
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.29.0
    hooks:
      - id: yamllint
        args: [-c=.yamllint]
```

## Compliance and Auditing

### Logging Requirements

Ensure proper logging for audit trails:

```yaml
- name: Configure Docker daemon logging
  ansible.builtin.template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
    mode: '0644'
  vars:
    log_config:
      "log-driver": "json-file"
      "log-opts":
        "max-size": "100m"
        "max-file": "5"
```

### Backup Validation

Always validate backups to ensure recoverability:

```yaml
- name: Run backup verification
  ansible.builtin.command: "{{ backup_script }} verify"
  args:
    chdir: "{{ backup_dir }}"
  changed_when: false
  register: backup_verification
  
- name: Display backup verification results
  ansible.builtin.debug:
    var: backup_verification.stdout_lines
    
- name: Fail if backup verification failed
  ansible.builtin.fail:
    msg: "Backup verification failed: {{ backup_verification.stderr }}"
  when: backup_verification.rc != 0
```

## Decision Criteria for Common Patterns

This section provides explicit guidance for common decision points that might otherwise require judgment calls.

### When to Use Block/Rescue vs. Direct Error Handling

- **Use `block/rescue/always` when:**
  * Multiple related tasks must succeed or fail together
  * You need cleanup actions regardless of success/failure
  * You're handling potential failures that require recovery steps
  * The operation needs to preserve a consistent state if it fails

- **Use direct error handling (e.g., with `failed_when`) when:**
  * The operation is single-step or self-contained
  * You need granular control over what constitutes a failure
  * The logic to determine success or failure is complex
  * There's no need for recovery steps

**Example - Block/Rescue Pattern:**
```yaml
- name: Manage SSL certificate
  block:
    - name: Generate new SSL certificate
      command: certbot --nginx -d example.com
      register: cert_result

    - name: Configure web server with new certificate
      template:
        src: nginx-ssl.conf.j2
        dest: /etc/nginx/conf.d/ssl.conf
  rescue:
    - name: Restore previous certificate configuration
      copy:
        src: /etc/nginx/conf.d/ssl.conf.backup
        dest: /etc/nginx/conf.d/ssl.conf
        remote_src: yes
  always:
    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
```

**Example - Direct Error Handling:**
```yaml
- name: Check API endpoint health
  uri:
    url: https://api.example.com/health
    method: GET
    status_code: 200
  register: api_check
  failed_when: api_check.status != 200 or api_check.json.status != "healthy"
  changed_when: false
```

### When to Split Roles vs. Adding to Existing Roles

- **Create a new role when:**
  * The functionality has a distinct, single responsibility
  * The code would be reusable across different projects or contexts
  * It requires its own dependencies or variables
  * It would be tested or deployed independently
  * It aligns with the strict single-responsibility principle in the PRD

- **Add to an existing role when:**
  * The functionality is a minor extension of the role's existing purpose
  * It shares most dependencies and variables with the existing role
  * The functionality would always be deployed together with the existing role
  * It operates on the same resources as the existing role

**Example - Split Role Decision:**
```
The mail_security role should be separate from the mailu role because:
1. It has a distinct responsibility (security-specific configurations)
2. It might be reused in different contexts
3. It can be tested independently
4. It might evolve on a different timeline than the core mailu functionality
```

**Example - Same Role Decision:**
```
Adding a task to configure mail aliases belongs in the user_management role because:
1. It extends the existing user management functionality
2. It operates on the same user database
3. It uses the same variables and dependencies
4. It would always be deployed with user management
```

### When to Use Tags vs. Separate Playbooks

- **Use tags when:**
  * You need selective execution within larger playbooks
  * The tasks are part of the same logical workflow
  * You want to maintain a single entry point with options

- **Create separate playbooks when:**
  * The tasks represent a completely different operational workflow
  * The tasks would be run on a different schedule
  * The tasks require different inventory or variables
  * The tasks would be triggered by different events

**Example - Tags Usage:**
```yaml
- name: Configure firewall rules for mail services
  community.general.ufw:
    rule: allow
    port: "{{ item }}"
  loop: "{{ mailu_required_ports }}"
  tags: [firewall, mail]
```

**Example - Separate Playbook:**
```
The backup.yml playbook should be separate from site.yml because:
1. It represents an operational workflow rather than deployment
2. It would be run on a different schedule
3. It might use different connection parameters or limits
4. It could be triggered by different events (e.g., scheduled vs. deployment)
```

## Versioning and Compatibility Standards

In line with our PRD's principle of avoiding technical debt and ensuring production readiness, all dependencies must be explicitly versioned and compatibility documented.

### Version Pinning

- **Always pin specific versions** for all dependencies:
  * Docker images
  * Ansible collections and roles
  * External packages

- **Never use floating tags** like `latest`, `stable`, or version ranges like `~=1.9` or `^2.0` as these introduce unpredictable behavior.

**Do:**
```yaml
# In docker-compose.yml.j2
image: mailu/postfix:1.9.2

# In requirements.yml
collections:
  - name: community.general
    version: 6.6.0
  - name: community.docker
    version: 3.4.0

roles:
  - name: geerlingguy.docker
    version: 6.1.0
```

**Don't:**
```yaml
# Floating tags that can change unexpectedly
image: mailu/postfix:latest

# Missing version pins
collections:
  - name: community.general
  
# Version ranges that can introduce unexpected changes
roles:
  - name: geerlingguy.docker
    version: ">=5.0.0"
```

### Version Documentation

Document compatibility constraints explicitly in:

1. **Role READMEs**: Each role's README.md must document its tested version combinations:

```markdown
## Compatibility

This role has been tested with:
- Ansible: 2.9.x, 2.10.x, 2.11.x
- Python: 3.8+
- Docker Engine: 20.10.x, 23.x, 24.x
- Ubuntu: 20.04, 22.04
- Debian: 11, 12
```

2. **Variables**: Include version constraints in variable definitions with clear comments:

```yaml
# Docker Engine version to install
# Compatible with Ubuntu 20.04/22.04 and Debian 11/12
# Type: string
docker_version: "24.0.7"
```

### Upgrade Paths

Document clear upgrade paths for major version changes:

1. **Include upgrade steps** in role READMEs or dedicated documentation
2. **Document breaking changes** between major versions
3. **Provide automated migration tasks** where possible

**Example Upgrade Task:**
```yaml
- name: Check for Mailu version upgrade
  block:
    - name: Compare installed and target versions
      ansible.builtin.set_fact:
        mailu_version_changed: "{{ installed_mailu_version is defined and installed_mailu_version != mailu_version }}"
    
    - name: Backup existing configuration before major version upgrade
      ansible.builtin.copy:
        src: "{{ mailu_base_dir }}/mailu.env"
        dest: "{{ mailu_base_dir }}/mailu.env.{{ installed_mailu_version }}.bak"
        remote_src: true
      when: 
        - mailu_version_changed | bool
        - installed_mailu_version.split('.')[0] != mailu_version.split('.')[0] 
  when: installed_mailu_version is defined
```

### Dependency Management

- **Test and document major dependency updates** before implementation
- **Maintain a CHANGELOG.md** documenting version changes and compatibility
- **Use CI testing** to verify compatibility across supported systems

## Variable Naming Standards

All variables must follow clear, consistent naming patterns to ensure readability and prevent conflicts.

### Naming Pattern Structure

Variables must follow this pattern:
`<scope>_<component>_<description>_<subcomponent>`

Where:
- `<scope>`: Indicates the variable's scope:
  * `mailu`: For Mailu-specific variables
  * `traefik`: For Traefik-specific variables
  * `docker`: For Docker-related variables
  * `system`: For system-wide settings
  * Role name prefix for role-specific variables
- `<component>`: The functional area (e.g., `smtp`, `admin`, `security`)
- `<description>`: What the variable controls
- `<subcomponent>`: Optional further categorization

### Examples

**Do:**
```yaml
# Mailu-specific SMTP port
mailu_smtp_port: 25

# Traefik TLS settings
traefik_tls_options_min_version: "VersionTLS12"

# Role-specific backup retention
backup_retention_days: 30

# System-wide setting
system_timezone: "UTC"
```

**Don't:**
```yaml
# Too generic, no scope
port: 25

# Unclear scope or component
tls_version: "VersionTLS12"

# Missing description
backup_days: 30  

# Inconsistent naming style
systemTimezone: "UTC"
```

### Variable Definition Standards

Variables must be properly documented where they are defined:

```yaml
# roles/mailu/defaults/main.yml

# The version of Mailu to install
# Type: string 
# Example: "1.9.2"
# Compatible with: All supported platforms
mailu_version: "1.9.2"

# Base directory where Mailu data will be stored
# Type: string
# Required: yes
# Default: "/opt/mailu"
mailu_base_dir: "/opt/mailu"

# Whether to enable the web admin interface
# Type: boolean
# Default: true
mailu_enable_admin: true

# Memory limit for the SMTP container (in Docker format)
# Type: string
# Default: "512M"
# Recommended: At least 512M for production use
mailu_smtp_memory: "512M"
```

### Variable Usage Standards

When using variables in tasks, templates, or other roles:

1. **Always use full Jinja2 syntax** with double braces and quotes for string values:
   ```yaml
   dest: "{{ mailu_base_dir }}/config"
   ```

2. **Always use default filters** for optional variables:
   ```yaml
   port: "{{ mailu_admin_port | default(80) }}"
   ```

3. **Validate required variables** before using them:
   ```yaml
   - name: Check required variables
     ansible.builtin.assert:
       that:
         - mailu_version is defined
         - mailu_base_dir is defined
       fail_msg: "Required variables mailu_version and mailu_base_dir must be set"
   ```

## Template Documentation Standards

Jinja2 templates must include comprehensive documentation and follow consistent formatting to ensure maintainability.

### Template Header

Every template file must begin with a standardized header:

```jinja
{#
  filename.j2 - Purpose of this template
  
  Required variables:
  - variable_name (type): Description and purpose
  - another_variable (type): Description and purpose
  
  Optional variables:
  - optional_var (type, default=value): Description and purpose
  
  Output: Description of the generated file and its purpose
#}
```

### Section Comments

Each logical section must have a descriptive comment:

```jinja
{# Section: User Authentication Configuration #}
{% if mailu_auth_method == "ldap" %}
# LDAP authentication settings
authentication_type = ldap
ldap_server = {{ mailu_ldap_server }}
ldap_base_dn = {{ mailu_ldap_base_dn }}
{% else %}
# SQL authentication (default)
authentication_type = sql
{% endif %}
```

### Complex Logic Documentation

Explain any non-obvious logic clearly:

```jinja
{# 
  Conditional admin access configuration:
  - If admin_mode is 'full': Enable all admin features
  - If admin_mode is 'restricted': Enable only user management
  - Otherwise: Disable admin interface completely
#}
{% if mailu_admin_mode == 'full' %}
  # Full administration features
  admin_access: full
{% elif mailu_admin_mode == 'restricted' %}
  # Restricted to user management only
  admin_access: restricted
{% else %}
  # Admin interface disabled
  admin_access: disabled
{% endif %}
```

### End Markers for Long Blocks

Use end markers for long conditional blocks or loops to improve readability:

```jinja
{% if mailu_components.front | default(true) %}
# Front service configuration
# ...many lines of configuration...
{% endif %}{# endif mailu_components.front #}

{% for domain in mailu_domains %}
# Domain: {{ domain.name }}
# ...domain configuration...
{% endfor %}{# endfor mailu_domains #}
```

### Whitespace Control

Use whitespace control modifiers (`-`, `+`) consistently:

```jinja
{# Compact output with no unnecessary newlines #}
{% for port in exposed_ports -%}
  - "{{ port }}"
{% endfor %}

{# Preserve formatting with deliberate whitespace #}
{% for user in mailu_users %}
  
  # User: {{ user.name }}
  # Configuration follows
  {% if user.admin %}
  admin: true
  {% endif %}
  
{% endfor %}
```

**Do:**
```jinja
{# docker-compose.yml.j2 - Generates Docker Compose configuration for Mailu
   
   Required variables:
   - mailu_version: Mailu version tag to use for container images
   - mailu_components: Dict of enabled components (front, admin, webmail)
   - mailu_base_dir: Base directory for persistent data
   
   Optional variables:
   - mailu_subnet: Docker subnet to use (default: 172.18.0.0/16)
   - mailu_memory_limits: Dict of memory limits per container
#}

version: '3.8'

services:
{# Core services that are always included #}
  redis:
    image: redis:{{ redis_version | default('6.2') }}
    restart: always
    volumes:
      - "{{ mailu_base_dir }}/redis:/data"
    
{# Front-end is conditionally included #}
{% if mailu_components.front | default(true) %}
  front:
    image: {{ mailu_registry | default('mailu/nginx') }}:{{ mailu_version }}
    restart: always
    volumes:
      - "{{ mailu_base_dir }}/certs:/certs"
    {% if mailu_memory_limits.front is defined %}
    mem_limit: {{ mailu_memory_limits.front }}
    {% endif %}
{% endif %}{# endif mailu_components.front #}
```

**Don't:**
```jinja
# Missing documentation, poor formatting, and inconsistent whitespace
version: '3.8'
services:
  redis:
    image: redis:6.2
    restart: always
    volumes:
      - "{{ mailu_base_dir }}/redis:/data"
  {% if mailu_components.front | default(true) %}
  front:
    image: {{ mailu_registry | default('mailu/nginx') }}:{{ mailu_version }}
    restart: always
    volumes:
      - "{{ mailu_base_dir }}/certs:/certs"{% endif %}
```

## Role Dependency Management

Clear management of role dependencies ensures modularity, reusability, and prevents unexpected issues.

### Defining Dependencies

Define all role dependencies explicitly in `meta/main.yml`:

```yaml
# roles/mailu/meta/main.yml
dependencies:
  - role: docker_base
    # This ensures Docker is installed before attempting to run containers
    
  - role: common
    # This ensures basic system requirements are met
    
  # Conditional dependencies can be included with 'when'
  - role: firewall
    when: configure_firewall | default(true)
    # Only include the firewall role if configuration is enabled
```

### Documentation Standards

In each role's README.md, explicitly document:

1. **Hard dependencies** (always required):
   ```markdown
   ## Dependencies
   
   This role requires the following roles to be run first:
   - `docker_base`: Installs and configures Docker Engine
   - `common`: Sets up basic system requirements
   ```

2. **Soft dependencies** (optional or conditional):
   ```markdown
   ## Optional Dependencies
   
   This role can optionally use:
   - `firewall`: To configure required firewall rules (when `configure_firewall=true`)
   - `monitoring`: To set up monitoring for mail services (when `enable_monitoring=true`)
   ```

3. **Conflicts or incompatibilities**:
   ```markdown
   ## Compatibility Notes
   
   This role cannot be used with:
   - `legacy_mail_role`: Contains conflicting mail server configurations
   - `postfix_direct`: Attempts to use the same ports
   ```

### Managing Dependency Versions

When depending on external roles, pin specific versions:

```yaml
# requirements.yml
roles:
  - name: geerlingguy.docker
    version: "6.1.0"  # Specific version, not "latest" or a version range
```

### Circular Dependency Prevention

- **Never create circular dependencies** between roles
- **Extract common functionality** to a shared role instead
- **Verify dependency trees** before finalizing a role

**Do:**
```yaml
# Extract common functionality to a shared base role
# roles/base_mail/meta/main.yml
dependencies: []  # No dependencies

# roles/mailu/meta/main.yml
dependencies:
  - role: base_mail  # Depends on the shared base
  - role: docker_base

# roles/postfix_direct/meta/main.yml
dependencies:
  - role: base_mail  # Also depends on the shared base
```

**Don't:**
```yaml
# Circular dependency - will cause Ansible to fail
# roles/mailu/meta/main.yml
dependencies:
  - role: firewall

# roles/firewall/meta/main.yml
dependencies:
  - role: mailu  # CIRCULAR! Mailu depends on firewall, and firewall depends on Mailu
```

## Automated Validation Mechanisms

The project must implement automated validation to ensure consistent adherence to these standards.

### Required Validation Tools

All code must pass validation with these tools before being committed:

1. **ansible-lint**: Validates playbooks and roles against best practices
   ```bash
   # Command to run
   ansible-lint .
   
   # Configuration in .ansible-lint
   skip_list:
     - 'yaml[line-length]'  # We prioritize readability over strict line length
     
   warn_list:
     - 'experimental'  # Include experimental rules as warnings
   ```

2. **yamllint**: Validates YAML syntax and formatting
   ```bash
   # Command to run
   yamllint .
   
   # Configuration in .yamllint
   extends: default
   
   rules:
     line-length:
       max: 160
     truthy:
       allowed-values: ['true', 'false', 'yes', 'no']
   ```

3. **shellcheck**: Validates shell scripts
   ```bash
   # For shell scripts in the repository
   shellcheck scripts/*.sh
   ```

### Pre-commit Hooks

Configure development environments with pre-commit hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.14.3
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.29.0
    hooks:
      - id: yamllint
        args: [-c=.yamllint]
        
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.9.0
    hooks:
      - id: shellcheck
```

### CI Integration

All pull requests must pass automated validation in CI:

```yaml
# .github/workflows/ansible-lint.yml
---
name: Ansible Lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
          
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install ansible-lint yamllint
          
      - name: Run ansible-lint
        run: ansible-lint
        
      - name: Run yamllint
        run: yamllint .
```

### Custom Validation Scripts

Create custom scripts to verify project-specific requirements:

```yaml
# Example validation task
- name: Verify role structure completeness
  ansible.builtin.script: scripts/verify_role_structure.py {{ role_path }}
  changed_when: false
  delegate_to: localhost
```

These scripts should check for:
1. Required files in each role (meta/main.yml, README.md)
2. Documentation completeness
3. Variable naming consistency
4. Security-related configuration presence

## Code Comment Density and Location

Clear guidelines on comment usage ensure the codebase is well-documented and maintainable by both humans and LLMs.

### Required Comment Locations

The following elements MUST include descriptive comments:

#### 1. Variable Definitions

All variables in `defaults/main.yml` and `vars/main.yml` must have comments explaining:

```yaml
# The version of Mailu to install
# Type: string
# Example: "1.9.2"
mailu_version: "1.9.2"

# Base directory where Mailu data will be stored
# Type: string
# Default: "/opt/mailu"
mailu_base_dir: "/opt/mailu"

# Whether to enable the web admin interface
# Type: boolean
mailu_enable_admin: true

# Memory limit for the SMTP container (in Docker format)
# Type: string
# Default is 512MB
mailu_smtp_memory: "512M"
```

#### 2. Task Files

Each task file must begin with a comment block describing:

```yaml
# tasks/main.yml
# 
# Purpose: Main entry point for the mailu role
# This file:
# 1. Validates input parameters
# 2. Creates required directories
# 3. Imports specialized task files for specific components
# 
# Dependencies:
# - Requires docker_base role to be applied first

- name: Ensure required variables are defined
  ansible.builtin.assert:
    that:
      - mailu_version is defined
      - mailu_base_dir is defined
    fail_msg: "Required variables are not defined. Please set mailu_version and mailu_base_dir."
```

#### 3. Complex Tasks

Any task with complex logic requires explaining the rationale:

```yaml
# Using command module instead of community.docker.docker_container
# because we need to perform health checks during startup
# that aren't supported by the module
- name: Start Mailu using docker-compose
  ansible.builtin.command: docker-compose up -d
  args:
    chdir: "{{ mailu_base_dir }}"
  changed_when: false  # Will be handled by our custom change detection
```

#### 4. Non-obvious Default Values

Explain why specific default values were chosen:

```yaml
# Default of 2048 chosen as balance between security and performance.
# Higher values (4096+) significantly impact CPU usage during signing.
mailu_dkim_key_size: 2048

# 30 day retention balances storage requirements with typical
# regulatory needs. Adjust based on your compliance requirements.
backup_retention_days: 30
```

### Comment Density Guidelines

Follow these guidelines for comment distribution:

- **Variable Files**: Every variable must be commented
- **Task Files**: At minimum, one comment per logical group of tasks (typically every 5-10 tasks)
- **Templates**: Comment at section boundaries and for any conditional logic
- **Handlers**: Brief comment explaining when/why the handler is notified
- **Meta Files**: Comment for each dependency explaining why it's needed

### Implementation Example

**Do (Well-commented task file):**
```yaml
# tasks/configure_mail_security.yml
# This file handles the configuration of mail security features:
# - DKIM key generation and configuration
# - SPF record management
# - DMARC policy setup
# - MTA-STS configuration

# Generate DKIM keys for each domain if they don't exist
- name: Ensure DKIM directory exists
  ansible.builtin.file:
    path: "{{ mailu_base_dir }}/dkim"
    state: directory
    mode: '0750'
    owner: "{{ mailu_user }}"
    group: "{{ mailu_group }}"

# Use OpenSSL to generate keys since the appropriate
# key size and format is important for mail deliverability
- name: Generate DKIM keys for domains
  ansible.builtin.shell: openssl genrsa -out {{ key_path }} {{ mailu_dkim_key_size }}
  args:
    creates: "{{ key_path }}"  # Makes the task idempotent
  vars:
    key_path: "{{ mailu_base_dir }}/dkim/{{ domain.name }}.key"
  loop: "{{ mailu_domains }}"
  loop_control:
    loop_var: domain
  notify: restart postfix container
```

**Don't (Poorly commented tasks):**
```yaml
# Missing descriptions, purpose unclear
- file:
    path: "{{ mailu_base_dir }}/dkim"
    state: directory
    mode: '0750'

# No explanation of why shell is used instead of a module
- shell: openssl genrsa -out {{ mailu_base_dir }}/dkim/{{ item.name }}.key 2048
  loop: "{{ mailu_domains }}"
  notify: restart
```

## LLM-Specific Testing Requirements

When LLMs generate code for this project, the code must include specific patterns to ensure testability, reliability, and consistency.

### Mandatory Testing Hooks

All LLM-generated code must include:

#### 1. Clear State Validation

Include tasks that verify the desired state was achieved after making changes:

```yaml
# Example: Verify configuration after applying it
- name: Apply Postfix configuration
  ansible.builtin.template:
    src: postfix_main.cf.j2
    dest: "{{ mailu_base_dir }}/postfix/main.cf"
    mode: '0644'
  register: postfix_config
  
- name: Verify Postfix configuration syntax
  ansible.builtin.command: postfix -c {{ mailu_base_dir }}/postfix check
  changed_when: false
  failed_when: postfix_check.rc != 0
  register: postfix_check
  when: postfix_config.changed
```

#### 2. Explicit Success/Failure Conditions

Define clear conditions for success:

```yaml
- name: Check Mailu API accessibility
  ansible.builtin.uri:
    url: "https://{{ mailu_admin_domain }}/api/health"
    status_code: 200
    validate_certs: yes
  register: api_check
  failed_when: api_check.status != 200
  changed_when: false
  retries: 3
  delay: 10
  until: api_check is succeeded or api_check.attempts|default(1) > 3
```

#### 3. Isolation for Testability

Structure code to allow isolated testing:

```yaml
# Break functionality into discrete, testable task files
- name: Include TLS configuration tasks
  ansible.builtin.include_tasks: tls_configuration.yml
  when: configure_tls | bool
  
- name: Include DKIM setup tasks
  ansible.builtin.include_tasks: dkim_setup.yml
  when: configure_dkim | bool
```

#### 4. Idempotence Verification Pattern

Include patterns that ensure idempotent execution:

```yaml
# Check if user exists before creating
- name: Check if user exists
  ansible.builtin.command: docker exec mailu-admin flask mailu admin user list
  register: user_list
  changed_when: false
  
- name: Create user if not exists
  ansible.builtin.command: >
    docker exec mailu-admin flask mailu admin user create {{ domain }} {{ username }} {{ password }}
  when: username not in user_list.stdout
  changed_when: true
```

### Testing Documentation

LLM-generated code must include testing guidance:

```yaml
# tasks/main.yml
# Testing Guidelines:
# 1. Run with --check first: ansible-playbook site.yml --check
# 2. Verify idempotence: run twice, second run should report no changes
# 3. Validate: use health_check.yml to verify functionality
```

### Example-Based Testing Format

When generating complex logic, include example test cases:

```yaml
# Example test cases for domain validation function:
# - "example.com" → Valid
# - "example.co.uk" → Valid
# - "xn--80aswg.xn--p1ai" (IDN) → Valid
# - "123.456.789.abc" → Invalid (not a proper domain)
# - "example.com." (trailing dot) → Invalid in this context

- name: Validate domain format
  ansible.builtin.assert:
    that:
      - domain.name is match('^[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+$')
    fail_msg: "Invalid domain format: {{ domain.name }}"
  loop: "{{ mailu_domains }}"
  loop_control:
    loop_var: domain
```

## Git Workflow Standards

The project follows a structured Git workflow to maintain code quality, traceability, and collaboration efficiency.

### Branch Management

Adhere to the following branch structure:

- **main**: Production-ready code only; protected branch
- **develop**: Integration branch for features; merged into main when stable
- **feature/name**: For new features (e.g., `feature/backup-s3`)
- **fix/issue-number**: For bug fixes (e.g., `fix/issue-42`)
- **release/version**: For release preparation (e.g., `release/1.2.0`)

### Commit Process

1. **Scope of Commits**: Each commit should represent a single logical change
2. **Pre-commit Check**: Run these before every commit:
   ```bash
   ansible-lint .
   yamllint .
   ```
3. **Commit Message Format**:
   ```
   <type>(<scope>): <subject>
   <BLANK LINE>
   <body>
   <BLANK LINE>
   <footer>
   ```

**Do:**
```
feat(mailu): add option to configure Postscreen settings

Implement configurable Postscreen settings through new variables:
- mailu_postscreen_enabled
- mailu_postscreen_dnsbl_sites
- mailu_postscreen_dnsbl_threshold

This provides better spam protection at the SMTP connection stage.

Fixes #42
```

**Don't:**
```
Added postscreen stuff and fixed some bugs
```

### Pull Request Process

All changes must follow this process:

1. Create a feature/fix branch from the appropriate base branch
2. Develop and test changes locally
3. Ensure all automated validation passes
4. Create a PR with a detailed description
5. Address all review comments
6. Squash commits if needed for a clean history
7. Merge only after approval and all checks pass

### Versioning

Follow semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Incompatible changes to playbook/role API or behavior
- **MINOR**: New features in a backward-compatible manner
- **PATCH**: Backward-compatible bug fixes

Update version numbers in:
- README.md
- CHANGELOG.md (document all changes)
- Any version-specific logic in playbooks/roles

### Rebase vs. Merge

- **Prefer rebase** for incorporating upstream changes into feature branches
- **Use merge commits** (no fast-forward) when merging into main/develop
- **Squash and merge** for small features or fixes

### Conventional Commit Types

Follow these conventional commit types for clarity:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation changes only
- **style**: Changes that don't affect code behavior (formatting, linting)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Code change that improves performance
- **test**: Adding or correcting tests
- **build**: Changes to build process or dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Other changes that don't modify src or test files