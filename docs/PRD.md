# 📦 Project: iac-mailu - Production-Ready Ansible Deployment for Mailu

**Vision:** To provide an exemplary, secure, and fully automated Infrastructure as Code (IaC) solution for deploying and managing a **single Mailu instance** supporting **multiple email domains**. This project aims to be the definitive, production-ready Ansible playbook for self-hosting Mailu, adhering strictly to security best practices, operational excellence, and maintainability.

---

## 🧭 Guiding Principles

This project adheres to the following core principles:

1.  **Security First:** Security is paramount and integrated into every aspect, from infrastructure hardening to configuration management and operational practices. We prioritize secure defaults and proactive threat mitigation.
2.  **Automation & Idempotency:** Strive for 100% automation via Ansible, ensuring deployments are repeatable, predictable, and idempotent. Manual intervention should be minimized or eliminated.
3.  **Production Readiness:** All components, configurations, and processes are designed for stability, reliability, and performance suitable for production environments. This includes robust error handling, monitoring hooks, and comprehensive testing.
4.  **Maintainability & Simplicity:** Code (Ansible YAML, Jinja2) and configurations must be clear, well-documented, modular, and easy to understand and maintain over time. Avoid unnecessary complexity.
5.  **Strict Modularity (Single Responsibility Roles):** Design Ansible roles with a clear, single responsibility. **Aggressively avoid monolithic roles.** Break down complex tasks into smaller, reusable, and independently testable roles. **Crucially, application-specific roles (e.g., `mailu`, `traefik`) MUST NOT perform unrelated system-level tasks (e.g., OS hardening, firewall configuration, general package management).** These belong in dedicated system or utility roles. Application roles *may* manage their direct dependencies (e.g., installing required Python libraries via `pip` within a specific context, ensuring necessary Docker images are pulled) but should rely on base roles for system prerequisites like `docker` itself.
6.  **Best Practices:** Adhere rigorously to industry best practices for Ansible, Docker, email server management, security, and IaC. Continuously evaluate and incorporate improvements. **Pin specific versions of Ansible collections and roles in `requirements.yml` for stable, repeatable builds.**
7.  **Comprehensive Documentation:** Maintain clear, accurate, and up-to-date documentation covering architecture, setup, configuration, operation, and troubleshooting.
8.  **Minimize Technical Debt:** Proactively address potential technical debt by choosing robust, scalable solutions and refactoring when necessary. Make design decisions favouring long-term health over short-term convenience. *(Enhanced Principle)*
9.  **Robust Error Handling:** Playbooks should fail fast on critical errors (e.g., inability to connect, failure to install core packages). Use `block/rescue` where appropriate for atomicity or cleanup. Non-critical errors should be logged clearly. *(New Principle)*
10. **Idempotent State Management:** Playbooks must handle updates to existing configurations gracefully (e.g., modifying users in `domains/*.yml`, changing DNS records) ensuring the final state matches the desired configuration without unintended side effects. *(New Principle)*

---

## 📁 Directory Structure (Illustrative)

```
iac-mailu/
├── docs/
│   ├── PRD.md
│   └── ARCHITECTURE.md
├── src/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts
│   ├── group_vars/
│   │   └── all.yml
│   ├── domains/
│   │   └── example.com.yml
│   │   └── another-project.net.yml
│   ├── roles/
│   │   ├── common/             # Common prerequisites, package installs
│   │   ├── hardening/          # OS & SSH hardening tasks
│   │   ├── firewall/           # Firewall configuration (e.g., UFW)
│   │   ├── docker_base/        # Docker Engine & Compose installation
│   │   ├── dns_management/     # Cloudflare DNS record management
│   │   ├── traefik/            # Traefik deployment & configuration
│   │   ├── crowdsec/           # CrowdSec agent & bouncer deployment
│   │   ├── mailu/              # Mailu application deployment & config
│   │   ├── backup/             # Backup configuration & scripts
│   │   ├── monitoring/         # (Future) Monitoring agent setup
│   │   └── ...                 # Other potential roles
│   ├── playbooks/
│   │   ├── site.yml            # Main deployment playbook
│   │   ├── backup.yml          # Run backup tasks
│   │   ├── restore.yml         # Run restore tasks
│   │   └── health_check.yml    # Run health checks
│   ├── templates/
│   │   ├── docker-compose.yml.j2
│   │   ├── traefik.yml.j2
│   │   └── ...                 # Other shared templates
│   ├── vault/
│   │   └── secrets.yml         # Encrypted secrets
│   └── requirements.yml        # Ansible collection dependencies
├── README.md
├── LICENSE
└── ...
```

