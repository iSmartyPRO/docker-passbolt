#!/bin/sh
# Trust the CA certificate mounted at /usr/local/share/ca-certificates/custom.crt (from docker-compose).
# Helps health checks when Passbolt sits behind a reverse proxy with custom TLS.
if [ -f /usr/local/share/ca-certificates/custom.crt ] && [ -s /usr/local/share/ca-certificates/custom.crt ]; then
  update-ca-certificates 2>/dev/null || true
fi
exec "$@"
