# Лабораторная среда SQL Server 2019 в Colima

Этот каталог запускает SQL Server 2019 Developer в Docker через Colima и
восстанавливает учебную базу `AdventureWorksLT2019`. Контейнер и volume
используются в профиле Colima `sqlserver`.

> **Ограничение:** образ SQL Server рассчитан на Linux x86-64. На Apple Silicon
> Colima запускает его с эмуляцией `linux/amd64`; Microsoft не тестирует и не
> поддерживает эмуляцию SQL Server. Используйте эту конфигурацию для учебных
> работ, не для production.

## Что понадобится

- macOS на Apple Silicon и Colima с профилем `sqlserver`;
- не менее 10 ГиБ свободного места;
- Docker CLI и Compose v2;
- Visual Studio Code и расширение Microsoft `MSSQL` (`ms-mssql.mssql`).

Установите инструменты, если их ещё нет:

```bash
brew install colima docker docker-compose
```

Профиль Colima должен использовать Docker runtime, VZ и Rosetta для amd64.
Проверьте `~/.colima/sqlserver/colima.yaml`: `runtime: docker`, `vmType: vz`,
`rosetta: true`, не менее 4 ГиБ памяти и 100 ГиБ диска. Запустите профиль:

```bash
colima start --profile sqlserver
```

Скрипты проекта обращаются к Docker context `colima-sqlserver`, не переключая
глобально Docker на другой runtime. Для Compose v2 Homebrew требует добавить
`/opt/homebrew/lib/docker/cli-plugins` в `cliPluginsExtraDirs` файла
`~/.docker/config.json`.

Azure Data Studio завершил поддержку 28 февраля 2026 года. На macOS используйте
Visual Studio Code с расширением MSSQL. SSMS доступен только на Windows.

## Первый запуск

```bash
cd 03SQL/docker
./scripts/setup.sh
```

Скрипт:

1. проверит Docker context Colima, Compose, amd64-эмуляцию, свободное место и
   порт `1433`;
2. если контейнер `adventure-db` уже есть, запустит его при необходимости и
   проверит базу, не перезаписывая её и не создавая новый пароль;
3. если контейнера нет, создаст `.env` с сильным случайным паролем `sa` и
   правами `0600`, скачает официальный `AdventureWorksLT2019.bak` и проверит
   размер и SHA-256;
4. запустит SQL Server 2019 Developer и дождётся готовности;
5. запустит одноразовый сервис `db-init`, который восстановит базу только в
   том случае, если она ещё не существует;
6. выполнит тестовый запрос к `SalesLT.Customer`.

Повторный запуск безопасен: существующая база в состоянии `ONLINE` не
перезаписывается. Backup и init-скрипт подключаются к контейнерам только для
чтения.

## Подключение из VS Code

Workspace рекомендует расширение `ms-mssql.mssql`. Установите его, если оно
ещё не установлено:

```bash
code --install-extension ms-mssql.mssql
```

В корневой папке workspace уже настроен профиль
`BIVT-labs AdventureWorksLT2019 (Colima)`. Откройте `.sql`-файл, выполните
**MS SQL: Connect** через палитру `F1` и выберите этот профиль. При первом
подключении введите пароль `sa` из `.env`; расширение сохранит его в системном
хранилище секретов, не в настройках workspace.

Параметры профиля:

| Параметр | Значение |
| --- | --- |
| Server | `127.0.0.1` |
| Port | `1433` |
| Authentication | `SQL Login` |
| User | `sa` |
| Password | значение `MSSQL_SA_PASSWORD` из `.env` |
| Database | `AdventureWorksLT2019` |
| Trust Server Certificate | `true` |

Посмотреть локально сохранённый пароль:

```bash
sed -n 's/^MSSQL_SA_PASSWORD=//p' .env
```

Windows Authentication и `(localdb)\MSSQLLocalDB` к Linux-контейнеру на macOS
не применяются.

Проверочный запрос:

```sql
SELECT TOP (10) *
FROM SalesLT.Customer
ORDER BY CustomerID;
```

## Управление базой в Colima

Команды выполняются из корня репозитория:

```bash
# Состояние базы
./03SQL/docker/scripts/colima.sh status

# Логи SQL Server
./03SQL/docker/scripts/colima.sh logs

# Остановить, сохранив контейнер и данные
./03SQL/docker/scripts/colima.sh stop

# Запустить снова
./03SQL/docker/scripts/colima.sh start
```

Команда `stop` останавливает только контейнер. База хранится в именованном
Docker volume `sql-server-lab-data`.

## Полный сброс — удаляет все изменения

Следующая команда **безвозвратно удаляет именованный том и все изменения в
учебной базе**:

```bash
docker --context colima-sqlserver rm -f adventure-db
docker --context colima-sqlserver volume rm sql-server-lab-data
./03SQL/docker/scripts/setup.sh
```

Эта последовательность удаляет контейнер и все изменения в базе. Не
используйте её для обычной остановки.

## Диагностика

- **Порт 1433 занят.** `setup.sh` принимает только контейнер `adventure-db`.
  Для чужого процесса он завершится с ошибкой; найдите процесс командой
  `lsof -nP -iTCP:1433 -sTCP:LISTEN`.
- **Контейнер долго запускается.** Эмуляция amd64 на Apple Silicon заметно
  медленнее нативных контейнеров. Проверьте
  `./03SQL/docker/scripts/colima.sh logs`.
- **Ошибка контрольной суммы резервной копии.** Удалите только повреждённый файл
  `.cache/AdventureWorksLT2019.bak` и снова запустите `./scripts/setup.sh`.
- **База существует не в состоянии ONLINE.** Автоматическое восстановление не
  перезаписывает её. Сначала сохраните нужные данные, затем осознанно выполните
  полный сброс из раздела выше.

## Официальные источники

- [Запуск SQL Server в Docker и ограничения архитектуры](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker?view=sql-server-ver17)
- [Восстановление базы в Linux-контейнере](https://learn.microsoft.com/en-us/sql/linux/migrate/tutorial-restore-backup-sql-server-container?view=sql-server-ver15)
- [Базы AdventureWorks](https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver17)
- [Завершение поддержки Azure Data Studio](https://learn.microsoft.com/en-us/sql/tools/whats-happening-azure-data-studio?view=sql-server-ver17)
- [Colima: Docker contexts and socket](https://github.com/abiosoft/colima/blob/main/docs/FAQ.md)
