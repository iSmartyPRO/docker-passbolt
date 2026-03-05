#!/bin/sh
# Добавляет CA-сертификат в доверенные (из docker-compose монтируется в /usr/local/share/ca-certificates).
# Нужно для прохождения healthcheck при работе за reverse proxy с кастомным SSL.
if [ -f /usr/local/share/ca-certificates/custom.crt ] && [ -s /usr/local/share/ca-certificates/custom.crt ]; then
  update-ca-certificates 2>/dev/null || true
fi
exec "$@"
