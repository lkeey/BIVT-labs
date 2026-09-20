# Лабораторные работы по SQL

В этом разделе хранятся лабораторные работы по Transact-SQL и локальная учебная
среда SQL Server 2019 с базой `AdventureWorksLT2019`.

## Быстрый запуск

Требуются Docker Desktop для Apple Silicon, Rosetta 2, не менее 4 ГиБ памяти для
Docker и около 10 ГиБ свободного места. Подробная инструкция и описание
ограничений находятся в [`docker/README.md`](docker/README.md).

```bash
cd 03SQL/docker
./scripts/setup.sh
```

Параметры подключения:

| Параметр | Значение |
| --- | --- |
| Сервер | `127.0.0.1,1433` |
| Аутентификация | SQL Login |
| Пользователь | `sa` |
| Пароль | значение `MSSQL_SA_PASSWORD` из `docker/.env` |
| База данных | `AdventureWorksLT2019` |
| Trust Server Certificate | `true` |

Для запросов рекомендуется Visual Studio Code с расширением Microsoft MSSQL.

## Управление средой

```bash
cd 03SQL/docker

# Проверить состояние
./scripts/compose.sh ps -a

# Посмотреть логи
./scripts/compose.sh logs --tail 100 sqlserver

# Остановить и удалить контейнеры, сохранив данные
./scripts/compose.sh down

# Запустить и проверить среду снова
./scripts/setup.sh
```

Команда `./scripts/compose.sh down -v` удаляет базу и все сделанные в ней
изменения. Используйте её только для осознанного полного сброса.

## Лабораторные

| № | Тема | Материалы | Статус |
| --- | --- | --- | --- |
| 01 | Введение в Transact-SQL | [`lab01/README.md`](lab01/README.md), [`lab01/solution.sql`](lab01/solution.sql) | В работе |

## Как сохраняются решения

Сначала студент присылает идею и запрос для очередного пункта. После проверки
на локальной `AdventureWorksLT2019` идея добавляется в README лабораторной, а
запрос — в `solution.sql`. Запросы `UPDATE`, необходимые по условию, проверяются
в транзакции с обязательным `ROLLBACK`.

Файлы `docker/.env` и `docker/.cache/` локальные и не попадают в Git.
