# Contributing to iac-mailu

Thank you for considering contributing to the `iac-mailu` project! This document outlines the process for contributing and helps ensure a smooth collaboration experience. **All contributors—human or LLM—must follow these guidelines to ensure the highest standards of quality, security, and maintainability, as defined in our [PRD](docs/PRD.md) and [STYLE_GUIDE.md](STYLE_GUIDE.md).**

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
- **Required:** If the bug relates to a specific role, playbook, or variable, reference the relevant file and line number if possible.
- **Required:** If the bug relates to a requirement in the [PRD](docs/PRD.md), reference the relevant section.

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- Use a clear and descriptive title (e.g., "[FEAT] Add support for automated backups using Restic").
- Provide a detailed description of the suggested enhancement and its relevance to the project goals ([PRD.md](docs/PRD.md)).
- Explain why this enhancement would be useful (e.g., improves security, adds needed functionality).
- Include any relevant examples or use cases (e.g., proposed variable names, role structure changes).
- Use the feature request template ([`.github/ISSUE_TEMPLATE/feature_request.md`](/.github/ISSUE_TEMPLATE/feature_request.md)).
- **Required:** Reference the relevant requirement or section in the [PRD](docs/PRD.md) to justify the enhancement.

## Getting Started: Development Environment Setup

### Prerequisites

Before you begin, ensure you have the following tools installed:

- **Ansible**: Version 2.13+ (minimum), 2.14+ (recommended)
- **Python**: Version 3.9+ (required for modern Ansible functionality)
- **Docker & Docker Compose**: For local testing
- **Git**: For version control
- **Text editor/IDE with YAML support**: VSCode recommended

### Recommended IDE Setup

If using Visual Studio Code (recommended):

1. **Essential Extensions**:
   - YAML extension (`redhat.vscode-yaml`) for YAML validation and formatting
   - Ansible extension (`redhat.ansible`) for Ansible integration
   - GitLens (`eamodio.gitlens`) for better Git integration
   - Jinja2 (`samuelcolvin.jinjahtml`) for improved Jinja2 template editing

2. **Configuration**:
   - Configure your editor to use 2 spaces for indentation in YAML files
   - Enable "Format on Save" with the YAML extension
   - Set up `.editorconfig` support

### Installation Steps

1. **Fork the Repository**: 
   - Visit https://github.com/robertsinfosec/iac-mailu and click "Fork"

