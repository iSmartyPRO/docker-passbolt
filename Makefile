# Passbolt CE — CLI via docker compose (service `passbolt` in docker-compose.yaml)
# Requires: .env in repo root and the `docker compose` command.

COMPOSE := docker compose
SERVICE := passbolt
# CakePHP commands as www-data (per Passbolt docs)
CAKE := /usr/share/php/passbolt/bin/cake

.DEFAULT_GOAL := help

.PHONY: help up down restart ps logs logs-f pull shell shell-root \
	healthcheck version cache-clear migrate send-test-email register-user cake \
	recovery-url list-users backup send-backup-email gpg-import network-create exec-root

help: ## Show this help
	@echo "Passbolt Docker — make targets"
	@echo ""
	@grep -E '^[a-zA-Z0-9_.-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make send-test-email RECIPIENT=you@example.com"
	@echo "  make register-user ARGS='-u admin@x.com -f Admin -l User -r admin'"
	@echo "  make recovery-url RECOVERY_EMAIL=user@example.com [RECOVERY_HOST=pass.example.com]"
	@echo "  make cake CAKE_ARGS=\"passbolt healthcheck --verbose\""

up: ## Start stack (docker compose up -d)
	$(COMPOSE) up -d

down: ## Stop and remove containers
	$(COMPOSE) down

restart: ## Restart passbolt service
	$(COMPOSE) restart $(SERVICE)

ps: ## Compose project container status
	$(COMPOSE) ps

logs: ## Last 100 lines of passbolt logs
	$(COMPOSE) logs --tail=100 $(SERVICE)

logs-f: ## Follow passbolt logs (Ctrl+C to exit)
	$(COMPOSE) logs -f $(SERVICE)

pull: ## Pull passbolt image and recreate container
	$(COMPOSE) pull $(SERVICE)
	$(COMPOSE) up -d $(SERVICE)

shell: ## Interactive shell as www-data in container
	$(COMPOSE) exec $(SERVICE) su -m -s /bin/sh www-data

shell-root: ## Interactive shell as root (debugging)
	$(COMPOSE) exec $(SERVICE) /bin/sh

exec-root: ## Run command as root: make exec-root CMD="ls -la /etc/passbolt"
	@test -n "$(CMD)" || (echo 'Set CMD, e.g. make exec-root CMD="ls -la"' >&2; exit 1)
	$(COMPOSE) exec $(SERVICE) sh -lc '$(CMD)'

healthcheck: ## Passbolt health check (cake passbolt healthcheck)
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) passbolt healthcheck" -s /bin/sh www-data

version: ## Show Passbolt version
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) passbolt version" -s /bin/sh www-data

cache-clear: ## Clear application cache
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) cache clear_all" -s /bin/sh www-data

migrate: ## Run DB migrations (cake passbolt migrate)
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) passbolt migrate" -s /bin/sh www-data

send-test-email: ## SMTP test: make send-test-email RECIPIENT=email@example.com
	@test -n "$(RECIPIENT)" || (echo 'Set RECIPIENT=email@example.com' >&2; exit 1)
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) passbolt send_test_email --recipient=$(RECIPIENT)" -s /bin/sh www-data

register-user: ## Register user: make register-user ARGS='-u ... -f ... -l ... -r admin|user'
	@test -n "$(ARGS)" || (echo 'Set ARGS, e.g. make register-user ARGS="-u a@b.com -f A -l B -r admin"' >&2; exit 1)
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) passbolt register_user $(ARGS)" -s /bin/sh www-data

cake: ## Arbitrary cake command: make cake CAKE_ARGS="passbolt status"
	@test -n "$(CAKE_ARGS)" || (echo 'Set CAKE_ARGS, e.g. make cake CAKE_ARGS="passbolt healthcheck"' >&2; exit 1)
	$(COMPOSE) exec -T $(SERVICE) su -m -c "$(CAKE) $(CAKE_ARGS)" -s /bin/sh www-data

recovery-url: ## Recovery URL: optional RECOVERY_HOST= and RECOVERY_EMAIL=, else interactive
	@if [ -n "$(RECOVERY_EMAIL)" ] && [ -n "$(RECOVERY_HOST)" ]; then \
		./scripts/generate_recovery_url.sh --host="$(RECOVERY_HOST)" --user="$(RECOVERY_EMAIL)"; \
	elif [ -n "$(RECOVERY_EMAIL)" ]; then \
		./scripts/generate_recovery_url.sh "$(RECOVERY_EMAIL)"; \
	else \
		./scripts/generate_recovery_url.sh; \
	fi

list-users: ## List users (id, email, name, role, active) from database
	./scripts/list_users.sh

backup: ## Local backup (scripts/backup.sh)
	./scripts/backup.sh

send-backup-email: ## Email latest backup to BACKUP_EMAIL_TO from .env
	./scripts/send-backup-email.sh

gpg-import: ## Import private key from /etc/passbolt/gpg/serverkey_private.asc (inside container)
	$(COMPOSE) exec -T $(SERVICE) su -m -c "gpg --home /var/lib/passbolt/.gnupg --import /etc/passbolt/gpg/serverkey_private.asc" -s /bin/sh www-data

network-create: ## Create external DOCKER_NETWORK_NAME from .env if missing
	@bash -c 'set -e; set -a; source .env; set +a; \
		if docker network inspect "$$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then \
			echo "Network already exists: $$DOCKER_NETWORK_NAME"; \
		else \
			docker network create "$$DOCKER_NETWORK_NAME"; \
			echo "Created network: $$DOCKER_NETWORK_NAME"; \
		fi'
