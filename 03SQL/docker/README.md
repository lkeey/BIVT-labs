# Лабораторная среда SQL Server 2019

Этот каталог запускает SQL Server 2019 Developer в Docker и автоматически
восстанавливает учебную базу `AdventureWorksLT2019`.

> **Важно:** официальный образ SQL Server поддерживается только на Linux с
> процессорами x86-64. На Apple Silicon он запускается через эмуляцию
> `linux/amd64`, которую Microsoft не тестирует и не поддерживает. Эта среда
> предназначена только для учебных работ и разработки, не для production.

## Что понадобится

- macOS на Apple Silicon и установленная Rosetta 2;
- не менее 10 ГиБ свободного места;
- [Docker Desktop для Mac с Apple Silicon](https://docs.docker.com/desktop/setup/install/mac-install/);
- Visual Studio Code и расширение Microsoft `MSSQL` (`ms-mssql.mssql`).

В Docker Desktop выберите **Settings → General → Virtual Machine Manager →
Apple Virtualization Framework** и включите **Use Rosetta for x86_64/amd64
emulation**. Docker VMM для этой лабораторной не подходит, потому что он не
поддерживает ускорение Rosetta. В **Settings → Resources** выделите Docker не
менее 4 ГиБ памяти.

Azure Data Studio завершил поддержку 28 февраля 2026 года. На macOS используйте
Visual Studio Code с расширением MSSQL. SSMS доступен только на Windows.

## Первый запуск

```bash
cd 03SQL/docker
./scripts/setup.sh
```

Скрипт:

1. проверит Docker, Compose, Rosetta, свободное место и порт `1433`;
2. создаст `.env` с сильным случайным паролем `sa` и правами `0600`;
3. скачает официальный `AdventureWorksLT2019.bak` и проверит размер и SHA-256;
4. запустит SQL Server 2019 Developer и дождётся состояния `healthy`;
5. запустит одноразовый сервис `db-init`, который восстановит базу только в
   том случае, если она ещё не существует;
6. выполнит `DBCC CHECKDB` и тестовый запрос к `SalesLT.Customer`.

Повторный запуск безопасен: существующая база в состоянии `ONLINE` не
перезаписывается. Backup и init-скрипт подключаются к контейнерам только для
чтения.

## Подключение из VS Code

Установите расширение, если оно ещё не установлено:

```bash
code --install-extension ms-mssql.mssql
```

Создайте подключение со следующими параметрами:

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

## Управление контейнером

Все команды выполняются из каталога `03SQL/docker`:

```bash
# Состояние сервисов
./scripts/compose.sh ps -a

# Логи SQL Server
./scripts/compose.sh logs --tail 100 sqlserver

# Остановить, сохранив контейнер и данные
./scripts/compose.sh stop

# Запустить снова
./scripts/compose.sh start

# Удалить контейнеры, но сохранить базу в именованном томе
./scripts/compose.sh down

# Повторно создать контейнер и проверить/восстановить базу
./scripts/setup.sh
```

## Полный сброс — удаляет все изменения

Следующая команда **безвозвратно удаляет именованный том и все изменения в
учебной базе**:

```bash
./scripts/compose.sh down -v
./scripts/setup.sh
```

Обычная команда `./scripts/compose.sh down` без `-v` данные не удаляет.

Обёртка `compose.sh` обращается к локальному engine-сокету Docker Desktop
напрямую. Это обходит зависание API-прокси Docker Desktop при запуске
эмулируемых amd64-контейнеров и не открывает Docker API по сети.

## Диагностика

- **Порт 1433 занят.** `setup.sh` принимает только контейнер этого Compose-проекта.
  Для чужого процесса он завершится с ошибкой; найдите процесс командой
  `lsof -nP -iTCP:1433 -sTCP:LISTEN`.
- **Контейнер долго запускается.** Эмуляция amd64 на Apple Silicon заметно
  медленнее нативных контейнеров. Проверьте
  `./scripts/compose.sh logs --tail 100 sqlserver`.
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
- [Настройки виртуализации Docker Desktop](https://docs.docker.com/desktop/features/vmm/)
