# Краткое описание
Отличный менеджер паролей, который подойдет для корпоративных пользователей.


# Как пользоваться

## Перед установкой
как выяснилось перед установкой надо создать две папки и назначить права:
```
md gpg
md jwt
chown -R www-data gpg
chown -R www-data jwt
```


## Установка
```
docker-compose up -d
```

## Удаление
```
docker-compose down
```

## Создание пользователя
После установки, необходимо создать пользователя:
```
docker exec iPass su -m -c "/usr/share/php/passbolt/bin/cake passbolt register_user -u Ilias.Aidar@ismarty.pro -f Ilias -l Aidar -r admin" -s /bin/sh www-data
```

## Если не работает почта... ручной способ
Подключение к базе данных:
```
mysql -uLogin -pPassword -h 192.168.0.10 Databasename
```
SQL Query:
Отобразить всех пользователей для получения нужного ID пользователя user_id:
```
select * from users;
```

Получение токена:
```
select user_id, token from authentication_tokens where user_id = '<user_id>' and type = 'recover' order by created desc limit 1;
```

Пример ссылки:
https://pass.example.com/setup/recover/<user_id>/<recovery_token>?case=default


### Важное примечание
Очень критично наличие рабочего почтового ящика, потому как Passbolt будет отправлять письма с ссылками для авторизации пользователей.
