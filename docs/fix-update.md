# Passbolt behind nginx (reverse proxy)

This guide covers **terminating TLS at nginx** and proxying to the Passbolt container from this repository, plus common issues: healthcheck failures from inside the container, Compose YAML errors, and browser redirect loops.

**See also:** [Documentation index](README.md) · [Root README](../README.md) · [docker-compose.yaml](../docker-compose.yaml) · [scripts/entrypoint-wrapper.sh](../scripts/entrypoint-wrapper.sh) · **Example nginx:** [nginx.passbolt.example.conf](nginx.passbolt.example.conf)

---

## Table of contents

- [Nginx reverse proxy](#nginx-reverse-proxy)
  - [Example configuration file](#example-configuration-file)
  - [Choosing the upstream URL](#choosing-the-upstream-url)
  - [Passbolt environment variables](#passbolt-environment-variables)
  - [Apply and verify](#apply-and-verify)
- [Troubleshooting: healthcheck URL](#troubleshooting-healthcheck-url)
- [Troubleshooting: YAML errors in Compose](#troubleshooting-yaml-errors-in-compose)
- [Troubleshooting: ERR_TOO_MANY_REDIRECTS](#troubleshooting-err_too_many_redirects)
- [Pre-production checklist](#pre-production-checklist)

---

## Nginx reverse proxy

Typical layout:

1. Clients use **HTTPS** to **nginx** (your certificate on nginx).
2. Nginx proxies to Passbolt over **HTTP** on the port published by Docker (container port **80** → host port from **`DOCKER_HTTP_PORT`** in `.env`, e.g. `8088`), *or* over HTTP directly to the container hostname on the Docker network (no host port needed).
3. Passbolt’s **public** URL in `.env` remains **`https://your-domain`** (`APP_FULL_BASE_URL`, `PASSBOLT_FULL_BASE_URL`).

Nginx must send forwarding headers so Passbolt builds correct URLs and knows the original scheme (**HTTPS**), even though the hop from nginx to the container is HTTP.

### Example configuration file

A full commented example lives in the repo:

**[docs/nginx.passbolt.example.conf](nginx.passbolt.example.conf)**

It includes:

- An **`upstream`** block pointing at Passbolt’s HTTP endpoint.
- **`listen 443 ssl http2`** with placeholder TLS paths.
- Optional **HTTP → HTTPS** redirect on port 80 (with a stub for ACME `/.well-known/acme-challenge/`).
- A **`location /`** block with `proxy_pass` and the headers listed below.
- **`client_max_body_size`** for uploads (adjust to your policy).

Copy the file (or merge the `server` / `upstream` blocks) into your nginx layout, then edit `server_name`, certificates, and upstream.

### Choosing the upstream URL

| Deployment | `proxy_pass` target (example) |
|------------|-------------------------------|
| Nginx on the **same host** as Docker; Passbolt maps **`DOCKER_HTTP_PORT:80`** (e.g. `8088:80`) | `http://127.0.0.1:8088` (use your real host port) |
| Nginx in a **container** on the **same Docker network** as Passbolt (`DOCKER_NETWORK_NAME`) | `http://CONTAINER_NAME:80` where `CONTAINER_NAME` is **`DOCKER_CONTAINER_NAME`** from `.env` (often `pass`) |

Ensure nginx can reach that address (firewall, `docker network connect`, etc.).

### Passbolt environment variables

Align `.env` (and therefore `docker-compose.yaml`) with proxy mode:

| Variable | Value behind nginx (typical) | Purpose |
|----------|------------------------------|---------|
| `APP_FULL_BASE_URL` | `https://pass.example.com` | Public URL (HTTPS) |
| `PASSBOLT_FULL_BASE_URL` | Same as above | Passbolt base URL |
| `PASSBOLT_SECURITY_PROXIES_ACTIVE` | `true` | Use proxy headers |
| `PASSBOLT_TRUST_PROXY` | `true` | Trust headers from nginx |
| `PASSBOLT_SSL_FORCE` | `false` | Avoid redirect loop: TLS ends at nginx; container sees HTTP |

Headers nginx should set (see the example file):

- `Host`, `X-Real-IP`, `X-Forwarded-For`
- **`X-Forwarded-Proto`** — usually `$scheme` on the TLS vhost (so Passbolt sees `https`)
- `X-Forwarded-Host`, `X-Forwarded-Port`
- Optional: `Forwarded` (RFC 7239), e.g. `proto=$scheme;host=$host`

### Apply and verify

```bash
nginx -t && nginx -s reload
# or, if nginx runs in Docker:
docker exec <nginx-container> nginx -t && docker exec <nginx-container> nginx -s reload
```

Open `https://your-domain` and run `make healthcheck` (or `cake passbolt healthcheck`) from the project root when the stack is up.

---

## Troubleshooting: healthcheck URL

**Symptom:** `passbolt healthcheck` reports that the healthcheck URL is unreachable. A frequent cause is HTTPS from the container to a certificate the container OS **does not trust** (internal CA, self-signed certificate, etc.).

**What this repo does:**

1. **Mount a CA into the container**  
   In [docker-compose.yaml](../docker-compose.yaml), a trusted CA (or chain) is mounted at  
   `/usr/local/share/ca-certificates/custom.crt`  
   The host path is **`SSL_CA_CERT_PATH`** (default `./ssl/custom.crt` in [.env.example](../.env.example)).

2. **Entrypoint wrapper** — [scripts/entrypoint-wrapper.sh](../scripts/entrypoint-wrapper.sh)  
   On start, if the file exists and is non-empty, `update-ca-certificates` runs, then the image’s normal entrypoint runs. OpenSSL/curl inside the container then trust your CA when calling the public URL.

3. **Environment variable**  
   `PASSBOLT_CHECK_DOMAIN_MISMATCH=false` reduces false failures when the certificate name and configuration differ (enable deliberately; see Passbolt docs).

Compose already sets `entrypoint: ["/entrypoint-wrapper.sh"]` and mounts the wrapper and CA. Ensure the script is executable: `chmod +x scripts/entrypoint-wrapper.sh`.

---

## Troubleshooting: YAML errors in Compose

**Symptom:** `did not find expected key` or similar when running `docker compose up` / `down`.

**Cause:** Wrong indentation in `docker-compose.yaml` under the service (`volumes`, `command`, `ports`, `environment`).

**Rule:** Keys directly under `passbolt:` use **4 spaces**; list items under those keys use **6 spaces**. A YAML linter or editor highlighting helps catch drift.

---

## Troubleshooting: ERR_TOO_MANY_REDIRECTS

**Symptom:** The browser reports too many redirects.

**Typical cause:** TLS terminates at **nginx**, traffic to the Passbolt container is **HTTP**, while the app forces HTTPS redirects — creating a loop.

**Fix:** Set **`PASSBOLT_SSL_FORCE=false`** and ensure nginx sends **`X-Forwarded-Proto`** (and related headers) as in [nginx.passbolt.example.conf](nginx.passbolt.example.conf). Keep public URLs in `.env` as **`https://...`**.

---

## Pre-production checklist

- [ ] `.env` has the correct public HTTPS URL.
- [ ] Nginx config tested with `nginx -t`; TLS and `server_name` match your domain.
- [ ] Upstream host/port or container name matches how Passbolt is actually reachable from nginx.
- [ ] Nginx sends `X-Forwarded-Proto` (and other headers as in the example).
- [ ] `PASSBOLT_TRUST_PROXY` and `PASSBOLT_SECURITY_PROXIES_ACTIVE` match your security policy (trust only your nginx).
- [ ] For custom TLS on healthcheck: CA file present, `SSL_CA_CERT_PATH` set, `entrypoint-wrapper.sh` runs.
- [ ] `docker compose config` succeeds with no errors.

See also [Passbolt documentation](https://www.passbolt.com/docs) for deployment and proxy guidance.
