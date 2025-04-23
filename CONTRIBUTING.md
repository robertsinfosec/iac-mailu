# Contributing to iac-mailu

Thank you for considering contributing to the `iac-mailu` project! This document outlines the process for contributing and helps ensure a smooth collaboration experience.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## How Can I Contribute?

There are many ways you can contribute to `iac-mailu`:

### Reporting Bugs

Before creating bug reports, please check the [issue tracker](https://github.com/robertsinfosec/iac-mailu/issues) to avoid duplicates. When you create a bug report, include as many details as possible:

- Use a clear and descriptive title (e.g., "[BUG] Traefik role fails on Debian 12").
- Describe the exact steps to reproduce the problem (including relevant configuration from `group_vars/all.yml`, `domains/*.yml`, `inventory/hosts`, redacting secrets).
- Specify which playbook command was run (e.g., `ansible-playbook playbooks/site.yml -vvv`).
- Describe the behavior you observed (e.g., error messages, incorrect configuration) and what you expected to see.
- Include sanitized terminal output (especially Ansible errors with `-vvv`).
- Provide information about your Control Node OS, Target Server OS, Ansible version, Docker version, etc.
- Use the bug report template ([`.github/ISSUE_TEMPLATE/bug_report.md`](/.github/ISSUE_TEMPLATE/bug_report.md)).

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- Use a clear and descriptive title (e.g., "[FEAT] Add support for automated backups using Restic").
- Provide a detailed description of the suggested enhancement and its relevance to the project goals ([PRD.md](docs/PRD.md)).
- Explain why this enhancement would be useful (e.g., improves security, adds needed functionality).
- Include any relevant examples or use cases (e.g., proposed variable names, role structure changes).
- Use the feature request template ([`.github/ISSUE_TEMPLATE/feature_request.md`](/.github/ISSUE_TEMPLATE/feature_request.md)).

### Pull Requests

We welcome contributions via Pull Requests (PRs).

- Ensure your PR addresses an existing issue or discusses a new feature/fix.
- Fill in the required PR template ([`.github/pull_request_template.md`](/.github/pull_request_template.md)).
- Follow the Ansible and IaC standards outlined below and in [`.github/copilot-instructions.md`](/.github/copilot-instructions.md).
- Include relevant testing steps you performed.
- Update documentation (READMEs, variable descriptions, `docs/` folder) as needed.
- Ensure all files end with a newline.
- Ensure your code passes `ansible-lint` checks.

## Development Workflow

### Setting Up the Development Environment

1.  **Fork the Repository:** Start by forking the main `iac-mailu` repository on GitHub to your own account.
2.  **Clone Your Fork:** Clone your forked repository to your local machine:
    ```bash
    git clone https://github.com/YOUR_USERNAME/iac-mailu.git
    cd iac-mailu
    ```
    *(Replace `YOUR_USERNAME` with your GitHub username)*
3.  **Set Up Upstream Remote:** Add the original `iac-mailu` repository as the `upstream` remote:
    ```bash
    git remote add upstream https://github.com/robertsinfosec/iac-mailu.git
    ```
4.  **Install Dependencies:** Ensure you have Ansible installed (check project docs or `requirements.txt` if available for version). Install required Ansible collections/roles:
    ```bash
    # If requirements.yml exists
    ansible-galaxy install -r requirements.yml
    # Install ansible-lint for testing
    pip install ansible-lint # Or use your preferred package manager
    ```
5.  **Set up Inventory & Vault:**
    *   Create an inventory file (e.g., copy `inventory/hosts.example` to `inventory/hosts`) pointing to your test server(s).
    *   Create an Ansible Vault password file (e.g., `.vault_pass`) and create/edit the `vault/secrets.yml` file using `ansible-vault edit vault/secrets.yml --vault-password-file .vault_pass`. Fill in necessary secrets for your test environment. **Do not commit your vault password file.**
    *   Configure `ansible.cfg` to use your vault password file if desired.
    *   Configure `group_vars/all.yml` and any necessary `domains/` files for your test setup.

### Development Process

1.  **Update Your Fork:** Before starting work, ensure your `main` branch is up-to-date with the `upstream` repository:
    ```bash
    git checkout main
    git fetch upstream
    git merge upstream/main
    git push origin main
    ```
2.  **Create a Branch:** Create a new branch for your feature or bug fix:
    ```bash
    # Use a descriptive branch name (e.g., feature/add-backup-role, fix/mailu-dkim-template)
    git checkout -b your-branch-name
    ```
3.  **Make Changes:** Implement your changes, adhering to the coding standards. Write clear Ansible tasks, roles, and templates.
4.  **Test Locally:**
    *   Run linters:
        ```bash
        ansible-lint .
        ```
    *   Run playbooks against your test environment:
        *   Use `--check` mode for a dry run:
            ```bash
            ansible-playbook playbooks/site.yml -i inventory/hosts --check --diff --vault-password-file .vault_pass
            ```
        *   Perform a full run:
            ```bash
            ansible-playbook playbooks/site.yml -i inventory/hosts --diff --vault-password-file .vault_pass
            ```
        *   Test idempotency by running the playbook multiple times. Verify the state on the target server.
5.  **Commit Changes:** Commit your changes with clear, descriptive commit messages following conventional commit guidelines if possible. Reference relevant issue numbers (e.g., `Fixes #123`).
    ```bash
    git add .
    git commit -m "feat(backup): Add initial structure for backup role (Fixes #45)"
    ```
6.  **Push to Your Fork:** Push your branch to your GitHub fork:
    ```bash
    git push origin your-branch-name
    ```
7.  **Create a Pull Request:** Open a Pull Request (PR) from your branch on your fork to the `main` branch of the `upstream` `iac-mailu` repository. Fill out the PR template thoroughly, including details on how you tested your changes.

## Coding Standards

We follow strict Ansible and IaC best practices. Please refer to our [GitHub Copilot Instructions](.github/copilot-instructions.md) for detailed coding guidelines.

Key points:

-   **Ansible:** Write clean, idiomatic YAML. Ensure tasks are idempotent. Prefer modules over `command`/`shell`. Use Vault for secrets. Write clear task names. Structure logic into single-responsibility roles. Use tags appropriately.
-   **Jinja2:** Write clear and maintainable templates. Add comments for complex logic.
-   **Docker/Compose (via Ansible):** Ensure generated configurations are secure and follow best practices (non-root users, health checks where applicable).
-   Follow project structure conventions.
-   Ensure code is well-commented, especially complex logic in YAML or Jinja2.

## Testing

-   Run `ansible-lint .` and fix all reported issues before submitting a PR.
-   Thoroughly test your changes against a representative environment (e.g., a VM running the target OS).
-   Run playbooks in `--check` mode first.
-   Run playbooks multiple times to verify idempotency.
-   Manually verify the resulting configuration and service status on the target server.
-   Consider adding `molecule` tests for new or significantly modified roles (see Roadmap in PRD).

## Documentation

-   Update the main `README.md` if you change core functionality, setup steps, or major variables.
-   Add/update `README.md` files within roles you create or modify, explaining their purpose, variables, and usage.
-   Clearly document new variables in the relevant `defaults/main.yml` file.
-   Update any relevant documentation in the `docs/` folder (e.g., `ARCHITECTURE.md`, `PRD.md` if impacted).

## Review Process

Once you submit a PR:

1.  Maintainers will review your code for correctness, style, adherence to project goals, security, and best practices.
2.  Automated checks (linting, etc., via GitHub Actions if configured) will run.
3.  You may need to make additional changes based on feedback. Engage in discussion via PR comments.
4.  Once approved and checks pass, a maintainer will merge your PR.

Thank you for contributing to `iac-mailu`!