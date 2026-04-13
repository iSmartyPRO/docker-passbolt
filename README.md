# Passbolt CE (Docker)

[![Docker Compose](https://img.shields.io/badge/stack-Docker%20Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Passbolt CE](https://img.shields.io/badge/Passbolt-Community%20Edition-orange)](https://www.passbolt.com/)

Production-ready [Passbolt](https://www.passbolt.com/) Community Edition on Docker Compose: external MySQL/MariaDB, SMTP, GPG/JWT volumes, optional CA trust for health checks behind TLS, backup scripts, and a `Makefile` for common operations.

| Document | Purpose |
|----------|---------|
| This file | Quick start, repository layout, `.env` variables, commands |
| [docs/README.md](docs/README.md) | Documentation and scripts index |
| [docs/make.md](docs/make.md) | **Make**: targets, variables, prerequisites |
| [docs/backup.md](docs/backup.md) | Backups, cron, emailing archives |
| [docs/fix-update.md](docs/fix-update.md) | **Nginx** reverse proxy: setup, example config, troubleshooting |
| [docs/nginx.passbolt.example.conf](docs/nginx.passbolt.example.conf) | Example nginx `server` / `upstream` for Passbolt |

---

## Table of contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Repository layout](#repository-layout)
- [Configuration (`.env`)](#configuration-env)
- [Operations: Makefile and Docker](#operations-makefile-and-docker)
- [Recovery without working email](#recovery-without-working-email)
- [Backups](#backups)
- [Security](#security)
- [Links](#links)

---

## Requirements

- Docker and Docker Compose v2
- **MariaDB** or **MySQL** (separate container or host)
- **SMTP** for invitations, recovery, and notifications
- External Docker network if `docker-compose.yaml` uses `external: true` (name from `DOCKER_NETWORK_NAME`)

---

## Quick start

```bash
git clone https://github.com/iSmartyPRO/docker-passbolt.git
cd docker-passbolt
cp .env.example .env
```

The directory created by `git clone` matches the repository name; `cd` into that folder if yours differs.

1. Edit `.env` (database, mail, public URL, GPG fingerprint — see [Configuration](#configuration-env)).
2. Create key directories and ownership:

   ```bash
   mkdir -p gpg jwt
   sudo chown -R 33:33 gpg jwt
   ```

   UID `33` often maps to `www-data` in the image; verify the user inside the container if unsure.

3. Place server GPG material under `gpg/` and set `PASSBOLT_GPG_SERVER_KEY_FINGERPRINT`. Details: [Passbolt docs — GPG](https://www.passbolt.com/docs/configure/gpg).

4. Create the external network (if used):

   ```bash
   docker network create docker-lan
   ```

   The name must match `DOCKER_NETWORK_NAME` in `.env`, or run `make network-create` from the repository root.

5. Start the stack:

   ```bash
   docker compose up -d
   ```

   Logs: `docker compose logs -f` or `make logs-f`.

6. Register the first user (admin). Use the container name from `DOCKER_CONTAINER_NAME` (default `pass`):

   ```bash
   docker exec -it pass su -m -c "/usr/share/php/passbolt/bin/cake passbolt register_user -u admin@example.com -f Admin -l User -r admin" -s /bin/sh www-data
   ```

   Equivalent: `make register-user ARGS='-u admin@example.com -f Admin -l User -r admin'`.

Stop: `docker compose down` or `make down`. This compose file does not define Passbolt data volumes; database data lives on your DB server.

---

## Repository layout

```
.
├── .env.example          # Sample variables (copy to .env)
├── .env                  # Local config (do not commit)
├── docker-compose.yaml   # passbolt service, external network
├── Makefile              # Targets: up, healthcheck, backup, recovery-url, …
├── scripts/
│   ├── backup.sh
│   ├── send-backup-email.sh
│   ├── install-cron.sh
│   ├── generate_recovery_url.sh
│   ├── list_users.sh
│   └── entrypoint-wrapper.sh   # Trust CA at startup (see docs/fix-update.md)
├── gpg/                  # Server GPG keys
├── jwt/                  # JWT keys
├── ssl/
│   └── custom.crt        # Optional: CA for the container (or path via SSL_CA_CERT_PATH)
├── backups/              # Backup archives (created by the script)
└── docs/                 # More documentation → docs/README.md
```

---

## Configuration (`.env`)

| Variable | Description |
|----------|-------------|
| `APP_FULL_BASE_URL`, `PASSBOLT_FULL_BASE_URL` | Public HTTPS URL of the instance |
| `DOCKER_CONTAINER_NAME` | Container name for `docker exec` (examples in this README) |
| `DOCKER_HTTP_PORT`, `DOCKER_HTTPS_PORT` | Published ports on the host |
| `DATASOURCES_DEFAULT_*` | DB host, port, user, password, database name |
| `EMAIL_DEFAULT_*`, `EMAIL_TRANSPORT_DEFAULT_*` | From address and SMTP |
| `PASSBOLT_GPG_SERVER_KEY_FINGERPRINT` | Server GPG fingerprint (required) |
| `DOCKER_NETWORK_NAME` | External Docker network name |
| `SSL_CA_CERT_PATH` | Host path to a CA file (default `./ssl/custom.crt`), mounted for TLS trust during checks |
| `PASSBOLT_SSL_FORCE`, `PASSBOLT_TRUST_PROXY`, `PASSBOLT_SECURITY_PROXIES_ACTIVE` | Behind a reverse proxy — see [docs/fix-update.md](docs/fix-update.md) |

**GPG fingerprint** for a public key in `gpg/serverkey.asc`:

```bash
gpg --show-keys --with-fingerprint --with-colons gpg/serverkey.asc | grep '^fpr:'
```

Copy the 40 hex characters from the fingerprint field into `.env`.

For SMTP with a self-signed or internal certificate, the sample relaxes TLS verification; in production with a trusted CA, enable verification and set `PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_CAFILE` if needed (see Passbolt documentation).

---

## Operations: Makefile and Docker

From the repository root (with `.env` filled in), run **`make`** or **`make help`** for a built-in list of targets.

Full reference (every target, command-line variables such as `RECIPIENT`, `ARGS`, `CAKE_ARGS`, `RECOVERY_EMAIL`, `CMD`): **[docs/make.md](docs/make.md)**.

Direct `docker compose exec` (Compose service name is `passbolt`; container name comes from `.env`):

```bash
docker compose exec passbolt su -m -c "/usr/share/php/passbolt/bin/cake passbolt healthcheck" -s /bin/sh www-data
docker compose exec passbolt su -m -c "/usr/share/php/passbolt/bin/cake passbolt send_test_email --recipient=you@example.com" -s /bin/sh www-data
```

---

## Recovery without working email

If mail is broken, generate a recovery link with the script (the DB host from `.env` must resolve and be reachable):

```bash
./scripts/generate_recovery_url.sh admin@example.com
# override public host (https:// added if you omit the scheme):
./scripts/generate_recovery_url.sh --host=pass.example.com --user=admin@example.com
```

Or use `make recovery-url` (interactive, or `RECOVERY_EMAIL=…`, optional `RECOVERY_HOST=…`). For manual DB steps, see [Passbolt documentation](https://www.passbolt.com/docs) and community resources.

---

## Backups

Full details on variables, cron, and emailing archives: **[docs/backup.md](docs/backup.md)**.

In short: `./scripts/backup.sh` writes an archive under `backups/`; `scripts/install-cron.sh` can install crontab entries.

---

## Security

- Do not commit `.env` or secrets; only `.env.example` belongs in the repo.
- Restrict filesystem permissions on `gpg/`, `jwt/`, and backup files on the host.
- Use trusted TLS certificates and deliberate SMTP verification settings in production.

---

## Links

- [Passbolt CE](https://www.passbolt.com/)
- [Passbolt documentation](https://www.passbolt.com/docs)
- Documentation index for this repo: [docs/README.md](docs/README.md)

Documentation and script improvements are welcome via **Issues** and **Pull requests**.

Configuration and helper scripts in this repository are provided as part of the project; **Passbolt CE** itself is licensed by Passbolt SA.
