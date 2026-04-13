# Passbolt CE (Docker)

Docker-развёртывание **Passbolt Community Edition** — менеджера паролей для команд с общими хранилищами, шифрованием и веб-интерфейсом.

---

## Кратко

- **Что это:** Passbolt CE в Docker (официальный образ `passbolt/passbolt:latest-ce`).
- **Нужно:** MariaDB/MySQL, SMTP-сервер для писем, GPG-ключ сервера, сеть Docker (или host).
- **Запуск:** скопировать `.env.example` → `.env`, заполнить переменные, выполнить `docker compose up -d`.

---

## Требования

- Docker и Docker Compose (v2)
- Доступная БД: MariaDB или MySQL (отдельный контейнер или хост)
- SMTP-сервер для отправки писем (приглашения, восстановление, уведомления)
- Внешняя сеть Docker: по умолчанию используется сеть с именем из `DOCKER_NETWORK_NAME` (должна существовать при `external: true`)

---

## Структура проекта

```
pass/
├── .env.example      # Пример переменных окружения (скопировать в .env)
├── .env              # Локальная конфигурация (не коммитить, см. .gitignore)
├── docker-compose.yaml
├── scripts/                # Скрипты: backup, send-backup-email, install-cron, generate_recovery_url, entrypoint-wrapper
├── gpg/              # GPG-ключи (серверный ключ и т.д.)
├── jwt/              # JWT-ключи
├── ssl/
│   └── custom.crt    # Опционально: свой CA-сертификат (или путь в SSL_CA_CERT_PATH)
├── docs/             # Документация (см. docs/README.md)
└── README.md
```

Все чувствительные параметры (БД, почта, URL, сеть) задаются через `.env`; в репозитории лежит только `.env.example`.

---

## Инструкция по запуску

### 1. Клонирование и подготовка конфигурации

```bash
cd /path/to/repo/pass
cp .env.example .env
```

Отредактируйте `.env`: укажите свои значения для БД, почты, URL и (при необходимости) сети и пути к CA-сертификату.

### 2. Каталоги и права (Linux)

Создайте каталоги для данных Passbolt и задайте владельца (на хосте обычно `www-data` или ваш пользователь; в контейнере Passbolt может работать от своего пользователя):

```bash
mkdir -p gpg jwt
# На Linux, если контейнер использует www-data:
sudo chown -R 33:33 gpg jwt
```

*(UID 33 часто соответствует `www-data`. При сомнениях проверьте пользователя внутри контейнера.)*

### 3. GPG-ключ сервера

Сгенерируйте или импортируйте GPG-ключ сервера Passbolt и положите файлы в `gpg/`. В `.env` укажите отпечаток этого ключа в переменной `PASSBOLT_GPG_SERVER_KEY_FINGERPRINT`. Без корректного ключа и отпечатка приложение не запустится.

**Как получить значение для `PASSBOLT_GPG_SERVER_KEY_FINGERPRINT`:** это не отдельная генерация, а отпечаток уже существующей пары ключей — 40 шестнадцатеричных символов без пробелов (удобно в верхнем регистре, как ожидает Passbolt). Если публичный ключ лежит в `gpg/serverkey.asc`, из корня репозитория выполните:

```bash
gpg --show-keys --with-fingerprint --with-colons gpg/serverkey.asc | grep '^fpr:'
```

В выводе будет строка вида `fpr:::::::::XXXXXXXX...XXXXXXXX:` — скопируйте среднюю часть (40 символов `0-9A-F`) в `.env`. Тот же отпечаток должен соответствовать `gpg/serverkey_private.asc`; при необходимости проверьте той же командой по файлу приватного ключа или через `gpg --list-secret-keys --with-fingerprint` после импорта ключа.

