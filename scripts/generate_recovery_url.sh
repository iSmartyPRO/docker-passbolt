#!/bin/bash
set -e

# Run from project root (script cd's here; can be invoked from any directory)
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

usage() {
    echo "Usage:"
    echo "  $0 <username>              — base URL from APP_FULL_BASE_URL in .env"
    echo "  $0                        — interactive prompts (username; asks for URL if APP_FULL_BASE_URL is empty)"
    echo "  $0 passboltUrl=<host> username=<email>  — override host (https:// added if omitted)"
    exit 1
}

passbolt_host_override=""
username=""

if [ $# -eq 0 ]; then
    if [ -z "${APP_FULL_BASE_URL:-}" ] && [ -z "${PASSBOLT_FULL_BASE_URL:-}" ]; then
        read -r -p "Base URL (e.g. https://pass.example.com): " APP_FULL_BASE_URL
    fi
    read -r -p "Username (email): " username
elif [ $# -eq 1 ]; then
    username="$1"
elif [ $# -eq 2 ]; then
    for arg in "$@"; do
        case $arg in
            passboltUrl=*)
                passbolt_host_override="${arg#*=}"
                ;;
            username=*)
                username="${arg#*=}"
                ;;
            *)
                echo "Invalid argument: $arg"
                usage
                ;;
        esac
    done
else
    echo "Too many arguments."
    usage
fi

if [ -z "$username" ]; then
    echo "Error: username is required."
    exit 1
fi

# Recovery link base: APP_FULL_BASE_URL from .env or legacy passboltUrl (hostname only)
if [ -n "$passbolt_host_override" ]; then
    h="${passbolt_host_override#https://}"
    h="${h#http://}"
    h="${h%/}"
    recovery_base="https://${h}"
else
    base="${APP_FULL_BASE_URL:-${PASSBOLT_FULL_BASE_URL:-}}"
    if [ -z "$base" ]; then
        echo "Error: set APP_FULL_BASE_URL in .env or use passboltUrl=..."
        exit 1
    fi
    recovery_base="${base%/}"
fi

for var in DATASOURCES_DEFAULT_HOST DATASOURCES_DEFAULT_USERNAME DATASOURCES_DEFAULT_PASSWORD DATASOURCES_DEFAULT_DATABASE; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

export MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD"
trap 'unset MYSQL_PWD' EXIT

user_id=$(docker exec -i -e MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD" "$DATASOURCES_DEFAULT_HOST" mysql \
    -u"$DATASOURCES_DEFAULT_USERNAME" \
    "$DATASOURCES_DEFAULT_DATABASE" -N -e "SELECT id FROM users WHERE username = '$username';" 2>/dev/null | awk '{print $1}')

if [ -z "$user_id" ]; then
    echo "User not found: $username"
    exit 1
fi

token=$(docker exec -i -e MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD" "$DATASOURCES_DEFAULT_HOST" mysql \
    -u"$DATASOURCES_DEFAULT_USERNAME" \
    "$DATASOURCES_DEFAULT_DATABASE" -N -e "SELECT token FROM authentication_tokens WHERE user_id = '$user_id' AND type = 'recover' ORDER BY created DESC LIMIT 1;" 2>/dev/null | awk '{print $1}')

if [ -z "$token" ]; then
    echo "No recovery token found for user ID: $user_id. Request recovery from the login page first."
    exit 1
fi

url="${recovery_base}/setup/recover/${user_id}/${token}?case=default"
echo "Recovery URL: $url"
