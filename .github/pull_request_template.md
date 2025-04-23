## Description

<!-- Provide a brief description of the changes in this PR and the motivation behind them. -->

## Type of Change

<!-- Mark relevant options with 'x' -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update (READMEs, variable descriptions, etc.)
- [ ] Code refactoring (improving code structure or clarity without changing functionality)
- [ ] Ansible Role update/addition
- [ ] Ansible Playbook change
- [ ] Variable change (`group_vars`, `defaults`, `vault`)
- [ ] Template change (`*.j2`)
- [ ] Dependency update (`requirements.yml`)
- [ ] Other (please describe):

## Related Issues

<!-- Link any related issues here with "Fixes #123" or "Relates to #123" -->
<!-- If this PR addresses a specific requirement from docs/PRD.md, mention it here -->

## How Has This Been Tested?

<!-- 
Describe the tests you ran to verify your changes. Be specific!
- Which playbook(s) were run? (`ansible-playbook ...`)
- Was `--check` mode used?
- Was `ansible-lint` run? What was the result?
- What manual verification steps were performed on the target server? (e.g., checked service status, verified config files, tested Mailu functionality via UI/API)
- What environment was used for testing? (e.g., Target OS, Ansible version)
-->

## Screenshots (if appropriate)

<!-- Add screenshots here if applicable, especially for UI changes or complex configuration results -->

## Checklist

- [ ] My code follows the principles outlined in `.github/copilot-instructions.md`.
- [ ] I have run `ansible-lint` on my changes and fixed any reported issues.
- [ ] I have performed a self-review of my own code.
- [ ] I have commented my code clearly, particularly in hard-to-understand areas (YAML, Jinja2).
- [ ] I have made corresponding changes to the documentation (e.g., Role READMEs, `defaults/main.yml` variable descriptions).
- [ ] My changes generate no new warnings or errors during playbook execution.
- [ ] I have tested the idempotency of my changes (running the playbook multiple times produces the same result).
- [ ] I have ensured that no secrets are hardcoded and sensitive data uses Ansible Vault.
- [ ] I have checked my code and documentation for security best practices.
- [ ] I have read and agree to the [Code of Conduct](/CODE_OF_CONDUCT.md).
- [ ] I have read the [Contributing Guidelines](/CONTRIBUTING.md).
- [ ] I have reviewed the project's [Style Guide](/STYLE_GUIDE.md).
- [ ] I have read the project's [License](/LICENSE).
