# Запуск прикладных процессов на одном VPS

Эти файлы дополняют [инструкцию установки SQL Server 2025 Express](../../docs/vps-express.md).
Они рассчитаны на Ubuntu 24.04, SQL Server на этом же хосте и отдельное
HTTPS-имя API. До запуска нужны готовая база `SocialNetworkDB`, два SQL-логина
с ролями `coursework_api` и `coursework_worker`, сертификат SQL для `localhost`,
публичный Firebase Web API key и доступная модель ответа. Ни один пример с
`REPLACE_` не является рабочим секретом.

После установки и настройки SQL Server из корня `03SQL-CourseWork/` примените
[`tools/apply-vps-database.sh`](../../tools/apply-vps-database.sh). Он принимает
пароль `sa` из `SQLCMDPASSWORD` или спрашивает его в терминале; пароль не
передаётся в аргументах `sqlcmd`. Скрипт использует TLS с проверкой
сертификата для `localhost` и пропускает учебные данные `11-demo.sql`.
Если база уже существует, скрипт останавливается, чтобы не переиграть
инициализацию поверх пользовательских данных; после частичного сбоя
администратор должен осмотреть базу и решить, как восстановить развёртывание.
Затем администратор создаёт отдельные SQL-логины и пользователей базы для
двух ролей из `database/17-auth-and-roles.sql`. Имена SQL-логинов совпадают
с DSN в примерах окружения, а имена пользователей базы отличаются от имён
ролей, поскольку они находятся в одном пространстве имён:

```sql
USE master;
GO
CREATE LOGIN [coursework_api] WITH PASSWORD = 'REPLACE_WITH_RANDOM_API_PASSWORD', CHECK_POLICY = ON;
GO
CREATE LOGIN [coursework_worker] WITH PASSWORD = 'REPLACE_WITH_RANDOM_WORKER_PASSWORD', CHECK_POLICY = ON;
GO
USE SocialNetworkDB;
GO
CREATE USER [coursework_api_runtime] FOR LOGIN [coursework_api];
CREATE USER [coursework_worker_runtime] FOR LOGIN [coursework_worker];
ALTER ROLE [coursework_api] ADD MEMBER [coursework_api_runtime];
ALTER ROLE [coursework_worker] ADD MEMBER [coursework_worker_runtime];
GO
```

Подставьте разные случайные пароли, сохраните их только в соответствующих
`api.env` и `index.env`, выполняйте SQL через приватное соединение с сервером.
Пароль API кодируйте как URL-компонент в `SQLSERVER_DSN`; пароль worker
записывайте с экранированием по правилам ODBC connection string.
Не передавайте текст `CREATE LOGIN` с паролями в аргументе shell-команды.
При создании через `sqlcmd` вводите команды в его интерактивном режиме и
не сохраняйте SQL с подставленными паролями в репозитории.

## Размещение файлов

Операции выполняются из корня клона репозитория после получения нужного
коммита. Установите Go версии из
[`backend/go.mod`](../../backend/go.mod), Python 3.11+, Python venv, ODBC
Driver 18, `tesseract-ocr`, `tesseract-ocr-rus` и Caddy. Пакеты SQL Server и
Full-Text ставятся отдельно по основной инструкции. Системные пользователи
не имеют права входа и собственного домашнего каталога:

```sh
sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin coursework-api
sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin coursework-index
sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin coursework-embed
sudo install -d -m 0755 /opt/sql-coursework /opt/sql-coursework/bin /etc/sql-coursework
git archive --format=tar HEAD 03SQL-CourseWork/backend 03SQL-CourseWork/worker | sudo tar -xf - -C /opt/sql-coursework --strip-components=1
go -C /opt/sql-coursework/backend build -o /tmp/coursework-api .
sudo install -m 0755 /tmp/coursework-api /opt/sql-coursework/bin/coursework-api
sudo python3 -m venv /opt/sql-coursework/venv
sudo /opt/sql-coursework/venv/bin/python -m pip install -r /opt/sql-coursework/worker/requirements.txt
```

Команды создания пользователей выполняются один раз. При обновлении кода
повторите копирование исходников, сборку и перезапуск изменённых служб;
`git archive` переносит только файлы коммита и не копирует локальные секреты.

