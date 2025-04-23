# 📦 Project: iac-mailu - Production-Ready Ansible Deployment for Mailu

**Vision:** To provide an exemplary, secure, and fully automated Infrastructure as Code (IaC) solution for deploying and managing a **single Mailu instance** supporting **multiple email domains**. This project aims to be the definitive, production-ready Ansible playbook for self-hosting Mailu, adhering strictly to security best practices, operational excellence, and maintainability.

---

## 🧭 Guiding Principles

This project adheres to the following core principles:

1.  **Security First:** Security is paramount and integrated into every aspect, from infrastructure hardening to configuration management and operational practices. We prioritize secure defaults and proactive threat mitigation.
2.  **Automation & Idempotency:** Strive for 100% automation via Ansible, ensuring deployments are repeatable, predictable, and idempotent. Manual intervention should be minimized or eliminated.
3.  **Production Readiness:** All components, configurations, and processes are designed for stability, reliability, and performance suitable for production environments. This includes robust error handling, monitoring hooks, and comprehensive testing.
4.  **Maintainability & Simplicity:** Code (Ansible YAML, Jinja2) and configurations must be clear, well-documented, modular, and easy to understand and maintain over time. Avoid unnecessary complexity.
5.  **Strict Modularity (Single Responsibility Roles):** Design Ansible roles with a clear, single responsibility. **Aggressively avoid monolithic roles.** Break down complex tasks into smaller, reusable, and independently testable roles to enhance maintainability and reduce technical debt. *(New Principle Added)*
6.  **Best Practices:** Adhere rigorously to industry best practices for Ansible, Docker, email server management, security, and IaC. Continuously evaluate and incorporate improvements.
7.  **Comprehensive Documentation:** Maintain clear, accurate, and up-to-date documentation covering architecture, setup, configuration, operation, and troubleshooting.
8.  **Minimize Technical Debt:** Proactively address potential technical debt by choosing robust, scalable solutions and refactoring when necessary. Make design decisions favouring long-term health over short-term convenience. *(Enhanced Principle)*

---

## 📁 Directory Structure

```
mailu-iac/src/
├── ansible.cfg
├── inventory/
│   └── hosts
├── group_vars/
│   └── all.yml
├── domains/
│   └── fun-project.org.yml
│   └── another-project.net.yml
├── roles/
│   └── mailu/
│       ├── tasks/
│       ├── templates/
│       └── files/
├── templates/
│   ├── docker-compose.yml.j2
│   └── traefik_dynamic.yml.j2
├── playbooks/
│   └── site.yml
├── vault/
│   └── secrets.yml (encrypted with ansible-vault)
├── .env.j2
```

---

## 🎯 Core Features (Current & Planned)

*   **Automated End-to-End Deployment:** Ansible playbooks manage everything from OS preparation (hardening, package installation) to Mailu stack deployment and ongoing configuration updates.
*   **Multi-Domain Architecture:** Natively supports hosting multiple distinct email domains on a single Mailu instance, configured via simple, per-domain YAML files (`domains/*.yml`).
*   **Secure TLS Management:**
    *   Uses Traefik as a secure reverse proxy.
    *   Automated TLS certificate acquisition and renewal via Let's Encrypt using the robust Cloudflare DNS-01 challenge (avoids exposing port 80).
    *   Ensures per-domain TLS certificates, preventing Subject Alternative Name (SAN) leakage between domains.
    *   Configured with strong TLS protocols and cipher suites.
*   **Automated & Secure DNS:**
    *   Leverages the Cloudflare API via Ansible for fully automated management of required DNS records (MX, SPF, DKIM, DMARC, A/CNAME, `_acme-challenge`).
    *   Configures security-focused DNS records (e.g., strict DMARC policies where appropriate, secure SPF).
*   **Containerized & Isolated Services:**
    *   Runs Mailu, Traefik, and CrowdSec within Docker containers managed by Docker Compose for isolation and dependency management.
    *   Ansible generates secure and optimized `docker-compose.yml` configurations from Jinja2 templates.
