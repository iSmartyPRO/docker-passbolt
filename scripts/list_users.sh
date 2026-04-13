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

# List Passbolt users (roles from roles table, CE schema)
docker exec -i -e MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD" "$DATASOURCES_DEFAULT_HOST" mysql \
    -u"$DATASOURCES_DEFAULT_USERNAME" \
    "$DATASOURCES_DEFAULT_DATABASE" --table -e "
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
