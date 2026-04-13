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
    echo "  $0 <email>                    — base URL from APP_FULL_BASE_URL / PASSBOLT_FULL_BASE_URL in .env"
    echo "  $0 --host=<host> --user=<email>   — override public host (https:// added if scheme omitted)"
    echo "  $0 --host <host> --user <email>   — same as above"
    echo "  $0                            — interactive (username; asks for URL if base URL missing in .env)"
    echo ""
    echo "Legacy (still supported):"
    echo "  $0 passboltUrl=<host> username=<email>"
    exit 1
}

passbolt_host_override=""
username=""
positional=()

if [ $# -eq 0 ]; then
    if [ -z "${APP_FULL_BASE_URL:-}" ] && [ -z "${PASSBOLT_FULL_BASE_URL:-}" ]; then
        read -r -p "Base URL (e.g. https://pass.example.com): " APP_FULL_BASE_URL
    fi
    read -r -p "Username (email): " username
else
    while [ $# -gt 0 ]; do
        case $1 in
            --host=*)
                passbolt_host_override="${1#*=}"
                shift
                ;;
            --host)
                if [ -z "${2:-}" ]; then
                    echo "Error: --host requires a value."
                    usage
                fi
                passbolt_host_override="$2"
                shift 2
                ;;
            --user=*)
                username="${1#*=}"
                shift
                ;;
            --user)
                if [ -z "${2:-}" ]; then
                    echo "Error: --user requires a value."
                    usage
                fi
                username="$2"
                shift 2
                ;;
            passboltUrl=*)
                passbolt_host_override="${1#*=}"
                shift
                ;;
            username=*)
                username="${1#*=}"
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo "Unknown option: $1"
                usage
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    if [ "${#positional[@]}" -gt 1 ]; then
        echo "Error: at most one positional argument (email) is allowed."
        usage
    fi
    if [ "${#positional[@]}" -eq 1 ] && [ -n "$username" ]; then
        echo "Error: use either --user=... or one positional email, not both."
        usage
    fi
    if [ "${#positional[@]}" -eq 1 ]; then
        username="${positional[0]}"
    fi
fi

if [ -z "$username" ]; then
    echo "Error: username (email) is required."
    exit 1
fi

# Recovery link base: .env or --host / passboltUrl (hostname only)
if [ -n "$passbolt_host_override" ]; then
    h="${passbolt_host_override#https://}"
    h="${h#http://}"
    h="${h%/}"
    recovery_base="https://${h}"
else
    base="${APP_FULL_BASE_URL:-${PASSBOLT_FULL_BASE_URL:-}}"
    if [ -z "$base" ]; then
        echo "Error: set APP_FULL_BASE_URL in .env or use --host=..."
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