*Note: This structure is illustrative and may evolve. The key principle is the separation into single-responsibility roles.*

---

## 📋 Role Responsibilities (Illustrative Boundaries)

To enforce the "Strict Modularity" principle, the primary responsibilities of core roles are defined as follows:

*   **`common`:** Installs essential system packages required by multiple roles (e.g., `python3`, `curl`, `ca-certificates`, potentially `git`). Sets basic system environment settings like timezone if needed globally.
*   **`hardening`:** Configures OS-level security settings (e.g., `sysctl`), SSH daemon (`sshd_config` hardening like disabling password auth, setting up banners), potentially installs basic security tools like `fail2ban` (if not using CrowdSec bouncer for SSH). Does *not* manage application-specific security.
*   **`firewall`:** Manages the host firewall (e.g., UFW, firewalld). Defines allowed ingress/egress ports based on required services (Mailu ports, SSH, Traefik web ports).
*   **`docker_base`:** Installs and configures Docker Engine and Docker Compose. Manages Docker daemon configuration (`daemon.json`). Does *not* run application containers.
*   **`dns_management`:** Manages DNS records exclusively via the Cloudflare API. Creates/updates records required by Mailu, Traefik (for ACME), and security standards (SPF, DKIM, DMARC, MTA-STS, TLSRPT).
*   **`traefik`:** Deploys and configures the Traefik reverse proxy container. Manages static and dynamic configurations, including TLS settings, middleware, and entrypoints. Handles Let's Encrypt certificate acquisition via DNS-01 challenge using credentials provided via Vault.
*   **`crowdsec`:** Deploys the CrowdSec agent and relevant bouncers (e.g., Docker bouncer for Traefik). Manages CrowdSec configuration files.
*   **`mailu`:** Deploys the Mailu Docker Compose stack. Manages Mailu configuration (`mailu.env`, `docker-compose.yml.j2`), persistent volumes, and Mailu-specific setup tasks. Relies on `docker_base` being completed.
*   **`backup`:** Configures and potentially schedules backups of critical data (Mailu volumes, configs, Vault file). (See Roadmap)
*   **`monitoring`:** Installs and configures monitoring agents (e.g., Node Exporter). (See Roadmap)

---

## 🎯 Core Features (Current & Planned)

*   **Automated End-to-End Deployment:** Ansible playbooks manage everything from OS preparation (hardening, package installation) to Mailu stack deployment and ongoing configuration updates.
*   **Multi-Domain Architecture:** Natively supports hosting multiple distinct email domains on a single Mailu instance, configured via simple, per-domain YAML files (`domains/*.yml`).
*   **Secure TLS Management:**
    *   Uses Traefik as a secure reverse proxy.
    *   Automated TLS certificate acquisition and renewal via Let's Encrypt using the robust Cloudflare DNS-01 challenge (avoids exposing port 80).
    *   Ensures **per-domain TLS certificates**, preventing Subject Alternative Name (SAN) leakage between domains.
    *   Configured with strong TLS protocols and cipher suites (e.g., aiming for Mozilla Intermediate compatibility or better).
*   **Automated & Secure DNS:**
    *   Leverages the Cloudflare API via Ansible for fully automated management of required DNS records (MX, SPF, DKIM, DMARC, MTA-STS, TLSRPT, A/CNAME, `_acme-challenge`).
    *   Configures security-focused DNS records (e.g., strict DMARC policies like `p=quarantine` or `p=reject` where appropriate, secure SPF `~all` or `-all`).
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
    *   **Required Global Variables:** A minimal set of core variables must be defined in `group_vars/all.yml` for the system to function (e.g., `mailu_base_dir`, `target_user`, `cloudflare_api_email` [if using API key], potentially default timezone). See "Minimal User Configuration" below.
    *   **Domain Configuration Schema:** `domains/*.yml` files should adhere to the defined structure (domain, hostname, webmail, admin, users list). Extensions beyond this schema are not guaranteed to be supported by the core roles.
