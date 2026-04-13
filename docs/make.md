# Using GNU Make with this project

The [Makefile](../Makefile) wraps **`docker compose`** and a few **shell scripts** so you can run common tasks from the repository root without typing long `docker compose exec …` lines.

**See also:** [Documentation index](README.md) · [Root README](../README.md) · [backup.md](backup.md) (backup-related targets)

---

## Table of contents

1. [Prerequisites](#prerequisites)
2. [How to list targets](#how-to-list-targets)
3. [Targets reference](#targets-reference)
4. [Variables you pass on the command line](#variables-you-pass-on-the-command-line)
5. [Notes](#notes)

---

## Prerequisites

- **GNU Make** (`make`) — usually preinstalled on Linux and macOS.
- **Docker Compose v2** as the `docker compose` CLI (not legacy `docker-compose` unless you symlink it).
- A populated **`.env`** in the **repository root** (same directory as `Makefile` and `docker-compose.yaml`). Targets that talk to the Passbolt container expect the stack to be up and healthy; script targets (`backup`, `list-users`, `recovery-url`, etc.) also rely on `.env` and host/network access as described in each script’s documentation.

Run all `make` commands from the repository root:

```bash
cd /path/to/docker-passbolt
make help
```

---

## How to list targets

The default goal is **`help`**, so plain `make` prints the same as `make help`: a sorted list of targets and their short descriptions (from `##` comments in the Makefile), plus a few usage examples.

```bash
make
# or
make help
```

For the exact commands Make runs, open [Makefile](../Makefile) in an editor.

---

## Targets reference

Compose **service name** is always **`passbolt`** (see `SERVICE` in the Makefile). Your **container name** on the Docker host is still whatever you set in **`DOCKER_CONTAINER_NAME`** in `.env`; Compose resolves the service to that container.

### Stack lifecycle

| Target | What it does |
|--------|----------------|
| `up` | `docker compose up -d` — start the project |
| `down` | `docker compose down` — stop and remove containers |
| `restart` | Restart the `passbolt` service |
| `ps` | `docker compose ps` |
| `pull` | Pull the Passbolt image and recreate the `passbolt` service |
| `network-create` | If `DOCKER_NETWORK_NAME` from `.env` does not exist, run `docker network create …` |

### Logs and shells

| Target | What it does |
|--------|----------------|
| `logs` | Last 100 lines of the `passbolt` service logs |
| `logs-f` | Follow `passbolt` logs (Ctrl+C to stop) |
| `shell` | Interactive shell as **`www-data`** inside the container |
| `shell-root` | Interactive shell as **root** (debugging) |
| `exec-root` | Run a single command as root — requires **`CMD=…`** (see [variables](#variables-you-pass-on-the-command-line)) |

### Passbolt / Cake (as `www-data`)

These use **`docker compose exec -T`** (no TTY), suitable for scripts and CI.

| Target | What it does |
|--------|----------------|
| `healthcheck` | `cake passbolt healthcheck` |
| `version` | `cake passbolt version` |
| `cache-clear` | `cake cache clear_all` |
| `migrate` | `cake passbolt migrate` |
| `send-test-email` | SMTP test — requires **`RECIPIENT=email@example.com`** |
| `register-user` | Register a user — requires **`ARGS='…'`** (Passbolt CLI flags) |
| `cake` | Arbitrary Cake command — requires **`CAKE_ARGS="…"`** |
| `gpg-import` | Import `/etc/passbolt/gpg/serverkey_private.asc` into the app’s GnuPG home |

### Host scripts (same as `./scripts/…`)

| Target | Script / behavior |
|--------|---------------------|
| `recovery-url` | `./scripts/generate_recovery_url.sh` — optional **`RECOVERY_EMAIL=`**, **`RECOVERY_HOST=`** |
| `list-users` | `./scripts/list_users.sh` |
| `backup` | `./scripts/backup.sh` |
| `send-backup-email` | `./scripts/send-backup-email.sh` |

---

## Variables you pass on the command line

Use **`make TARGET VAR=value`** (no spaces around `=`). Quote values that contain spaces.

| Variable | Used by | Example |
|----------|---------|---------|
| `RECIPIENT` | `send-test-email` | `make send-test-email RECIPIENT=you@example.com` |
| `ARGS` | `register-user` | `make register-user ARGS='-u admin@x.com -f Admin -l User -r admin'` |
| `CAKE_ARGS` | `cake` | `make cake CAKE_ARGS="passbolt healthcheck --verbose"` |
| `RECOVERY_EMAIL` | `recovery-url` | With optional `RECOVERY_HOST`: `make recovery-url RECOVERY_HOST=pass.example.com RECOVERY_EMAIL=user@example.com` |
| `RECOVERY_HOST` | `recovery-url` | Public host for the recovery link when not using `.env` base URL (requires `RECOVERY_EMAIL`) |
| `CMD` | `exec-root` | `make exec-root CMD="ls -la /etc/passbolt"` |

---

## Notes

- **Interactive vs non-interactive:** `shell`, `shell-root`, and `logs-f` attach to a TTY; most other targets use `-T` and are non-interactive.
- **Backups and email:** `backup` / `send-backup-email` need the same `.env` and host tools as the underlying scripts — see [backup.md](backup.md).
- **Changing Compose or service names:** If you rename the service in `docker-compose.yaml`, update `SERVICE := passbolt` in the Makefile or the exec targets will break.
