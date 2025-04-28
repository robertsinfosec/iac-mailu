# iac-mailu Deployment Architecture

**Version:** 1.1
**Last Updated:** April 24, 2025

## 1. Introduction & Goals

This document details the architecture of the `iac-mailu` project. Its primary goal is to provide an exemplary, secure, and fully automated Infrastructure as Code (IaC) solution for deploying and managing a **single Mailu instance** supporting **multiple email domains**, as defined in the [Product Requirements Document (`docs/PRD.md`)](./PRD.md).

The architecture is designed to meet the following high-level goals derived from the PRD:

*   **Automation:** Achieve end-to-end automation for deployment, configuration, and basic management tasks using Ansible.
*   **Security:** Implement a security-first approach, incorporating robust hardening, secure defaults, and proactive threat mitigation.
*   **Production Readiness:** Ensure stability, reliability, and operational excellence suitable for production environments.
*   **Maintainability:** Promote clarity, modularity, and comprehensive documentation to facilitate long-term maintenance and contribution.
*   **Idempotency:** Guarantee that all automation is idempotent, ensuring predictable and repeatable results.
*   **Modularity:** Enforce strict separation of concerns through single-responsibility Ansible roles.

## 2. Guiding Architectural Principles

The architecture adheres strictly to the [Guiding Principles outlined in the PRD](./PRD.md#🧭-guiding-principles), including:

1.  **Security First:** Security considerations permeate every layer, from host hardening to application configuration and secret management.
2.  **Automation & Idempotency:** All infrastructure and configuration changes are managed via Ansible playbooks designed for idempotency.
3.  **Production Readiness:** Focus on stability, error handling, and operational considerations.
4.  **Maintainability & Simplicity:** Prioritize clear, well-documented, and modular code.
5.  **Strict Modularity (Single Responsibility Roles):** Ansible roles have narrowly defined responsibilities.
6.  **Best Practices:** Adherence to industry best practices for Ansible, Docker, security, and IaC.
7.  **Comprehensive Documentation:** This document is part of a commitment to thorough documentation.
8.  **Minimize Technical Debt:** Proactive avoidance of shortcuts that compromise long-term health.
9.  **Robust Error Handling:** Playbooks are designed to fail predictably and safely.
10. **Idempotent State Management:** Configuration updates are handled gracefully.

## 3. Core Technologies & Justification

The following technologies form the foundation of this architecture:

*   **Ansible:** Chosen for its agentless architecture, strong community support, extensive module library (especially for system configuration, Docker, and cloud APIs), idempotency guarantees, and suitability for orchestrating complex deployments. It aligns well with the goal of readable, version-controlled IaC.
*   **Docker & Docker Compose:** Selected for containerizing Mailu and its dependencies. This provides process isolation, simplifies dependency management, ensures consistency across environments, and aligns with modern application deployment practices. Docker Compose simplifies the definition and management of the multi-container Mailu stack on a single node.
*   **Mailu:** The core open-source email server suite. Chosen for its container-native design, comprehensive feature set, and active development.
*   **Traefik:** A modern, container-aware reverse proxy. Chosen for its excellent Docker integration, automatic service discovery (though less critical in this single-node setup), and seamless Let's Encrypt integration (especially DNS-01 challenge), simplifying TLS management.
*   **CrowdSec:** An open-source, collaborative security automation tool. Chosen for its ability to detect and block malicious behavior targeting web and mail services, leveraging community-driven blocklists and local analysis. Its containerized deployment fits well within the architecture.
*   **Cloudflare API:** Leveraged for automated DNS record management. This is crucial for Mailu's operation (MX, SPF, DKIM, DMARC, MTA-STS, TLSRPT) and Traefik's DNS-01 challenge for Let's Encrypt, ensuring fully automated and secure TLS certificate provisioning without exposing port 80.
*   **Ansible Vault:** The mandated mechanism for encrypting secrets (API keys, passwords). Chosen for its tight integration with Ansible, ensuring secrets are stored securely within the version-controlled repository.
*   **Git & GitHub/GitLab (Implied):** Version control is fundamental. The entire configuration and automation codebase resides in Git, enabling change tracking, collaboration, and GitOps-like workflows. CI/CD (e.g., GitHub Actions) is intended for testing and automated deployment triggers.
*   **Jinja2:** Used by Ansible for templating configuration files, allowing dynamic generation based on variables.

## 4. System Components & Responsibilities

The system is composed of logical components, primarily implemented as Ansible roles, interacting with services running in Docker containers on the target host. Responsibilities align with the [Role Responsibilities defined in the PRD](./PRD.md#📋-role-responsibilities-illustrative-boundaries).

We can visualize the components and their interactions in three parts:

**4.1. Ansible Control Node Components**

This diagram shows the inputs and components involved on the Ansible control node during a playbook run.

```mermaid
graph LR
    subgraph "Ansible Control Node"
        A[User/CI] --> B(ansible-playbook);
        B -- Reads --> C(Inventory);
        B -- Reads --> D(Variables);
        B -- Reads --> E(Playbooks);
        B -- Uses --> F(Ansible Roles);
        D -- Includes --> G(group_vars/all.yml);
        D -- Includes --> H(domains/*.yml);
        D -- Includes --> I(vault/secrets.yml);
        F -- Tasks Interact With --> J((Target Server via SSH));
        B -- Optionally Notifies --> V((External: Ntfy Server));
        A -- Pushes/Pulls --> W((External: Git Repository));
        B -- Reads Code From --> W;
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#ccf,stroke:#333,stroke-width:2px
    style F fill:#ccf,stroke:#333,stroke-width:1px
    style J fill:#f9d,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5
    style V fill:#f9d,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5
    style W fill:#f9d,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5
```

**4.2. Target Server Components & Layers**

This diagram details the layers and components managed by Ansible on the target server.

```mermaid
graph TB
    J(Ansible Tasks via SSH) --> K;
    J --> L;
    J --> M;
    J --> N;
    J --> R;
    J -- Manages --> O;
    J -- Manages --> P;
    J -- Manages --> Q;
    J -- Manages --> S;

    subgraph "Target Server"
        direction TB

        subgraph "System Layer (Managed by Ansible Roles)"
            K(OS Packages / Common Setup);
            L(OS/SSH Hardening);
            M(Firewall - UFW/firewalld);
            N(Docker Engine & Compose);
        end

        subgraph "Application Layer (Managed by Ansible Roles via Docker Compose)"
            O(Traefik Container);
            P(CrowdSec Agent/Bouncer Containers);
            Q(Mailu Stack Containers);
        end

        subgraph "Configuration & State (Managed by Ansible)"
            R(Generated Config Files);
            S(Docker Volumes / Persistent Data);
        end

        N -- Runs/Manages --> O;
        N -- Runs/Manages --> P;
        N -- Runs/Manages --> Q;
        O -- Uses --> R;
        P -- Uses --> R;
        Q -- Uses --> R;
        Q -- Uses --> S;
        P -- Uses --> S;
        O -- Uses --> S;
    end

    style J fill:#ccf,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5
```

**4.3. High-Level Interaction Overview**

This diagram shows the primary interactions between the main actors and external services.

```mermaid
graph TD
    A[Ansible Control Node] -- SSH --> B[Target Server];
    A -- Manages DNS via API --> C[External: Cloudflare API];
    B -- Traefik Requests Certs --> D[External: Let's Encrypt API];
    B -- Traefik uses DNS-01 --> C;
    A -- Reads Code / User Commits --> E[External: Git Repository];
    A -- Optionally Notifies --> F[External: Ntfy Server];

    style A fill:#ccf,stroke:#333,stroke-width:2px
    style B fill:#9cf,stroke:#333,stroke-width:2px
    style C fill:#f9d,stroke:#333,stroke-width:2px
    style D fill:#f9d,stroke:#333,stroke-width:2px
    style E fill:#f9d,stroke:#333,stroke-width:2px
    style F fill:#f9d,stroke:#333,stroke-width:2px
```

**4.4. Detailed Mailu Container Components**

The Mailu stack consists of several specialized containers that work together to provide complete email services. Understanding their interactions is crucial:

```mermaid
graph TD
    subgraph "Mailu Docker Stack"
        FRONT[front: Nginx Reverse Proxy]
        ADMIN[admin: Web Admin Interface]
        IMAP[imap: Dovecot IMAP Server]
        SMTP[smtp: Postfix MTA]
        ANTISPAM[antispam: Rspamd]
        ANTIVIRUS[antivirus: ClamAV]
        WEBMAIL[webmail: Roundcube]
        REDIS[redis: Redis DB]
        
        FRONT --> ADMIN
        FRONT --> WEBMAIL
        SMTP --> ANTISPAM
        SMTP --> ANTIVIRUS
        SMTP -- Delivers mail --> IMAP
        ADMIN -- Manages accounts --> IMAP
        WEBMAIL -- Reads/sends mail --> IMAP
        ANTISPAM -- Uses --> REDIS
        ADMIN -- Uses --> REDIS
    end

    TRAEFIK[Traefik Reverse Proxy] --> FRONT
    INTERNET[Internet] -- SMTP/Port 25 --> SMTP
    INTERNET -- IMAPS/Port 993 --> IMAP
    INTERNET -- Submission/Port 587 --> SMTP
```

**4.5. Role Implementation Details**

This section provides specific implementation details for each role, including required variables, key templates, task execution order, and error handling expectations.

| Role | Required Variables | Key Templates | Critical Task Order | Error Handling |
|------|-------------------|--------------|-------------------|---------------|
| **common** | `timezone` (default: UTC) | N/A | Check prerequisites → Install packages → Configure timezone | Fail fast on package installation failures |
| **hardening** | `ssh_allowed_users`, `ssh_port` (default: 22) | `/etc/ssh/sshd_config.j2`, `/etc/issue.net.j2` | Configure sysctl → Configure SSH → Set file permissions → Apply security policies | Fail if SSH configuration can't be applied |
| **firewall** | `allowed_ports` (array of port/protocol) | N/A | Install firewall software → Configure default deny → Add required rules → Enable firewall | Use `block/rescue` for firewall activation to prevent lockout |
| **docker_base** | `docker_version`, `docker_compose_version` | `daemon.json.j2` | Add Docker repo → Install packages → Configure daemon → Install Docker Compose | Validate Docker service is running after install |
| **dns_management** | `cloudflare_api_token` OR (`cloudflare_api_email` AND `cloudflare_api_key`) | N/A | Validate credentials → Read domain configs → Create/update DNS records | Fail if credentials invalid; retry API operations with exponential backoff |
| **traefik** | `traefik_version`, `traefik_acme_email` | `traefik.yml.j2`, `traefik_dynamic.yml.j2` | Create directories → Generate config → Start container → Verify health | Wait for container to be healthy before proceeding |
| **crowdsec** | `crowdsec_version`, `crowdsec_collections` (array) | `crowdsec_acquis.yaml.j2`, `crowdsec_collections.yaml.j2` | Create directories → Configure collections → Start agent → Configure bouncers | Validate agent connectivity before bouncer setup |
| **mailu** | `mailu_version`, `mailu_base_dir`, domain configuration from `domains/*.yml` | `mailu.env.j2`, `docker-compose.yml.j2` | Validate domains → Create directories → Generate configs → Pull images → Start containers | Use health checks to verify services start correctly |
| **mail_security** | Domain configuration from `domains/*.yml` | `mta-sts.yml.j2` | Generate DKIM keys → Configure SPF/DMARC → Setup MTA-STS | Coordinate with dns_management role for record creation |
| **domain_management** | Domain configuration from `domains/*.yml` | N/A | Validate domain formats → Apply domain settings via Mailu API | Idempotent operations (check-then-change) |
| **user_management** | User definitions from `domains/*.yml` | N/A | Validate user formats → Create/update users via Mailu API → Apply permissions | Idempotent operations (check-then-change) |
| **backup** | `backup_target_type`, target-specific credentials | `backup_script.sh.j2`, `restore_script.sh.j2` | Install tools → Configure credentials → Generate scripts → Schedule jobs | Verify backup destination accessibility |
| **health_check** | `health_notification_method` (optional) | `health_check.py.j2` | Check system resources → Test mail services → Verify TLS → Send notifications | Non-blocking failures (report but don't halt playbook) |
| **monitoring** | `monitoring_target` (e.g., Prometheus) | Various exporter configs | Install exporters → Configure metrics → Configure alerts → Verify connectivity | Ensure metrics endpoints are accessible |

**Implementation Standards:**
* **File Permissions:** Configuration files containing secrets: 0640, TLS certificates/keys: 0600, Scripts: 0750, Data directories: 0750
* **Owner/Group:** All files should be owned by `{{ target_user }}:{{ target_user }}` unless specific service requirements dictate otherwise
* **Task Naming:** All tasks must have clear, descriptive names (e.g., "Install required system packages", not "Install packages")
* **Variable References:** Role-specific variables should be prefixed with role name (e.g., `mailu_version`, `traefik_acme_email`) 
* **Idempotency:** All tasks must be idempotent, using appropriate `creates`, `changed_when`, and state checks
* **Module Preference:** Always prefer Ansible modules over shell commands; use shell only when absolutely necessary

## 5. Interaction & Data Flows

### 5.1. Deployment Flow (GitOps-like)

```mermaid
sequenceDiagram
    participant User
    participant GitRepo as Git Repository
    participant CICD as CI/CD (GitHub Actions)
    participant Ansible as Ansible Control Node
    participant Target as Target Server

    User->>+GitRepo: Commit config change (e.g., domains/*.yml, group_vars/all.yml)
    GitRepo->>+CICD: Trigger pipeline (on push/merge)
    CICD->>+Ansible: Checkout code
    CICD->>Ansible: Run Linting/Static Analysis (Optional)
    CICD->>Ansible: Run Molecule Tests (Optional, Roadmap)
    CICD->>Ansible: Execute `ansible-playbook site.yml`
    Ansible->>+Target: Connect via SSH
    Ansible->>Target: Execute Roles/Tasks (Idempotent)
    Target->>Target: Apply OS/Firewall changes
    Target->>Target: Generate Config Files (docker-compose.yml, mailu.env, etc.)
    Ansible->>Cloudflare: Manage DNS Records (via dns_management role)
    Target->>Target: Run `docker compose up -d`
    Target->>DockerHub: Pull Images (if needed)
    Target->>Target: Start/Recreate Containers
    Target->>Traefik: Apply new config / Cert Request
    Traefik->>LetsEncrypt: Request/Renew Certs (DNS-01)
    Traefik->>Cloudflare: Create TXT records for DNS-01
    Ansible-->>-CICD: Report Success/Failure
    CICD-->>-User: Notify Result (Optional)
    deactivate Target
```
*This flow emphasizes managing infrastructure state through Git and automated Ansible execution.*

### 5.2. Incoming Mail Flow (Simplified)

```mermaid
graph LR
    A[Internet MTA] -- SMTP (25/587) --> B(Firewall);
    B -- Allows --> C(Host Port Mapping);
    C -- Directs --> D(Mailu SMTP Container);
    D -- Anti-spam check --> E(Rspamd Container);
    D -- Virus scan --> F(ClamAV Container);
    D -- Delivers --> G(Dovecot Container);
    G -- Stores mail --> H(Persistent Mail Volume);
```
*Note: SMTP traffic typically bypasses Traefik. Ports are exposed directly from the Mailu SMTP container via Docker Compose port mapping, protected by the host firewall (`firewall` role).*

### 5.3. Incoming HTTP/S Flow (Webmail/Admin)

```mermaid
graph LR
    A[User Browser] -- HTTPS (443) --> B(Firewall);
    B -- Allows --> C(Traefik Container);
    C -- TLS Termination & Routing --> D(Mailu Front Container);
    D -- Routes to webmail.domain --> E(Webmail Container);
    D -- Routes to webmailadmin.domain --> F(Admin Container);
    E -- Accesses mail via --> G(Dovecot Container);
    F -- Manages accounts in --> G;
    G -- Reads/writes --> H(Persistent Mail Volume);
```
*Traefik handles TLS using Let's Encrypt certificates (obtained via DNS-01) and routes requests based on hostname to the appropriate Mailu web interface.*

### 5.4. User & Domain Management Flow

```mermaid
sequenceDiagram
    participant User
    participant GitRepo as Git Repository
    participant Ansible
    participant MailuAdmin as Mailu Admin Container
    participant DNS as Cloudflare DNS

    User->>GitRepo: Update domains/*.yml with new domain/users
    User->>GitRepo: Update vault/secrets.yml with passwords
    GitRepo->>Ansible: Trigger ansible-playbook site.yml
    Ansible->>DNS: Create/update DNS records for domain
    Ansible->>MailuAdmin: Create/update domain configuration
    Ansible->>MailuAdmin: Create/update user accounts
    
    Note over Ansible,MailuAdmin: Updates are made via Mailu's flask API
    
    MailuAdmin-->>User: Confirmation of changes
    
    Note over User,DNS: Alternative: Future manage_users.yml and manage_domains.yml playbooks
```

*This flow shows the GitOps-based approach to user and domain management, which aligns with the principle of maintaining configuration as code and applying changes idempotently.*

### 5.5. Service Deployment and Dependency Order

Proper sequencing of deployment tasks and service startup is critical for ensuring system integrity and successful operation. The following order must be strictly observed during deployment:

```mermaid
graph TD
    A[System Preparation] --> B[Docker Installation]
    B --> C[DNS Record Management]
    C --> D[Traefik Deployment]
    D --> E[CrowdSec Deployment]
    E --> F[Mailu Stack Deployment]
    F --> G[Post-deployment Configuration]
    G --> H[Health Checks]
    
    subgraph "System Preparation"
    A1[common role: OS packages] --> A2[hardening role: OS/SSH security]
    A2 --> A3[firewall role: Network security]
    end
    
    subgraph "Docker Installation"
    B1[docker_base role: Install Docker Engine] --> B2[docker_base role: Install Docker Compose]
    end
    
    subgraph "DNS Record Management"
    C1[dns_management role: Create MX records] --> C2[dns_management role: Create service records]
    C2 --> C3[dns_management role: Create security records]
    end
    
    subgraph "Mailu Stack Deployment"
    F1[Create volumes] --> F2[Generate configs]
    F2 --> F3[Start core containers]
    F3 --> F4[Start dependent containers]
    end
    
    A --- A1
    B --- B1
    C --- C1
    F --- F1
```

**Critical Dependency Chains:**

1. **OS Security Chain:**
   - `common` → `hardening` → `firewall`
   - System packages must be installed before hardening can be applied
   - Firewall must be configured after hardening to ensure required ports for SSH remain accessible

2. **Docker Chain:**
   - `docker_base` must complete before any container deployment
   - Docker daemon configuration must be validated before proceeding

3. **DNS Chain:**
   - `dns_management` must be applied before attempting Traefik deployment
   - DNS records must be created/verified before Let's Encrypt certificate issuance

4. **Network Services Chain:**
   - Traefik must be healthy and accessible before Mailu web services are launched
   - CrowdSec should be operational before exposing services to protect against initial attacks

5. **Mailu Container Chain:**
   - Internal Mailu container dependencies: Redis → Front → Admin → Other Services
   - Container health checks must pass before proceeding with post-deployment configuration

**Implementation Requirements:**

1. Ansible tasks must enforce the correct dependency order through role dependencies (`meta/main.yml`) and explicit `depends_on` in Docker Compose templates
2. Health checks must validate critical component readiness before proceeding to dependent components
3. Playbook tasks must use `wait_for` to ensure required network services are accessible
4. When updating existing deployments, prioritize infrastructure changes (e.g., DNS, firewall) before application changes

## 6. Deployment Strategy & Configuration Management

*   **Primary Method:** Configuration changes (domains, users, global settings) are made by editing YAML files (`group_vars/all.yml`, `domains/*.yml`) and Vault secrets (`vault/secrets.yml`) in the Git repository.
*   **Applying Changes:** Changes are applied by re-running the main `ansible-playbook playbooks/site.yml`. This playbook orchestrates all roles idempotently, ensuring the target server converges to the desired state defined in Git.
*   **MVP Operations:** As per the PRD, initial domain/user/config management relies solely on editing files and re-running `site.yml`. Dedicated management playbooks are a roadmap item.
*   **Secrets:** Ansible Vault is mandatory for all sensitive data. The vault password must be supplied during playbook execution (e.g., via `--ask-vault-pass` or environment variables in CI).
*   **Version Control:** All code, configuration (except secrets' plaintext values), and documentation are stored in Git.
*   **Configuration Validation:** Before applying changes, Ansible performs validation of domain configurations and user settings to ensure consistency and prevent errors.
*   **State Management:** The architecture maintains a clean separation between:
    * **Declarative Configuration:** YAML files and templates that define the desired state
    * **Runtime State:** Persisted in Docker volumes and container state
    * **Secrets:** Encrypted at rest, decrypted only during deployment

### 6.1. Variable Schema Examples

To ensure clarity and consistency across implementations, the following examples illustrate the expected structure for key variable files:

**Example `group_vars/all.yml`:**
```yaml
# Base Configuration
mailu_version: "1.9.2"                # Version of Mailu to deploy
mailu_base_dir: "/opt/mailu"          # Root directory for Mailu installation
target_user: "mailadmin"              # Non-root user who will own Mailu files
timezone: "UTC"                       # System timezone configuration

# Infrastructure Configuration
traefik_version: "2.9.8"              # Version of Traefik to deploy
crowdsec_version: "1.5.2"             # Version of CrowdSec to deploy
docker_version: "24.0.7"              # Version of Docker to install
docker_compose_version: "2.21.0"      # Version of Docker Compose to install

# Security Configuration
ssh_port: 22                          # SSH port (can be changed for security)
ssh_allowed_users:                    # Users allowed to SSH to the server
  - "mailadmin"
  - "{{ ansible_user }}"

# TLS/DNS Configuration
traefik_acme_email: "admin@example.com"  # Email for Let's Encrypt registration
cloudflare_api_email: "admin@example.com" # Email for Cloudflare API (if using Global API Key)
# Note: API tokens/keys must be in vault/secrets.yml

# Mail Security Configuration
mail_dmarc_policy: "reject"           # DMARC policy (none, quarantine, reject)
mail_spf_policy: "-all"               # SPF policy (~all or -all, -all is stricter)
mail_dkim_key_size: 2048              # Size of DKIM keys to generate

# Resource Limits
mailu_smtp_memory: "512M"             # Memory limit for SMTP container
mailu_smtp_cpu: "0.5"                 # CPU limit for SMTP container
mailu_imap_memory: "1G"               # Memory limit for IMAP container
mailu_imap_cpu: "1.0"                 # CPU limit for IMAP container
```

**Example `domains/example.com.yml`:**
```yaml
# Basic Domain Configuration
domain: example.com                   # Primary domain name
hostname: mail.example.com            # Mail server hostname (must have A record)
webmail: webmail.example.com          # Webmail access URL
admin: admin.example.com              # Admin interface URL

# Domain-Specific Settings (Optional)
dkim_selector: "mail"                 # DKIM selector (default: "mail")
dmarc_rua: "mailto:abuse@example.com" # DMARC aggregate report email
enable_autoconfig: true               # Enable email client autoconfig

# User Configuration
users:
  - name: admin                       # Username (becomes admin@example.com)
    password_var: vault_admin_example_com  # Variable name in vault/secrets.yml
    admin: true                       # Admin privileges in Mailu
  
  - name: support
    password_var: vault_support_example_com
    quota_bytes: 2147483648           # Mailbox quota in bytes (2GB here)
    catchall: true                    # This user receives mail for non-existent addresses
    
  - name: info
    password_var: vault_info_example_com
    forward: "external@othercompany.com"  # Forward emails to external address
```

**Example `vault/secrets.yml` (before encryption):**
```yaml
# User Passwords
vault_admin_example_com: "SecureAdminPassword123!"
vault_support_example_com: "AnotherSecurePassword456!"
vault_info_example_com: "YetAnotherSecurePassword789!"

# API Credentials (choose ONE authentication method)
# Option 1: Cloudflare API Token (preferred)
cloudflare_api_token: "0123456789abcdef0123456789abcdef01234567"

# Option 2: Cloudflare Global API Key (legacy)
# cloudflare_api_key: "0123456789abcdef0123456789abcdef01234"

# Backup Credentials (if using backup role)
backup_s3_access_key: "AKIAIOSFODNN7EXAMPLE"
backup_s3_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Implementation Note:** All sensitive values **MUST** be stored in `vault/secrets.yml` and encrypted using Ansible Vault. The examples above show unencrypted values for clarity only.

### 6.2. Template Structure Standards

To ensure templates are clear, maintainable, and generate consistent configurations, all Jinja2 templates should follow these standards:

**Formatting & Documentation:**
* Use comments to document non-obvious logic: `{# This section configures TLS settings #}`
* For conditional blocks spanning multiple lines, add end comments to improve readability:
  ```jinja
  {% if use_secure_tls %}
  # Configuration for secure TLS
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...';
  {% endif %}{# endif use_secure_tls #}
  ```
* Use consistent indentation (2 spaces) within templates
* Include a header comment in each template explaining its purpose and key variables used

**Variables & Logic Management:**
* Prefer simple conditionals in templates; move complex logic to tasks or filters
* Use default filters for variables that might be undefined: `{{ smtp_port | default(25) }}`
* Set variable precedence clearly: role defaults → group_vars → host_vars → extra vars
* Use namespacing to avoid variable collisions: `{{ mailu_admin_user }}` not just `{{ admin_user }}`

**Security Best Practices:**
* Never include passwords or secrets directly in templates; use variables from Vault
* Sanitize inputs for variables that populate shell commands or paths
* For templates that generate configuration containing secrets, ensure outputs have restrictive permissions

**Example Template Structure (`docker-compose.yml.j2`):**
```jinja
{# 
  docker-compose.yml.j2 - Generates Docker Compose configuration for Mailu
  
  Important variables:
  - mailu_version: Mailu version to deploy
  - mailu_base_dir: Base directory for Mailu data
  - domains: List of configured mail domains
#}

version: '3.8'

services:
  # Core Mailu Services
  front:
    image: mailu/nginx:{{ mailu_version }}
    restart: unless-stopped
    {% if container_resource_limits | default(true) %}
    # Resource limits
    mem_limit: {{ mailu_front_memory | default('256M') }}
    cpus: {{ mailu_front_cpu | default(0.5) }}
    {% endif %}{# endif container_resource_limits #}
    volumes:
      - "{{ mailu_base_dir }}/certs:/certs"
      - "{{ mailu_base_dir }}/data:/data"
      
  # More services...
  
  {% for domain in domains %}
  {# Generate domain-specific configurations if needed #}
  {% endfor %}
```

**Implementation Notes:**
* Templates must be idempotent - running them multiple times with the same inputs should produce identical outputs
* Templates should fail gracefully with helpful errors for missing required variables
* Complex templates should be broken into smaller, more manageable pieces (e.g., via includes)
* Use environment-specific configuration blocks sparingly; prefer passing different variables

## 7. Security Architecture

Security is layered throughout the architecture, adhering to the "Security First" principle:

*   **Network Security:**
    *   **Firewall:** The `firewall` role configures host-level firewall rules (UFW/firewalld) to restrict ingress traffic strictly to necessary ports (SSH, HTTPS, SMTP, IMAP/S, Submission) as defined in the PRD. Egress is typically less restricted but can be tightened if required.
    *   **Traefik:** Acts as the sole entrypoint for HTTP/S, reducing the attack surface exposed directly by Mailu web components. Handles TLS termination with strong configurations (Mozilla Intermediate target). Uses DNS-01 challenge, avoiding the need to expose port 80.
    *   **Docker Networks:** Docker's internal networks provide segmentation between containers. Mailu internal communication happens on a dedicated network.
    *   **CrowdSec Integration:** Provides active protection against brute force, bot scanning, and other malicious activities targeting the mail server.

*   **Host Security:**
    *   **Hardening:** The `hardening` role applies OS-level security settings (sysctl) and SSH lockdown (key-only auth, disabled root login, specific allowed users, banner) as per PRD requirements.
    *   **Regular Updates:** OS package updates should be applied regularly (potentially automated via a dedicated Ansible role or manual playbook run).
    *   **Minimal Attack Surface:** Principles of least privilege are applied throughout the system, with only required ports and services exposed.

*   **Application Security:**
    *   **Mailu:** Relies on Mailu's internal security features (authentication, antispam, antivirus). Configuration is managed securely via Ansible, applying secure defaults.
    *   **CrowdSec:** Provides active threat detection and blocking based on logs from Traefik and potentially Mailu. The `crowdsec` role manages its deployment and configuration.
    *   **DNS Security:** Automated setup of SPF, DKIM, DMARC, MTA-STS, and TLSRPT via the `dns_management` role enhances email deliverability and spoofing protection.
    *   **Email Authentication:** Comprehensive implementation of SPF, DKIM, and DMARC, properly configured and tested to prevent email spoofing and improve deliverability.

*   **Secret Management:**
    *   **Ansible Vault:** Strictly enforced for all secrets (API keys, user passwords). Secrets are encrypted at rest in the Git repository.
    *   **Transmission:** Secrets are decrypted by Ansible on the control node during playbook execution and securely transmitted to the target server via SSH, often used to populate environment variables for containers or generate config files with appropriate permissions. `no_log: true` is used on sensitive tasks.
    *   **Credential Isolation:** Different types of credentials (API keys, user passwords, administrative access) are carefully segregated and managed with appropriate access controls.

*   **Data Security:**
    *   **TLS:** Mandatory TLS for HTTP (via Traefik/Let's Encrypt) and encouraged/enforced for mail protocols (via Mailu configuration).
    *   **Permissions:** Ansible roles ensure appropriate file permissions for generated configurations and persistent data volumes, applying the principle of least privilege.
    *   **Backup Encryption:** Backups of sensitive data are always encrypted, both in transit and at rest.

### 7.5. File Permission Standards

To enforce security best practices and the principle of least privilege, all files and directories deployed or managed by Ansible must adhere to the following permission standards:

| File/Directory Type | Permission (Octal) | Owner:Group | Justification |
|---------------------|-------------------|-------------|---------------|
| Configuration files (no secrets) | 0644 | `{{ target_user }}:{{ target_user }}` | Readable for debugging, not writable by others |
| Configuration files with secrets | 0640 | `{{ target_user }}:{{ target_user }}` | Prevents other users from reading sensitive data |
| TLS certificates and keys | 0600 | `{{ target_user }}:{{ target_user }}` | Maximum protection for cryptographic material |
| Shell scripts | 0750 | `{{ target_user }}:{{ target_user }}` | Executable but only by owner/group |
| Data directories | 0750 | `{{ target_user }}:{{ target_user }}` | Prevents other users from listing contents |
| Log directories | 0755 | `{{ target_user }}:syslog` | Allows log writing by services |
| Backup scripts | 0700 | `{{ target_user }}:{{ target_user }}` | Contains potentially sensitive operations |

**Implementation Requirements:**

1. All roles that create or modify files must explicitly set appropriate permissions using the `mode` parameter
2. Recursive permission application must be used when securing directories with sensitive contents
3. Files containing secrets (API tokens, passwords, keys) must never have permissions greater than 0640
4. Temporary files containing sensitive information must be secured and cleaned up using `block/always` constructs
5. When using templates to generate files containing sensitive data, the resulting files must have appropriate permissions set

**Common Implementation Pattern:**

```yaml
- name: Ensure configuration directory exists with proper permissions
  ansible.builtin.file:
    path: "{{ mailu_base_dir }}/config"
    state: directory
    mode: "0750"
    owner: "{{ target_user }}"
    group: "{{ target_user }}"

- name: Generate configuration file from template
  ansible.builtin.template:
    src: mailu.env.j2
    dest: "{{ mailu_base_dir }}/mailu.env"
    mode: "0640"
    owner: "{{ target_user }}"
    group: "{{ target_user }}"
```

## 8. Scalability & Resilience

*   **Scalability (MVP):** The current architecture targets a **single-node deployment**. Scalability is limited to the vertical resources (CPU, RAM, Disk I/O) of the target server. Horizontal scaling is explicitly a non-goal for the MVP. Future roadmap items may explore multi-node possibilities.

*   **Resilience (MVP):**
    *   **Containerization:** Docker provides process isolation; failure of one container (e.g., ClamAV) may not bring down the entire stack. Docker Compose restart policies (`restart: unless-stopped`) ensure services attempt to recover from crashes.
    *   **Health Checks:** Docker Compose health checks (defined in `docker-compose.yml.j2`) allow Docker to identify and potentially restart unhealthy containers. The `health_check.yml` playbook provides an external check.
    *   **Idempotency:** Ansible's idempotency ensures that re-running the playbook can correct configuration drift or recover from partial failures during deployment.
    *   **Automated Recovery:** Services are configured to automatically restart after failures or server reboots.
    *   **Backup/Recovery:** A robust backup and tested recovery strategy (defined as a critical roadmap item in the PRD) is essential for true resilience against data loss or catastrophic server failure.

*   **Resource Management:**
    *   **Container Resource Limits:** Docker Compose configurations include appropriate CPU and memory limits to prevent resource exhaustion.
    *   **Storage Monitoring:** Health checks include monitoring of available disk space to prevent outages due to storage exhaustion.
    *   **Log Rotation:** Appropriate log rotation policies are implemented to prevent disk space issues from growing log files.

## 9. Testability

Testability is considered crucial for maintaining quality and reliability:

*   **Ansible Lint:** Code should adhere to `ansible-lint` rules enforced via `.ansible-lint` configuration for static analysis and best practice checks. CI pipelines should enforce linting.
*   **Molecule (Roadmap):** The PRD mandates implementing `molecule` testing for core roles. This allows testing roles in isolation using Docker containers, verifying installation, idempotency, and basic functionality across different scenarios or distributions.
*   **CI Integration Tests (Roadmap):** The roadmap includes expanding CI tests to perform end-to-end checks like sending/receiving emails and verifying TLS configuration.
*   **Modularity:** The single-responsibility role design inherently improves testability by allowing roles to be tested independently.
*   **Health Checks:** The `health_check.yml` playbook provides a mechanism for validating the system's operational state, including:
    * SMTP connectivity tests
    * IMAP connectivity tests
    * Web interface accessibility
    * DNS record verification
    * Certificate validation
    * Disk space monitoring

## 10. Error Handling & Resilience Strategies

The architecture implements several strategies for robust error handling and operational resilience:

*   **Ansible Error Handling:**
    *   **Fail Fast:** Critical errors (e.g., inability to connect to the target server, missing prerequisites) cause immediate failure with clear error messages.
    *   **Block/Rescue:** Complex task sequences use Ansible's `block/rescue/always` structure to ensure proper cleanup and error handling.
    *   **Conditional Retries:** Tasks that may experience transient failures (e.g., network operations) implement appropriate retry mechanisms.
    *   **Validation:** Input parameters are validated before use to prevent configuration errors.

*   **Container Resilience:**
    *   **Health Checks:** All critical containers include Docker health checks that verify their operational status.
    *   **Restart Policies:** Containers use appropriate restart policies (`unless-stopped` for most services) to recover from failures.
    *   **Dependency Management:** Container startup order and dependencies are properly managed to prevent cascading failures during startup.

*   **Service Recovery:**
    *   **Automated Recovery:** The system is designed to recover automatically from most service disruptions, including server restarts.
    *   **Playbook Idempotency:** All Ansible roles and playbooks are designed to be safely re-runnable to recover from partial failures or configuration drift.
    *   **Health Check Playbook:** The dedicated `health_check.yml` playbook can diagnose and potentially remediate issues.

*   **Notification & Alerting:**
    *   **Playbook Notifications:** Ansible playbooks can send notifications (e.g., via Ntfy) upon completion or failure.
    *   **Service Alerts:** Health checks can trigger alerts for service disruptions.
    *   **Monitoring Integration:** (Roadmap) Integration with monitoring systems for more sophisticated alerting.

### 10.1. Error Handling Specifications

This table provides specific guidance on expected behavior in common failure scenarios:

| Scenario | Expected Behavior | Recovery Method |
|----------|-------------------|----------------|
| **DNS API Authentication Failure** | Fail immediately with clear error message indicating Cloudflare credentials issue | Fix credentials in vault/secrets.yml, re-run playbook |
| **Docker Service Not Starting** | Retry 3 times with 10s delay, then fail with diagnostics output | Check Docker logs, fix system issue, re-run playbook |
| **Mail Domain Already Exists** | Update existing domain with new settings from domains/*.yml file | N/A - handled automatically via idempotent operations |
| **Certificate Acquisition Failure** | Fail with detailed error from Let's Encrypt/Cloudflare | Fix DNS settings or Let's Encrypt access, re-run playbook |
| **Network Connectivity Issues** | For API calls: retry with exponential backoff (3 attempts)<br>For package installation: retry once after apt update | Fix network, re-run playbook |
| **Disk Space Low** | Check before critical operations, fail with clear warning if below threshold (e.g., < 1GB) | Free disk space, re-run playbook |
| **SSH Connection Lost During Deployment** | Ansible will fail clearly, state may be partial | Re-run playbook (idempotency will continue from failure point) |
| **Required Variable Missing** | Validate early, fail with clear message about which variable is required | Add missing variable, re-run playbook |
| **Container Startup Failure** | Health check on critical containers, timeout after 60s, detailed error from container logs | Fix issue based on logs, re-run playbook |
| **User Creation API Failure** | Report specific HTTP status code and response body, retry once, then fail | Fix Mailu admin container, re-run playbook |
| **Vault Password Missing** | Immediate failure with clear instruction on how to provide vault password | Provide vault password via --ask-vault-pass or env variable |
| **Docker Image Pull Failure** | Retry once with full error output, validate connectivity to Docker Hub | Check internet connectivity, Docker Hub status, re-run playbook |
| **Role Dependency Failure** | Fail fast with clear indication of which role dependency failed | Fix underlying role first, re-run playbook |

**Implementation Patterns:**

```yaml
# Sample implementation of retry pattern for network operations
- name: Create DNS records via Cloudflare API
  cloudflare_dns:
    # [parameters]
  register: cf_result
  retries: 3
  delay: 5
  until: cf_result is succeeded
  failed_when: cf_result is failed and cf_result.attempts|default(1) >= 3
  
# Sample implementation of validation pattern
- name: Validate required variables
  assert:
    that:
      - mailu_base_dir is defined
      - target_user is defined
    fail_msg: "Required variable(s) missing: ensure mailu_base_dir and target_user are defined"
    
# Sample implementation of block/rescue pattern
- name: Configure and start firewall
  block:
    - name: Apply firewall rules
      # [firewall rule tasks]
    - name: Enable firewall service
      # [enable task]
  rescue:
    - name: Revert to safe defaults
      # [reversion task]
    - name: Fail with clear message
      fail:
        msg: "Failed to configure firewall. SSH access may be lost if rules were partially applied."
```

## 11. Backup & Recovery Architecture

The backup and recovery system is designed as a critical component of the overall architecture, ensuring data durability and disaster recovery capabilities:

```mermaid
graph TD
    subgraph "Ansible Control Node"
        BP[backup.yml Playbook]
        RP[restore.yml Playbook]
    end

    subgraph "Target Server"
        BR[Backup Role Tasks]
        BS[Backup Scripts]
        MC[Mailu Containers]
        MV[Mailu Volumes]
        TC[Traefik Config/Certs]
        CC[CrowdSec State]
        AC[Ansible Config Files]
    end
    
    subgraph "Backup Destinations"
        S3[AWS S3/Compatible Storage]
        RS[Remote SFTP/SSH Server]
        B2[Backblaze B2]
    end
    
    BP -- Executes --> BR
    BR -- Generates --> BS
    BS -- Backs up --> MV
    BS -- Backs up --> TC
    BS -- Backs up --> CC
    BS -- Backs up --> AC
    
    BS -- Stores to --> S3
    BS -- Stores to --> RS
    BS -- Stores to --> B2
    
    RP -- Triggers --> BS
    BS -- Restores from --> S3
    BS -- Restores from --> RS
    BS -- Restores from --> B2
    BS -- Restores to --> MV
    BS -- Restores to --> TC
    BS -- Restores to --> CC
    BS -- Restores to --> AC
```

**Key Features:**

*   **Comprehensive Coverage:** Backups include all critical data:
    *   Mailu email data (mail storage, user databases)
    *   Configuration files (mailu.env, docker-compose.yml)
    *   TLS certificates (Traefik state)
    *   CrowdSec state data
    *   Ansible configuration (for reference)

*   **Multiple Strategies:**
    *   **File-based Sync:** Using rsync for efficient incremental backups to SFTP/SSH destinations
    *   **Deduplicating Backup Tools:** Support for Restic or BorgBackup for efficient, encrypted backups
    *   **S3-compatible Storage:** Backing up to AWS S3, Backblaze B2, or other compatible object storage

*   **Security Considerations:**
    *   **Encryption:** All backups are encrypted, both in transit and at rest
    *   **Access Control:** Backup destinations use strict access control (IAM policies for S3, key-only authentication for SSH)
    *   **Credential Security:** Backup credentials are stored in Ansible Vault

*   **Scheduling & Retention:**
    *   **Configurable Schedule:** Backups run on a configurable schedule (typically daily)
    *   **Retention Policy:** Tiered retention policy (e.g., 7 daily, 4 weekly, 3 monthly)
    *   **Storage Lifecycle:** For cloud storage, integration with lifecycle policies for cost-effective long-term storage

*   **Recovery Process:**
    *   **Tested Recovery:** Recovery procedures are documented and tested
    *   **Complete Restoration:** The `restore.yml` playbook can perform a complete recovery
    *   **Selective Recovery:** Support for restoring specific components or data (e.g., individual mailboxes)

*   **Validation & Monitoring:**
    *   **Backup Validation:** Automated verification of backup integrity
    *   **Notification:** Success/failure notifications via integration with Ntfy or other channels
    *   **Monitoring Integration:** (Roadmap) Integration with monitoring systems for backup status tracking

## 12. Monitoring & Alerting Architecture

The monitoring and alerting system is designed to provide visibility into the health, performance, and security of the iac-mailu deployment:

```mermaid
graph TD
    subgraph "Target Server"
        NE[Node Exporter]
        ME[Mailu Exporters]
        TE[Traefik Metrics]
        CE[CrowdSec Metrics]
        HC[Health Check Scripts]
    end

    subgraph "Monitoring Infrastructure (External)"
        P[Prometheus]
        G[Grafana]
        A[Alertmanager]
        N[Ntfy Server]
    end
    
    NE -- Exposes metrics --> P
    ME -- Exposes metrics --> P
    TE -- Exposes metrics --> P
    CE -- Exposes metrics --> P
    HC -- Sends health status --> P
    
    P -- Feeds data --> G
    P -- Triggers alerts --> A
    A -- Sends notifications --> N
    
    style P fill:#f96,stroke:#333,stroke-width:2px
    style G fill:#f96,stroke:#333,stroke-width:2px
    style A fill:#f96,stroke:#333,stroke-width:2px
```

**Key Features:**

*   **Core Metrics Collection:**
    *   **System Metrics:** CPU, memory, disk, network via Node Exporter
    *   **Container Metrics:** Resource usage per container
    *   **Application-Specific Metrics:** Mail queue length, delivery rates, etc.
    *   **Security Metrics:** Login attempts, blocked IPs from CrowdSec

*   **Health Checks:**
    *   **Service Availability:** Regular checks for all critical services (SMTP, IMAP, HTTP)
    *   **End-to-End Tests:** Sending/receiving test emails to verify complete mail flow
    *   **Certificate Monitoring:** Alerting on upcoming certificate expirations
    *   **Disk Space:** Monitoring of available storage space on mail volumes

*   **Alerting Channels:**
    *   **Ntfy Integration:** Push notifications for alerts and playbook results
    *   **Email Alerts:** Critical alerts sent via email (assuming mail service is operational)
    *   **Webhook Support:** Integration with other notification systems

*   **Visualization:**
    *   **Grafana Dashboards:** Pre-configured dashboards for system health, mail metrics, and security events
    *   **Status Page:** (Roadmap) Simple health status overview accessible via web

*   **Implementation Notes:**
    *   The monitoring role primarily configures exporters and agents on the target server
    *   External monitoring infrastructure (Prometheus, Grafana, Alertmanager) is assumed to exist separately
    *   For simpler setups, the health check playbook can provide basic monitoring without external infrastructure

## 13. Security Threat Model & Mitigations

The security architecture addresses specific threats relevant to email infrastructure:

| Threat | Impact | Mitigation |
|--------|--------|------------|
| **Email Spoofing / Phishing** | Reputation damage, recipient security | Strict SPF (`-all`), DKIM signing, DMARC enforcement (`p=reject`), properly configured in `mail_security` role |
| **Brute Force Attacks** | Unauthorized access | CrowdSec detection and blocking, strong password requirements, rate limiting |
| **TLS Downgrade** | Privacy breach | Secure TLS configuration in Traefik and Mailu, MTA-STS policy |
| **DNS Hijacking** | Service disruption, MitM | DNSSEC (where supported), secure API tokens for Cloudflare, monitoring for unexpected DNS changes |
| **Data Exfiltration** | Privacy breach | Encrypted backups, restricted shell access, firewall egress rules |
| **Vulnerability Exploitation** | System compromise | Regular updates, minimal exposed services, container isolation |
| **Spam Relaying** | Reputation damage, blacklisting | Proper authentication requirements, regular review of mail logs |
| **Resource Exhaustion (DoS)** | Service disruption | Container resource limits, CrowdSec rate limiting, queue size monitoring |
| **Container Escape** | Host compromise | Minimal container privileges, regular updates, secure Docker configuration |
| **Configuration Exposure** | Credential leakage | Ansible Vault for secrets, proper file permissions, `.gitignore` for sensitive files |

**Security Control Implementation:**

```mermaid
graph TD
    subgraph "Perimeter Security"
        FW[Firewall Role]
        CS[CrowdSec]
        TR[Traefik TLS]
    end
    
    subgraph "Email Security"
        SPF[SPF Records]
        DKIM[DKIM Signing]
        DMARC[DMARC Policy]
        MTASTS[MTA-STS]
    end
    
    subgraph "System Security"
        HARD[OS Hardening]
        SSHD[SSH Hardening]
        UPDT[Regular Updates]
        PERM[File Permissions]
    end
    
    subgraph "Data Security"
        VAULT[Ansible Vault]
        ENCBAK[Encrypted Backups]
        VOLPERM[Volume Permissions]
    end
    
    ATTACK[Attack Vectors] --> FW
    FW --> CS
    CS --> TR
    TR --> SPF
    SPF --> DKIM
    DKIM --> DMARC
    DMARC --> MTASTS
    MTASTS --> HARD
    HARD --> SSHD
    SSHD --> UPDT
    UPDT --> PERM
    PERM --> VAULT
    VAULT --> ENCBAK
    ENCBAK --> VOLPERM
    
    style ATTACK fill:#f99,stroke:#933,stroke-width:2px
```

## 14. Technical Debt Prevention

The architecture implements specific strategies to prevent technical debt accumulation, aligning with the "Minimize Technical Debt" principle from the PRD:

*   **Version Pinning:** All Docker images, Ansible collections, and external dependencies have specific versions pinned in their respective configuration files (`requirements.yml`, `docker-compose.yml.j2`). This prevents unexpected changes from upstream updates.

*   **Role Isolation:** The strict adherence to single-responsibility roles makes it easier to update, test, and replace individual components without affecting others.

*   **Comprehensive Documentation:** This architecture document and role-specific README files serve as living documentation, reducing knowledge barriers for future maintenance.

*   **Forward-Compatible Choices:** Core technology choices (Ansible, Docker, Traefik, Mailu) are all actively maintained projects with good community support, reducing the risk of obsolescence.

*   **Upgrade Paths:** The idempotent nature of the playbooks provides a clear path for incremental upgrades of components.

*   **Test Coverage:** (Roadmap) The planned test suite using Molecule and CI/CD will help catch regressions early, preventing issues from accumulating.

*   **Code Standards:** Adherence to Ansible and general coding best practices, enforced via linting and peer review, maintains code quality and prevents maintenance challenges.

*   **Refactoring Budget:** The architecture acknowledges that refactoring is sometimes necessary and accommodates it through a modular design that allows incremental improvements.

## 15. Future Considerations (Roadmap Alignment)

This architecture provides a foundation for future enhancements outlined in the PRD's roadmap, including:

1. **Backup and Recovery Implementation:** 
   * Complete implementation of the `backup` role with multiple storage options
   * Development of tested recovery procedures and documentation
   * Integration with monitoring for backup validation

2. **Enhanced Monitoring & Alerting:**
   * Full implementation of the `monitoring` role
   * Development of Grafana dashboards for comprehensive visibility
   * Integration with external monitoring systems

3. **Comprehensive Testing:**
   * Molecule test coverage for all core roles
   * CI pipeline integration tests
   * Formal idempotence validation

4. **Advanced Security Hardening:**
   * Container security profiles (AppArmor/SELinux)
   * Automated security scanning integration
   * Advanced network segmentation

5. **Centralized Log Management:**
   * Integration with log shipping tools (Fluentd, Vector)
   * Log aggregation and analysis

6. **Granular Management Playbooks:**
   * Dedicated `manage_domains.yml` and `manage_users.yml` playbooks
   * Fast-path updates for common operations

7. **Multi-Node / HA Considerations:**
   * Research on scaling Mailu across multiple nodes
   * Load balancing and failover strategies

8. **Advanced Security Hardening:**
   * Expanded hardening role capabilities
   * Integration of automated vulnerability scanning
   * TLS configuration testing and scoring

9. **Improved Operational Experience:**
   * Operational runbooks for common tasks
   * Enhanced error reporting and pre-flight checks

10. **Deliverability Assurance:**
    * Automated validation of email security configurations
    * IP reputation monitoring

## 16. Validation Requirements

This section defines specific validation criteria that must be enforced throughout the implementation to ensure consistency, security, and operational reliability.

### 16.1. Input Validation

**Domain Configuration Validation:**
* Domain name must be a valid FQDN (RFC 1035 compliant)
* Hostnames (mail.domain.com, webmail.domain.com, admin.domain.com) must be valid FQDNs
* All domains must have distinct FQDN values to prevent routing conflicts
* Implementation: Use Ansible's `assert` module with regex pattern validation in `domain_management` role

**Email Address Format Validation:**
* User email addresses must comply with RFC 5322
* Implementation: Validate in `user_management` role before API calls to Mailu

**Password Strength Requirements:**
* Minimum 12 characters
* Must include at least: 1 uppercase letter, 1 lowercase letter, 1 number, 1 special character
* Must not be a commonly used password (basic dictionary check)
* Implementation: Validate in `user_management` role before user creation

**Resource Limit Validation:**
* Container memory limits must be valid Docker format (e.g., "512M", "1G")
* Container CPU limits must be valid decimal values (e.g., 0.5, 1.0, 2.0)
* User quotas must be valid byte values
* Implementation: Validate in pre-tasks of affected roles

### 16.2. Post-Deployment Validation

**DNS Record Validation:**
* Verify that all required DNS records are properly propagated
* Check that MX, SPF, DKIM, and DMARC records match expected values
* Implementation: Include in `health_check.yml` playbook

**TLS Certificate Validation:**
* Verify certificate validity period (warn if < 30 days remaining)
* Validate certificate chain and trusted CA
* Verify hostname matches certificate subject
* Implementation: Include in `health_check.yml` playbook

**Service Availability Checks:**
* SMTP connections (ports 25, 465, 587) established successfully
* IMAP connections (port 993) established successfully
* HTTP/HTTPS connections to admin and webmail interfaces return 200 OK
* Implementation: Include in `health_check.yml` playbook

**Email Functionality Checks:**
* Send test email and verify receipt (if configured)
* Verify mail flow through complete stack
* Implementation: Optional component of `health_check.yml` playbook

### 16.3. Health Check Success Criteria

The `health_check.yml` playbook must evaluate the following criteria for a "healthy" system:

| Component | Check Type | Success Criteria | Failure Action |
|-----------|-----------|------------------|----------------|
| **System** | Disk Space | >20% free space on mail volume | Warning at <20%, Critical at <10% |
| **System** | Memory Usage | <85% used memory | Warning only |
| **System** | CPU Load | 1-minute load < number of cores | Warning only |
| **DNS** | Record Presence | All required DNS records exist | Warning, details in output |
| **TLS** | Certificate Validity | Valid for >30 days | Warning at <30 days, Critical at <7 days |
| **TLS** | Certificate Trust | Chain validates to trusted root | Critical |
| **Mailu Services** | Container Status | All containers running | Critical for core (front, smtp, imap, admin) |
| **Mailu Services** | Health Checks | All container health checks passing | Warning or Critical based on service |
| **Traefik** | Dashboard Access | Dashboard accessible (if enabled) | Warning |
| **CrowdSec** | Agent Status | Agent running and processing logs | Warning |
| **Mail Flow** | SMTP Connection | Can establish SMTP connection | Critical |
| **Mail Flow** | IMAP Connection | Can establish IMAP connection | Critical |

### 16.4. Implementation Sample

```yaml
# Example validation task in domain_management/tasks/validate_domains.yml
- name: Validate domain format
  assert:
    that:
      - domain | regex_search('^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')
    fail_msg: "Domain '{{ domain }}' is not a valid FQDN format"
    
# Example health check implementation
- name: Check TLS certificate validity
  openssl_certificate_info:
    path: "{{ mailu_base_dir }}/certs/{{ domain }}.crt"
  register: cert_info
  
- name: Evaluate certificate expiration
  set_fact:
    cert_status: >-
      {% if cert_info.not_after_time_ts - ansible_date_time.epoch | int < 604800 %}CRITICAL
      {% elif cert_info.not_after_time_ts - ansible_date_time.epoch | int < 2592000 %}WARNING
      {% else %}OK{% endif %}

- name: Display certificate status
  debug:
    msg: "Certificate for {{ domain }} expires in {{ (cert_info.not_after_time_ts - ansible_date_time.epoch | int) // 86400 }} days (Status: {{ cert_status }})"
```

## 17. Performance Considerations

While the current architecture targets a single-node deployment, performance considerations remain critical to ensure reliable operation under varying loads. This section outlines key performance requirements, benchmarks, and optimization strategies.

### 17.1. Resource Requirements

**Minimum Recommended Hardware:**
* **CPU:** 2 dedicated cores (4 recommended for production)
* **RAM:** 4GB minimum (8GB recommended for production)
* **Disk Space:** 20GB for system + adequate space for mail storage (depends on user count and retention policies)
* **Network:** Stable connection with at least 10Mbps upload/download, low latency preferred

**Container Resource Allocation:**
* Critical containers (SMTP, IMAP, front) should have guaranteed resources via Docker resource constraints
* Resource limits must be balanced to ensure stability without over-allocation:

| Container | Minimum Memory | Recommended Memory | CPU Limit |
|-----------|----------------|-------------------|-----------|
| smtp      | 512MB          | 1GB               | 0.5       |
| imap      | 512MB          | 1GB               | 1.0       |
| front     | 256MB          | 512MB             | 0.5       |
| antispam  | 512MB          | 1GB               | 0.5       |
| antivirus | 512MB          | 1GB               | 0.5       |
| admin     | 256MB          | 512MB             | 0.3       |
| webmail   | 256MB          | 512MB             | 0.3       |

### 17.2. Performance Optimizations

**System Level:**
* Optimize kernel parameters for network throughput (`net.core.somaxconn`, `net.ipv4.tcp_max_syn_backlog`)
* Configure appropriate disk I/O schedulers for mail volume storage
* Enable and correctly size the swap space (at least equal to RAM for emergency situations)
* Set appropriate file descriptor limits for container processes

**Application Level:**
* Configure appropriate worker processes for Mailu services based on available CPU cores
* Implement caching strategies for Dovecot (metadata, index)
* Optimize Rspamd caching and worker counts
* Configure message size limits and concurrent delivery limits appropriately

**Load Management:**
* Implement rate limiting for SMTP connections to prevent resource exhaustion during peak loads
* Configure queue management parameters for optimal message processing
* Implement graduated resource scaling based on load (via monitoring triggers)

### 17.3. Implementation Notes

The `mailu` role should generate optimized configurations based on system resources:

```yaml
# Example task for adaptive worker configuration
- name: Set optimal worker counts based on CPU cores
  set_fact:
    mailu_smtp_workers: "{{ [2, (ansible_processor_cores|int * 0.5)|int]|max }}"
    mailu_imap_workers: "{{ [2, (ansible_processor_cores|int * 0.7)|int]|max }}"

# Example task for adaptive memory configuration  
- name: Configure optimized memory limits
  set_fact:
    mailu_smtp_memory: "{{ [512, (ansible_memtotal_mb|int * 0.15)|int]|min }}M"
    mailu_imap_memory: "{{ [512, (ansible_memtotal_mb|int * 0.2)|int]|min }}M"
```

Resource allocation should be configurable but with safe defaults that prevent system instability. The `health_check` role should monitor resource utilization and alert when approaching critical thresholds.

## 18. Compliance and Regulatory Considerations

Email systems often process sensitive personal data and may be subject to various regulatory requirements. This section outlines key compliance considerations and how they are addressed in the architecture.

### 18.1. Privacy and Data Protection

The architecture supports compliance with privacy regulations such as GDPR, CCPA, and similar frameworks through:

* **Data Minimization:** Only essential user data is collected and stored
* **Access Controls:** Strict permission model for administrative access
* **Data Encryption:** TLS for transmission, encrypted backups for storage
* **Data Lifecycle Management:** Tools for proper data retention and deletion
* **Processing Records:** Logging mechanisms that can track mail processing while respecting privacy

**Implementation Requirements:**
* Mailbox export/deletion tools must be available for data subject access requests
* Log retention policies must be configurable to align with organizational requirements
* Backup encryption is mandatory, not optional

### 18.2. Email-Specific Compliance

**Key Requirements:**
* **Anti-Abuse Measures:** The Rspamd configuration enforces proper controls against abuse
* **Message Retention:** Configurable retention policies for compliance with legal hold requirements
* **Email Authentication:** Mandatory SPF, DKIM, DMARC implementation helps prevent fraudulent use
* **TLS Enforcement:** MTA-STS and TLSRPT records enable encryption and reporting

**Implementation Note:**
```yaml
# Example implementation of configurable retention policy
- name: Configure mail retention policy
  lineinfile:
    path: "{{ mailu_base_dir }}/overrides/dovecot.conf"
    regexp: "^mail_max_retention_days"
    line: "mail_max_retention_days = {{ mail_retention_days | default(365) }}"
    create: yes
    mode: "0640"
    owner: "{{ target_user }}"
    group: "{{ target_user }}"
```

### 18.3. Audit and Accountability

The architecture supports auditing requirements through:

* **Administrative Action Logging:** All admin actions are logged
* **Access Logging:** Authentication attempts and access to services are recorded
* **Configuration Change Tracking:** Git-based version control provides audit trail for configuration changes
* **Non-Repudiation:** Email authentication and logs preserve chain of custody

**Tools and Implementations:**
* Rspamd and Postfix logs maintain records of mail processing
* Traefik access logs capture web interface usage
* Container logs can be aggregated via the planned centralized logging system
* Ansible execution logs (when run with `-v`) provide deployment audit trails

### 18.4. Compliance Documentation

As part of deployment, the architecture can generate documentation to assist with compliance efforts:

* **Configuration Baselines:** Automated documentation of security controls
* **Processing Activities:** Mail flow diagrams and processing documentation
* **Technical Measures:** Encryption, authentication, and security control documentation

These artifacts can be generated as part of playbook execution to assist organizations with maintaining compliance documentation.

**Implementation Sample:**
```yaml
- name: Generate compliance documentation
  template:
    src: compliance_report.md.j2
    dest: "{{ mailu_base_dir }}/docs/compliance_report.md"
    mode: "0640"
    owner: "{{ target_user }}"
    group: "{{ target_user }}"
  when: generate_compliance_docs | default(false)
  tags:
    - documentation
    - compliance
```

## 19. Development Workflow and CI/CD Integration

This section details the recommended development workflow and CI/CD integration to maintain code quality and operational reliability.

### 19.1. Development Workflow

The project follows a standardized development workflow designed to maintain quality and facilitate collaboration:

```mermaid
graph TD
    A[Feature/Issue Branch Creation] --> B[Local Development]
    B --> C[Static Analysis/Linting]
    C --> D[Local Testing]
    D --> E[Pull Request]
    E --> F[Automated CI Checks]
    F --> G[Peer Review]
    G --> H[Merge to Main]
    H --> I[Automated Deployment]
    
    subgraph "Developer Activities"
        A
        B
        C
        D
        E
    end
    
    subgraph "CI/CD Pipeline"
        F
        I
    end
    
    subgraph "Team Activities"
        G
        H
    end
```

**Key Workflow Components:**

1. **Branch Strategy:**
   * `main` branch represents the stable, deployable state
   * Feature/bugfix branches created from `main` for all changes
   * Branch naming convention: `feature/short-description`, `fix/issue-reference`, `docs/topic`

2. **Local Development:**
   * Development occurs in feature branches
   * Use of `ansible-lint` for local validation
   * Regular commits with meaningful commit messages

3. **Pre-Commit Validation:**
   * Syntax checks
   * Linting against established rules
   * YAML validation
   * Idempotence checks on local test environment

4. **Pull Request Process:**
   * Detailed PR description referencing issues
   * PR template ensures documentation is updated
   * CI validation is triggered automatically

### 19.2. CI/CD Pipeline Implementation

The CI/CD pipeline is implemented using GitHub Actions and includes:

```yaml
# Example GitHub Actions workflow (simplified)
name: Ansible Lint & Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run ansible-lint
        uses: ansible/ansible-lint-action@v6
        with:
          path: "src/"
          
  molecule:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: pip install molecule docker ansible-core
      - name: Run Molecule tests
        run: cd src/roles/[role] && molecule test
        
  deploy:
    if: github.ref == 'refs/heads/main'
    needs: [lint, molecule]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Ansible Playbook
        uses: dawidd6/action-ansible-playbook@v2
        with:
          playbook: src/playbooks/site.yml
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          vault_password: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
          inventory: |
            [servers]
            server ansible_host=${{ secrets.SERVER_IP }}
```

**Key CI/CD Components:**

1. **Static Analysis:**
   * `ansible-lint` enforces coding standards
   * YAML syntax validation
   * Variable usage validation
   * Best practice adherence verification

2. **Automated Testing:**
   * Molecule tests for individual roles
   * Integration tests for complete playbooks (roadmap)
   * Idempotence testing (run twice, expect no changes on second run)
   * Edge case validation

3. **Deployment Automation:**
   * Automated deployment triggered on merges to main
   * Vault password provided securely via CI/CD secrets
   * Comprehensive reporting of deployment results
   * Safety mechanisms to prevent failed deployments from affecting production

4. **Documentation Updates:**
   * Automated verification that documentation stays current with changes
   * README generation/validation for roles

### 19.3. Quality Gates

The CI/CD pipeline implements multiple quality gates that must be passed:

1. **Pre-Merge Gates:**
   * All linting checks pass
   * All Molecule tests pass (where implemented)
   * Documentation is updated
   * PR has required approvals

2. **Deployment Gates:**
   * Pre-deployment validation checks
   * Task failure-rate thresholds
   * Post-deployment health checks

3. **Manual Gates:**
   * Peer code review by at least one team member
   * Additional approvals for sensitive changes (e.g., security configurations)

### 19.4. Implementation Standards

**Repository Structure:**
* `.github/workflows/` directory contains CI workflow definitions
* `molecule/` directories exist in each role to be tested
* `.ansible-lint` in repository root defines linting rules and exceptions

**Local Development Environment:**
* Consistent development environment using containerization
* Local pre-commit hooks for validation
* Documentation for setting up local test environment

This approach ensures consistent quality, maintains the security-first principle, and reduces the risk of technical debt accumulation through automated validation at multiple stages of the development process.