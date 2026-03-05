# Документация Passbolt CE (Docker)

Оглавление всей документации проекта.

---

## Скрипты (`scripts/`)

| Скрипт | Назначение |
|--------|------------|
| `backup.sh` | Резервная копия: дамп БД, каталоги gpg/jwt, архив в `backups/` |
| `send-backup-email.sh` | Отправка последнего бэкапа на почту (адрес в `BACKUP_EMAIL_TO`) |
| `install-cron.sh` | Добавить в crontab запуск backup (ежедневно) и send-backup-email (еженедельно) |
| `generate_recovery_url.sh` | Получить ссылку восстановления доступа по email пользователя |
| `entrypoint-wrapper.sh` | Обёртка entrypoint контейнера (добавление CA-сертификата для healthcheck) |

Перед использованием: `chmod +x scripts/*.sh`.

---

## Основные материалы

| Документ | Описание |
|----------|----------|
| [**README проекта**](../README.md) | Краткое описание, требования, инструкция по запуску, конфигурация `.env`, полезные команды, восстановление доступа |

---

## Дополнительная документация

| Документ | Описание |
|----------|----------|
| [**backup.md**](backup.md) | Скрипт бэкапов: настройка, переменные окружения, cron, отправка на почту, политика хранения |
| [**fix-update.md**](fix-update.md) | Исправления при работе за reverse proxy (nginx): healthcheck, YAML, ERR_TOO_MANY_REDIRECTS |

---

## Внешние ссылки

- [Passbolt CE](https://www.passbolt.com/)
- [Документация Passbolt](https://www.passbolt.com/docs)
- [Настройка GPG-ключа сервера](https://www.passbolt.com/docs/configure/gpg)