*   **Operational Tooling:**
    *   Includes playbooks for health checks (`health_check.yml`).
    *   Optional integration with Ntfy for push notifications on playbook runs or alerts.
*   **Modularity & Reusability:** Built using well-defined, single-responsibility Ansible roles (e.g., `docker_base`, `hardening`, `firewall`, `dns_management`, `traefik`, `mailu`, `crowdsec`, `backup`) following best practices for structure and reusability. The `mailu` role specifically focuses *only* on Mailu application deployment and configuration.
*   **CI/CD Integration:** Designed for seamless integration into CI/CD pipelines (e.g., **GitHub Actions**) for automated testing and deployment upon configuration changes (like adding domains/users).

---

## 📄 Example Domain Config

```yaml
# domains/fun-project.org.yml
domain: fun-project.org
hostname: mail.fun-project.org
webmail: webmail.fun-project.org
admin: webmailadmin.fun-project.org

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
- SPF → `v=spf1 mx ~all` (or configurable strictness `-all`)
- DKIM → TXT record from Mailu key
- DMARC → `v=DMARC1; p=none; rua=mailto:support@domain` (configurable policy `p=`, reporting `rua=`)
- A/CNAME for `webmail.`, `admin.`, `autoconfig.`
- `_mta-sts.` CNAME/TXT record for MTA-STS policy.
- `_smtp._tls.` TXT record for TLSRPT reporting.
- `_acme-challenge.` for DNS-01 via Cloudflare

---

## 🔐 Security Posture & Hardening (Current & Planned)

Security is foundational. Measures include:

*   **Ansible Vault:** Mandatory for all secrets.
*   **CrowdSec:** Real-time intrusion detection and prevention (managed via a dedicated `crowdsec` role).
*   **Traefik TLS:** Secure certificate handling (DNS-01), strong ciphers/protocols (target: Mozilla Intermediate), HSTS headers (managed via the `traefik` role).
*   **Automated DNS Security Records:** Correct SPF, DKIM, DMARC, MTA-STS, TLSRPT setup (managed via the `dns_management` role).
*   **Minimal Exposure:** DNS-01 challenge avoids opening port 80. Firewall rules restrict access to necessary ports only (e.g., 25, 143, 443, 465, 587, 993, SSH port) from `any` or specified sources (managed via a dedicated `firewall` role, e.g., using UFW or firewalld).
*   **Server Hardening (Managed via dedicated `hardening` role(s)):**
    *   SSH lockdown (Mandatory: `PermitRootLogin no`, `PasswordAuthentication no`, `AllowUsers <ansible_user>`).
    *   Configure a clear **SSH warning banner** (`/etc/issue.net`).
    *   Basic OS security tuning (e.g., sysctl parameters like `net.ipv4.tcp_syncookies=1`).
    *   Regular security updates applied via Ansible (potentially part of `common` or a separate `os_updates` role).
*   **Docker Security:** Assumes a standard secure installation of Docker Engine and Compose via the `docker_base` role. Advanced Docker security hardening (e.g., user namespaces, security profiles, image scanning) is considered out of scope for the initial MVP.
*   **Mailu Configuration (Managed via `mailu` role):** Secure defaults applied via Ansible variables specific to Mailu.
*   **Regular Audits:** Plan for periodic review of security configurations and practices.

---

## ⚙️ Minimal User Configuration (Getting Started)

To achieve a **turnkey configuration experience**, a user primarily needs to configure the following:

1.  **`inventory/hosts`:** Define the target server(s) and connection details.
2.  **`group_vars/all.yml`:**
    *   `mailu_base_dir`: The root directory for Mailu data and configuration on the target host (e.g., `/opt/mailu`).
    *   `target_user`: The non-root user Ansible should primarily operate as for file ownership, etc. (e.g., `mailuadmin`).
    *   `cloudflare_api_email`: (If using Global API Key) Your Cloudflare account email.
    *   `ansible_user`: The user Ansible connects via SSH as (can also be set in inventory).
    *   *(Review `roles/*/defaults/main.yml` for other essential global overrides like timezone, specific versions, etc.)*
3.  **`domains/yourdomain.com.yml`:** Create at least one domain file, specifying:
    *   `domain`: Your email domain.
    *   `hostname`: The FQDN for the mail server (e.g., `mail.yourdomain.com`).
    *   `webmail`: The FQDN for webmail access (e.g., `webmail.yourdomain.com`).
    *   `admin`: The FQDN for admin access (e.g., `admin.yourdomain.com`).
    *   `users`: A list of users, each with a `name` and `password_var` referencing a Vault variable.
4.  **`vault/secrets.yml`:** Define all secrets referenced in `domains/*.yml` and required by roles:
    *   `vault_<user>_<domain_underscores>`: Password for each user defined in domain files.
    *   `cloudflare_api_token` or `cloudflare_api_key`: Your Cloudflare API credential.
    *   *(Add any other secrets required by roles, e.g., potential backup credentials, notification service tokens)*

---

## 🔐 Vault Secrets (`vault/secrets.yml`)

```yaml
vault_support_fun_project_org: "plain-or-encrypted-pass"
cloudflare_api_token: "abcdef1234567890"
```

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

## ✅ MVP Scope (Initial `site.yml` Deliverable)

The initial, production-ready Minimum Viable Product (MVP) delivered by the `site.yml` playbook includes:

*   End-to-end deployment of a single Mailu instance supporting multiple domains.
*   OS preparation (common packages, Docker installation via `common` and `docker_base`).
*   Basic OS/SSH hardening (via `hardening` role).
*   Firewall configuration (via `firewall` role).
*   Automated Cloudflare DNS management for required records (via `dns_management`).
*   Traefik deployment with automated Let's Encrypt TLS (DNS-01) per domain (via `traefik`).
*   CrowdSec Agent and Docker Bouncer deployment (via `crowdsec`).
*   Mailu stack deployment and configuration based on `domains/*.yml` and Vault secrets (via `mailu`).
*   Secure secret management using Ansible Vault.
*   Basic health check capability (`health_check.yml`).

**Features explicitly NOT part of the initial MVP (but high priority roadmap items):**

*   Backup and Recovery (`backup` role, `restore.yml`)
*   Advanced Monitoring & Alerting (`monitoring` role)
*   Comprehensive Molecule/CI Testing (basic structure may exist, but full coverage is roadmap)
*   Dedicated playbooks for granular domain/user management (`manage_domains.yml`, `manage_users.yml`) - MVP relies on re-running `site.yml`.
*   Centralized Log Management.

---

## 🔄 Ongoing Management & Operations (Post-MVP Deployment)

This automation aims for simplicity in ongoing management:

*   **Domain & User Management:** Adding, removing, or modifying domains and users is achieved by editing the relevant `domains/*.yml` files and associated secrets in `vault/secrets.yml`, then **re-running the main `site.yml` playbook**. The roles are designed to idempotently apply these changes to the Mailu configuration.
*   **Mailu Configuration Updates:** Changes to Mailu's core configuration (controlled via `mailu.env`, such as quotas, message size limits, etc.) are managed by updating the corresponding Ansible variables (primarily in `group_vars/all.yml`, role defaults, or Vault for secrets) and **re-running the `site.yml` playbook**.
*   **Mailu Version Upgrades:** Upgrading the Mailu stack version is handled by updating the relevant version variable (e.g., `mailu_version`, defined in `group_vars/all.yml` or role defaults) and **re-running the `site.yml` playbook**. *Note: Users are responsible for reviewing Mailu's official release notes for potential breaking changes or manual migration steps required between versions, which are outside the scope of this automation.*

---

## 🗺️ Roadmap / Future Enhancements (Prioritized Post-MVP)

1.  **Critical: Backup and Recovery:**
    *   Develop a dedicated, robust `backup` role.
    *   Support multiple backup strategies/tools, allowing user choice:
        *   **File-based sync:** `rsync` to a remote SSH destination.
        *   **Deduplicating backup tools:** Restic or BorgBackup.
    *   Support encrypted, off-site backups to various targets:
        *   **Cloud Storage:** AWS S3, Azure Blob Storage, Google Cloud Storage.
        *   **Other:** Backblaze B2, SFTP/SSH destinations.
    *   Automate backups of Mailu volumes (data, certs), Mailu config (`mailu.env`), Traefik state, CrowdSec state, and relevant Ansible configurations/secrets.
    *   **Crucially:** Develop and document a tested disaster recovery plan and restore procedure playbook (`restore.yml`).
2.  **Enhanced Monitoring & Alerting:**
    *   Integrate Prometheus Node Exporter and potentially Mailu-specific exporters via Ansible.
    *   Provide baseline Grafana dashboard templates for system and Mailu metrics.
    *   Configure Alertmanager for critical alerts (e.g., service down, disk space low, certificate expiry imminent) via Ntfy or other channels.
    *   Implement checks for email queue lengths and delivery delays.
3.  **Comprehensive Testing:**
    *   Implement `molecule` testing for core Ansible roles (`mailu`, `traefik`, `hardening`, `backup`, `dns_management`). Molecule tests should cover default installations, common configuration variations, service status checks, configuration file correctness, and basic idempotency checks.
    *   Expand CI pipeline integration tests (post-MVP): basic email send/receive, DNS record verification, TLS configuration check (e.g., using `testssl.sh`).
    *   Formalize idempotence checks within CI (ensure playbooks run twice with no changes on the second run).
4.  **Advanced Security Hardening:**
    *   Explore options like AppArmor/SELinux profiles for containers.
    *   Implement automated security scanning (e.g., container image scanning, dependency checks).
5.  **Centralized Log Management:**
    *   Integrate log shipping (e.g., Fluentd, Vector) to send container and system logs to a central logging platform (e.g., Elasticsearch/Loki).
6.  **Granular Management Playbooks:**
    *   Implement dedicated playbooks (`manage_domains.yml`, `manage_users.yml`) for faster, more targeted updates without running the full `site.yml`.
7.  **Multi-Node / HA Considerations:**
    *   Research and document potential approaches for scaling Mailu across multiple nodes.
    *   Explore options for high availability (HA) configurations, including load balancing and failover strategies.
8.  **Advanced Security Hardening:**
    *   Implement a dedicated `hardening` role covering OS, SSH, sysctl, and firewall rules (UFW/firewalld) more extensively.
    *   Integrate automated container image vulnerability scanning (e.g., Trivy) into CI.
    *   Implement stricter Docker resource limits and security options (seccomp, AppArmor profiles if feasible).
    *   Add automated TLS configuration testing/scoring to CI.
9.  **Improved Operational Experience:**
    *   Develop operational runbooks (in `/docs`) for common tasks: upgrades (Mailu, OS, dependencies), troubleshooting common issues, manual user/domain changes (if ever needed outside Ansible).
    *   Enhance Ansible playbook error reporting and pre-flight checks (e.g., validate variable formats, check reachability).
    *   Implement stricter version pinning for Docker images and Ansible collections/roles in `requirements.yml`.
10.  **Deliverability Assurance:**
    *   Integrate automated checks (e.g., via playbook or CI job) for SPF/DKIM/DMARC validity using external tools/APIs post-deployment.
    *   Add optional monitoring hooks for IP reputation/RBL status.
11.  **Documentation Overhaul:**
    *   Create a dedicated Troubleshooting Guide.
    *   Refine `README.md` for clarity and completeness.
    *   Ensure all role `README.md` files are comprehensive regarding variables and purpose.
    *   Add performance tuning guidance.

---

## ✅ System Requirements

*   **Control Node:** Ansible Core (e.g., >= 2.15, specify exact minimum), Python 3.x. Ansible Collections as defined in `src/requirements.yml`.
*   **Target Server:** Ubuntu 22.04/24.04 LTS or Debian 12 (latest) strongly recommended. Clean OS install preferred. Sufficient RAM/CPU/Disk (see Mailu recommendations + overhead for Traefik, CrowdSec, etc.). SSH access (key-based) for the `ansible_user`.
*   **Dependencies (Managed by Ansible):** Docker Engine, Docker Compose (latest compatible versions installed by `docker_base` role).
*   **External Services:** Cloudflare Account & API Token (Global API Key or scoped Token with DNS edit permissions). Ntfy server (optional).

---

This PRD serves as the definitive guide and standard for the `iac-mailu` project. All contributions and development efforts must align with this vision and its underlying principles.