Подробности: [официальная документация Passbolt — серверный ключ](https://www.passbolt.com/docs/configure/gpg).

### 4. Сеть Docker

Если в `docker-compose.yaml` используется внешняя сеть (`external: true`), создайте её до первого запуска:

```bash
docker network create docker-lan
```

Имя сети должно совпадать с `DOCKER_NETWORK_NAME` в `.env`.

### 5. Запуск

```bash
docker compose up -d
```

Проверка логов:

```bash
docker compose logs -f
```

### 6. Первый пользователь (администратор)

После успешного старта зарегистрируйте первого пользователя (обычно admin):

```bash
docker exec -it pass su -m -c "/usr/share/php/passbolt/bin/cake passbolt register_user -u admin@example.com -f Admin -l User -r admin" -s /bin/sh www-data
```

Далее войдите в веб-интерфейс по `APP_FULL_BASE_URL` (или `PASSBOLT_FULL_BASE_URL`) и завершите настройку по инструкциям в браузере.

### 7. Остановка и удаление

```bash
docker compose down
```

Для удаления вместе с томами (осторожно, данные БД не в этом проекте):

```bash
docker compose down -v
```

---

## Конфигурация (.env)

Основные переменные:

| Переменная | Описание |
|------------|----------|
| `APP_FULL_BASE_URL` | Публичный URL приложения (например `https://pass.example.com`) |
| `PASSBOLT_FULL_BASE_URL` | То же значение для Passbolt |
| `DATASOURCES_DEFAULT_*` | Хост, порт, пользователь, пароль и имя БД |
| `EMAIL_DEFAULT_FROM`, `EMAIL_TRANSPORT_DEFAULT_*` | От кого и через какой SMTP отправлять письма |
| `PASSBOLT_GPG_SERVER_KEY_FINGERPRINT` | Отпечаток GPG-ключа сервера |
| `DOCKER_NETWORK_NAME` | Имя внешней Docker-сети |
| `SSL_CA_CERT_PATH` | Путь к файлу CA-сертификата (опционально; по умолчанию используется `./ssl/custom.crt`) |

Для SMTP-серверов с самоподписанным или внутренним сертификатом в примере отключена проверка SSL:

- `PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_VERIFY_PEER=false`
- `PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_ALLOW_SELF_SIGNED=true`

В продакшене с доверенным сертификатом лучше включить проверку и при необходимости задать `PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_CAFILE`.

---

## Полезные команды

Везде ниже контейнер предполагается с именем `pass` (или как задано в `DOCKER_CONTAINER_NAME`).

**Версия Passbolt:**

```bash
docker exec pass su -m -c "/usr/share/php/passbolt/bin/cake passbolt version" -s /bin/sh www-data
```

**Проверка здоровья:**

```bash
docker exec pass su -m -c "/usr/share/php/passbolt/bin/cake passbolt healthcheck" -s /bin/sh www-data
```

**Тестовое письмо:**

```bash
docker exec pass su -m -c "/usr/share/php/passbolt/bin/cake passbolt send_test_email --recipient=your@email.com" -s /bin/sh www-data
```

**Очистка кэша:**

```bash
docker exec pass su -m -c "/usr/share/php/passbolt/bin/cake cache clear_all" -s /bin/sh www-data
```

**Импорт серверного GPG-ключа:**

```bash
docker exec pass su -m -c "gpg --home /var/lib/passbolt/.gnupg --import /etc/passbolt/gpg/serverkey_private.asc" -s /bin/sh www-data
```

**Миграции БД вручную:**

```bash
docker exec pass su -m -c "/usr/share/php/passbolt/bin/cake passbolt migrate" -s /bin/sh www-data
```

---

## Если не работает почта (восстановление доступа)

Passbolt отправляет ссылки для входа и восстановления по email. Если почта не настроена или письма не доходят, можно получить ссылку восстановления через скрипт или вручную по БД.

**Через скрипт** (контейнер БД должен быть доступен по имени из `DATASOURCES_DEFAULT_HOST`):
```bash
./scripts/generate_recovery_url.sh passboltUrl=pass.example.com username=admin@example.com
```

**Вручную по БД:**
1. Подключитесь к БД (например, `mysql -u ... -p -h ... database_name`).
2. Узнайте `id` пользователя: `SELECT id, username FROM users;`
3. Получите токен восстановления:
   ```sql
   SELECT user_id, token FROM authentication_tokens
   WHERE user_id = '<user_id>' AND type = 'recover'
   ORDER BY created DESC LIMIT 1;
   ```
4. Соберите ссылку:
   `https://pass.example.com/setup/recover/<user_id>/<token>?case=default`

Важно: для нормальной работы нужен рабочий SMTP (см. раздел конфигурации и тестовое письмо выше).

---

## Бэкапы

Описание скрипта и процедуры бэкапов см. в [docs/backup.md](docs/backup.md).

---

## Документация

Полный список документов и ссылки — в [docs/README.md](docs/README.md):

- [docs/backup.md](docs/backup.md) — бэкапы, отправка на почту, cron (`backup.sh`, `send-backup-email.sh`, `install-cron.sh`)
- [docs/fix-update.md](docs/fix-update.md) — исправления при работе за reverse proxy (nginx)

---

## Лицензия и документация

- Passbolt CE: [passbolt.com](https://www.passbolt.com/)  
- Документация: [passbolt.com/docs](https://www.passbolt.com/docs)