*   **Integrated Intrusion Prevention:**
    *   Deploys CrowdSec (Agent and Docker Bouncer) for proactive threat detection and blocking based on shared community intelligence and local behavior analysis.
*   **Robust Secret Management:**
    *   **Strictly** enforces the use of Ansible Vault for all sensitive data (API keys, user passwords, internal secrets). No secrets are ever stored in plaintext within the repository or configuration files visible in Git.
*   **Configuration Management:**
    *   Centralized and version-controlled configuration via Git.
    *   Clear separation of global (`group_vars/all.yml`), domain-specific (`domains/*.yml`), and secret (`vault/secrets.yml`) variables.
*   **Operational Tooling:**
    *   Includes playbooks for health checks (`health_check.yml`).
    *   Optional integration with Ntfy for push notifications on playbook runs or alerts.
*   **Modularity & Reusability:** Built using well-defined Ansible roles following best practices for structure and reusability.
*   **CI/CD Integration:** Designed for seamless integration into CI/CD pipelines (e.g., GitHub Actions) for automated testing and deployment.

---

## 📄 Example Domain Config

```yaml
# domains/fun-project.org.yml
domain: fun-project.org
hostname: mail.fun-project.org
webmail: webmail.fun-project.org
admin: admin.fun-project.org

users:
  - name: support
    password_var: vault_support_fun_project_org
    catchall: true
```

---

## 🔐 Vault Secrets (`vault/secrets.yml`)

```yaml
vault_support_fun_project_org: "plain-or-encrypted-pass"
cloudflare_api_token: "abcdef1234567890"
```

---

## ☁️ DNS Records Automatically Created

- MX → `mail.domain`
- SPF → `v=spf1 mx ~all`
- DKIM → TXT record from Mailu key
- DMARC → `v=DMARC1; p=none; rua=mailto:support@domain`
- A/CNAME for `webmail.`, `admin.`, `autoconfig.`
- `_acme-challenge.` for DNS-01 via Cloudflare

---

## 🔐 Security Posture & Hardening (Current & Planned)

Security is foundational. Measures include:

*   **Ansible Vault:** Mandatory for all secrets.
*   **CrowdSec:** Real-time intrusion detection and prevention.
*   **Traefik TLS:** Secure certificate handling (DNS-01), strong ciphers/protocols, HSTS headers.
*   **Automated DNS Security Records:** Correct SPF, DKIM, and DMARC setup managed via Ansible.
*   **Minimal Exposure:** DNS-01 challenge avoids opening port 80. Firewall rules (managed via Ansible role TBD) restrict access to necessary ports only.
*   **Server Hardening (via `common` role / dedicated `hardening` role TBD):**
    *   SSH lockdown (key-based auth only, disable root login, rate limiting).
    *   Basic firewall configuration (UFW or firewalld).
    *   Regular security updates applied via Ansible.
    *   Filesystem permissions hardening.
*   **Docker Security:**
    *   Run containers with minimal privileges where possible.
    *   Network segmentation using Docker networks.
    *   Resource limits configured via Docker Compose (TBD).
    *   Regular scanning of container images (CI task TBD).
*   **Mailu Configuration:** Secure defaults applied via Ansible variables.
*   **Regular Audits:** Plan for periodic review of security configurations and practices.

---

## ▶️ Running the Playbook

```bash
ansible-playbook playbooks/site.yml
```

---

## 🔁 Adding a New Domain

1. Create `domains/newproject.org.yml`
2. Add passwords to `vault/secrets.yml`
3. Re-run the playbook

---

## 🚫 Non-Goals

*   **High Availability (HA) / Clustering:** Focus remains on a robust single-node deployment.
*   **Support for Non-Cloudflare DNS Providers:** Automation is currently tied to Cloudflare API.
*   **Graphical User Management Interface (beyond Mailu Admin):** Management is primarily via configuration files (`domains/*.yml`) and Ansible.
*   **Direct Database Management:** Relies on Mailu's internal handling or standard Docker volume management.

