# Mailu Backup and Recovery Guide

This guide explains how to use the backup and recovery features available in the Mailu multi-domain email server.

## Overview

The backup system provides:

- AES-256 encrypted backup archives
- Multiple storage backends: Local, rsync, AWS S3/Glacier, Azure Blob Storage, GCP Cloud Storage
- Scheduled automatic backups
- Flexible restore options
- Backup rotation with configurable retention periods

## What Gets Backed Up

1. **Email data**: All user mailboxes and messages
2. **Configuration**: Mailu's `.env` file, Docker Compose configuration, and Traefik settings
3. **TLS Certificates**: SSL/TLS certificates used by the mail server
4. **DKIM Keys**: Domain Keys Identified Mail signatures for all domains
5. **Database**: User accounts, aliases, and other mail server settings

## Configuration

Backup settings are defined in the `roles/backup/defaults/main.yml` file. The most important settings are:

```yaml
# General backup settings
backup_enabled: true
backup_base_dir: "{{ mailu_base_dir }}/backups"
backup_retention_days: 14   # How many days to keep backups

# Schedule
backup_schedule_enabled: true
backup_schedule_hour: "2"    # Run at 2 AM by default
backup_schedule_minute: "0"
backup_schedule_weekday: "*" # Run every day

# Storage backends
backup_local_enabled: true
backup_rsync_enabled: false
backup_aws_enabled: false
backup_azure_enabled: false
backup_gcp_enabled: false
```

### Backup Encryption

Backups are encrypted using AES-256. The encryption key is automatically generated and stored in the Mailu `.env` file under the `BACKUP_ENCRYPTION_KEY` variable. **Keep this key secure** - you will need it to restore from encrypted backups.

## Storage Backends

### Local Storage

By default, backups are stored locally in the `{{ mailu_base_dir }}/backups/archives` directory. This is suitable for development but not recommended for production use without additional backup strategies.

### Rsync to Remote Host

To enable rsync backups to a remote server:

1. Set `backup_rsync_enabled: true` in your variables
2. Configure the rsync target:
   ```yaml
   backup_rsync_host: "backuphost.example.com"
   backup_rsync_user: "backupuser"
   backup_rsync_path: "/backups/mailu"
   ```
3. An SSH key will be generated for passwordless authentication
4. Add the displayed public key to the `~/.ssh/authorized_keys` file on your backup server

### AWS S3/Glacier

To enable backups to Amazon S3:

1. Set `backup_aws_enabled: true` in your variables
2. Configure AWS settings:
   ```yaml
   backup_aws_bucket: "my-mailu-backups"
   backup_aws_region: "us-east-1"
   backup_aws_path: "backups/"
   ```
3. For Glacier storage, set:
   ```yaml
   backup_aws_glacier: true
   backup_aws_storage_class: "GLACIER"  # or "DEEP_ARCHIVE" for longer term storage
   ```
4. Add your AWS credentials to the vault:
   ```yaml
   vault_aws_access_key: "YOUR_ACCESS_KEY"
   vault_aws_secret_key: "YOUR_SECRET_KEY"
   ```

### Azure Blob Storage

To enable backups to Azure Blob Storage:

1. Set `backup_azure_enabled: true` in your variables
2. Configure Azure settings:
   ```yaml
   backup_azure_container: "mailu-backups"
   backup_azure_path: "backups/"
   backup_azure_storage_account: "mystorageaccount"
   ```
3. Add your Azure credentials to the vault:
   ```yaml
   vault_azure_storage_key: "YOUR_STORAGE_KEY"
   # Optional service principal for additional Azure operations
   vault_azure_app_id: "APP_ID"
   vault_azure_password: "PASSWORD"
   vault_azure_tenant: "TENANT_ID"
   ```

### Google Cloud Storage

To enable backups to Google Cloud Storage:

1. Set `backup_gcp_enabled: true` in your variables
2. Configure GCP settings:
   ```yaml
   backup_gcp_bucket: "mailu-backups"
   backup_gcp_path: "backups/"
   backup_gcp_project: "my-gcp-project"
   ```
3. Add your GCP service account credentials to the vault:
   ```yaml
   vault_gcp_credentials: |
     {
       "type": "service_account",
       "project_id": "my-project",
       ...
     }
   ```

## Manual Backup Operation

To run a backup manually:

```bash
cd /path/to/iac-mailu/src
ansible-playbook -i inventory/hosts playbooks/backup.yml
```

## Restore Operations

### Listing Available Backups

To list available backups on the server:

```bash
ssh user@mail-server
cd /path/to/mailu/backups
./restore.sh --list
```

### Restoring from Backup

#### Using the Restore Playbook

This is the recommended approach for most users:

```bash
cd /path/to/iac-mailu/src
ansible-playbook -i inventory/hosts playbooks/restore.yml -e "backup_file=latest"
```

Available options:
- `backup_file`: Specify backup file name or "latest" (default)
- `restore_config`: Set to "false" to skip configuration restore
- `restore_mail_data`: Set to "false" to skip mail data restore
- `restore_dkim`: Set to "false" to skip DKIM keys restore
- `force_restore`: Set to "true" to skip confirmation prompts

Example to restore only configuration from a specific backup:
```bash
ansible-playbook -i inventory/hosts playbooks/restore.yml -e "backup_file=mailu-backup-2025-04-22-120000.tar.gz.gpg restore_config=true restore_mail_data=false restore_dkim=false"
```

#### Direct Restore Script Usage

For advanced users who need more control:

```bash
ssh user@mail-server
cd /path/to/mailu/backups
./restore.sh [options] <backup_file>
```

Options:
- `--help`: Show help message
- `--list`: List available backups
- `--config-only`: Restore only configuration files
- `--data-only`: Restore only mail data
- `--dkim-only`: Restore only DKIM keys
- `--force`: Skip confirmation prompts

## Troubleshooting

### Backup Logs

Backup logs are stored in:
- `/path/to/mailu/backups/backup.log`

### Common Issues

1. **Encryption key missing**: Ensure the `.env` file contains the `BACKUP_ENCRYPTION_KEY` variable
2. **Cannot restore encrypted backup**: Verify you're using the same encryption key used during backup
3. **Failed cloud storage uploads**: Check credentials and network connectivity

For rsync issues:
- Verify the SSH key is correctly added to the remote server
- Check network connectivity and firewall settings
- Verify the remote user has write permissions to the backup directory

## Best Practices

1. **Regular verification**: Periodically verify your backups by performing test restores
2. **Multiple storage locations**: Enable at least two different storage backends
3. **Secure the encryption key**: Store a copy of your encryption key in a secure location outside the mail server
4. **Monitor backup success**: Check the backup logs regularly or enable monitoring/alerting
5. **Document your recovery procedure**: Create a step-by-step guide specific to your environment