# Backup Script Documentation

This script performs a backup of a database and specific directories (`gpg` and `jwt`). It then archives them into a `.tar.gz` file, logs the output, and automatically removes old backups based on a user-defined retention period.

## Table of Contents

1. [Requirements](#requirements)
2. [Setup](#setup)
3. [Environment Variables](#environment-variables)
4. [Script Workflow](#script-workflow)
5. [Cron Job](#cron-job)
6. [Log File](#log-file)
7. [Retention Policy](#retention-policy)

---

## Requirements

- **Linux** or compatible Unix system.
- `mysqldump` for database backups.
- Docker installed on the system.
- Bash shell (`/bin/bash`).
- Cron for scheduling.

---

## Setup
0. Install mariadb-client is it's not presented 
   ```bash
   sudo apt install mariadb-client
   ```
1. Clone or copy the backup script into a directory (e.g., `/dockers/pass`).
2. Make the script executable:
    ```bash
    chmod +x backup.sh
    ```
3. Set up environment variables in a `.env` file in the script directory.

---

## Environment Variables

The script uses the following environment variables from a `.env` file:

| Variable                    | Description                                   |
| --------------------------- | --------------------------------------------- |
| `DATASOURCES_DEFAULT_HOST`   | Database host (e.g., `localhost`, `mariadb`). |
| `DATASOURCES_DEFAULT_PORT`   | Database port (e.g., `3306`).                 |
| `DATASOURCES_DEFAULT_USERNAME` | Database username.                          |
| `DATASOURCES_DEFAULT_PASSWORD` | Database password.                          |
| `DATASOURCES_DEFAULT_DATABASE` | Name of the database to back up.            |
| `GPG_DIR`                    | Path to the `gpg` directory.                  |
| `JWT_DIR`                    | Path to the `jwt` directory.                  |
| `DOCKER_PATH`                | Path where `.env` and `docker-compose.yaml` are located. |
| `BACKUP_DAYS`                | Retention period in days for old backups.     |

Example `.env` file:
```bash
DATASOURCES_DEFAULT_HOST=mariadb
DATASOURCES_DEFAULT_PORT=3306
DATASOURCES_DEFAULT_USERNAME=pass
DATASOURCES_DEFAULT_PASSWORD=pass
DATASOURCES_DEFAULT_DATABASE=pass
GPG_DIR=/dockers/pass/gpg
JWT_DIR=/dockers/pass/jwt
DOCKER_PATH=/dockers/pass
BACKUP_DAYS=7
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

To automate the backup process, add the following entry to the system's `cron`:

```bash
0 23 * * * cd /dockers/pass && ./backup.sh
```

- This command runs the script every day at **23:00**.

To add it:
1. Open the crontab editor:
    ```bash
    crontab -e
    ```
2. Add the line, save, and exit.

To check the scheduled jobs:
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

## Retention Policy

The script automatically removes backup files older than the number of days specified in `BACKUP_DAYS`.  

**Example**:  
If `BACKUP_DAYS=7`, backups older than 7 days will be deleted.

---

## License

This script is distributed under the MIT License. Use it at your own risk.