---

## 🏗️ Architecture Overview

*(Refer to `docs/ARCHITECTURE.md` for a detailed diagram and explanation)*

Key components remain Ansible, Docker, Docker Compose, Mailu, Traefik, CrowdSec, Cloudflare API, and Jinja2, orchestrated to provide the features described above.

---

## 🗺️ Roadmap / Future Enhancements (Prioritized for Production Readiness)

1.  **Critical: Backup and Recovery:**
    *   Develop a dedicated, robust `backup` role using tools like Restic or BorgBackup.
    *   Automate backups of Mailu volumes (data, certs), Mailu config (`mailu.env`), Traefik state, CrowdSec state, and Ansible configurations.
    *   Support encrypted, off-site backups (e.g., S3, Backblaze B2).
    *   **Crucially:** Develop and document a tested disaster recovery plan and restore procedure playbook.
2.  **Enhanced Monitoring & Alerting:**
    *   Integrate Prometheus Node Exporter and potentially Mailu-specific exporters via Ansible.
    *   Provide baseline Grafana dashboard templates for system and Mailu metrics.
    *   Configure Alertmanager for critical alerts (e.g., service down, disk space low, certificate expiry imminent) via Ntfy or other channels.
    *   Implement checks for email queue lengths and delivery delays.
3.  **Comprehensive Testing:**
    *   Implement `molecule` testing for core Ansible roles (`mailu`, `traefik`, `common`, `backup`).
    *   Expand CI pipeline integration tests: basic email send/receive, DNS record verification, TLS configuration check (e.g., using `testssl.sh`).
    *   Formalize idempotence checks within CI.
4.  **Advanced Security Hardening:**
    *   Implement a dedicated `hardening` role covering OS, SSH, sysctl, and firewall rules (UFW/firewalld) more extensively.
    *   Integrate automated container image vulnerability scanning (e.g., Trivy) into CI.
    *   Implement stricter Docker resource limits and security options (seccomp, AppArmor profiles if feasible).
    *   Add automated TLS configuration testing/scoring to CI.
5.  **Improved Operational Experience:**
    *   Develop operational runbooks (in `/docs`) for common tasks: upgrades (Mailu, OS, dependencies), troubleshooting common issues, manual user/domain changes (if ever needed outside Ansible).
    *   Enhance Ansible playbook error reporting and pre-flight checks (e.g., validate variable formats, check reachability).
    *   Implement stricter version pinning for Docker images and Ansible collections/roles in `requirements.yml`.
6.  **Deliverability Assurance:**
    *   Integrate automated checks (e.g., via playbook or CI job) for SPF/DKIM/DMARC validity using external tools/APIs post-deployment.
    *   Add optional monitoring hooks for IP reputation/RBL status.
7.  **Documentation Overhaul:**
    *   Create a dedicated Troubleshooting Guide.
    *   Refine `README.md` for clarity and completeness.
    *   Ensure all role `README.md` files are comprehensive regarding variables and purpose.
    *   Add performance tuning guidance.

---

## ✅ System Requirements

*   **Control Node:** Ansible (latest stable recommended, see `requirements.txt`/docs), Python 3.x.
*   **Target Server:** Ubuntu 22.04/24.04 LTS or Debian 12 (latest) strongly recommended. Clean OS install preferred. Sufficient RAM/CPU/Disk (see Mailu recommendations + overhead). SSH access (key-based).
*   **Dependencies (Managed by Ansible):** Docker Engine, Docker Compose (latest compatible versions).
*   **External Services:** Cloudflare Account & API Token (Global API Key or scoped Token with DNS edit permissions). Ntfy server (optional).

---

This PRD serves as the definitive guide and standard for the `iac-mailu` project. All contributions and development efforts must align with this vision and its underlying principles.
