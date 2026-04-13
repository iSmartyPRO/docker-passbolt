# Passbolt backups

The scripts dump the database, copy **`gpg/`** and **`jwt/`**, and include **`.env`** and **`docker-compose.yaml`** in a **`.tar.gz`** under **`backups/`**. You can optionally email the latest archive; scheduling uses cron.

**See also:** [Documentation index](README.md) · [Root README](../README.md) · [make.md](make.md) (`make backup`, `make send-backup-email`)

**Scripts:**

- `scripts/backup.sh` — create a backup archive.
- `scripts/send-backup-email.sh` — email the latest archive to `BACKUP_EMAIL_TO` (Python 3, same SMTP variables as Passbolt).
- `scripts/install-cron.sh` — install crontab entries for backup and email.

---

## Table of contents

1. [Requirements](#requirements)
2. [Setup](#setup)
3. [Environment variables](#environment-variables)
4. [Backup workflow](#backup-workflow)
5. [Cron](#cron)
6. [Logs](#logs)
7. [Emailing the latest archive](#emailing-the-latest-archive)
8. [Retention](#retention)

---

## Requirements

- Linux or a compatible Unix environment.
- `mysqldump` (often from `mariadb-client` / `mysql-client`).
- Docker installed if the dump runs via `docker exec` into the database container.
- Bash (`/bin/bash`).
- Cron for scheduling.
- Python 3 for the email script.

---

## Setup

1. Install a MariaDB/MySQL client if needed:

   ```bash
   sudo apt install mariadb-client
   ```

2. Make scripts executable (from the repository root):

   ```bash
   chmod +x scripts/backup.sh scripts/send-backup-email.sh scripts/install-cron.sh
   ```

3. Place **`.env`** in the **project root** (parent of `scripts/`). Scripts `cd` to the root on startup. Optionally set `GPG_DIR` and `JWT_DIR` (defaults: `gpg/` and `jwt/` in the root).

---

## Environment variables

Values are read from **`.env`** in the root (same variables Passbolt uses, plus backup options):

| Variable | Description |
|----------|-------------|
| `DATASOURCES_DEFAULT_HOST` | Database host (`localhost`, container name, etc.) |
| `DATASOURCES_DEFAULT_PORT` | Database port (e.g. `3306`) |
| `DATASOURCES_DEFAULT_USERNAME` | Database user |
| `DATASOURCES_DEFAULT_PASSWORD` | Database password |
| `DATASOURCES_DEFAULT_DATABASE` | Database name |
| `BACKUP_DB_CONTAINER` | Optional: **container name** for MySQL/MariaDB when host `mysqldump` cannot reach `DATASOURCES_DEFAULT_HOST` |
| `BACKUP_EMAIL_TO` | Recipient for the latest archive (`send-backup-email.sh`) |
| `BACKUP_DAYS` | How many days to keep archives (default `7`) |
| `BACKUP_CRON_SCHEDULE` | Backup schedule for `install-cron.sh` (default `0 2 * * *`) |
| `BACKUP_EMAIL_CRON_SCHEDULE` | Email schedule (default `0 3 * * 0`) |
| `GPG_DIR` | Path to the GPG directory (default `./gpg`) |
| `JWT_DIR` | Path to the JWT directory (default `./jwt`) |

Example overrides:

```bash
BACKUP_DAYS=7
BACKUP_EMAIL_TO=admin@example.com
# BACKUP_DB_CONTAINER=mariadb
# BACKUP_CRON_SCHEDULE="0 2 * * *"
# BACKUP_EMAIL_CRON_SCHEDULE="0 3 * * 0"
```

For SMTP with a self-signed certificate, `.env` often disables strict TLS verification (as in `.env.example`); in production prefer a trusted CA.

---

## Backup workflow

1. Load variables from `.env`.
2. Timestamp for file names.
3. Create working directories if needed.
4. Database dump (`mysqldump` on the host, or via `docker exec` when `BACKUP_DB_CONTAINER` is set).
5. Copy `gpg/` and `jwt/`.
6. Record Docker version (reference).
7. Pack everything into `.tar.gz` under `backups/`.
8. Remove temporary files.
9. Delete archives older than `BACKUP_DAYS`.

Manual run:

```bash
./scripts/backup.sh
```

---

## Cron

Recommended: **`scripts/install-cron.sh`**. Defaults:

- **backup** — daily at 02:00
- **send-backup-email** — Sundays at 03:00

```bash
./scripts/install-cron.sh
```

Custom schedules (minute hour day-of-month month day-of-week):

```bash
./scripts/install-cron.sh '0 3 * * *' '0 4 * * 1'
```

Verify:

```bash
crontab -l
```

---

## Logs

Each run writes a log next to the archive: same basename, **`.log`** extension. The log includes start/end time, steps, and duration.

Example excerpt:

```
2024-12-01 23:00:01: Script started at: 2024-12-01 23:00:01
2024-12-01 23:00:01: Creating a database backup...
...
2024-12-01 23:00:11: Execution time: 10 seconds.
```

---

## Emailing the latest archive

**`scripts/send-backup-email.sh`** picks the **newest** `.tar.gz` in `backups/` and sends it to `BACKUP_EMAIL_TO` using `EMAIL_TRANSPORT_DEFAULT_*` and `EMAIL_DEFAULT_FROM` from `.env`.

```bash
./scripts/send-backup-email.sh
```

Requires Python 3 and working SMTP variables. Equivalent: `make send-backup-email`.

---

## Retention

Archives older than **`BACKUP_DAYS`** days are removed automatically after a successful new backup. Adjust `BACKUP_DAYS` or copy archives to remote storage if you need longer retention or more disk headroom.