2. **Clone Your Fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/iac-mailu.git
   cd iac-mailu
   ```

3. **Set Up Upstream Remote**:
   ```bash
   git remote add upstream https://github.com/robertsinfosec/iac-mailu.git
   ```

4. **Install Required Dependencies**:
   ```bash
   # Install Python dependencies (create a virtualenv if desired)
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt

   # Install required Ansible collections
   ansible-galaxy collection install -r requirements.yml

   # Install development tools
   pip install ansible-lint yamllint pre-commit
   pre-commit install
   ```

5. **Configure Testing Environment**:
   - Set up a test VM or container with a supported OS (Ubuntu 22.04, Debian 12 recommended)
   - Create a minimal inventory for testing:
     ```bash
     cp inventory/hosts.example inventory/hosts
     # Edit inventory/hosts to point to your test server
     ```
   - Set up vault for secrets:
     ```bash
     echo "your-secure-password" > .vault_pass  # Replace with a secure password
     echo ".vault_pass" >> .gitignore  # Make sure not to commit this file
     ansible-vault create vault/secrets.yml  # Create your secrets file
     ```
   - **MANDATORY:** All secrets, credentials, and sensitive data must be stored in `vault/secrets.yml` and encrypted with Ansible Vault. Never commit plaintext secrets.

6. **Linting and Static Analysis**:
   - Run `ansible-lint .` and `yamllint .` before every commit. All code must pass these checks.
   - Pre-commit hooks are required and will run these checks automatically.

7. **Reference Documentation**:
   - The [PRD](docs/PRD.md) is the single source of truth for requirements and scope. Review it before making changes.
   - The [STYLE_GUIDE.md](STYLE_GUIDE.md) defines all coding, documentation, and security standards. All code must comply.

### Development Workflow

1. **Update Your Fork** before starting new work:
   ```bash
   git checkout main
   git fetch upstream
   git merge upstream/main
   git push origin main
   ```

2. **Create a Feature Branch**:
   ```bash
   # Create a descriptively named branch
   git checkout -b feature/descriptive-feature-name
   # For bug fixes:
   git checkout -b fix/issue-number-brief-description
   ```

3. **Make Changes**: Implement your changes following our [STYLE_GUIDE.md](STYLE_GUIDE.md) and referencing the [PRD](docs/PRD.md).

4. **Test Your Changes**:
   ```bash
   # Lint your code
   ansible-lint .
   yamllint .
   
   # Run in check mode first
   ansible-playbook playbooks/site.yml -i inventory/hosts --check --diff --vault-password-file .vault_pass
   
   # Run the actual playbook
   ansible-playbook playbooks/site.yml -i inventory/hosts --diff --vault-password-file .vault_pass
   
   # Test idempotency (run again, should report no changes)
   ansible-playbook playbooks/site.yml -i inventory/hosts --diff --vault-password-file .vault_pass
   ```
   - **MANDATORY:** All playbooks and roles must be idempotent. The second run should report no changes.
   - **MANDATORY:** All secrets must be managed with Ansible Vault. Never commit plaintext secrets.
   - **MANDATORY:** All variables and tasks must be commented for clarity and maintainability.
   - **MANDATORY:** Documentation (README, role docs, variable comments) must be updated alongside code changes.

## Pull Request Process

Creating high-quality Pull Requests (PRs) helps maintainers review and merge your contributions efficiently, ensuring the project remains stable and high-quality for everyone.

### PR Requirements

1. **Create Small, Focused PRs**:
   - Each PR should address a **single issue or feature**
   - DO NOT create large PRs addressing multiple issues at once
   - Small, targeted PRs are reviewed faster and have a higher chance of being merged

2. **Link to Related Issues and PRD Requirements**:
   - Always reference related issues using GitHub syntax (e.g., "Fixes #123" or "Related to #456")
   - Reference the relevant requirement or section in the [PRD](docs/PRD.md) to justify the change

3. **Follow the Style Guide and PRD**:
   - Strictly adhere to our [STYLE_GUIDE.md](STYLE_GUIDE.md) and [PRD](docs/PRD.md)
   - Ensure code passes `ansible-lint` and `yamllint` checks
   - Follow the established patterns in existing code
   - **MANDATORY:** All code must be idiomatic, idempotent, and secure as defined in the PRD and Style Guide

4. **Tests and Documentation**:
   - Add tests for new functionality when applicable (e.g., Molecule scenarios for new roles)
   - Ensure all existing tests pass
   - Update or add documentation:
     - Role README.md files (must include variable documentation, requirements, dependencies, and example usage)
     - Variable documentation in defaults/main.yml (every variable must be commented)
     - Main README.md if appropriate
     - Update the docs/ folder if necessary
   - **MANDATORY:** All new or changed variables must be documented in `defaults/main.yml` with type, default, and description

5. **PR Description**:
   - Fill out the PR template completely and thoughtfully
   - Clearly explain:
     - **What** the change does
     - **Why** the change is needed (reference PRD section)
     - **How** you tested the change (including idempotence and linting)
     - Any **caveats** or important notes for reviewers

6. **Commit Messages**:
   - Write clear, descriptive commit messages
   - Follow the [Conventional Commits](https://www.conventionalcommits.org/) format:
     - `feat:` for features
     - `fix:` for bug fixes
     - `docs:` for documentation
     - `chore:` for maintenance tasks
     - `refactor:` for code refactoring
     - Example: `fix(traefik): correct TLS configuration template variable reference`
   - **MANDATORY:** Each commit should represent a single logical change and reference the relevant PRD section if applicable

7. **Code Review Responses**:
   - Be responsive to feedback during code reviews
   - Address review comments promptly
   - Be open to suggestions and improvements
   - If a reviewer requests clarification on how your change aligns with the PRD or Style Guide, provide a direct reference

### PR Review Process

After submitting your PR:

1. **Automated Checks**: 
   - GitHub Actions will run linting and other automated checks
   - Fix any issues identified by these checks
   - PRs that fail linting, idempotence, or documentation checks will not be merged

2. **Maintainer Review**:
   - Maintainers will review your code for:
     - Adherence to project style and standards
     - Security implications
     - Architectural fit (as defined in [ARCHITECTURE.md](docs/ARCHITECTURE.md))
     - Potential issues or edge cases
     - Alignment with the [PRD](docs/PRD.md)

3. **Iterative Feedback**:
   - Expect feedback and requests for changes
   - This is a normal part of the collaborative development process
   - The goal is to ensure high-quality code that aligns with project goals

4. **Final Approval and Merge**:
   - Once approved, a maintainer will merge your PR
   - For complicated changes, you may be asked to rebase before merging

**Note**: PRs that significantly deviate from these standards may require substantial revision before they can be merged, or may be closed if they cannot be brought up to standard.

## Coding Standards

We adhere to strict standards for Infrastructure as Code (IaC) to ensure security, maintainability, and reliability. Our full style guide is available in [STYLE_GUIDE.md](STYLE_GUIDE.md).

Key principles:

### Ansible Best Practices

- Write **idiomatic** Ansible YAML following community style guides
- Ensure all tasks are **idempotent** (can run multiple times without side effects)
- Strongly prefer Ansible modules over `command`/`shell`
- Use `block/rescue/always` for proper error handling
- Implement proper handlers for service restarts
- Use tags effectively for granular execution
- **MANDATORY:** All secrets must be managed with Ansible Vault. Never commit plaintext secrets.
- **MANDATORY:** All variables and tasks must be commented for clarity and maintainability.
- **MANDATORY:** All code must be tested for idempotence and pass linting before submission.

### Security Standards

- **Never** hardcode secrets in playbooks or templates
- Use Ansible Vault for **all** secrets
- Apply proper file permissions with restrictive modes
- Follow the principle of least privilege
- Add `no_log: true` to tasks handling sensitive data
- Validate all user-provided variables before use (see [STYLE_GUIDE.md](STYLE_GUIDE.md) for patterns)

### Documentation Requirements

- Document all variables in `defaults/main.yml` with clear comments (type, default, description)
- Maintain comprehensive README files for roles (see [STYLE_GUIDE.md](STYLE_GUIDE.md) for required sections)
- Add comments to explain complex logic or non-obvious decisions
- Document role dependencies and requirements
- Update the main README.md and docs/ as needed

### Testing Requirements

- Run linters (`ansible-lint`, `yamllint`) before submitting
- Test playbooks with `--check` mode first
- Verify idempotency by running playbooks multiple times
- Manually verify resulting configurations
- Add or update Molecule scenarios for new roles or major changes (if applicable)

## Communication

### Where to Get Help or Discuss

- **GitHub Issues**: For bug reports, feature requests, and formal discussions
- **Pull Request Comments**: For code-related discussions
- **[Project Wiki](https://github.com/robertsinfosec/iac-mailu/wiki)**: For documentation and guides
- **[GitHub Discussions](https://github.com/robertsinfosec/iac-mailu/discussions)**: For general questions and community discussions

### Response Times

- Bug reports and security issues typically receive a response within 1-3 days
- Feature requests and enhancements may take longer to review
- PRs are typically reviewed within 1 week, depending on complexity

## Further Reading

These resources can help you become a more effective contributor:

- [Ansible Best Practices Guide](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Open Source Guide: How to Contribute](https://opensource.guide/how-to-contribute/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Pull Request Documentation](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-requests)
- [Ansible Infrastructure as Code Best Practices](https://www.redhat.com/en/blog/6-best-practices-infrastructure-as-code-using-ansible)
- [PRD - Product Requirements Document](docs/PRD.md)
- [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [STYLE_GUIDE.md](STYLE_GUIDE.md)

## Acknowledgments

Your contributions make this project better! We appreciate the time and effort you dedicate to improving `iac-mailu`.

Thank you for contributing to `iac-mailu`!