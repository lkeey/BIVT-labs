# Лабораторные работы по SQL

В этом разделе хранятся лабораторные работы по Transact-SQL и локальная учебная
среда SQL Server 2019 с базой `AdventureWorksLT2019`.

## Первый запуск базы данных

Требуются Colima для Apple Silicon с Docker runtime, VZ и Rosetta для amd64,
не менее 4 ГиБ памяти и около 10 ГиБ свободного места. Подробная инструкция и
описание ограничений находятся в [`docker/README.md`](docker/README.md).

```bash
cd 03SQL/docker
./scripts/setup.sh
```

Запустите профиль Colima `sqlserver` командой `colima start --profile sqlserver`.
Скрипт использует Docker context `colima-sqlserver`. Если контейнер
`adventure-db` уже существует, скрипт проверяет его и сохраняет текущие данные;
для новой установки создаёт контейнер и восстанавливает `AdventureWorksLT2019`.

Параметры подключения:

| Параметр | Значение |
| --- | --- |
| Сервер | `127.0.0.1,1433` |
| Аутентификация | SQL Login |
| Пользователь | `sa` |
| Пароль | значение `MSSQL_SA_PASSWORD` из `docker/.env` |
| База данных | `AdventureWorksLT2019` |
| Trust Server Certificate | `true` |

Для запросов используется Visual Studio Code с расширением Microsoft MSSQL.

## Как включать и выключать базу данных

Команды выполняются из корня репозитория `BIVT-labs`.

```bash
# Включить ранее остановленную базу
./03SQL/docker/scripts/colima.sh start

# Выключить базу, сохранив контейнер и все данные
./03SQL/docker/scripts/colima.sh stop

# Проверить состояние
./03SQL/docker/scripts/colima.sh status

# Посмотреть логи
./03SQL/docker/scripts/colima.sh logs
```

После первого запуска для повседневной работы достаточно команд `start` и
`stop`. Остановка контейнера сохраняет базу в Docker volume.

Если контейнер был удалён командой `down`, запустите setup ещё раз:

```bash
# Снова создать контейнер и включить базу
./03SQL/docker/scripts/setup.sh
```

Полный сброс базы требует удаления контейнера и volume вручную. Команды,
удаляющие volume, приведены в [`docker/README.md`](docker/README.md); они
безвозвратно удаляют все изменения в базе.

## Как выполнить запрос в Visual Studio Code

Создавать новый SQL-файл для первой лабораторной не нужно. Удобнее открыть в
VS Code весь репозиторий `BIVT-labs`, а затем готовый файл
[`03SQL/lab01/solution.sql`](lab01/solution.sql). Можно открыть только каталог
`03SQL`, но тогда в командах терминала опускайте начальную часть `03SQL/`,
например используйте `./docker/scripts/colima.sh status`.

1. Убедитесь, что профиль Colima и база запущены:

   ```bash
   ./03SQL/docker/scripts/colima.sh status
   ```

2. Откройте палитру команд клавишей `F1` и выберите **MS SQL: Connect**.
   Workspace уже содержит профиль `BIVT-labs AdventureWorksLT2019 (Colima)`.
3. При первом подключении введите пароль SQL Login `sa` из локального файла
   `03SQL/docker/.env`. MSSQL сохранит его в системном хранилище секретов, а не
   в файлах репозитория. Профиль использует `127.0.0.1,1433` и базу
   `AdventureWorksLT2019`.

   Если нужно посмотреть пароль локально, выполните:

   ```bash
   sed -n 's/^MSSQL_SA_PASSWORD=//p' 03SQL/docker/.env
   ```

4. Напишите запрос под комментарием нужного задания. Чтобы выполнить только
   этот запрос, выделите его и нажмите `Cmd+Shift+E`. Без выделения расширение
   выполнит весь SQL-файл.
5. Результат появится в панели под редактором.

Команды управления базой доступны также из **Terminal → Run Task** под именами
`AdventureWorks: Start database`, `Stop database`, `Status` и `Logs`.

Подключение назначается конкретному SQL-редактору. Если новый `.sql`-файл не
подключился автоматически, снова выполните **MS SQL: Connect**.

## Лабораторные

| № | Тема | Материалы | Статус |
| --- | --- | --- | --- |
| 01 | Введение в Transact-SQL | [`lab01/README.md`](lab01/README.md), [`lab01/solution.sql`](lab01/solution.sql) | Выполнена |
| 02 | Запросы к таблицам SELECT | [`lab02/README.md`](lab02/README.md), [`lab02/solution.sql`](lab02/solution.sql) | Выполнена |

## Как сохраняются решения

Сначала студент присылает идею и запрос для очередного пункта. После проверки
на локальной `AdventureWorksLT2019` идея добавляется в README лабораторной, а
запрос — в `solution.sql`. Запросы `UPDATE`, необходимые по условию, проверяются
в транзакции с обязательным `ROLLBACK`.

Файлы `docker/.env` и `docker/.cache/` локальные и не попадают в Git.
