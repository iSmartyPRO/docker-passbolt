#!/bin/bash

# Подключение переменных из .env
source .env

# Проверка аргументов
if [ $# -ne 2 ]; then
  echo "Usage: $0 passboltUrl=<url> username=<email>"
  exit 1
fi

# Извлечение аргументов
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

# Запрос ID пользователя
user_id=$(docker exec -i "$DATASOURCES_DEFAULT_HOST" mysql \
  -u"$DATASOURCES_DEFAULT_USERNAME" \
  -p"$DATASOURCES_DEFAULT_PASSWORD" \
  pass -N -e "SELECT id FROM users WHERE username = '$username';" | awk '{print $1}')

if [ -z "$user_id" ]; then
  echo "User not found for username: $username"
  exit 1
fi

# Запрос токена
token=$(docker exec -i "$DATASOURCES_DEFAULT_HOST" mysql \
  -u"$DATASOURCES_DEFAULT_USERNAME" \
  -p"$DATASOURCES_DEFAULT_PASSWORD" \
  pass -N -e "SELECT token FROM authentication_tokens WHERE user_id = '$user_id' AND type = 'recover' ORDER BY created DESC LIMIT 1;" | awk '{print $1}')

if [ -z "$token" ]; then
  echo "No recovery token found for user ID: $user_id"
  exit 1
fi

# Формирование URL
url="https://$passboltUrl/setup/recover/$user_id/$token?case=default"

# Вывод URL
echo "Recovery URL: $url"
