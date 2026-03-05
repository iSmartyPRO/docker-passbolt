# Backup Script Documentation

Backup of Passbolt data: database dump, `gpg/` and `jwt/` directories, plus `.env` and `docker-compose.yaml`, archived to `.tar.gz`. Optional: send latest backup by email; schedule both via cron.

**См. также:** [Оглавление документации](README.md) · [Основной README](../README.md)

**Скрипты в `scripts/`:**
- `backup.sh` — создание резервной копии (дамп БД, gpg, jwt, архив).
- `send-backup-email.sh` — отправка последнего архива на почту (нужны Python 3 и SMTP в `.env`; для самоподписанного SSL: `PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_VERIFY_PEER=false`).
- `install-cron.sh` — добавить в crontab запуск backup (ежедневно) и send-backup-email (еженедельно).

---

## Table of Contents

1. [Requirements](#requirements)
2. [Setup](#setup)
3. [Environment Variables](#environment-variables)
4. [Script Workflow](#script-workflow)
5. [Cron Job](#cron-job)
6. [Log File](#log-file)
7. [Sending backup by email](#sending-backup-by-email)
8. [Retention Policy](#retention-policy)

---

## Requirements

- **Linux** or compatible Unix system.
- `mysqldump` for database backups.
- Docker installed on the system.
- Bash shell (`/bin/bash`).
- Cron for scheduling.

---

## Setup
0. Install mariadb-client if not present: 
   ```bash
   sudo apt install mariadb-client
   ```
1. Clone or copy the project; the backup script is in the `scripts/` directory (e.g., `/dockers/pass/scripts/backup.sh`).
2. Make scripts executable (run from project root):
    ```bash
    chmod +x scripts/backup.sh scripts/send-backup-email.sh scripts/install-cron.sh
    ```
3. Set up environment variables in a `.env` file in the **project root** (parent of `scripts/`). The script automatically switches to the project root when run from any directory. Optional in `.env`: `GPG_DIR`, `JWT_DIR` (defaults: project root `gpg/` and `jwt/`).

---

## Environment Variables

The script uses the following environment variables from a `.env` file:

| Variable                    | Description                                   |
| --------------------------- | --------------------------------------------- |
| `DATASOURCES_DEFAULT_HOST`   | Database host (e.g., `localhost`, `mariadb`). |
| `BACKUP_DB_CONTAINER`        | Optional. If DB runs in Docker, set to container name (e.g. `mariadb`) so backup runs `mysqldump` via `docker exec`. |
| `BACKUP_EMAIL_TO`            | Optional. Email for latest backup (used by `scripts/send-backup-email.sh`). |
| `BACKUP_CRON_SCHEDULE`       | Optional. Cron expression for backup (default: `0 2 * * *`). Used by `install-cron.sh`. |
| `BACKUP_EMAIL_CRON_SCHEDULE` | Optional. Cron expression for send-backup-email (default: `0 3 * * 0`). Used by `install-cron.sh`. |
| `DATASOURCES_DEFAULT_PORT`   | Database port (e.g., `3306`).                 |
| `DATASOURCES_DEFAULT_USERNAME` | Database username.                          |
| `DATASOURCES_DEFAULT_PASSWORD` | Database password.                          |
| `DATASOURCES_DEFAULT_DATABASE` | Name of the database to back up.            |
| `GPG_DIR`                    | Path to the `gpg` directory (default: project `gpg/`). |
| `JWT_DIR`                    | Path to the `jwt` directory (default: project `jwt/`). |
| `BACKUP_DAYS`                | Retention period in days for old backups (default: 7).  |

Example (optional overrides; most variables come from main Passbolt `.env`):
```bash
BACKUP_DAYS=7
BACKUP_EMAIL_TO=admin@example.com
# BACKUP_DB_CONTAINER=mariadb
# BACKUP_CRON_SCHEDULE="0 2 * * *"
# BACKUP_EMAIL_CRON_SCHEDULE="0 3 * * 0"
```

---

## Script Workflow

1. **Load Environment Variables**  
   The script reads variables from the `.env` file.

2. **Set Timestamp**  
   Sets a timestamp for consistent file naming.

3. **Create Backup Directories**  
   Ensures the backup directories exist.

4. **Database Backup**  
   Executes `mysqldump` to back up the specified database.

5. **Copy Directories**  
   Copies the contents of `gpg` and `jwt` directories.

6. **Retrieve Docker Version**  
   Retrieves the version of Docker installed and saves it to a file.

7. **Archive Data**  
   Archives the database dump, copied directories, and Docker-related files into a `.tar.gz` file.

8. **Remove Temporary Files**  
   Cleans up the temporary files and directories used during the backup process.

9. **Remove Old Backups**  
   Deletes backups older than the specified retention period (`BACKUP_DAYS`).

---

## Cron Job

Use **`scripts/install-cron.sh`** to add both backup and email tasks to crontab. Default schedule:

- **backup.sh** — daily at 02:00
- **send-backup-email.sh** — weekly on Sunday at 03:00

```bash
./scripts/install-cron.sh
```

Override schedule via arguments or `.env`:

```bash
# Custom: backup at 03:00 daily, email Monday 04:00
./scripts/install-cron.sh '0 3 * * *' '0 4 * * 1'
```

In `.env` (optional): `BACKUP_CRON_SCHEDULE`, `BACKUP_EMAIL_CRON_SCHEDULE` (cron format: min hour day month weekday).

To check scheduled jobs:
```bash
crontab -l
```

---

## Log File

Each backup creates a log file with the same name as the archive file but with a `.log` extension. The log file includes:

- Script start and end time.
- Status of each step (e.g., success or failure).
- Execution time.

Example log file entry:
```
2024-12-01 23:00:01: Script started at: 2024-12-01 23:00:01
2024-12-01 23:00:01: Creating a database backup...
2024-12-01 23:00:05: Database backup completed successfully.
2024-12-01 23:00:05: Copying gpg and jwt folders...
2024-12-01 23:00:06: Folders copied successfully.
2024-12-01 23:00:07: Getting Docker version...
2024-12-01 23:00:07: Docker version retrieved successfully.
2024-12-01 23:00:07: Archiving data...
2024-12-01 23:00:10: Backup successfully created: ./backups/pass_2024-12-01_230000.tar.gz
2024-12-01 23:00:10: Temporary folders and files removed.
2024-12-01 23:00:10: Removing backups older than 7 days...
2024-12-01 23:00:11: Old backups removed.
2024-12-01 23:00:11: Script finished at: 2024-12-01 23:00:11
2024-12-01 23:00:11: Execution time: 10 seconds.
```

---

## Sending backup by email

The script `scripts/send-backup-email.sh` sends the **latest** backup archive (the most recent `.tar.gz` in `backups/`) to the address specified in `BACKUP_EMAIL_TO` in `.env`. It uses the same SMTP settings as Passbolt (`EMAIL_TRANSPORT_DEFAULT_*`, `EMAIL_DEFAULT_FROM`).

**Requirements:** Python 3, SMTP variables in `.env` (same as Passbolt). For self-signed SMTP certificates set `PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_VERIFY_PEER=false` in `.env`.

**Usage:**
```bash
./scripts/send-backup-email.sh
```

Set in `.env`:
```bash
BACKUP_EMAIL_TO=admin@example.com
```

---

## Retention Policy

The script automatically removes backup files older than the number of days specified in `BACKUP_DAYS`.  

**Example**:  
If `BACKUP_DAYS=7`, backups older than 7 days will be deleted.

---

## License

This script is distributed under the MIT License. Use it at your own risk.
