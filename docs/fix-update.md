# Исправления настройки Passbolt (pass.railway.kg)

Описание изменений, выполненных для корректной работы Passbolt в Docker за reverse proxy (nginx).

**См. также:** [Оглавление документации](README.md) · [Основной README](../README.md)

---

## 1. Ошибка healthcheck: «Could not reach the /healthcheck/status»

**Проблема:** При запуске `passbolt healthcheck` падала проверка доступности URL — из-за самоподписанного/недоверенного сертификата и проверки SSL из контейнера.

**Сделано:**

- **Монтирование сертификата в контейнер**  
  Файл `../nginx/server/conf.d/ssl/wildcard.railway.kg.crt` подмонтирован в  
  `/usr/local/share/ca-certificates/railway.kg.crt`, чтобы система внутри контейнера доверяла HTTPS при обращении к `https://pass.railway.kg`.

- **Скрипт-обёртка entrypoint** (`scripts/entrypoint-wrapper.sh`)  
  При старте контейнера вызывается `update-ca-certificates`, затем выполняется штатный entrypoint (wait-for + docker-entrypoint). Так сертификат попадает в системное хранилище доверенных CA.

- **Переменная окружения**  
  `PASSBOLT_CHECK_DOMAIN_MISMATCH: "false"` — чтобы не падать из-за несовпадения имени в сертификате при проверках.

**В `docker-compose.yaml`:**
- добавлен `entrypoint: ["/entrypoint-wrapper.sh"]`;
- volumes: сертификат и `scripts/entrypoint-wrapper.sh` смонтированы, скрипт должен быть исполняемым (`chmod +x scripts/entrypoint-wrapper.sh`).

---

## 2. Ошибка парсинга docker-compose: «did not find expected key»

**Проблема:** При `docker compose down/up` — ошибка YAML: неверные отступы у ключей `volumes`, `command`, `ports`.

**Сделано:** Выровняны отступы: все ключи сервиса `passbolt` (включая `volumes`, `command`, `ports`) имеют отступ 4 пробела; элементы списков под ними — 6 пробелов.

---

## 3. Ошибка в браузере: ERR_TOO_MANY_REDIRECTS

**Проблема:** При открытии https://pass.railway.kg в браузере — «Слишком много переадресаций». Причина: SSL обрывается на nginx, до контейнера запрос доходит по HTTP; при включённом принудительном HTTPS Passbolt редиректит на HTTPS снова и снова → цикл редиректов.

**Сделано:**

### 3.1. Nginx (`/dockers/nginx/server/conf.d/pass.railway.kg.conf`)

- Для прокси добавлены заголовки:
  - `X-Forwarded-Proto $scheme` (чтобы бэкенд знал, что клиент зашёл по HTTPS);
  - `Forwarded "proto=$scheme;host=$host"` (стандартный заголовок для прокси).
- Отступы в `location /` приведены к единому виду.

### 3.2. Переменные окружения Passbolt (docker-compose)

- **`PASSBOLT_SECURITY_PROXIES_ACTIVE: "true"`** — включена поддержка работы за reverse proxy (учёт заголовков прокси).
- **`PASSBOLT_TRUST_PROXY: "true"`** — приложение доверяет заголовкам от прокси.
- **`PASSBOLT_SSL_FORCE: "false"`** — **главное изменение:** отключено принудительное перенаправление на HTTPS внутри приложения. Терминация SSL остаётся на nginx, пользователь по-прежнему заходит только по https://pass.railway.kg; цикл редиректов исчезает.

---

## Итоговая конфигурация (релевантные фрагменты)

### docker-compose.yaml (pass)

- Entrypoint: `/entrypoint-wrapper.sh`.
- Volumes: gpg, jwt, сертификат `wildcard.railway.kg.crt` в `/usr/local/share/ca-certificates/railway.kg.crt`, скрипт `scripts/entrypoint-wrapper.sh`.
- Переменные: `PASSBOLT_SSL_FORCE: "false"`, `PASSBOLT_TRUST_PROXY: "true"`, `PASSBOLT_SECURITY_PROXIES_ACTIVE: "true"`, `PASSBOLT_CHECK_DOMAIN_MISMATCH: "false"`, `PASSBOLT_FULL_BASE_URL: "https://pass.railway.kg"` (и остальные из текущего файла).

### Nginx

- В `location /` для pass.railway.kg передаются заголовки: Host, X-Forwarded-Host, X-Forwarded-Port, X-Forwarded-Proto, Forwarded, X-Real-IP, X-Forwarded-For.
- После правок конфига nginx перезагружен: `docker exec nginx nginx -s reload`.

### Файл scripts/entrypoint-wrapper.sh

- Проверяет наличие сертификата в `/usr/local/share/ca-certificates/railway.kg.crt`, при наличии запускает `update-ca-certificates`, затем `exec "$@"` для штатного запуска контейнера.

---

## Доступ к приложению

- Основной интерфейс: **https://pass.railway.kg/app/**
- Страница входа: **https://pass.railway.kg/login** (редирект на `/auth/login`).

При необходимости очистить кэш и куки для домена pass.railway.kg или открыть сайт в режиме инкогнито.
