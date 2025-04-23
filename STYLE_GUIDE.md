# iac-mailu Style Guide

This document outlines the coding standards and style guidelines for contributing to the `iac-mailu` project. Adhering to these guidelines ensures consistency, readability, and maintainability across the codebase.

## General Principles

- Write clean, readable, and maintainable Infrastructure as Code (IaC).
- Optimize for clarity, security, and long-term maintainability over cleverness or brevity.
- Be consistent with existing code patterns and architectural choices within this repository.
- Follow Ansible, Docker, and general IaC best practices rigorously.
- Prioritize security in all aspects of development and configuration.
- Ensure all contributions align with the project goals outlined in the [PRD](docs/PRD.md) and the principles in [.github/copilot-instructions.md](/.github/copilot-instructions.md).

## Ansible Guidelines

### YAML Style

- **Readability:** Use clear indentation (2 spaces) and formatting.
- **Consistency:** Follow common Ansible YAML conventions. Refer to the official [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html).
- **Linting:** Code **must** pass `ansible-lint .` checks using the configuration in `.ansible-lint`. Fix all reported errors and warnings.
- **Line Length:** Keep lines reasonably short for readability. While `ansible-lint` may enforce a limit, prioritize clarity. Break long lines logically.
- **Quotes:** Use quotes consistently, especially for strings that might be misinterpreted as numbers or booleans (e.g., `'yes'`, `'no'`, version numbers like `'1.0'`). Prefer single quotes unless double quotes are needed for interpolation or escaping.
- **Boolean Values:** Use `true`/`false` (lowercase) for boolean values in YAML.

### Structure and Naming

- **Roles:** Structure logic into **single-responsibility roles** following the standard Ansible role directory structure (`tasks/`, `handlers/`, `templates/`, `files/`, `vars/`, `defaults/`, `meta/`). **Avoid monolithic roles.**
- **Task Names:** Use clear, descriptive task names using `name:`. The name should clearly state *what* the task is doing and *why*.
- **Variable Names:** Use descriptive `snake_case` names (e.g., `mailu_webmail_variant`, `traefik_enable_dashboard`). Provide clear explanations for variables, especially in `defaults/main.yml`.
- **File Names:** Use `snake_case` for playbook files, role directories, and template/file names.

### Task Implementation

- **Idempotency:** Ensure **all** tasks are idempotent. Use Ansible modules designed for idempotency. Use `changed_when` and `failed_when` appropriately to accurately report state changes and failures.
- **Modules vs. `command`/`shell`:** **Strongly prefer** using built-in Ansible modules over `command` or `shell`. If `command`/`shell` is unavoidable, ensure the command itself is idempotent or use `creates`/`removes` arguments or `changed_when`/`failed_when` to make the task idempotent.
- **Error Handling:** Use `block`/`rescue`/`always` for robust error handling where appropriate. Use `failed_when` to define custom failure conditions. Use `ignore_errors: true` **very sparingly** and only when the failure is truly expected and handled.
- **Handlers:** Use handlers for actions that should only occur when a change is made and typically only once per play (e.g., restarting services).
- **Tags:** Use tags (`tags:`) effectively on plays, roles, and tasks to allow for granular execution (e.g., `tags: [mailu, configuration]`, `tags: [docker, install]`). Include `always` for critical setup/cleanup tasks if needed.
- **Privilege Escalation:** Use `become: true` only when necessary for specific tasks or blocks, rather than globally for an entire play if possible.

### Secrets Management

- **Ansible Vault:** **All** secrets (API keys, passwords, sensitive tokens) **must** be stored in `vault/secrets.yml` and encrypted using `ansible-vault`.
- **No Hardcoding:** Never hardcode secrets in playbooks, roles, templates, or variable files visible in Git.
- **`no_log: true`:** Use `no_log: true` on tasks that handle sensitive data to prevent secrets from appearing in logs.

## Jinja2 Guidelines (Templates)

- **Clarity:** Write clear, readable, and well-formatted Jinja2 templates.
- **Indentation:** Maintain consistent indentation that reflects the structure of the generated file.
- **Comments:** Use Jinja2 comments (`{# This is a comment #}`) to explain complex logic, loops, or non-obvious sections within templates.
- **Variables:** Access variables clearly (e.g., `{{ mailu_admin_port }}`).
- **Logic:** Keep complex logic minimal within templates. Prefer preparing data structures in Ansible tasks using `set_fact` if it improves template readability. Use filters (`|`) for common transformations (e.g., `{{ some_list | join(',') }}`, `{{ some_var | default('default_value') }}`).
- **Whitespace Control:** Use whitespace control modifiers (`-`, `+`) carefully if needed to manage newlines and spacing in the generated output, but prioritize template readability.

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

## Testing

- **Linting:** Always run `ansible-lint .` and fix all issues before committing or creating a PR.
- **Check Mode:** Use `ansible-playbook --check --diff` frequently during development to catch syntax errors and preview changes without applying them.
- **Idempotency:** Run playbooks multiple times against the same target to ensure they converge to the same state without making unexpected changes after the first run.
- **Manual Verification:** After applying changes, manually verify the state of the target system: check service status (`docker ps`, service logs), inspect generated configuration files, test core functionality (e.g., can Mailu UI be accessed?).
- **Molecule (Future):** As per the PRD roadmap, `molecule` testing should be added for core roles to enable automated, isolated testing.

## Documentation

- **READMEs:** Maintain a high-quality main `README.md`. Roles **must** have their own `README.md` explaining their purpose, variables (inputs), dependencies, and example usage.
- **Variable Documentation:** Clearly document all variables intended for user configuration in the `defaults/main.yml` of the relevant role, including type, default value, and purpose.
- **Code Comments:** Use YAML comments (`#`) in Ansible code and Jinja2 comments (`{# #}`) in templates to explain *why* something is done, especially for complex or non-obvious logic. The code itself should explain the *what*.
- **`docs/` Folder:** Keep architectural documents (`ARCHITECTURE.md`, `PRD.md`) up-to-date with significant changes.

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

Examples:
```
feat(mailu): Add option to configure Postscreen settings
fix(traefik): Correct template logic for middleware chaining
docs(role:common): Document firewall variables in README
style: Apply ansible-lint fixes across all roles
refactor(mailu): Split DKIM key generation into separate task file
test(mailu): Add initial molecule test scenario
ci: Configure GitHub Actions to run ansible-lint
```

By following these guidelines, we maintain a consistent, secure, and high-quality IaC codebase that's easier for everyone to contribute to and maintain, aligning with our goal of providing a production-ready Mailu deployment solution.