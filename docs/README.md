# Documentation

Central index: jump to detailed topics or the root [README](../README.md).

---

## Where to start

1. [Project README](../README.md) — requirements, getting started, `.env`, and pointers to everything else.
2. **Make** shortcuts (`make help`, backups, Cake, etc.) — [make.md](make.md).
3. **Nginx** reverse proxy — [fix-update.md](fix-update.md) and example config [nginx.passbolt.example.conf](nginx.passbolt.example.conf).
4. **Backups** and emailing archives — [backup.md](backup.md).

---

## Scripts (`scripts/`)

Paths are relative to the **repository root**. Before first use: `chmod +x scripts/*.sh`.

| Script | Purpose |
|--------|---------|
| [backup.sh](../scripts/backup.sh) | DB dump, copies of `gpg/`, `jwt/`, `.env`, `docker-compose.yaml`; archive under `backups/` |
| [send-backup-email.sh](../scripts/send-backup-email.sh) | Email the **latest** `.tar.gz` in `backups/` to `BACKUP_EMAIL_TO` |
| [install-cron.sh](../scripts/install-cron.sh) | Append crontab lines for backup and send-backup-email |
| [generate_recovery_url.sh](../scripts/generate_recovery_url.sh) | Recovery link from username and `.env` |
| [list_users.sh](../scripts/list_users.sh) | List users from the database (id, email, name, role, active) |
| [entrypoint-wrapper.sh](../scripts/entrypoint-wrapper.sh) | Before Passbolt starts: `update-ca-certificates` when a CA is mounted (see [fix-update.md](fix-update.md)) |

Makefile equivalents (from repo root): see **[make.md](make.md)** or run `make help`.

---

## Documents in `docs/`

| File | Contents |
|------|----------|
| [make.md](make.md) | Using **Make**: prerequisites, `make help`, all targets, `RECIPIENT` / `ARGS` / `CMD` / … |
| [backup.md](backup.md) | Requirements, `.env` variables, backup flow, cron, logs, retention |
| [fix-update.md](fix-update.md) | Nginx reverse proxy (setup, headers, `.env`), troubleshooting |
| [nginx.passbolt.example.conf](nginx.passbolt.example.conf) | **Example** `server` / `upstream` for TLS termination and proxy to Passbolt |

---

## External resources

- [Passbolt CE](https://www.passbolt.com/)
- [Passbolt documentation](https://www.passbolt.com/docs)
- [Server GPG key setup](https://www.passbolt.com/docs/configure/gpg)
