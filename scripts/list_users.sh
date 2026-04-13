#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT"

if [ ! -f ".env" ]; then
    echo "Error: .env not found in $PROJECT_ROOT"
    exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

for var in DATASOURCES_DEFAULT_HOST DATASOURCES_DEFAULT_USERNAME DATASOURCES_DEFAULT_PASSWORD DATASOURCES_DEFAULT_DATABASE; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

export MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD"
trap 'unset MYSQL_PWD' EXIT

# Same rules as backup.sh: docker exec only when host is a container name (or BACKUP_DB_CONTAINER)
DB_CONTAINER=""
if [ -n "${BACKUP_DB_CONTAINER:-}" ]; then
    DB_CONTAINER="$BACKUP_DB_CONTAINER"
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$DATASOURCES_DEFAULT_HOST"; then
    DB_CONTAINER="$DATASOURCES_DEFAULT_HOST"
fi

run_mysql() {
    if [ -n "$DB_CONTAINER" ]; then
        docker exec -i -e MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD" "$DB_CONTAINER" mysql \
            -h 127.0.0.1 -P "${DATASOURCES_DEFAULT_PORT:-3306}" \
            -u"$DATASOURCES_DEFAULT_USERNAME" \
            "$DATASOURCES_DEFAULT_DATABASE" "$@"
    else
        if ! command -v mysql >/dev/null 2>&1; then
            echo "Error: mysql client not found. Install mariadb-client (or mysql-client), or set BACKUP_DB_CONTAINER in .env for docker exec."
            exit 1
        fi
        mysql -h "$DATASOURCES_DEFAULT_HOST" -P "${DATASOURCES_DEFAULT_PORT:-3306}" \
            -u"$DATASOURCES_DEFAULT_USERNAME" \
            "$DATASOURCES_DEFAULT_DATABASE" "$@"
    fi
}

# List Passbolt users (roles from roles table, CE schema)
run_mysql --table -e "
SELECT
    u.id AS id,
    u.username AS email,
    COALESCE(NULLIF(TRIM(CONCAT(COALESCE(p.first_name, ''), ' ', COALESCE(p.last_name, ''))), ''), '-') AS name,
    COALESCE(r.name, CONCAT('role_id=', u.role_id)) AS role,
    u.active AS active
FROM users u
LEFT JOIN roles r ON r.id = u.role_id
LEFT JOIN profiles p ON p.user_id = u.id
ORDER BY u.id;
"
