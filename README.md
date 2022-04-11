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

### Важное примечание
Очень критично наличие рабочего почтового ящика, потому как Passbolt будет отправлять письма с ссылками для авторизации пользователей.
