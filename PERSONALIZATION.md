# Personalizing Your Mailu Multi-Domain Deployment

This guide explains how to fork and customize this repository to create your own personalized Mailu deployment configuration.

## Why Personalize?

While you can use this repository directly by modifying configuration files, creating your own personalized fork gives you several advantages:

1. **Version control** for your specific configuration
2. **CI/CD workflows** tailored to your environment
3. **Documentation** specific to your setup
4. **Custom features** that may not be relevant to the original repository

## Step-by-Step Personalization Guide

### 1. Fork or Clone the Repository

Start by creating your own copy of the repository:

```bash
# Option 1: Create a fresh repository
git clone https://github.com/yourusername/iac-mailu.git my-mailu-config
cd my-mailu-config
rm -rf .git
git init

# Option 2: Fork via GitHub web interface and then clone your fork
git clone https://github.com/yourusername/iac-mailu.git
cd iac-mailu
```

### 2. Update Basic Configuration

Update the following files with your specific information:

1. **README.md**: Change the documentation to reflect your specific deployment.

2. **inventory/hosts**: Replace with your actual server details.
   ```ini
   [mail_server]
   mail.yourdomain.com ansible_host=203.0.113.10 ansible_user=your-admin-user
   ```

3. **group_vars/all.yml**: Modify settings to match your preferences.
   ```yaml
   # Example modifications
   mailu_base_dir: /opt/mailu
   ntfy_enabled: true
   ntfy_url: https://ntfy.yourdomain.com  # If using self-hosted ntfy
   ntfy_topic: "your-private-alerts"
   ```

### 3. Configure Your Domains

1. **Remove the example domains**:
   ```bash
   rm src/domains/example.com.yml
   ```

2. **Add your own domains**:
   ```bash
   # Create a domain file for each domain you want to host
   nano src/domains/yourdomain.com.yml
   ```

   Use this template:
   ```yaml
   ---
   domain: yourdomain.com
   hostname: mail.yourdomain.com
   webmail: webmail.yourdomain.com
   admin: admin.yourdomain.com

   users:
     - name: user1
       password_var: vault_user1_yourdomain_com
     - name: postmaster
       password_var: vault_postmaster_yourdomain_com
       catchall: true
   ```

### 4. Set Up Your Vault

1. **Create your vault file**:
   ```bash
   ansible-vault create src/vault/secrets.yml
   ```

2. **Add your secrets**:
   ```yaml
   # Cloudflare API token with DNS edit permissions
   vault_cloudflare_api_token: "your-cloudflare-api-token"

   # Mailu admin API secret
   vault_mailu_admin_secret: "your-mailu-admin-secret"

   # User passwords
   vault_user1_yourdomain_com: "secure-password-1"
   vault_postmaster_yourdomain_com: "secure-password-2"

   # Optional: Ntfy auth token if needed
   vault_ntfy_auth_token: "your-ntfy-auth-token"
   ```

### 5. Customize Docker Images (Optional)

If you want to use specific versions of Mailu or other services, edit `src/group_vars/all.yml` to add image version preferences:

```yaml
# Mailu image versions
mailu_image_front: "mailu/nginx:1.9"
mailu_image_admin: "mailu/admin:1.9"
mailu_image_imap: "mailu/dovecot:1.9"
mailu_image_smtp: "mailu/postfix:1.9"
mailu_image_antispam: "mailu/rspamd:1.9"
mailu_image_antivirus: "mailu/clamav:1.9"
mailu_image_webmail: "mailu/roundcube:1.9"
```

### 6. Configure GitHub Actions

1. Set up secrets in your GitHub repository:
   - `ANSIBLE_VAULT_PASSWORD`
   - `SSH_PRIVATE_KEY`
   - `KNOWN_HOSTS`
   - Any other secrets needed for your deployment

2. Update the GitHub Actions workflow file (`.github/workflows/deploy.yml`) to match your branch names and deployment triggers.

### 7. Adding Custom Modules

If you need to extend functionality:

1. **Create new task files** in the `src/roles/mailu/tasks/` directory.
2. **Include them** in `src/roles/mailu/tasks/main.yml`.
3. **Add templates** to `src/templates/` as needed.

### 8. Testing Your Changes

Before deploying to production:

1. Test in a staging environment:
   ```bash
   ansible-playbook -i inventory/staging src/playbooks/site.yml --ask-vault-pass
   ```

2. Validate your configuration:
   ```bash
   ansible-playbook -i inventory/staging src/playbooks/site.yml --check --diff --ask-vault-pass
   ```

### 9. Version Control Best Practices

1. **Use branches** for different environments (production, staging)
2. **Tag releases** with semantic versioning (v1.0.0, v1.1.0)
3. **Document changes** in commit messages and releases
4. **Don't commit unencrypted secrets** to version control

### 10. Keeping Up with Upstream Changes

To incorporate improvements from the original repository:

```bash
# Add the original repo as a remote
git remote add upstream https://github.com/original/iac-mailu.git

# Fetch upstream changes
git fetch upstream

# Merge upstream changes into your branch
git merge upstream/main

# Resolve any conflicts and commit the changes
```

## Advanced Customizations

### Custom Email Filtering Rules

Create custom Rspamd rules in `src/roles/mailu/files/rspamd-overrides/` and update the Docker Compose template to mount them.

### Extended Monitoring 

Integrate with Prometheus and Grafana by adding exporters to the Docker Compose file and configuring dashboards.

### Backup Solutions

Create additional playbooks for automatic backups to S3, remote servers, or other storage systems.

## Conclusion

By following this guide, you can create a personalized version of the Mailu multi-domain deployment that meets your specific requirements while maintaining the ability to incorporate future improvements from the original repository.