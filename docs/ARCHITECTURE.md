# iac-mailu Deployment Architecture

This document provides an overview of the `iac-mailu` project architecture to help contributors understand the structure, components, and interactions involved in deploying and managing a Mailu email server stack using Ansible.

## Overview

`iac-mailu` is an Infrastructure as Code (IaC) project designed to automate the deployment, configuration, and management of a Mailu email server suite and its supporting services (like Traefik and CrowdSec) using Ansible. The target infrastructure runs Mailu within Docker containers, orchestrated by Docker Compose. Ansible manages the target server setup, Docker installation, configuration generation (including `docker-compose.yml` and Mailu's `.env` file), service deployment, and ongoing maintenance tasks.

The architecture emphasizes automation, idempotency, configuration management through version control, and secure secret handling via Ansible Vault.

## Core Technologies

-   **Ansible**: Automation engine for configuration management, application deployment, and orchestration.
-   **Docker**: Containerization platform for running Mailu and supporting services.
-   **Docker Compose**: Tool for defining and running the multi-container Mailu application stack on the target server.
-   **Jinja2**: Templating engine used by Ansible to generate configuration files dynamically.
-   **Mailu**: The core email server suite being deployed (includes Postfix, Dovecot, Rspamd, Nginx, etc., within containers).
-   **Traefik**: (Optional) Reverse proxy and load balancer, managed as a Docker container via Ansible/Docker Compose.
-   **CrowdSec**: (Optional) Security automation tool, managed as Docker containers via Ansible/Docker Compose.
-   **Let's Encrypt**: Used via Traefik or Certbot (managed by Ansible) for obtaining TLS certificates.
-   **Cloudflare API**: (Optional) Used by Ansible for automated DNS record management for Mailu domains.
-   **Ntfy**: (Optional) Used for push notifications from Ansible playbooks.

## Directory Structure

```
iac-mailu/
├── .github/              # GitHub Actions workflows, issue/PR templates, Copilot instructions
├── docs/                 # Project documentation (ARCHITECTURE.md, PRD.md, etc.)
├── domains/              # Per-domain configuration files (users, aliases, relays)
│   └── example.com.yml   # Example domain configuration
├── group_vars/           # Ansible group variables
│   └── all.yml           # Global configuration settings
├── host_vars/            # Ansible host-specific variables (optional)
├── inventory/            # Ansible inventory files
│   └── hosts             # Defines target hosts and groups
├── playbooks/            # Main Ansible playbooks
│   ├── site.yml          # Main deployment playbook
│   ├── health_check.yml  # Playbook to check service health
│   └── ...               # Other utility playbooks
├── roles/                # Ansible roles for modular tasks
│   ├── common/           # Common server setup tasks
│   ├── docker/           # Docker and Docker Compose installation
│   ├── mailu/            # Mailu deployment and configuration
│   ├── traefik/          # Traefik deployment and configuration
│   ├── crowdsec/         # CrowdSec deployment and configuration
│   ├── dns_cloudflare/   # Cloudflare DNS management
│   └── ...               # Other roles (e.g., backup, monitoring)
├── templates/            # Global Jinja2 templates (if any, most are role-specific)
├── vault/                # Ansible Vault encrypted secrets
│   └── secrets.yml       # Encrypted sensitive data (API keys, passwords)
├── .ansible-lint         # Configuration for ansible-lint
├── .gitignore            # Files/directories ignored by Git
├── ansible.cfg           # Ansible configuration file
├── LICENSE               # Project license
├── README.md             # Project overview and setup instructions
└── requirements.yml      # Ansible Galaxy collection/role dependencies
```

## Key Components

1.  **Ansible Control Node**: The machine where `ansible-playbook` commands are executed. It reads the inventory, variables, roles, and playbooks to connect to and configure the target server(s).
2.  **Target Server(s)**: The host(s) defined in the `inventory/hosts` file where Mailu will be deployed. Ansible connects to these via SSH.
3.  **Ansible Inventory (`inventory/`)**: Defines the target hosts and groups them.
4.  **Ansible Variables (`group_vars/`, `host_vars/`, `domains/`, `vault/`)**: Define the configuration parameters for the deployment.
    *   `group_vars/all.yml`: Global settings applicable to all hosts.
    *   `domains/*.yml`: Specific configurations for each email domain (users, aliases).
    *   `vault/secrets.yml`: Encrypted sensitive data.
5.  **Ansible Roles (`roles/`)**: Encapsulate specific tasks like installing Docker, configuring Mailu, setting up Traefik, etc., promoting reusability and modularity.
6.  **Ansible Playbooks (`playbooks/`)**: Orchestrate the execution of roles and tasks against the target hosts defined in the inventory.
7.  **Docker Engine & Docker Compose (on Target Server)**: Installed and managed by Ansible. Docker runs the containers, and Docker Compose defines and manages the multi-container Mailu application based on a template generated by Ansible.
8.  **Mailu Stack (Containers on Target Server)**: The running containers (Admin, Front, IMAP, SMTP, Antivirus, Antispam, Webmail, etc.) as defined by the `docker-compose.yml` generated by the `mailu` role.
9.  **Supporting Services (Containers on Target Server)**: Traefik, CrowdSec, etc., deployed and configured by their respective Ansible roles via Docker Compose.

## Interaction Flow (Ansible Deployment)

```mermaid
graph LR
    A[User/CI] -- Runs --> B(ansible-playbook);
    B -- Reads --> C[Inventory];
    B -- Reads --> D[Variables (group_vars, domains, vault)];
    B -- Reads --> E[Playbooks & Roles];
    B -- Connects via SSH --> F(Target Server);
    subgraph Ansible Control Node
        direction LR
        A
        B
        C
        D
        E
    end

    subgraph Target Server
        direction TB
        F -- Manages --> G(Docker Engine);
        F -- Manages --> H(Docker Compose);
        F -- Generates --> I(Configuration Files);
        H -- Uses --> I;
        H -- Instructs --> G;
        G -- Runs --> J((Mailu Containers));
        G -- Runs --> K((Traefik Container));
        G -- Runs --> L((CrowdSec Containers));
        I -- Includes --> M[docker-compose.yml];
        I -- Includes --> N[mailu.env];
        I -- Includes --> O[traefik.yml, etc.];
    end

```

1.  A user or CI system executes an `ansible-playbook` command (e.g., `ansible-playbook playbooks/site.yml`).
2.  Ansible reads the inventory to determine target hosts.
3.  Ansible loads variables from `group_vars`, `host_vars`, `domains`, and decrypts `vault/secrets.yml`.
4.  Ansible executes tasks defined in the specified playbook and its included roles.
5.  Roles connect to the target server via SSH.
6.  Tasks are executed idempotently:
    *   Install necessary packages (Docker, Docker Compose, dependencies).
    *   Create directories and manage permissions.
    *   Generate configuration files from Jinja2 templates (e.g., `/root/mailu/docker-compose.yml`, `/root/mailu/mailu.env`, Traefik configs).
    *   Use the `docker_compose` Ansible module to start/update the Docker Compose stack defined in the generated `docker-compose.yml`.
    *   Manage DNS records via Cloudflare API (if configured).
    *   Perform other setup or maintenance tasks.
7.  Docker Compose pulls necessary images and starts/recreates the Mailu, Traefik, and CrowdSec containers based on the Ansible-generated configuration.

## Configuration Management

-   The primary way to configure the deployment is by modifying YAML files within `group_vars/all.yml` and `domains/`.
-   Secrets **must** be stored in `vault/secrets.yml` and encrypted using `ansible-vault`.
-   Role defaults are defined in `roles/<role_name>/defaults/main.yml`.
-   The Jinja2 templates (mostly within roles, e.g., `roles/mailu/templates/docker-compose.yml.j2`) combine variables to generate the final configuration files deployed to the target server.

## Extending the Platform

-   **Add/Modify Mailu Configuration**: Adjust variables in `group_vars/all.yml` or domain files. Modify templates in the `mailu` role if necessary.
-   **Add New Services**: Create a new Ansible role to manage the deployment and configuration of the service (likely involving Docker container management). Include the role in the main `playbooks/site.yml`.
-   **Modify Server Setup**: Add tasks to the `common` role or create new specialized roles.