Создайте файлы окружения из `*.env.example` в `/etc/sql-coursework/`. Для
`api.env` задайте `root:coursework-api`, для `index.env` —
`root:coursework-index`, для `embed.env` — `root:coursework-embed`; режим каждого
файла — `0640`, каталог `/etc/sql-coursework` — `0755`. Замените все примеры
паролей; указанную в образце модель загрузите перед запуском API. Firebase
Web API key возьмите из конфигурации веб-приложения того же проекта и задайте
как `FIREBASE_WEB_API_KEY`; сервисный JSON не требуется. Не печатайте секреты в истории shell
или журнале. Сертификат, которому доверяют Go и ODBC, должен соответствовать
`localhost` в SAN; `TrustServerCertificate` остаётся `false` / `no`.

`embed_service.py` слушает только `127.0.0.1:8765`, поэтому в этой схеме
Bearer-токен ему не нужен. Оба Python-процесса скачивают закреплённую E5-модель
в собственные системные кеши. Это дублирует модель на диске, зато у
индексатора нет доступа к файлам embedding-сервиса и наоборот. Модель
предварительно загрузите до приёма документов, если исходящий доступ к
Hugging Face на сервере ограничен.

## Службы и HTTPS

После заполнения окружения установите unit-файлы и включите службы:

```sh
sudo install -m 0644 03SQL-CourseWork/deploy/vps/coursework-api.service /etc/systemd/system/
sudo install -m 0644 03SQL-CourseWork/deploy/vps/coursework-index.service /etc/systemd/system/
sudo install -m 0644 03SQL-CourseWork/deploy/vps/coursework-embed.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now coursework-embed coursework-index coursework-api
```

Установите [`Caddyfile.example`](Caddyfile.example) как Caddyfile и замените
`api.example.com` реальным DNS-именем, указывающим на VPS. Для учебной
демонстрации можно использовать бесплатное имя вида
`api.<IPv4-адрес-VPS>.sslip.io` без регистрации домена;
[sslip.io](https://sslip.io/) возвращает адрес, встроенный в имя. Убедитесь,
что DNS-ответ совпадает с публичным IP VPS. Для постоянного адреса лучше
собственный домен: имя `sslip.io` зависит от стороннего DNS-сервиса.
Разрешите входящие 80/443; Caddy самостоятельно получает публичный
TLS-сертификат. Перед
перезапуском проверьте `caddy validate --config /etc/caddy/Caddyfile`.
`reverse_proxy` оставляет путь `/api/v1/...` без изменений и ждёт ответ
дольше максимальных 90 секунд RAG-маршрута. SQL (1433), Go API (8081),
embedding (8765) и локальная LLM (если есть) доступны лишь через loopback.
Задайте `network.ipaddress=127.0.0.1` для SQL Server через `mssql-conf` и
перезапустите его; дополнительно запретите внешний 1433 в firewall хостинга.

Если используется локальный Ollama, установите его как отдельную службу и
слушайте только `127.0.0.1:11434`. Стартовый выбор для сервера с 12 ГБ RAM —
[`qwen3:4b-instruct-2507-q4_K_M`](https://ollama.com/library/qwen3:4b-instruct-2507-q4_K_M)
(вес файла около 2,5 ГБ): выполните `ollama pull qwen3:4b-instruct-2507-q4_K_M`.
Именно это имя уже указано в образце `api.env`, который направляет
запросы на OpenAI-совместимый маршрут Ollama. Проверьте, что имя присутствует
в `/v1/models`, и выполните короткий пробный `POST /v1/chat/completions`
до запуска API: ответ должен успевать за 45 секунд, отведённых backend на
генерацию:

```sh
curl --fail-with-body --max-time 45 -sS http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3:4b-instruct-2507-q4_K_M","messages":[{"role":"user","content":"Ответь одним предложением по-русски."}],"max_tokens":100,"stream":false}'
```

Размер файла модели не равен её полному потреблению RAM; если
памяти или скорости не хватает, используйте меньшую модель либо внешний
HTTPS endpoint.
Внешняя LLM требует HTTPS endpoint и отдельного ключа в `api.env`.

Публичную конфигурацию [сайта](../../web/public/config.js) переключайте на
новый API только после того, как `GET /healthz`, `GET /readyz`, аутентификация
Firebase, публикация с индексацией и RAG-ответ с цитатами работают на
реальном адресе. До этого `backendReady` должен оставаться `false`.
