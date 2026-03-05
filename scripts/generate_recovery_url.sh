#!/bin/bash
set -e

# Переход в корень проекта — скрипт можно вызывать из любой директории
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT"

if [ ! -f ".env" ]; then
    echo "Error: .env not found in $PROJECT_ROOT"
    exit 1
fi
set -a
source .env
set +a

# Проверка аргументов
if [ $# -ne 2 ]; then
    echo "Usage: $0 passboltUrl=<hostname> username=<email>"
    echo "Example: $0 passboltUrl=pass.example.com username=admin@example.com"
    exit 1
fi

passboltUrl=""
username=""
for arg in "$@"; do
    case $arg in
        passboltUrl=*)
            passboltUrl="${arg#*=}"
            ;;
        username=*)
            username="${arg#*=}"
            ;;
        *)
            echo "Invalid argument: $arg"
            exit 1
            ;;
    esac
done

if [ -z "$passboltUrl" ] || [ -z "$username" ]; then
    echo "Error: passboltUrl and username are required."
    exit 1
fi

# Убираем протокол из URL, если передан
passboltUrl="${passboltUrl#https://}"
passboltUrl="${passboltUrl#http://}"

for var in DATASOURCES_DEFAULT_HOST DATASOURCES_DEFAULT_USERNAME DATASOURCES_DEFAULT_PASSWORD DATASOURCES_DEFAULT_DATABASE; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

export MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD"
trap 'unset MYSQL_PWD' EXIT

user_id=$(docker exec -i "$DATASOURCES_DEFAULT_HOST" mysql \
    -u"$DATASOURCES_DEFAULT_USERNAME" \
    "$DATASOURCES_DEFAULT_DATABASE" -N -e "SELECT id FROM users WHERE username = '$username';" 2>/dev/null | awk '{print $1}')

if [ -z "$user_id" ]; then
    echo "User not found: $username"
    exit 1
fi

token=$(docker exec -i "$DATASOURCES_DEFAULT_HOST" mysql \
    -u"$DATASOURCES_DEFAULT_USERNAME" \
    "$DATASOURCES_DEFAULT_DATABASE" -N -e "SELECT token FROM authentication_tokens WHERE user_id = '$user_id' AND type = 'recover' ORDER BY created DESC LIMIT 1;" 2>/dev/null | awk '{print $1}')

if [ -z "$token" ]; then
    echo "No recovery token found for user ID: $user_id. Request recovery from the login page first."
    exit 1
fi

url="https://${passboltUrl}/setup/recover/$user_id/$token?case=default"
echo "Recovery URL: $url"
