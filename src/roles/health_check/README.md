# Health Check Role

This Ansible role sets up and configures automated health checks for the Mailu mail server. It creates scripts to monitor various services, sends notifications on failures, and provides a foundation for proactive monitoring.

## Responsibilities

- Monitoring critical mail services (SMTP, IMAP, web interfaces)
- Sending notifications when service failures are detected
- Generating health check reports
- Setting up scheduled health check jobs via cron

## Requirements

- Python 3
- Access to the Mailu services
- SMTP server for email notifications (optional)
- Webhook endpoint for webhook notifications (optional)

## Role Variables

### Default Variables

```yaml
# Base directory for health checks
health_check_base_dir: "/opt/mailu/health"

# Health check interval in minutes
health_check_interval: 5

# Health check services to monitor
health_check_services:
  - name: smtp
    port: 25
    type: tcp
    timeout: 10
    
  - name: imap
    port: 143
    type: tcp
    timeout: 5
    
  - name: submission
    port: 587
    type: tcp
    timeout: 5
    
  - name: webmail
    path: "/webmail/"
    type: http
    timeout: 10
    status_code: 200
    
  - name: admin
    path: "/admin/"
    type: http
    timeout: 10
    status_code: 200

# Notification settings
health_check_notify_enabled: true
health_check_notify_method: "smtp"  # Options: smtp, webhook, script
health_check_notify_email: "admin@example.com"
health_check_smtp_server: "localhost"
health_check_smtp_port: 25
health_check_smtp_from: "health@example.com"

# Webhook notification settings
health_check_webhook_url: ""
health_check_webhook_method: "POST"

# Custom script notification settings
health_check_script_path: ""

# Debug mode
health_check_debug: false
```

## Service Types and Configuration

### TCP Service Checks

```yaml
- name: smtp
  host: localhost  # Optional, defaults to localhost
  port: 25
  type: tcp
  timeout: 10  # Seconds
```

### HTTP Service Checks

```yaml
- name: webmail
  host: webmail.example.com  # Optional, defaults to localhost
  port: 443  # Optional, defaults to 80
  path: "/webmail/"
  protocol: "https"  # Optional, defaults to https
  type: http
  timeout: 10  # Seconds
  status_code: 200  # Expected response code
```

## Notification Methods

### SMTP Email Notifications

Sends email notifications through an SMTP server when health checks fail.

```yaml
health_check_notify_method: "smtp"
health_check_notify_email: "admin@example.com"
health_check_smtp_server: "localhost"
health_check_smtp_port: 25
health_check_smtp_from: "health@example.com"
```

### Webhook Notifications

Sends webhook notifications to services like Slack, Discord, or custom endpoints.

```yaml
health_check_notify_method: "webhook"
health_check_webhook_url: "https://hooks.slack.com/services/XXX/YYY/ZZZ"
health_check_webhook_method: "POST"  # GET or POST
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: mail_servers
  roles:
    - role: docker_base
    - role: traefik
    - role: domain_management
    - role: user_management
    - role: health_check
      health_check_interval: 10
      health_check_notify_enabled: true
      health_check_notify_method: "smtp"
      health_check_notify_email: "admin@example.com"
```

## Manual Health Check

You can run a health check manually with:

```bash
cd /opt/mailu/health
python3 health_check.py
```

The health check results will be saved to a JSON file in the same directory.

## Author Information

Created for the Mailu Multi-Domain Ansible project.